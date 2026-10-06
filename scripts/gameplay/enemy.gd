class_name Enemy
extends CharacterBody3D
## Simple, readable enemies whose job is to create physical comedy:
## they telegraph (big anticipation), then smack the goblin with exaggerated
## knockback. They get bonked around just as cartoonishly in return.
##
##   bandit  wind-up, then a club swing that knocks you stumbling
##   boar    paws the ground, then CHARGES — a direct hit launches you
##   rat     small, fast, nibbly
##   brute   dungeon boss: slow, enormous ground slam

enum S { IDLE, CHASE, WINDUP, ATTACK, RECOVER, STUNNED, HIDDEN }

const TYPES := {
	"bandit": {"hp": 3, "speed": 4.2, "aggro": 13.0, "range": 1.8, "windup": 0.55, "damage": 1, "force": 8.0, "scale": 1.0, "loot": 4},
	"boar": {"hp": 4, "speed": 3.0, "aggro": 15.0, "range": 9.0, "windup": 0.8, "damage": 1, "force": 13.0, "scale": 1.0, "loot": 3},
	"rat": {"hp": 1, "speed": 5.5, "aggro": 10.0, "range": 1.2, "windup": 0.3, "damage": 1, "force": 4.0, "scale": 0.55, "loot": 1},
	"brute": {"hp": 10, "speed": 3.0, "aggro": 14.0, "range": 2.8, "windup": 0.9, "damage": 2, "force": 15.0, "scale": 1.7, "loot": 20},
}

var type_id := "bandit"
var def: Dictionary
var placement_id := ""
var ambush := false
var hp := 3
var state := S.IDLE
var home := Vector3.ZERO
var gravity := 26.0

var _t := 0.0
var _state_t := 0.0
var _wander := Vector3.ZERO
var _charge_dir := Vector3.ZERO
var _hit_done := false
var _visual: Node3D
var _weapon: Node3D
var _squash := Spring.new(220.0, 9.0)
var _lean := Spring.new(90.0, 8.0)
var _spin := 0.0
var _flash_t := 0.0
var _mesh_inst: MeshInstance3D
var _rng := RandomNumberGenerator.new()


func setup(t: String, pid: String, is_ambush := false) -> void:
	type_id = t if TYPES.has(t) else "bandit"
	placement_id = pid
	ambush = is_ambush


func _ready() -> void:
	def = TYPES[type_id]
	hp = def["hp"]
	home = global_position
	_wander = home
	_rng.seed = placement_id.hash()
	add_to_group("enemy")
	add_to_group("hittable")
	add_to_group("explodable")
	collision_layer = 4
	collision_mask = 1 | 2 | 4 | 8
	floor_max_angle = deg_to_rad(50)
	var s: float = def["scale"]
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4 * s
	cap.height = maxf(1.3 * s, cap.radius * 2.0 + 0.05)
	if type_id == "boar":
		cap.height = 1.0
		cap.radius = 0.45
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	add_child(cs)
	_build_visual()
	if ambush:
		state = S.HIDDEN
		_visual.visible = false


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var k := MeshKit.new(type_id.hash())
	match type_id:
		"boar":
			var fur := Color(0.45, 0.3, 0.2)
			k.sphere(MeshKit.at(Vector3(0, 0.55, 0.05), 0, Vector3(0.8, 0.75, 1.25)), 0.5, fur, 8, 5)
			k.sphere(MeshKit.at(Vector3(0, 0.62, -0.55), 0, Vector3(0.9, 0.85, 1.0)), 0.32, fur.darkened(0.1), 7, 5)
			k.cylinder(MeshKit.rot(Vector3(0, 0.55, -0.85), Vector3(PI * 0.5, 0, 0)), 0.14, 0.14, 0.16, Color(0.85, 0.55, 0.55), 7)
			for sx in [-1.0, 1.0]:
				k.cone_between(Vector3(sx * 0.12, 0.48, -0.8), Vector3(sx * 0.22, 0.7, -0.95), 0.05, 0.0, Color(1, 0.97, 0.88), 5)
				k.sphere(MeshKit.at(Vector3(sx * 0.15, 0.75, -0.75)), 0.05, Color(0.1, 0.05, 0.05), 5, 3)
				k.cone_between(Vector3(sx * 0.2, 0.85, -0.45), Vector3(sx * 0.3, 1.1, -0.4), 0.09, 0.0, fur.darkened(0.2), 5)
				for sz in [-0.35, 0.4]:
					k.cylinder(MeshKit.at(Vector3(sx * 0.25, 0.15, sz)), 0.08, 0.07, 0.3, fur.darkened(0.3), 5)
			for i in 5:
				k.cone_between(Vector3(0, 0.95, -0.3 + i * 0.15), Vector3(0, 1.15, -0.25 + i * 0.15), 0.06, 0.0, Color(0.3, 0.2, 0.15), 4)
		"rat":
			var fur := Color(0.5, 0.48, 0.47)
			k.sphere(MeshKit.at(Vector3(0, 0.35, 0), 0, Vector3(0.8, 0.7, 1.2)), 0.4, fur, 7, 5)
			k.sphere(MeshKit.at(Vector3(0, 0.4, -0.45)), 0.22, fur, 6, 4)
			k.sphere(MeshKit.at(Vector3(0, 0.38, -0.66)), 0.06, Color(0.9, 0.5, 0.55), 5, 3)
			for sx in [-1.0, 1.0]:
				k.sphere(MeshKit.at(Vector3(sx * 0.15, 0.62, -0.38), 0, Vector3(1, 1, 0.4)), 0.12, Color(0.9, 0.6, 0.6), 6, 4)
				k.sphere(MeshKit.at(Vector3(sx * 0.09, 0.47, -0.6)), 0.035, Color(0.9, 0.1, 0.1), 4, 3)
			k.cone_between(Vector3(0, 0.3, 0.4), Vector3(0, 0.45, 1.2), 0.05, 0.01, Color(0.9, 0.6, 0.6), 4)
		_:
			var skin := Color(0.9, 0.72, 0.58) if type_id == "bandit" else Color(0.55, 0.62, 0.45)
			var cloth := Color(0.35, 0.27, 0.2) if type_id == "bandit" else Color(0.4, 0.3, 0.3)
			k.sphere(MeshKit.at(Vector3(0, 0.75, 0), 0, Vector3(1.05, 1.2, 0.9)), 0.42, cloth, 8, 5)
			k.cylinder(MeshKit.at(Vector3(0, 0.25, 0)), 0.3, 0.33, 0.5, cloth.darkened(0.3), 8)
			k.sphere(MeshKit.at(Vector3(0, 1.45, 0)), 0.3, skin, 8, 6)
			k.box(MeshKit.at(Vector3(0, 1.5, -0.22)), Vector3(0.62, 0.12, 0.2), Color(0.12, 0.1, 0.1))
			k.box(MeshKit.at(Vector3(0, 1.62, 0)), Vector3(0.62, 0.16, 0.62), Color(0.6, 0.12, 0.1))
			k.cone_between(Vector3(0, 1.62, 0.28), Vector3(0.05, 1.45, 0.6), 0.08, 0.0, Color(0.6, 0.12, 0.1), 5)
			for sx in [-1.0, 1.0]:
				k.sphere(MeshKit.at(Vector3(sx * 0.1, 1.5, -0.3)), 0.045, Color(1, 0.95, 0.4), 5, 3)
				k.cylinder(MeshKit.rot(Vector3(sx * 0.45, 0.85, 0), Vector3(0, 0, sx * 0.3)), 0.08, 0.08, 0.6, skin, 6)
			k.box(MeshKit.at(Vector3(0, 1.28, -0.28)), Vector3(0.22, 0.04, 0.03), Color(0.2, 0.05, 0.05))
	_mesh_inst = Mats.instance(Assets.pick("enemies/" + type_id, k.commit()))
	_visual.add_child(_mesh_inst)
	if type_id == "bandit" or type_id == "brute":
		_weapon = Node3D.new()
		_weapon.position = Vector3(0.5, 1.0, 0)
		_visual.add_child(_weapon)
		var wk := MeshKit.new(9)
		wk.cylinder(MeshKit.at(Vector3(0, 0.35, 0)), 0.05, 0.11, 0.8, Color(0.45, 0.3, 0.18), 6)
		wk.sphere(MeshKit.at(Vector3(0, 0.8, 0)), 0.15, Color(0.4, 0.28, 0.17), 6, 4)
		_weapon.add_child(Mats.instance(Assets.pick("enemies/club", wk.commit())))


func _physics_process(delta: float) -> void:
	var player := GameState.player
	if player == null:
		return
	var to := player.global_position - global_position
	var dist := to.length()
	if dist > 70.0 and state != S.STUNNED:
		return  # sleeping: far enemies cost nothing
	_t += delta
	_state_t += delta
	_flash_t -= delta
	var flat := Vector3(to.x, 0, to.z)
	var dir := flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var player_ok := player.state != Goblin.State.RAGDOLL and player.health > 0
	var speed: float = def["speed"]
	var hv := Vector3(velocity.x, 0, velocity.z)

	match state:
		S.HIDDEN:
			if dist < 12.0:
				state = S.CHASE
				_visual.visible = true
				_squash.kick(8.0)
				FX.poof(global_position + Vector3.UP * 0.5, Color(0.4, 0.6, 0.3))
				GameState.toast("AMBUSH!", Color(1, 0.4, 0.3))
		S.IDLE:
			if (_wander - global_position).length() < 0.6 or _state_t > 6.0:
				_wander = home + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
				_state_t = 0.0
			var wd := _wander - global_position
			wd.y = 0
			hv = hv.move_toward(wd.normalized() * speed * 0.35 if wd.length() > 0.6 else Vector3.ZERO, 10.0 * delta)
			if dist < def["aggro"] * player.noise() and player_ok:
				_go(S.CHASE)
				_squash.kick(5.0)
		S.CHASE:
			if not player_ok or dist > def["aggro"] * 1.8 or (global_position - home).length() > 35.0:
				_go(S.IDLE)
				_wander = home
			elif dist < def["range"] and (type_id != "boar" or dist > 3.0):
				_go(S.WINDUP)
			else:
				var chase_speed := speed if type_id != "boar" else speed * 1.2
				hv = hv.move_toward(dir * chase_speed, 14.0 * delta)
		S.WINDUP:
			hv = hv.move_toward(Vector3.ZERO, 20.0 * delta)
			_charge_dir = dir
			if _state_t > def["windup"]:
				_go(S.ATTACK)
				_hit_done = false
				if type_id == "boar":
					hv = _charge_dir * 12.0
				elif type_id == "brute":
					hv = Vector3.ZERO
				else:
					hv = _charge_dir * 5.0
		S.ATTACK:
			if type_id == "boar":
				hv = _charge_dir * 12.0
				if not _hit_done and dist < 1.5 and player_ok:
					_hit_done = true
					player.take_hit(_charge_dir + Vector3.UP * 0.3, def["force"], def["damage"])
				if _state_t > 1.1 or (is_on_wall() and _state_t > 0.15):
					if is_on_wall():
						_stun(Vector3.ZERO, 1.2)  # BONK into a tree
						GameState.toast("*the boar bonked a tree*", Color(1, 0.9, 0.6))
					else:
						_go(S.RECOVER)
			elif type_id == "brute":
				if not _hit_done and _state_t > 0.12:
					_hit_done = true
					_squash.kick(-8.0)
					FX.dust(global_position + _charge_dir * 1.5, 2.5)
					for g in get_tree().get_nodes_in_group("game_camera"):
						g.add_trauma(0.35)
					if dist < 3.6 and player_ok:
						player.take_hit(dir, def["force"], def["damage"])
				if _state_t > 0.6:
					_go(S.RECOVER)
			else:
				hv = hv.move_toward(Vector3.ZERO, 12.0 * delta)
				if not _hit_done and _state_t > 0.06 and dist < def["range"] + 0.5 and player_ok:
					_hit_done = true
					player.take_hit(dir, def["force"], def["damage"])
					# Bandits go for the goods.
					if type_id == "bandit" and not player.carrier.packages.is_empty() and randf() < 0.35:
						player.carrier.drop_one("A bandit knocked a parcel loose! Grab it!")
				if _state_t > 0.3:
					_go(S.RECOVER)
		S.RECOVER:
			hv = hv.move_toward(Vector3.ZERO, 12.0 * delta)
			if _state_t > 0.7:
				_go(S.CHASE)
		S.STUNNED:
			hv = hv.move_toward(Vector3.ZERO, 6.0 * delta if not is_on_floor() else 14.0 * delta)
			_spin += delta * 14.0 * maxf(0.0, 1.0 - _state_t)
			if _state_t > 0.9 and is_on_floor():
				_go(S.CHASE)

	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = -1.0
	move_and_slide()
	_animate(delta, hv, dir)
	if global_position.y < GameState.player.kill_y:
		queue_free()


func _go(s: S) -> void:
	state = s
	_state_t = 0.0


func _animate(delta: float, hv: Vector3, dir: Vector3) -> void:
	var face := dir if state in [S.CHASE, S.WINDUP, S.ATTACK] else hv
	if state == S.ATTACK:
		face = _charge_dir
	if face.length() > 0.1 and state != S.STUNNED:
		rotation.y = lerp_angle(rotation.y, atan2(-face.x, -face.z), 1.0 - exp(-10.0 * delta))
	var lean_t := 0.0
	match state:
		S.WINDUP:
			lean_t = 0.45  # big anticipation lean back
			_visual.position.x = sin(_t * 40.0) * 0.03 if type_id == "boar" else 0.0
		S.ATTACK:
			lean_t = -0.5
		S.CHASE:
			lean_t = -0.15
	_visual.rotation.x = _lean.step(lean_t, delta)
	_visual.rotation.y = _spin
	var bob := absf(sin(_t * 10.0)) * 0.08 * clampf(hv.length() / 4.0, 0.0, 1.0)
	var sq := _squash.step(0.0, delta)
	var base_s: float = def["scale"] if type_id != "boar" else 1.0
	_visual.scale = Vector3(base_s / sqrt(maxf(1.0 + sq * 0.1, 0.3)), base_s * (1.0 + sq * 0.1), base_s / sqrt(maxf(1.0 + sq * 0.1, 0.3)))
	_visual.position.y = bob
	if _weapon:
		var wr := 0.3
		if state == S.WINDUP:
			wr = -2.4
		elif state == S.ATTACK:
			wr = 1.6
		_weapon.rotation.x = lerpf(_weapon.rotation.x, wr, 1.0 - exp(-18.0 * delta))
	if _flash_t > 0.0:
		_visual.visible = int(_flash_t * 30.0) % 2 == 0
	elif state != S.HIDDEN:
		_visual.visible = true


func _stun(knock: Vector3, duration := 0.9) -> void:
	_go(S.STUNNED)
	velocity = knock
	_spin = 0.0
	_squash.kick(-6.0)
	_flash_t = 0.25


func on_bonk(_g: Node, dir: Vector3, force: float) -> void:
	if state == S.HIDDEN:
		state = S.CHASE
		_visual.visible = true
	hp -= 1
	var knock := dir * force * (1.6 if type_id != "brute" else 0.5)
	knock.y = maxf(knock.y, 4.0 if type_id != "brute" else 1.0)
	_stun(knock)
	FX.puff(global_position + Vector3.UP, Color(1, 1, 0.8), 0.6, 0.3, 0.2)
	if hp <= 0:
		_die()


func apply_explosion(center: Vector3, radius: float, force: float, _damage: int) -> void:
	var to := global_position - center
	if to.length() > radius:
		return
	var falloff := 1.0 - to.length() / radius
	hp -= 3
	_stun((to.normalized() + Vector3.UP).normalized() * force * (0.6 + falloff), 1.5)
	if hp <= 0:
		_die()


func _die() -> void:
	GameState.consume(placement_id)
	FX.poof(global_position + Vector3.UP * 0.6)
	var coins := Pickup.new()
	coins.amount = def["loot"]
	coins.placement_id = ""
	get_parent().add_child(coins)
	coins.global_position = global_position + Vector3.UP * 0.5
	queue_free()
