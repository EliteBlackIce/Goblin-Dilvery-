class_name GoblinRig
extends Node3D
## The goblin's body: built from chunky primitives and animated 100%
## procedurally with damped springs, so every motion overshoots, wobbles and
## jiggles. No keyframes — the pose is derived every frame from what the
## controller is doing (speed, acceleration, turning, falling, balance...).
##
## Proportions follow the art direction: huge head, tiny body, noodle arms
## with big hands, big feet, an oversized courier cap.
##
## The rig is top-level and interpolates between physics ticks so it stays
## smooth on high refresh-rate screens even though movement runs at 60 Hz.

const SKIN := Color(0.47, 0.74, 0.27)
const SKIN_DARK := Color(0.33, 0.56, 0.2)
const SKIN_INNER := Color(0.85, 0.5, 0.45)
const VEST := Color(0.2, 0.36, 0.7)
const VEST_TRIM := Color(0.95, 0.78, 0.25)
const BELT := Color(0.35, 0.22, 0.12)
const SATCHEL := Color(0.72, 0.52, 0.3)
const CAP := Color(0.82, 0.22, 0.17)
const CAP_DARK := Color(0.6, 0.14, 0.11)
const EYE := Color(1.0, 0.97, 0.82)
const PUPIL := Color(0.06, 0.05, 0.05)
const MOUTH := Color(0.35, 0.08, 0.1)
const TOOTH := Color(1, 1, 0.92)

const HIP_HEIGHT := 0.42
const SPRINT_REF := 9.0

const EXPRESSIONS := {
	"neutral": {"eye": 1.0, "pupil": 1.0, "brow": 0.0, "brow_y": 0.0, "mw": 1.0, "mh": 1.0},
	"happy": {"eye": 0.55, "pupil": 1.0, "brow": -0.25, "brow_y": 0.035, "mw": 1.5, "mh": 2.0},
	"determined": {"eye": 0.7, "pupil": 1.0, "brow": 0.4, "brow_y": -0.02, "mw": 1.3, "mh": 0.6},
	"scared": {"eye": 1.4, "pupil": 0.55, "brow": -0.45, "brow_y": 0.06, "mw": 0.8, "mh": 3.2},
	"panic": {"eye": 1.3, "pupil": 0.5, "brow": -0.55, "brow_y": 0.05, "mw": 1.1, "mh": 2.6},
	"ouch": {"eye": 0.12, "pupil": 1.0, "brow": 0.45, "brow_y": -0.01, "mw": 1.4, "mh": 2.2},
	"dizzy": {"eye": 1.1, "pupil": 0.8, "brow": -0.3, "brow_y": 0.03, "mw": 1.1, "mh": 1.6},
	"strain": {"eye": 0.45, "pupil": 1.0, "brow": 0.35, "brow_y": -0.015, "mw": 1.6, "mh": 0.45},
	"sleepy": {"eye": 0.1, "pupil": 1.0, "brow": -0.1, "brow_y": 0.0, "mw": 1.2, "mh": 3.0},
}

var goblin: Node  # Goblin (untyped to avoid a hard cycle)

# --- Scene parts -----------------------------------------------------------
var lean: Node3D
var squash: Node3D
var hips: Node3D
var torso_mesh: MeshInstance3D
var neck: Node3D
var head: Node3D
var ear_l: Node3D
var ear_r: Node3D
var eye_l: Node3D
var eye_r: Node3D
var pupil_l: Node3D
var pupil_r: Node3D
var brow_l: Node3D
var brow_r: Node3D
var mouth: Node3D
var cap: Node3D
var shoulder_l: Node3D
var shoulder_r: Node3D
var hip_l: Node3D
var hip_r: Node3D
var foot_l: Node3D
var foot_r: Node3D
var leg_l: MeshInstance3D
var leg_r: MeshInstance3D
var back_anchor: Node3D
var front_anchor: Node3D

# --- Springs ---------------------------------------------------------------
var s_pitch := Spring.new(110.0, 12.0)
var s_roll := Spring.new(110.0, 11.0)
var s_squash := Spring.new(260.0, 9.0)
var s_head_yaw := Spring.new(90.0, 7.0)
var s_head_pitch := Spring.new(110.0, 8.0)
var s_head_roll := Spring.new(80.0, 7.0)
var s_ear_l := Spring.new(90.0, 5.0)
var s_ear_r := Spring.new(90.0, 5.0)
var s_cap := Spring.new(60.0, 4.0)
var s_arm_lx := Spring.new(160.0, 11.0)
var s_arm_lz := Spring.new(160.0, 11.0)
var s_arm_rx := Spring.new(160.0, 11.0)
var s_arm_rz := Spring.new(160.0, 11.0)
var s_crouch := Spring.new(200.0, 14.0)
var s_foot_l := Spring3.new(700.0, 42.0)
var s_foot_r := Spring3.new(700.0, 42.0)

# --- Animation state -------------------------------------------------------
var phase := 0.0
var gait := 0.0
var time := 0.0
var _prev_hv := Vector3.ZERO
var _acc := Vector3.ZERO
var _windmill := false
var _last_step_sign := 1.0
var _blink_t := 2.0
var _blink := 0.0
var _expr_override := ""
var _expr_override_t := 0.0
var _face := {"eye": 1.0, "pupil": 1.0, "brow": 0.0, "brow_y": 0.0, "mw": 1.0, "mh": 1.0}
var _idle_t := 0.0
var _fidget := ""
var _fidget_t := 0.0
var _attack_t := -1.0
var _getup_t := -1.0
var _noise := FastNoiseLite.new()
var _step_dust_cd := 0.0

signal footstep(pos: Vector3, strength: float)


func _ready() -> void:
	top_level = true
	_noise.frequency = 0.9
	_noise.seed = randi()
	_build()


# ===========================================================================
# Construction
# ===========================================================================

func _part(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO, name_ := "") -> MeshInstance3D:
	var mi := Mats.instance(mesh)
	mi.position = pos
	if name_ != "":
		mi.name = name_
	parent.add_child(mi)
	return mi


func _pivot(parent: Node3D, pos: Vector3, name_: String) -> Node3D:
	var n := Node3D.new()
	n.name = name_
	n.position = pos
	parent.add_child(n)
	return n


func _build() -> void:
	lean = _pivot(self, Vector3.ZERO, "Lean")
	squash = _pivot(lean, Vector3.ZERO, "Squash")
	hips = _pivot(squash, Vector3(0, HIP_HEIGHT, 0), "Hips")

	# Torso: pear-shaped belly in a postal vest, belt and satchel.
	var k := MeshKit.new(11)
	k.sphere(MeshKit.at(Vector3(0, 0.2, 0), 0, Vector3(1.0, 1.12, 0.9)), 0.26, VEST, 9, 6)
	k.sphere(MeshKit.at(Vector3(0, 0.16, -0.13), 0, Vector3(0.75, 0.85, 0.5)), 0.24, SKIN, 8, 5)
	k.cylinder(MeshKit.at(Vector3(0, 0.03, 0)), 0.25, 0.25, 0.07, BELT, 10)
	k.box(MeshKit.at(Vector3(0, 0.03, -0.25)), Vector3(0.08, 0.07, 0.03), VEST_TRIM)
	k.box(MeshKit.rot(Vector3(0.24, 0.0, 0.04), Vector3(0, 0, 0.1)), Vector3(0.12, 0.18, 0.2), SATCHEL)
	k.box(MeshKit.rot(Vector3(0.0, 0.25, 0.0), Vector3(0, 0, -0.75)), Vector3(0.05, 0.62, 0.55), SATCHEL.darkened(0.15))
	torso_mesh = _part(hips, Assets.pick("goblin/torso", k.commit()), Vector3.ZERO, "Torso")

	back_anchor = _pivot(hips, Vector3(0, 0.3, 0.27), "BackAnchor")
	front_anchor = _pivot(hips, Vector3(0, 0.32, -0.55), "FrontAnchor")

	# Neck + giant head.
	neck = _pivot(hips, Vector3(0, 0.42, 0), "Neck")
	head = _pivot(neck, Vector3(0, 0.3, 0), "Head")
	k = MeshKit.new(12)
	k.sphere(MeshKit.at(Vector3.ZERO, 0, Vector3(1.15, 0.92, 1.0)), 0.36, SKIN, 10, 7)
	k.cylinder_between(Vector3(0, -0.02, -0.3), Vector3(0, -0.08, -0.6), 0.075, SKIN_DARK, 6)
	k.sphere(MeshKit.at(Vector3(0, -0.085, -0.6)), 0.05, SKIN_DARK, 6, 4)
	k.sphere(MeshKit.at(Vector3(0.0, -0.18, -0.17), 0, Vector3(1.4, 0.6, 1.0)), 0.16, SKIN, 8, 4)
	_part(head, Assets.pick("goblin/head", k.commit()), Vector3.ZERO, "Skull")

	# Ears: long floppy cones on spring pivots.
	for side in [-1.0, 1.0]:
		var ear := _pivot(head, Vector3(0.36 * side, 0.06, 0.02), "EarL" if side < 0 else "EarR")
		k = MeshKit.new(13)
		var tip := Vector3(0.46 * side, 0.12, 0.08)
		k.cone_between(Vector3.ZERO, tip, 0.13, 0.0, SKIN, 6, 0.45)
		k.cone_between(Vector3(0, 0, -0.03), tip * 0.92 + Vector3(0, 0, -0.03), 0.09, 0.0, SKIN_INNER, 6, 0.3)
		_part(ear, Assets.pick("goblin/ear_l" if side < 0 else "goblin/ear_r", k.commit()))
		if side < 0:
			ear_l = ear
		else:
			ear_r = ear

	# Eyes (separate so they can blink / bulge) with pupils.
	for side in [-1.0, 1.0]:
		var eye := _pivot(head, Vector3(0.15 * side, 0.08, -0.29), "EyeL" if side < 0 else "EyeR")
		k = MeshKit.new(14, 0.0)
		k.sphere(MeshKit.at(Vector3.ZERO, 0, Vector3(1, 1.1, 0.7)), 0.11, EYE, 8, 6)
		_part(eye, Assets.pick("goblin/eye", k.commit()))
		var pupil := _pivot(eye, Vector3(0, 0, -0.07), "Pupil")
		k = MeshKit.new(15, 0.0)
		k.sphere(MeshKit.at(Vector3.ZERO, 0, Vector3(1, 1, 0.5)), 0.05, PUPIL, 6, 4)
		_part(pupil, Assets.pick("goblin/pupil", k.commit()))
		var brow := _pivot(head, Vector3(0.15 * side, 0.22, -0.3), "Brow")
		k = MeshKit.new(16, 0.0)
		k.box(Transform3D(), Vector3(0.16, 0.04, 0.05), SKIN_DARK.darkened(0.35))
		_part(brow, Assets.pick("goblin/brow", k.commit()))
		if side < 0:
			eye_l = eye
			pupil_l = pupil
			brow_l = brow
		else:
			eye_r = eye
			pupil_r = pupil
			brow_r = brow

	# Mouth with one heroic snaggle tooth.
	mouth = _pivot(head, Vector3(0.02, -0.17, -0.3), "Mouth")
	k = MeshKit.new(17, 0.0)
	k.box(Transform3D(), Vector3(0.2, 0.045, 0.05), MOUTH)
	k.box(MeshKit.at(Vector3(0.05, 0.035, -0.012)), Vector3(0.04, 0.045, 0.03), TOOTH)
	_part(mouth, Assets.pick("goblin/mouth", k.commit()))

	# Oversized hat (courier cap by default; gear can swap it).
	cap = _pivot(head, Vector3(0, 0.25, 0.02), "Cap")
	set_hat(hat_style)

	# Noodle arms with big hands.
	for side in [-1.0, 1.0]:
		var sh := _pivot(hips, Vector3(0.27 * side, 0.34, 0.0), "ShoulderL" if side < 0 else "ShoulderR")
		k = MeshKit.new(19)
		k.cylinder(MeshKit.at(Vector3(0, -0.2, 0)), 0.045, 0.05, 0.4, SKIN, 6)
		k.sphere(MeshKit.at(Vector3(0, -0.45, -0.02), 0, Vector3(1.0, 1.05, 0.85)), 0.115, SKIN, 8, 5)
		k.sphere(MeshKit.at(Vector3(0.07 * -side, -0.42, -0.06), 0, Vector3(0.5, 0.8, 0.5)), 0.06, SKIN, 6, 4)
		k.cylinder(MeshKit.at(Vector3(0, -0.02, 0)), 0.07, 0.065, 0.1, VEST, 7)
		_part(sh, Assets.pick("goblin/arm_l" if side < 0 else "goblin/arm_r", k.commit()))
		if side < 0:
			shoulder_l = sh
		else:
			shoulder_r = sh

	# Hip joints (on the body) and feet (planted in squash space).
	hip_l = _pivot(hips, Vector3(-0.12, 0.0, 0.0), "HipL")
	hip_r = _pivot(hips, Vector3(0.12, 0.0, 0.0), "HipR")
	for side in [-1.0, 1.0]:
		var foot := _pivot(squash, Vector3(0.14 * side, 0, 0), "FootL" if side < 0 else "FootR")
		k = MeshKit.new(20)
		k.sphere(MeshKit.at(Vector3(0, 0.065, -0.07), 0, Vector3(0.13, 0.075, 0.23) / 0.1), 0.1, SKIN_DARK, 8, 5)
		k.sphere(MeshKit.at(Vector3(0.04 * side, 0.08, -0.26), 0, Vector3(0.5, 0.45, 0.55)), 0.07, SKIN_DARK, 6, 4)
		_part(foot, Assets.pick("goblin/foot_l" if side < 0 else "goblin/foot_r", k.commit()))
		var leg_k := MeshKit.new(21)
		leg_k.cylinder(Transform3D(), 0.045, 0.045, 1.0, SKIN, 6, false)
		var leg := _part(squash, Assets.pick("goblin/leg", leg_k.commit()), Vector3.ZERO, "LegL" if side < 0 else "LegR")
		if side < 0:
			foot_l = foot
			leg_l = leg
		else:
			foot_r = foot
			leg_r = leg
	s_foot_l.snap(foot_l.position)
	s_foot_r.snap(foot_r.position)


var hat_style := "cap"


func set_hat(style: String) -> void:
	hat_style = style
	if cap == null:
		return
	for c in cap.get_children():
		c.queue_free()
	var k := MeshKit.new(18)
	match style:
		"pot":
			k.cylinder(MeshKit.at(Vector3(0, 0.1, 0)), 0.36, 0.33, 0.28, Color(0.45, 0.45, 0.5), 10)
			k.box(MeshKit.at(Vector3(0.42, 0.12, 0)), Vector3(0.18, 0.05, 0.06), Color(0.3, 0.3, 0.32))
		"wizard":
			k.cylinder(MeshKit.at(Vector3(0, 0.0, 0)), 0.5, 0.5, 0.04, Color(0.3, 0.25, 0.7), 10)
			k.cylinder(MeshKit.rot(Vector3(0.05, 0.35, 0.05), Vector3(0.25, 0, -0.2)), 0.3, 0.0, 0.75, Color(0.3, 0.25, 0.7), 8)
			k.sphere(MeshKit.at(Vector3(0.0, 0.25, -0.24)), 0.05, Color(1, 0.9, 0.3), 5, 3)
		"crown":
			k.cylinder(MeshKit.at(Vector3(0, 0.06, 0)), 0.2, 0.22, 0.12, Color(1, 0.8, 0.25), 8, false)
			for i in 5:
				var a := TAU * i / 5.0
				k.cylinder(MeshKit.at(Vector3(cos(a) * 0.19, 0.17, sin(a) * 0.19)), 0.05, 0.0, 0.12, Color(1, 0.8, 0.25), 4)
		_:
			k.cylinder(MeshKit.rot(Vector3(0, 0.07, 0), Vector3(-0.08, 0, 0)), 0.32, 0.29, 0.17, CAP, 10)
			k.cylinder(MeshKit.rot(Vector3(0, 0.0, 0), Vector3(-0.08, 0, 0)), 0.335, 0.335, 0.04, CAP_DARK, 10)
			k.box(MeshKit.rot(Vector3(0, -0.005, -0.38), Vector3(0.12, 0, 0)), Vector3(0.42, 0.03, 0.24), CAP_DARK)
			k.box(MeshKit.rot(Vector3(0, 0.09, -0.3), Vector3(-0.3, 0, 0)), Vector3(0.11, 0.08, 0.02), VEST_TRIM)
	_part(cap, Assets.pick("goblin/hat_" + style, k.commit()))


# ===========================================================================
# Events from the controller
# ===========================================================================

func on_jump() -> void:
	# Anticipation squash for a single frame, then a big stretch.
	s_squash.snap(-0.16)
	s_squash.kick(6.5)
	s_arm_lz.kick(-14.0)
	s_arm_rz.kick(14.0)
	s_ear_l.kick(-8.0)
	s_ear_r.kick(8.0)
	s_pitch.kick(-2.0)


func on_land(impact: float) -> void:
	var k := clampf(impact, 0.0, 30.0)
	s_squash.kick(-k * 0.38)
	s_crouch.kick(-k * 0.06)
	s_pitch.kick(k * 0.12 * (1.0 if randf() < 0.5 else -0.6))
	s_roll.kick(randf_range(-1.0, 1.0) * k * 0.08)
	s_head_pitch.kick(k * 0.25)
	s_ear_l.kick(k * 0.6)
	s_ear_r.kick(-k * 0.6)
	s_arm_lz.kick(-k * 0.5)
	s_arm_rz.kick(k * 0.5)
	s_cap.kick(k * 0.3)
	footstep.emit(global_position, k / 10.0)


func on_hit(dir_world: Vector3, strength: float) -> void:
	var local := global_transform.basis.inverse() * dir_world
	s_pitch.kick(local.z * strength * 1.2)
	s_roll.kick(-local.x * strength * 1.2)
	s_head_roll.kick(randf_range(-1.0, 1.0) * strength * 2.0)
	s_head_pitch.kick(-strength * 1.0)
	s_squash.kick(-strength * 0.3)
	s_arm_lx.kick(-strength * 2.0)
	s_arm_rx.kick(-strength * 2.0)
	s_arm_lz.kick(-strength * 1.5)
	s_arm_rz.kick(strength * 1.5)
	set_expression("ouch", 0.6)


func on_skid() -> void:
	s_pitch.kick(3.0)
	s_squash.kick(-1.5)
	set_expression("panic", 0.5)


func play_attack() -> void:
	_attack_t = 0.0


func play_getup() -> void:
	_getup_t = 0.0
	s_pitch.snap(-1.45)
	s_roll.snap(randf_range(-0.4, 0.4))
	s_squash.snap(-0.35)
	s_squash.kick(3.0)
	s_head_roll.kick(10.0)
	s_arm_lz.snap(-1.4)
	s_arm_rz.snap(1.4)
	set_expression("dizzy", 1.1)


func set_expression(expr: String, duration: float) -> void:
	_expr_override = expr
	_expr_override_t = duration


func reset_pose() -> void:
	for s in [s_pitch, s_roll, s_squash, s_head_yaw, s_head_pitch, s_head_roll, s_ear_l, s_ear_r, s_cap, s_arm_lx, s_arm_lz, s_arm_rx, s_arm_rz, s_crouch]:
		s.snap(0.0)


# ===========================================================================
# Per-frame animation
# ===========================================================================

func _process(delta: float) -> void:
	if goblin == null or not visible:
		return
	var dt := minf(delta, 1.0 / 20.0)
	time += dt
	_follow_body()
	_animate(dt)


func _follow_body() -> void:
	var f := Engine.get_physics_interpolation_fraction()
	var p: Vector3 = goblin.prev_physics_pos.lerp(goblin.global_position, f)
	global_transform = Transform3D(Basis(Vector3.UP, goblin.facing_yaw), p)


func _animate(dt: float) -> void:
	var g = goblin
	var vel: Vector3 = g.velocity
	var hv := Vector3(vel.x, 0, vel.z)
	var speed := hv.length()
	var speed_n := clampf(speed / SPRINT_REF, 0.0, 1.0)
	var grounded: bool = g.grounded
	var sprinting: bool = g.sprinting and speed > 5.0
	var stumble: float = g.stumble_amount
	var balance: float = g.balance
	var carry: String = g.carry_pose
	var yaw: float = g.facing_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))

	# Smoothed acceleration in body space drives the lean.
	var acc := (hv - _prev_hv) / maxf(dt, 0.0001)
	_prev_hv = hv
	_acc = _acc.lerp(acc, 1.0 - exp(-10.0 * dt))
	var acc_f := _acc.dot(fwd)
	var acc_r := _acc.dot(right)

	# --- Gait ---------------------------------------------------------------
	var target_gait := clampf(speed / 1.2, 0.0, 1.0) if grounded else 0.0
	gait = lerpf(gait, target_gait, 1.0 - exp(-10.0 * dt))
	var stride := lerpf(0.5, 0.8, speed_n)  # quick little goblin steps
	if grounded:
		phase += speed * dt / stride * PI
		var step_sign := signf(sin(phase))
		if step_sign != _last_step_sign and gait > 0.3:
			_last_step_sign = step_sign
			s_head_pitch.kick(0.6 + speed_n * 1.2)
			s_ear_l.kick(1.5 + speed_n * 3.0)
			s_ear_r.kick(-1.5 - speed_n * 3.0)
			footstep.emit(global_position, 0.2 + speed_n * 0.5)

	if speed < 0.3 and grounded and not g.is_busy():
		_idle_t += dt
	else:
		_idle_t = 0.0
		_fidget = ""
	_update_fidget(dt)

	# --- Lean (pitch/roll) --------------------------------------------------
	var pitch_t := -acc_f * 0.028 - speed_n * 0.1
	if sprinting:
		pitch_t -= 0.22
	var roll_t := -acc_r * 0.034
	roll_t += sin(phase) * 0.07 * gait  # waddle
	var wob := _noise.get_noise_1d(time * 1.3)
	roll_t += (wob * 0.02 + sin(time * 0.7) * 0.03) * (1.0 - gait)  # gentle weight shift
	pitch_t += _noise.get_noise_1d(time * 1.1 + 50.0) * 0.012 * (1.0 - gait)
	roll_t += balance * sin(time * 8.5) * 0.1
	pitch_t += balance * sin(time * 6.1) * 0.05
	roll_t += stumble * sin(time * 14.0) * 0.25
	pitch_t -= stumble * 0.25
	if g.skidding:
		pitch_t = 0.5
	if carry == "front":
		pitch_t += 0.12  # leaning back under the huge box
	if _fidget == "wobble":
		roll_t += sin(time * 5.0) * 0.35
	pitch_t = clampf(pitch_t, -0.7, 0.6)
	roll_t = clampf(roll_t, -0.7, 0.7)
	var stiff := 1.0 if _getup_t < 0.0 else 0.6
	s_pitch.stiffness = 110.0 * stiff
	s_roll.stiffness = 110.0 * stiff
	lean.rotation = Vector3(s_pitch.step(pitch_t, dt), 0, s_roll.step(roll_t, dt))

	# --- Squash & stretch ---------------------------------------------------
	var sq_t := 0.0
	if not grounded:
		sq_t = clampf(absf(vel.y) * 0.012, 0.0, 0.18)
	var sq := s_squash.step(sq_t, dt)
	var sy := clampf(1.0 + sq, 0.45, 1.6)
	var sxz := 1.0 / sqrt(sy)
	squash.scale = Vector3(sxz, sy, sxz)

	# --- Hips bob / twist ---------------------------------------------------
	var crouch := s_crouch.step(-0.05 if carry == "front" else 0.0, dt)
	var bob := absf(sin(phase)) * (0.05 + speed_n * 0.06) * gait
	var breathe := sin(time * 2.3) * 0.012 * (1.0 - gait)
	hips.position = Vector3(0, HIP_HEIGHT + bob + breathe + crouch, 0)
	hips.rotation = Vector3(0, sin(phase) * 0.18 * gait, sin(phase) * 0.05 * gait)

	_animate_feet(dt, grounded, vel, stride, speed_n, stumble)
	_animate_arms(dt, grounded, vel, speed_n, sprinting, stumble, carry, g)
	_animate_head(dt, grounded, vel, speed_n, g, fwd)
	_animate_face(dt, grounded, vel, sprinting, stumble, carry, g)

	if _getup_t >= 0.0:
		_getup_t += dt
		if _getup_t > 0.9:
			_getup_t = -1.0
	_step_dust_cd -= dt


func _animate_feet(dt: float, grounded: bool, vel: Vector3, stride: float, speed_n: float, stumble: float) -> void:
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var ph := phase + (0.0 if i == 0 else PI)
		var swing := sin(ph)
		var lift := maxf(0.0, cos(ph))
		var rest := Vector3(0.14 * side, 0.0, 0.0)
		var target := rest
		var toe := 0.0
		if grounded:
			target += Vector3(stumble * sin(time * 9.0 + side) * 0.12, lift * (0.12 + speed_n * 0.14) * gait, -swing * stride * 0.45 * gait)
			toe = -swing * 0.45 * gait
			if goblin.skidding:
				target = rest + Vector3(0, 0, -0.25)
				toe = 0.5
		else:
			if vel.y > 0.0:
				target = rest + Vector3(0.04 * side, 0.18, 0.06)  # tucked
				toe = 0.4
			else:
				# Cartoon "running on air" while falling.
				var flail := clampf(-vel.y / 10.0, 0.0, 1.0)
				target = rest + Vector3(0.05 * side, 0.12 + sin(time * 17.0 + side) * 0.08 * flail, sin(time * 17.0 + side * 1.6) * 0.22 * flail)
				toe = sin(time * 17.0 + side) * 0.6 * flail
		var s: Spring3 = s_foot_l if i == 0 else s_foot_r
		var p := s.step(target, dt)
		var foot: Node3D = foot_l if i == 0 else foot_r
		foot.position = p
		foot.rotation = Vector3(toe, 0, 0)
		# Stretchy noodle leg from hip joint to ankle.
		var hip_node: Node3D = hip_l if i == 0 else hip_r
		var hip_p := squash.to_local(hip_node.global_position)
		var ankle := p + Vector3(0, 0.1, 0.02)
		var leg: MeshInstance3D = leg_l if i == 0 else leg_r
		_stretch_between(leg, hip_p, ankle)


func _stretch_between(mi: Node3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var length := maxf(d.length(), 0.01)
	var y := d / length
	var x := y.cross(Vector3.FORWARD)
	if x.length_squared() < 0.001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(y)
	mi.transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)


func _animate_arms(dt: float, grounded: bool, vel: Vector3, speed_n: float, sprinting: bool, stumble: float, carry: String, g) -> void:
	var lx := 0.0
	var lz := -0.15
	var rx := 0.0
	var rz := 0.15
	var windmill := false

	if grounded:
		var amp := 0.45 * gait + (0.75 if sprinting else 0.0) * speed_n
		lx = -sin(phase) * amp
		rx = sin(phase) * amp
		var flap := 0.12 + (0.3 * absf(sin(phase)) if sprinting else 0.0)
		lz = -flap
		rz = flap
		# Idle dangle.
		lx += _noise.get_noise_1d(time * 0.8 + 10.0) * 0.12 * (1.0 - gait)
		rx += _noise.get_noise_1d(time * 0.8 + 20.0) * 0.12 * (1.0 - gait)
		lz -= (sin(time * 1.6) * 0.05) * (1.0 - gait)
		rz += (sin(time * 1.6 + 1.0) * 0.05) * (1.0 - gait)
	else:
		if vel.y > 1.0:
			lx = 0.5
			rx = 0.5
			lz = -1.7
			rz = 1.7
		else:
			var fl := clampf(-vel.y / 8.0, 0.3, 1.0)
			lx = sin(time * 19.0) * 1.1 * fl
			rx = sin(time * 17.0 + 1.7) * 1.1 * fl
			lz = -(1.9 + sin(time * 21.0) * 0.5 * fl)
			rz = 1.9 + sin(time * 23.0 + 0.7) * 0.5 * fl

	if stumble > 0.25 or g.skidding:
		windmill = true

	if carry == "front":
		lx = 1.45 + sin(time * 3.0) * 0.05
		rx = 1.45 + sin(time * 3.0 + 1.0) * 0.05
		lz = -0.35
		rz = 0.35
		windmill = false
	elif carry == "back" and grounded and not sprinting:
		lx = -0.25 + lx * 0.4
		rx = -0.25 + rx * 0.4
		lz = -0.3
		rz = 0.3

	if _fidget == "scratch":
		rx = 2.7 + sin(time * 22.0) * 0.12
		rz = -0.25
	elif _fidget == "wobble":
		lz = -1.4 + sin(time * 5.0) * 0.4
		rz = 1.4 + sin(time * 5.0) * 0.4
	elif _fidget == "yawn":
		lx = 2.8
		rx = 2.8
		lz = -0.6
		rz = 0.6

	if _attack_t >= 0.0:
		_attack_t += dt
		var t := _attack_t
		if t < 0.12:
			rx = lerpf(0.0, -2.6, t / 0.12)  # big wind-up behind the head
			rz = 0.5
			lx = 0.8
		elif t < 0.26:
			rx = lerpf(-2.6, 1.9, (t - 0.12) / 0.14)
			rz = 0.2
			lx = -0.6
		elif t > 0.45:
			_attack_t = -1.0

	if windmill:
		_windmill = true
		var spin := time * 15.0
		s_arm_lx.snap(spin)
		s_arm_rx.snap(spin + PI)
		lz = -1.3
		rz = 1.3
	elif _windmill:
		_windmill = false
		s_arm_lx.snap(wrapf(s_arm_lx.value, -PI, PI))
		s_arm_rx.snap(wrapf(s_arm_rx.value, -PI, PI))

	if not windmill:
		s_arm_lx.step(lx, dt)
		s_arm_rx.step(rx, dt)
	s_arm_lz.step(lz, dt)
	s_arm_rz.step(rz, dt)
	shoulder_l.rotation = Vector3(s_arm_lx.value, 0, s_arm_lz.value)
	shoulder_r.rotation = Vector3(s_arm_rx.value, 0, s_arm_rz.value)


func _animate_head(dt: float, grounded: bool, vel: Vector3, speed_n: float, g, fwd: Vector3) -> void:
	# Head turns toward where the player is steering BEFORE the body does
	# (anticipation), then lags behind body turns (overlapping action).
	var wish: Vector3 = g.wish_dir
	var lead := 0.0
	if wish.length_squared() > 0.01:
		lead = clampf(fwd.signed_angle_to(wish, Vector3.UP), -1.0, 1.0) * 0.7
	var yaw_t := lead - float(g.turn_rate) * 0.06
	var pitch_t := -s_pitch.value * 0.45
	var roll_t := -s_roll.value * 0.7 + sin(time * 1.1) * 0.05 * (1.0 - gait)
	if not grounded and vel.y < -6.0:
		pitch_t += 0.35  # looking down at the approaching ground in horror
	if g.stumble_amount > 0.2:
		roll_t += sin(time * 11.0) * 0.4
	if _fidget == "look_around":
		yaw_t = sin(_fidget_t * 2.4) * 1.0
	elif _fidget == "yawn":
		pitch_t = -0.35
	elif _fidget == "scratch":
		roll_t = 0.25
	neck.rotation = Vector3(s_head_pitch.step(pitch_t, dt), s_head_yaw.step(yaw_t, dt), s_head_roll.step(roll_t, dt))

	# Ears flop with vertical motion.
	var ear_t := clampf(-vel.y * 0.04, -0.6, 0.7) - 0.15 * speed_n
	ear_l.rotation = Vector3(-s_ear_l.value * 0.2, 0, -s_ear_l.step(ear_t, dt))
	ear_r.rotation = Vector3(-s_ear_r.value * 0.2, 0, s_ear_r.step(-ear_t, dt))
	cap.rotation = Vector3(s_cap.step(-s_head_pitch.velocity * 0.02, dt), 0, -s_head_roll.value * 0.35)


func _animate_face(dt: float, grounded: bool, vel: Vector3, sprinting: bool, stumble: float, carry: String, g) -> void:
	var expr := "neutral"
	if _expr_override_t > 0.0:
		_expr_override_t -= dt
		expr = _expr_override
	elif _fidget == "yawn":
		expr = "sleepy"
	elif not grounded and vel.y < -8.0:
		expr = "scared"
	elif stumble > 0.2 or g.skidding:
		expr = "panic"
	elif g.balance > 0.45:
		expr = "scared"
	elif sprinting:
		expr = "determined"
	elif g.carry_weight > 5.0:
		expr = "strain"
	var e: Dictionary = EXPRESSIONS.get(expr, EXPRESSIONS["neutral"])
	var w := 1.0 - exp(-14.0 * dt)
	for key in _face.keys():
		_face[key] = lerpf(_face[key], e[key], w)

	_blink_t -= dt
	if _blink_t <= 0.0:
		_blink = 0.12
		_blink_t = randf_range(1.8, 5.0)
	var blink_scale := 1.0
	if _blink > 0.0:
		_blink -= dt
		blink_scale = 0.08

	var eye_sy: float = maxf(_face["eye"] * blink_scale, 0.06)
	var bulge := 1.0 + maxf(0.0, _face["eye"] - 1.0) * 0.6
	eye_l.scale = Vector3(bulge, eye_sy, bulge)
	eye_r.scale = Vector3(bulge * 1.08, eye_sy * 1.05, bulge * 1.08)  # asymmetric = goofier
	var ps: float = _face["pupil"]
	pupil_l.scale = Vector3.ONE * ps
	pupil_r.scale = Vector3.ONE * ps

	var look := Vector2(clampf(s_head_yaw.value * -0.05, -0.04, 0.04), 0.0)
	if expr == "dizzy":
		look = Vector2(cos(time * 9.0), sin(time * 9.0)) * 0.03
	pupil_l.position = Vector3(look.x, look.y, -0.07)
	pupil_r.position = Vector3(look.x if expr != "dizzy" else -look.x, look.y if expr != "dizzy" else -look.y, -0.07)

	var b: float = _face["brow"]
	brow_l.rotation = Vector3(0, 0, -b)
	brow_r.rotation = Vector3(0, 0, b)
	brow_l.position.y = 0.22 + _face["brow_y"]
	brow_r.position.y = 0.22 + _face["brow_y"] + 0.01
	mouth.scale = Vector3(_face["mw"], _face["mh"], 1.0)


func _update_fidget(dt: float) -> void:
	if _fidget != "":
		_fidget_t += dt
		var dur := {"look_around": 2.6, "scratch": 1.6, "wobble": 1.8, "yawn": 1.5}.get(_fidget, 1.5) as float
		if _fidget_t > dur:
			_fidget = ""
			_idle_t = 2.0
		return
	if _idle_t > 5.0:
		_fidget = ["look_around", "scratch", "wobble", "yawn"][randi() % 4]
		_fidget_t = 0.0
		_idle_t = 0.0
