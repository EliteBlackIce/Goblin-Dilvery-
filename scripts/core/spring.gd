class_name Spring
extends RefCounted
## Damped 1D spring used for all the cartoony secondary motion (lean, squash,
## ear flop, head lag...). Low damping = wobbly overshoot, which is the point.
## Steps internally at a fixed small dt so behaviour is frame-rate independent.

const MAX_STEP := 1.0 / 120.0

var value := 0.0
var velocity := 0.0
var stiffness := 120.0
var damping := 10.0


func _init(k := 120.0, d := 10.0, start := 0.0) -> void:
	stiffness = k
	damping = d
	value = start


func step(target: float, dt: float) -> float:
	var remaining := minf(dt, 0.1)
	while remaining > 0.0:
		var h := minf(remaining, MAX_STEP)
		var accel := (target - value) * stiffness - velocity * damping
		velocity += accel * h
		value += velocity * h
		remaining -= h
	return value


func kick(impulse: float) -> void:
	velocity += impulse


func snap(v: float) -> void:
	value = v
	velocity = 0.0
