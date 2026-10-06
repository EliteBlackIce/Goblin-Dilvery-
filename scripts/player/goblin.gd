class_name Goblin
extends CharacterBody3D
## Hybrid goblin controller.
##
##   Normal movement   -> this CharacterBody3D (tight, responsive input)
##   Big reactions     -> temporary GoblinRagdoll (RigidBody3D limbs + joints)
##   Personality       -> GoblinRig (springy procedural animation)
##
## The comedy comes from the body, not from stealing control: input is always
## read, buffered jumps and coyote time keep platforming fair, and stumbles
## only cap speed briefly. Real control loss (ragdoll) happens only on clear
## causes — explosions, big hits, huge falls, tumbling down cliffs, losing
## balance completely — and the player can wiggle and mash out of it.

signal health_changed(hp: int, max_hp: int)
signal camera_shake(amount: float)
signal camera_kick(dir: Vector3, amount: float)
signal ragdoll_started
signal ragdoll_ended
signal knocked_out
signal landed(impact: float)
signal teleported(pos: Vector3)

enum State { NORMAL, STUMBLE, RAGDOLL, RECOVERING }

const LAYER_PLAYER := 2
const MASK_PLAYER := 1 | 4 | 8

@export_group("Speed")
@export var walk_speed := 5.2
@export var sprint_speed := 9.0
@export var ground_accel := 32.0
@export var sprint_accel := 24.0
@export var stop_decel := 30.0
@export var air_accel := 10.0
@export_group("Turning / momentum")
@export var walk_turn_rate := 18.0
@export var sprint_turn_rate := 9.0
@export var body_turn_speed := 16.0
@export var skid_angle := 2.4
@export_group("Jumping")
@export var gravity := 26.0
@export var fall_gravity_mult := 1.5
@export var jump_velocity := 9.2
@export var max_fall_speed := 45.0
@export var coyote_time := 0.12
@export var jump_buffer := 0.14
@export_group("Clumsiness")
@export var stumble_threshold := 0.6
@export var land_stumble_impact := 20.0
@export var land_ragdoll_impact := 28.0
@export var hit_ragdoll_force := 11.0
@export var random_trip_chance := 0.012
@export var trip_cooldown_time := 25.0
@export_group("Health")
@export var max_health := 6

var state := State.NORMAL
var health := 6
var rig: GoblinRig
var carrier: PackageCarrier
var ragdoll: GoblinRagdoll

# Read by the rig / camera / HUD.
var prev_physics_pos := Vector3.ZERO
var facing_yaw := 0.0
var turn_rate := 0.0
var wish_dir := Vector3.ZERO
var grounded := true
var sprinting := false
var skidding := false
var stumble_amount := 0.0
var balance := 0.0
var carry_pose := "none"
var carry_weight := 0.0
var camera_yaw := 0.0
var current_interactable: Node = null
var control_enabled := true
var kill_y := -80.0
var respawn_point := Vector3(0, 5, 0)
var last_safe_pos := Vector3.ZERO

var _coyote_t := 0.0
var _jump_buffer_t := 0.0
var _air_time := 0.0
var _wall_slide_t := 0.0
var _stumble_t := 0.0
var _recover_t := 0.0
var _invuln_t := 0.0
var _trip_cd := 8.0
var _attack_cd := 0.0
var _attack_hit_t := -1.0
var _interact_scan_t := 0.0
var _safe_t := 0.0
var _was_skidding := false
var _time := 0.0
var _attack_requested := false


func _ready() -> void:
	add_to_group("player")
	add_to_group("explodable")
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_PLAYER
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.45
	floor_constant_speed = true
	safe_margin = 0.02
	health = max_health

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.25
	shape.shape = capsule
	shape.position = Vector3(0, 0.63, 0)
	add_child(shape)

	rig = GoblinRig.new()
	rig.name = "Rig"
	rig.goblin = self
	if GameState.equipped.has("hat"):
		rig.hat_style = Items.get_item(GameState.equipped["hat"]).get("hat", "cap")
	add_child(rig)
	rig.footstep.connect(_on_footstep)

	carrier = PackageCarrier.new()
	carrier.name = "Carrier"
	carrier.goblin = self
	add_child(carrier)

	prev_physics_pos = global_position
	last_safe_pos = global_position


# ===========================================================================
# Main loop
# ===========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("attack"):
		# A click that only captures the mouse shouldn't swing the satchel.
		if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return
		_attack_requested = true


func _physics_process(delta: float) -> void:
	_time += delta
	prev_physics_pos = global_position
	_invuln_t -= delta
	_trip_cd -= delta
	_attack_cd -= delta

	var input := Vector2.ZERO
	if control_enabled and not GameState.input_locked:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	wish_dir = Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0, input.y)
	if wish_dir.length() > 1.0:
		wish_dir = wish_dir.normalized()

	match state:
		State.RAGDOLL:
			_tick_ragdoll(delta)
		State.RECOVERING:
			_recover_t -= delta
			velocity.x = move_toward(velocity.x, 0, stop_decel * delta)
			velocity.z = move_toward(velocity.z, 0, stop_decel * delta)
			_apply_gravity(delta, false)
			move_and_slide()
			grounded = is_on_floor()
			# Mashing a direction lets you shake it off a bit early.
			if _recover_t <= 0.0 or (_recover_t < 0.25 and wish_dir.length() > 0.3):
				state = State.NORMAL
		_:
			_tick_movement(delta)

	carry_pose = carrier.carry_pose()
	carry_weight = carrier.total_weight()

	_interact_scan_t -= delta
	if _interact_scan_t <= 0.0:
		_interact_scan_t = 0.1
		_scan_interactables()

	if state != State.RAGDOLL and global_position.y < kill_y:
		_fell_out_of_world()


func _tick_movement(delta: float) -> void:
	var mods := carrier.get_modifiers()
	var stability: float = GameState.stat("stability")
	var can_act := control_enabled and not GameState.input_locked
	var input_strength := minf(wish_dir.length(), 1.0)

	sprinting = can_act and Input.is_action_pressed("sprint") and input_strength > 0.3
	var max_speed: float = (sprint_speed if sprinting else walk_speed) * mods["speed"] * GameState.stat("speed")
	if state == State.STUMBLE:
		max_speed = minf(max_speed, walk_speed * 1.2)

	var hv := Vector3(velocity.x, 0, velocity.z)
	var speed := hv.length()
	skidding = false

	if grounded:
		if input_strength > 0.05:
			var target_dir := wish_dir.normalized()
			var target_speed := max_speed * input_strength
			if speed > 0.6:
				var cur_dir := hv / speed
				var ang := cur_dir.signed_angle_to(target_dir, Vector3.UP)
				if absf(ang) > skid_angle and speed > 7.5:
					# Reversing at speed: skid, flail, kick up dust.
					skidding = true
					hv = hv.move_toward(Vector3.ZERO, stop_decel * 1.4 * delta)
					if not _was_skidding:
						rig.on_skid()
						balance += 0.12 * (1.0 + mods["instability"]) / stability
						FX.dust(global_position, 1.2)
				else:
					# Momentum: the velocity direction can only rotate so fast,
					# and slower the faster (and heavier) you go.
					var fast := clampf((speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0)
					var tr: float = lerpf(walk_turn_rate, sprint_turn_rate, fast) * mods["turn"]
					var step := clampf(ang, -tr * delta, tr * delta)
					cur_dir = cur_dir.rotated(Vector3.UP, step)
					var accel: float = (sprint_accel if speed > walk_speed else ground_accel) * mods["accel"]
					var new_speed := move_toward(speed, target_speed, accel * delta)
					hv = cur_dir * new_speed
			else:
				hv = hv.move_toward(target_dir * target_speed, ground_accel * mods["accel"] * delta)
		else:
			hv = hv.move_toward(Vector3.ZERO, stop_decel * delta)
	else:
		if input_strength > 0.05:
			var target := wish_dir * maxf(max_speed, speed)
			hv = hv.move_toward(target, air_accel * delta)

	_was_skidding = skidding
	velocity.x = hv.x
	velocity.z = hv.z

	# --- Jumping -----------------------------------------------------------
	if grounded:
		_coyote_t = coyote_time
	else:
		_coyote_t -= delta
	if can_act and Input.is_action_just_pressed("jump"):
		_jump_buffer_t = jump_buffer
	else:
		_jump_buffer_t -= delta
	var jumped := false
	if _jump_buffer_t > 0.0 and _coyote_t > 0.0:
		velocity.y = jump_velocity * mods["jump"] * GameState.stat("jump")
		_jump_buffer_t = 0.0
		_coyote_t = 0.0
		jumped = true
		rig.on_jump()
	_apply_gravity(delta, jumped, mods["gravity"])

	# --- Move --------------------------------------------------------------
	var pre_vy := velocity.y
	var was_grounded := grounded
	move_and_slide()
	grounded = is_on_floor()
	_push_rigid_bodies(hv)

	if grounded and not was_grounded:
		_on_landed(-pre_vy)
	_check_bump(hv)
	_check_hard_stop(hv, input_strength)
	if grounded:
		_air_time = 0.0
	else:
		_air_time += delta

	# Tumbling down something too steep to stand on.
	if not grounded and is_on_wall() and velocity.y < -9.0:
		_wall_slide_t += delta
		if _wall_slide_t > 0.6:
			var down := get_wall_normal()
			down.y = 0
			start_ragdoll(down.normalized() * 4.0 + Vector3.DOWN * 2.0, 7.0)
			GameState.toast("Wheeeee—", Color(1, 0.9, 0.5))
			return
	else:
		_wall_slide_t = maxf(0.0, _wall_slide_t - delta)

	# --- Facing (body catches up with the velocity) ------------------------
	var prev_yaw := facing_yaw
	var face_dir := Vector3.ZERO
	if skidding:
		face_dir = Vector3.ZERO  # keep facing the old way while sliding
	elif hv.length() > 0.4:
		face_dir = hv
	elif input_strength > 0.1:
		face_dir = wish_dir
	if face_dir != Vector3.ZERO:
		var target_yaw := atan2(-face_dir.x, -face_dir.z)
		var turn_speed := body_turn_speed * (0.55 if sprinting else 1.0)
		facing_yaw = _approach_angle(facing_yaw, target_yaw, turn_speed * delta)
	turn_rate = lerpf(turn_rate, wrapf(facing_yaw - prev_yaw, -PI, PI) / maxf(delta, 0.0001), 1.0 - exp(-12.0 * delta))

	_update_balance(delta, mods, stability, speed)

	# --- Actions -------------------------------------------------------------
	if can_act and Input.is_action_just_pressed("interact") and current_interactable != null:
		if is_instance_valid(current_interactable):
			current_interactable.interact(self)
	if _attack_requested and can_act and _attack_cd <= 0.0:
		_start_attack()
	_attack_requested = false
	if _attack_hit_t >= 0.0:
		_attack_hit_t -= delta
		if _attack_hit_t < 0.0:
			_resolve_attack()

	if grounded and state == State.NORMAL and balance < 0.2:
		_safe_t -= delta
		if _safe_t <= 0.0:
			_safe_t = 0.5
			last_safe_pos = global_position


func _apply_gravity(delta: float, jumped: bool, gravity_mult := 1.0) -> void:
	if grounded and not jumped:
		return
	var g := gravity * gravity_mult
	if velocity.y < 0.0:
		g *= fall_gravity_mult
	elif not Input.is_action_pressed("jump") or GameState.input_locked:
		g *= 2.2  # short hop when jump is released early
	velocity.y = maxf(velocity.y - g * delta, -max_fall_speed)


func _update_balance(delta: float, _mods: Dictionary, _stability: float, _speed: float) -> void:
	# Balance only builds from real events (hits, hard landings); it never
	# nudges you around on its own, so normal control is always reliable.
	balance = maxf(0.0, balance - 1.2 * delta)
	if state == State.STUMBLE:
		_stumble_t -= delta
		stumble_amount = clampf(_stumble_t / 0.35, 0.0, 1.0)
		if _stumble_t <= 0.0:
			state = State.NORMAL
			stumble_amount = 0.0
	else:
		stumble_amount = move_toward(stumble_amount, 0.0, delta * 4.0)
	if balance >= 1.0:
		trip()


static func _approach_angle(from: float, to: float, max_step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	return from + clampf(diff, -max_step, max_step)


func _on_landed(impact: float) -> void:
	rig.on_land(impact)
	landed.emit(impact)
	carrier.on_impact(impact)
	if impact > 10.0:
		camera_shake.emit(clampf((impact - 10.0) / 22.0, 0.0, 0.55))
		FX.dust(global_position, clampf(impact / 12.0, 0.6, 2.2))
	var stability: float = GameState.stat("stability") * GameState.stat("landing")
	if impact > land_ragdoll_impact * stability:
		var fwd := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
		if impact > 30.0:
			take_damage(1)
		start_ragdoll(fwd * 3.0 + Vector3.UP * 1.0, 5.0)
		GameState.toast("SPLAT.", Color(1, 0.6, 0.4))
	elif impact > land_stumble_impact * stability:
		balance += 0.25 + (impact - land_stumble_impact) * 0.05
		start_stumble(0.7)


var _bump_cd := 0.0
var _was_fast := false


## Running face-first into a wall: a little "bonk!" bounce, not a control loss.
func _check_bump(hv: Vector3) -> void:
	_bump_cd -= get_physics_process_delta_time()
	if _bump_cd > 0.0 or not is_on_wall() or hv.length() < 5.5:
		return
	var n := get_wall_normal()
	n.y = 0.0
	if n.length() < 0.5 or hv.normalized().dot(-n.normalized()) < 0.7:
		return
	_bump_cd = 0.8
	velocity.x = n.x * 3.0
	velocity.z = n.z * 3.0
	rig.on_hit(n, 3.0)
	rig.set_expression("ouch", 0.5)
	camera_kick.emit(n, 0.3)
	start_stumble(0.35)
	FX.dust(global_position + Vector3.UP * 0.8 - n * 0.4, 0.7)


## Letting go of the stick at a sprint: a quick cartoon foot-slide.
func _check_hard_stop(hv: Vector3, input_strength: float) -> void:
	var fast := hv.length() > 7.0 and grounded
	if _was_fast and input_strength < 0.05 and grounded and hv.length() > 3.0:
		rig.on_skid()
		FX.dust(global_position, 0.8)
		_was_fast = false
	elif fast:
		_was_fast = true
	elif hv.length() < 1.0:
		_was_fast = false


func _push_rigid_bodies(hv: Vector3) -> void:
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var body := col.get_collider()
		if body is RigidBody3D:
			var rb := body as RigidBody3D
			var n := col.get_normal()
			var push := -n * (0.6 + hv.length() * 0.35)
			push.y = maxf(push.y, 0.0)
			rb.apply_impulse(push * minf(rb.mass, 4.0) * 0.5, col.get_position() - rb.global_position)
			# Something heavy rolling INTO us knocks us around.
			var rel := rb.linear_velocity.dot(n)
			if rel > 5.0 and rb.mass > 2.0:
				take_hit(n, rel * 0.9, 1)


# ===========================================================================
# Stumbles, hits, explosions
# ===========================================================================

func start_stumble(duration: float) -> void:
	if state == State.RAGDOLL or state == State.RECOVERING:
		return
	state = State.STUMBLE
	_stumble_t = maxf(_stumble_t, duration)
	stumble_amount = 1.0


func trip() -> void:
	var fwd := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	balance = 0.0
	start_ragdoll(fwd * (2.0 + velocity.length() * 0.3) + Vector3.UP * 1.5, 4.0)
	GameState.toast(WorldText.pick_trip_line(), Color(1, 0.9, 0.6))


## How noticeable the goblin is to enemies (sneaking = walking, no loud parcels).
func noise() -> float:
	return (1.3 if sprinting else 0.8) * carrier.get_modifiers()["noise"] * GameState.stat("noise")


func is_busy() -> bool:
	return state != State.NORMAL or not grounded


## Generic hit (enemy club, flying barrel...). `dir` points away from the source.
func take_hit(dir: Vector3, force: float, damage: int) -> void:
	if _invuln_t > 0.0 or state == State.RAGDOLL:
		return
	_invuln_t = 0.6
	GameState.note_hit()
	if GameState.stat_add("armor") > 0.0 and randf() < 0.5:
		damage = maxi(0, damage - 1)  # the pot helmet goes BONG
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.0001 else Vector3(-sin(facing_yaw), 0, -cos(facing_yaw)) * -1.0
	take_damage(damage)
	carrier.on_hit(force)
	camera_kick.emit(dir, clampf(force / 10.0, 0.2, 1.0))
	camera_shake.emit(clampf(force / 30.0, 0.1, 0.4))
	var knock := dir * force * 1.5
	if force >= hit_ragdoll_force * GameState.stat("stability") or health <= 0:
		start_ragdoll(knock + Vector3.UP * force * 0.5, 6.0 + force * 0.3)
	else:
		velocity = Vector3(knock.x, maxf(velocity.y, force * 0.45), knock.z)
		grounded = false
		balance += force * 0.03
		start_stumble(0.6)
		rig.on_hit(dir, force * 0.35)


func apply_explosion(center: Vector3, radius: float, force: float, damage: int) -> void:
	var to_me := global_position + Vector3.UP * 0.6 - center
	var dist := to_me.length()
	if dist > radius:
		return
	var falloff := 1.0 - dist / radius
	var dir := (to_me.normalized() + Vector3.UP * 0.9).normalized()
	if state != State.RAGDOLL:
		take_damage(maxi(1, int(round(damage * falloff))))
	carrier.on_hit(force * falloff)
	camera_shake.emit(clampf(0.3 + falloff * 0.4, 0.0, 0.7))
	start_ragdoll(dir * force * (0.4 + falloff), 10.0 + 8.0 * falloff)
	_invuln_t = 0.8


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)


func heal(amount: int) -> void:
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)


# ===========================================================================
# Ragdoll
# ===========================================================================

func start_ragdoll(impulse: Vector3, spin := 6.0) -> void:
	if state == State.RAGDOLL and ragdoll != null:
		ragdoll.torso.apply_central_impulse(impulse * ragdoll.torso.mass)
		return
	state = State.RAGDOLL
	stumble_amount = 0.0
	skidding = false
	ragdoll = GoblinRagdoll.new()
	ragdoll.name = "GoblinRagdoll"
	get_parent().add_child(ragdoll)
	ragdoll.build(rig, velocity, impulse, spin)
	rig.visible = false
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	carrier.on_ragdoll()
	camera_shake.emit(0.25)
	ragdoll_started.emit()


func _tick_ragdoll(delta: float) -> void:
	if ragdoll == null:
		state = State.NORMAL
		return
	var wiggle := control_enabled and not GameState.input_locked and Input.is_action_just_pressed("jump")
	ragdoll.tick(delta, wiggle_dir(), wiggle)
	global_position = ragdoll.center() - Vector3(0, 0.6, 0)
	velocity = ragdoll.average_velocity()
	grounded = false
	if ragdoll.center().y < kill_y:
		_end_ragdoll()
		_fell_out_of_world()
		return
	if ragdoll.is_settled():
		_end_ragdoll()


func wiggle_dir() -> Vector3:
	return wish_dir


func _end_ragdoll() -> void:
	var c := ragdoll.center()
	var yaw := ragdoll.facing_yaw()
	ragdoll.queue_free()
	ragdoll = null
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(c + Vector3.UP * 1.0, c + Vector3.DOWN * 60.0, 1)
	var hit := space.intersect_ray(q)
	var p: Vector3 = hit["position"] if not hit.is_empty() else c - Vector3(0, 0.3, 0)
	global_position = p + Vector3.UP * 0.05
	prev_physics_pos = global_position
	facing_yaw = yaw
	collision_layer = LAYER_PLAYER
	collision_mask = MASK_PLAYER
	velocity = Vector3.ZERO
	rig.visible = true
	rig.reset_pose()
	rig.play_getup()
	state = State.RECOVERING
	_recover_t = 0.45 / GameState.stat("recovery")
	ragdoll_ended.emit()
	if health <= 0:
		_knock_out()


func _knock_out() -> void:
	knocked_out.emit()
	health = max_health
	health_changed.emit(health, max_health)
	teleport(respawn_point)


func _fell_out_of_world() -> void:
	GameState.toast("A passing eagle returns you to solid ground. It charges a fee.", Color(1, 0.8, 0.5))
	GameState.add_gold(-mini(GameState.gold, 5))
	take_damage(1)
	teleport(last_safe_pos + Vector3.UP * 1.0)


func teleport(pos: Vector3) -> void:
	if ragdoll != null:
		ragdoll.queue_free()
		ragdoll = null
		rig.visible = true
		collision_layer = LAYER_PLAYER
		collision_mask = MASK_PLAYER
	state = State.NORMAL
	teleported.emit(pos)  # lets the world stream in ground before we land
	global_position = pos
	prev_physics_pos = pos
	velocity = Vector3.ZERO
	balance = 0.0
	rig.reset_pose()


func camera_target() -> Vector3:
	if ragdoll != null:
		return ragdoll.center() + Vector3.UP * 0.5
	return rig.global_position + Vector3.UP * 1.15


# ===========================================================================
# Attack ("the satchel bonk") and interaction
# ===========================================================================

func _start_attack() -> void:
	if state != State.NORMAL and state != State.STUMBLE:
		return
	_attack_cd = 0.5
	_attack_hit_t = 0.14
	rig.play_attack()


func _resolve_attack() -> void:
	var fwd := Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))
	var origin := global_position + Vector3.UP * 0.6
	var hit_any := false
	for n in get_tree().get_nodes_in_group("hittable"):
		if not (n is Node3D) or n == self:
			continue
		var to: Vector3 = (n as Node3D).global_position - origin
		to.y *= 0.5
		if to.length() < 2.0 and fwd.dot(to.normalized()) > 0.25:
			n.on_bonk(self, (fwd + Vector3.UP * 0.35).normalized(), 7.0)
			hit_any = true
	velocity += fwd * 2.5  # comedic lunge
	if hit_any:
		camera_shake.emit(0.12)
		carrier.on_bonk()


func _scan_interactables() -> void:
	var best: Node = null
	var best_d := 1e9
	if state == State.NORMAL or state == State.STUMBLE:
		for n in get_tree().get_nodes_in_group("interactable"):
			if not (n is Node3D):
				continue
			if n.has_method("can_interact") and not n.can_interact(self):
				continue
			var radius: float = n.get("interact_radius") if n.get("interact_radius") != null else 2.5
			var d := ((n as Node3D).global_position - global_position).length()
			if d < radius and d < best_d:
				best = n
				best_d = d
	current_interactable = best


func _on_footstep(pos: Vector3, strength: float) -> void:
	if strength > 0.45:
		FX.dust(pos, strength * 0.6)
