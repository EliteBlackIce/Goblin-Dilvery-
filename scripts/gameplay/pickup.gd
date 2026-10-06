class_name Pickup
extends Node3D
## Spinning coin pile. Collected automatically when the goblin walks close.

var amount := 3
var placement_id := ""
var _t := 0.0
var _mesh: Node3D
static var _coin_mesh: ArrayMesh


func _ready() -> void:
	if _coin_mesh == null:
		var k := MeshKit.new(4, 0.0)
		for i in 3:
			k.cylinder(MeshKit.rot(Vector3(i * 0.12 - 0.12, 0.25 + (i % 2) * 0.08, 0), Vector3(PI * 0.5, 0, 0.3 * i)), 0.16, 0.16, 0.05, Color(1.0, 0.82, 0.25), 8)
		_coin_mesh = k.commit()
	_mesh = Node3D.new()
	add_child(_mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = _coin_mesh
	mi.material_override = Mats.color(Color(1.0, 0.82, 0.25), 0.4)
	_mesh.add_child(mi)
	_t = randf() * 5.0


func _physics_process(delta: float) -> void:
	_t += delta
	_mesh.rotation.y = _t * 2.5
	_mesh.position.y = sin(_t * 3.0) * 0.1
	var p := GameState.player
	if p and p.global_position.distance_to(global_position) < 1.4 and p.ragdoll == null:
		GameState.add_gold(amount)
		if placement_id != "":
			GameState.consume(placement_id)
		FX.sparkle(global_position)
		queue_free()
