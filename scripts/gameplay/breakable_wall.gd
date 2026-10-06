class_name BreakableWall
extends StaticBody3D
## A suspiciously cracked wall. Bonk it twice to find a secret room.

var size := Vector3(3.6, 4.5, 1.0)
var color := Color(0.45, 0.43, 0.46)
var _hits := 0
var _mi: MeshInstance3D


func _ready() -> void:
	collision_layer = 1
	add_to_group("hittable")
	add_to_group("explodable")
	var k := MeshKit.new(10)
	k.box(Transform3D(), size, color)
	for i in 5:
		k.box(MeshKit.rot(Vector3(randf_range(-1, 1), randf_range(-1.5, 1.5), -size.z * 0.5 - 0.01), Vector3(0, 0, randf_range(-1, 1))), Vector3(0.9, 0.06, 0.02), Color(0.15, 0.13, 0.14))
		k.box(MeshKit.rot(Vector3(randf_range(-1, 1), randf_range(-1.5, 1.5), size.z * 0.5 + 0.01), Vector3(0, 0, randf_range(-1, 1))), Vector3(0.9, 0.06, 0.02), Color(0.15, 0.13, 0.14))
	_mi = Mats.instance(Assets.pick("dungeon/cracked_wall", k.commit()))
	add_child(_mi)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	add_child(cs)


func on_bonk(_g: Node, _dir: Vector3, _force: float) -> void:
	_hits += 1
	FX.dust(global_position, 1.5)
	_mi.position = Vector3(randf_range(-0.05, 0.05), 0, randf_range(-0.05, 0.05))
	if _hits >= 2:
		_break()


func apply_explosion(center: Vector3, radius: float, _force: float, _damage: int) -> void:
	if global_position.distance_to(center) < radius + 1.5:
		_break()


func _break() -> void:
	FX.poof(global_position, Color(0.6, 0.58, 0.6))
	FX.poof(global_position + Vector3.UP, Color(0.5, 0.48, 0.5))
	GameState.toast("A secret room!", Color(0.7, 1, 0.8))
	queue_free()
