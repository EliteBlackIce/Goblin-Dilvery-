class_name Spring3
extends RefCounted
## Vector3 version of [Spring]. Used for package stacks, camera kicks, etc.

const MAX_STEP := 1.0 / 120.0

var value := Vector3.ZERO
var velocity := Vector3.ZERO
var stiffness := 120.0
var damping := 10.0


func _init(k := 120.0, d := 10.0, start := Vector3.ZERO) -> void:
	stiffness = k
	damping = d
	value = start


func step(target: Vector3, dt: float) -> Vector3:
	var remaining := minf(dt, 0.1)
	while remaining > 0.0:
		var h := minf(remaining, MAX_STEP)
		var accel := (target - value) * stiffness - velocity * damping
		velocity += accel * h
		value += velocity * h
		remaining -= h
	return value


func kick(impulse: Vector3) -> void:
	velocity += impulse


func snap(v: Vector3) -> void:
	value = v
	velocity = Vector3.ZERO
