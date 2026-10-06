class_name GoblinCamera
extends Node3D
## Third-person orbit camera. Sits far enough back to show off the goblin's
## whole-body animation, collides with the world via a SpringArm3D, and
## reacts *subtly* to the action:
##   sprint  -> slight pull-back + FOV widen + gentle sway
##   landing -> trauma shake scaled by impact
##   hit     -> a springy kick away from the hit
##   ragdoll -> looser follow so the camera chases the chaos
## Shake uses squared "trauma" with hard caps so it never gets nauseating.

@export var mouse_sensitivity := 0.0025
@export var stick_sensitivity := 2.6
@export var base_distance := 6.2
@export var min_pitch := deg_to_rad(-65.0)
@export var max_pitch := deg_to_rad(20.0)
@export var auto_follow := true
@export var max_shake_offset := 0.28
@export var max_shake_roll := deg_to_rad(2.5)

var target: Goblin
var yaw := 0.0
var pitch := deg_to_rad(-18.0)
var trauma := 0.0

var _yaw_node: Node3D
var _pitch_node: Node3D
var _arm: SpringArm3D
var camera: Camera3D
var _distance := 6.2
var _fov := 70.0
var _look_idle := 0.0
var _kick := Spring3.new(90.0, 9.0)
var _noise := FastNoiseLite.new()
var _t := 0.0
var _follow_pos := Vector3.ZERO


func _ready() -> void:
	top_level = true
	add_to_group("game_camera")
	_noise.frequency = 2.2
	_yaw_node = Node3D.new()
	add_child(_yaw_node)
	_pitch_node = Node3D.new()
	_yaw_node.add_child(_pitch_node)
	_arm = SpringArm3D.new()
	_arm.collision_mask = 1
	_arm.margin = 0.25
	_arm.spring_length = base_distance
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	_pitch_node.add_child(_arm)
	camera = Camera3D.new()
	camera.fov = _fov
	camera.far = 600.0
	_arm.add_child(camera)
	camera.current = true


func attach(goblin: Goblin) -> void:
	target = goblin
	goblin.camera_shake.connect(add_trauma)
	goblin.camera_kick.connect(kick)
	_follow_pos = goblin.camera_target()
	global_position = _follow_pos
	yaw = goblin.facing_yaw
	_arm.add_excluded_object(goblin.get_rid())


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func kick(dir: Vector3, amount: float) -> void:
	_kick.kick(dir.normalized() * amount * 3.0)


func snap_behind() -> void:
	if target:
		yaw = target.facing_yaw


func _unhandled_input(event: InputEvent) -> void:
	if GameState.input_locked:
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, min_pitch, max_pitch)
		_look_idle = 0.0
	if event.is_action_pressed("camera_recenter"):
		snap_behind()


func _process(delta: float) -> void:
	if target == null:
		return
	var dt := minf(delta, 0.05)
	_t += dt
	_look_idle += dt

	if not GameState.input_locked:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if stick.length() > 0.1:
			yaw -= stick.x * stick_sensitivity * dt
			pitch = clampf(pitch - stick.y * stick_sensitivity * 0.7 * dt, min_pitch, max_pitch)
			_look_idle = 0.0

	var hv := Vector3(target.velocity.x, 0, target.velocity.z)
	var speed := hv.length()
	var ragdolled := target.ragdoll != null

	# Gently drift behind the goblin when the player isn't steering the camera.
	if auto_follow and _look_idle > 1.5 and speed > 2.0 and not ragdolled:
		var behind := atan2(-hv.x, -hv.z)
		var diff := wrapf(behind - yaw, -PI, PI)
		if absf(diff) < 2.4:  # don't whip around when running at the camera
			yaw += diff * (1.0 - exp(-0.9 * dt)) * clampf(speed / 9.0, 0.0, 1.0)

	# Follow: loose vertically so jumps read, looser still while ragdolled.
	var goal := target.camera_target()
	var k_h := 4.5 if ragdolled else 11.0
	var k_v := 3.5 if ragdolled else 6.0
	_follow_pos.x = lerpf(_follow_pos.x, goal.x, 1.0 - exp(-k_h * dt))
	_follow_pos.z = lerpf(_follow_pos.z, goal.z, 1.0 - exp(-k_h * dt))
	_follow_pos.y = lerpf(_follow_pos.y, goal.y, 1.0 - exp(-k_v * dt))

	var kick_off := _kick.step(Vector3.ZERO, dt)
	global_position = _follow_pos + kick_off

	# Distance / FOV react to sprinting and huge packages.
	var sprint := target.sprinting and speed > 6.0
	var want_dist := (4.2 if GameState.indoors else base_distance) + (0.9 if sprint else 0.0) + (1.6 if target.carrier.blocks_view() else 0.0) + (1.0 if ragdolled else 0.0)
	_distance = lerpf(_distance, want_dist, 1.0 - exp(-3.0 * dt))
	_arm.spring_length = _distance
	_fov = lerpf(_fov, 76.0 if sprint else 70.0, 1.0 - exp(-4.0 * dt))
	camera.fov = _fov

	var sway := Vector2.ZERO
	if sprint and target.grounded:
		sway = Vector2(sin(_t * 6.0) * 0.04, absf(sin(_t * 12.0)) * 0.03)

	# Huge package: lift the view so you can (barely) see over it.
	var lift := 0.55 if target.carrier.blocks_view() else 0.0
	_pitch_node.position = Vector3(0, lift, 0)

	_yaw_node.rotation = Vector3(0, yaw, 0)
	_pitch_node.rotation = Vector3(pitch, 0, 0)

	# Trauma shake (squared, capped, decays quickly).
	trauma = maxf(0.0, trauma - 1.4 * dt)
	var sh := trauma * trauma
	camera.h_offset = sway.x + _noise.get_noise_2d(_t * 25.0, 0.0) * max_shake_offset * sh
	camera.v_offset = sway.y + _noise.get_noise_2d(0.0, _t * 25.0) * max_shake_offset * sh
	camera.rotation = Vector3(0, 0, _noise.get_noise_2d(_t * 20.0, 100.0) * max_shake_roll * sh)

	# Tell the goblin which way is "forward" for its input.
	target.camera_yaw = yaw
