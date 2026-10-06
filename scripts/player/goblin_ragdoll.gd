class_name GoblinRagdoll
extends Node3D
## Temporary physics body for the goblin. When something big happens
## (explosion, boar charge, nasty fall, tumbling down a hill) the controller
## hides its animated rig and spawns this: torso, head, arms and legs become
## RigidBody3Ds joined with cone-twist joints, copied from the rig's pose
## at that exact moment so the transition is seamless.
##
## The player is never fully helpless: steering input pushes the torso
## ("wiggling"), and mashing jump shortens the recovery.

const LAYER_RAGDOLL := 16
const MASK := 1 | 8 | 16

var torso: RigidBody3D
var head: RigidBody3D
var bodies: Array[RigidBody3D] = []
var elapsed := 0.0
var _still_time := 0.0
var _wiggle_cd := 0.0
var mash := 0.0


func build(rig: GoblinRig, velocity: Vector3, impulse: Vector3, spin: float) -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY

	torso = _make_body(rig.hips, [rig.hips.get_node("Torso")], _capsule(0.27, 0.62), Vector3(0, 0.2, 0), 3.0)
	head = _make_body(rig.head, [rig.head], _sphere(0.34), Vector3.ZERO, 1.3, true)
	var arm_l := _make_body(rig.shoulder_l, [rig.shoulder_l], _capsule(0.09, 0.55), Vector3(0, -0.27, 0), 0.35, true)
	var arm_r := _make_body(rig.shoulder_r, [rig.shoulder_r], _capsule(0.09, 0.55), Vector3(0, -0.27, 0), 0.35, true)
	var leg_l := _make_leg(rig, rig.hip_l, rig.foot_l, rig.leg_l)
	var leg_r := _make_leg(rig, rig.hip_r, rig.foot_r, rig.leg_r)

	_joint(torso, head, rig.neck.global_position, Vector3.UP, 0.7, 0.5)
	_joint(torso, arm_l, rig.shoulder_l.global_position, -rig.shoulder_l.global_transform.basis.y, 1.9, 0.8)
	_joint(torso, arm_r, rig.shoulder_r.global_position, -rig.shoulder_r.global_transform.basis.y, 1.9, 0.8)
	_joint(torso, leg_l, rig.hip_l.global_position, Vector3.DOWN, 1.2, 0.4)
	_joint(torso, leg_r, rig.hip_r.global_position, Vector3.DOWN, 1.2, 0.4)

	var axis := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)).normalized()
	for b in bodies:
		b.linear_velocity = velocity
		b.angular_velocity = axis * spin
	torso.apply_central_impulse(impulse * torso.mass)
	head.apply_central_impulse(impulse * head.mass * 1.25)  # whiplash
	for b in [arm_l, arm_r, leg_l, leg_r]:
		b.apply_central_impulse(impulse * b.mass * randf_range(0.8, 1.3))


func _capsule(r: float, h: float) -> Shape3D:
	var c := CapsuleShape3D.new()
	c.radius = r
	c.height = maxf(h, r * 2.0 + 0.01)
	return c


func _sphere(r: float) -> Shape3D:
	var s := SphereShape3D.new()
	s.radius = r
	return s


## Creates a rigid body at `source`'s global transform with duplicated visuals.
func _make_body(source: Node3D, visuals: Array, shape: Shape3D, shape_offset: Vector3, mass: float, dup_children := false) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.collision_layer = LAYER_RAGDOLL
	body.collision_mask = MASK
	body.mass = mass
	body.linear_damp = 0.15
	body.angular_damp = 1.2
	body.continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.25
	body.physics_material_override = pm
	add_child(body)
	body.global_transform = source.global_transform.orthonormalized()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = shape_offset
	body.add_child(cs)
	for v in visuals:
		var copy: Node3D
		if dup_children and v == source:
			copy = Node3D.new()
			for c in source.get_children():
				if c is Node3D:
					var cc: Node3D = c.duplicate()
					copy.add_child(cc)
		else:
			copy = (v as Node3D).duplicate()
		body.add_child(copy)
		# Keep the visual's exact world pose (including squash scale).
		if v == source:
			copy.transform = Transform3D(Basis.from_scale(source.global_transform.basis.get_scale()), Vector3.ZERO)
		else:
			copy.global_transform = (v as Node3D).global_transform
	bodies.append(body)
	return body


func _make_leg(rig: GoblinRig, hip: Node3D, foot: Node3D, leg: Node3D) -> RigidBody3D:
	var a := hip.global_position
	var b := foot.global_position + Vector3(0, 0.08, 0)
	var body := RigidBody3D.new()
	body.collision_layer = LAYER_RAGDOLL
	body.collision_mask = MASK
	body.mass = 0.45
	body.angular_damp = 1.2
	add_child(body)
	body.global_transform = Transform3D(rig.global_transform.basis, (a + b) * 0.5)
	var cs := CollisionShape3D.new()
	var len := maxf(a.distance_to(b), 0.2)
	cs.shape = _capsule(0.1, len + 0.1)
	body.add_child(cs)
	var leg_copy: Node3D = leg.duplicate()
	body.add_child(leg_copy)
	leg_copy.global_transform = leg.global_transform
	var foot_copy: Node3D = foot.duplicate()
	body.add_child(foot_copy)
	foot_copy.global_transform = foot.global_transform
	bodies.append(body)
	return body


func _joint(a: RigidBody3D, b: RigidBody3D, at_pos: Vector3, axis: Vector3, swing: float, twist: float) -> void:
	var j := ConeTwistJoint3D.new()
	add_child(j)
	var x := axis.normalized()
	var ref := Vector3.FORWARD if absf(x.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var y := ref.cross(x).normalized()
	var z := x.cross(y).normalized()
	j.global_transform = Transform3D(Basis(x, y, z), at_pos)
	j.node_a = j.get_path_to(a)
	j.node_b = j.get_path_to(b)
	j.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, swing)
	j.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, twist)
	j.set_param(ConeTwistJoint3D.PARAM_SOFTNESS, 0.9)
	j.set_param(ConeTwistJoint3D.PARAM_RELAXATION, 0.6)


## Called by the goblin every physics tick while ragdolled.
func tick(delta: float, steer: Vector3, wiggle_pressed: bool) -> void:
	elapsed += delta
	_wiggle_cd -= delta
	if steer.length_squared() > 0.01:
		torso.apply_central_force(steer * 22.0)
		head.apply_central_force(steer * 6.0)
	if wiggle_pressed and _wiggle_cd <= 0.0:
		_wiggle_cd = 0.18
		mash += 0.35
		var b: RigidBody3D = bodies[randi() % bodies.size()]
		b.apply_central_impulse(Vector3(randf_range(-1, 1), 2.2, randf_range(-1, 1)) * b.mass)
	if torso.linear_velocity.length() < 0.9 and torso.angular_velocity.length() < 3.0:
		_still_time += delta
	else:
		_still_time = 0.0


func is_settled() -> bool:
	if elapsed > 9.0:
		return true  # hard cap, whatever is going on
	var min_time := maxf(0.7, 1.1 - mash * 0.3)
	if elapsed < min_time:
		return false
	if _still_time > maxf(0.15, 0.5 - mash * 0.2):
		return true
	# Mashing / timeout only gets you up once you've stopped flying through the air.
	return (mash >= 2.5 or elapsed > 4.5) and torso.linear_velocity.length() < 2.5


func center() -> Vector3:
	return torso.global_position


func average_velocity() -> Vector3:
	return torso.linear_velocity


## Direction the goblin's belly is facing, flattened — used to stand up facing
## the way it fell.
func facing_yaw() -> float:
	var f := -torso.global_transform.basis.z
	f.y = 0.0
	if f.length_squared() < 0.01:
		f = torso.global_transform.basis.y
		f.y = 0.0
	if f.length_squared() < 0.0001:
		return 0.0
	f = f.normalized()
	return atan2(-f.x, -f.z)
