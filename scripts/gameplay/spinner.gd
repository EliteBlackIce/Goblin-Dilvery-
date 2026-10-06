class_name Spinner
extends Node3D
## Rotates continuously (windmill blades, magic orbs...).

@export var axis := Vector3.UP
@export var speed := 1.0


func _process(delta: float) -> void:
	rotate_object_local(axis, speed * delta)
