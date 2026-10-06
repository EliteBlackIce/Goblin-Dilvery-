class_name PhysicsProp
extends RigidBody3D
## Crates, barrels, hay bales and (gulp) explosive barrels. They can be
## bonked, kicked around by the goblin, launched by explosions — and rolled
## into the goblin, which knocks HIM over in turn.

const TYPES := {
	"crate": {"mass": 2.0, "size": Vector3(0.8, 0.8, 0.8), "color": Color(0.7, 0.52, 0.32)},
	"barrel": {"mass": 2.5, "size": Vector3(0.8, 0.95, 0.8), "color": Color(0.55, 0.36, 0.2)},
	"explosive_barrel": {"mass": 2.5, "size": Vector3(0.8, 0.95, 0.8), "color": Color(0.8, 0.2, 0.15)},
	"haybale": {"mass": 6.0, "size": Vector3(1.3, 0.8, 0.9), "color": Color(0.9, 0.78, 0.35)},
}

var type_id := "crate"
var placement_id := ""
var _exploding := false
var _mi: MeshInstance3D
static var _meshes := {}


func _ready() -> void:
	var d: Dictionary = TYPES.get(type_id, TYPES["crate"])
	mass = d["mass"]
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 8 | 16
	continuous_cd = false
	contact_monitor = type_id == "explosive_barrel"
	max_contacts_reported = 2 if contact_monitor else 0
	can_sleep = true
	add_to_group("hittable")
	add_to_group("explodable")
	var size: Vector3 = d["size"]
	var cs := CollisionShape3D.new()
	if type_id.ends_with("barrel"):
		var c := CylinderShape3D.new()
		c.radius = size.x * 0.5
		c.height = size.y
		cs.shape = c
	else:
		var b := BoxShape3D.new()
		b.size = size
		cs.shape = b
	add_child(cs)
	_mi = Mats.instance(_mesh_for(type_id))
	_mi.visibility_range_end = 120.0
	add_child(_mi)
	if contact_monitor:
		body_entered.connect(_on_body_entered)


static func _mesh_for(t: String) -> ArrayMesh:
	if _meshes.has(t):
		return _meshes[t]
	var d: Dictionary = TYPES.get(t, TYPES["crate"])
	var size: Vector3 = d["size"]
	var c: Color = d["color"]
	var k := MeshKit.new(t.hash())
	match t:
		"barrel", "explosive_barrel":
			k.cylinder(Transform3D(), size.x * 0.45, size.x * 0.45, size.y, c, 10)
			k.cylinder(MeshKit.at(Vector3(0, 0, 0)), size.x * 0.5, size.x * 0.5, size.y * 0.5, c.lightened(0.05), 10)
			for y in [-0.35, 0.35]:
				k.cylinder(MeshKit.at(Vector3(0, size.y * y, 0)), size.x * 0.48, size.x * 0.48, 0.06, Color(0.2, 0.2, 0.22), 10)
			if t == "explosive_barrel":
				k.box(MeshKit.at(Vector3(0, 0, -size.x * 0.5)), Vector3(0.32, 0.32, 0.03), Color(1, 0.9, 0.2))
				k.box(MeshKit.at(Vector3(0, 0.02, -size.x * 0.5 - 0.02)), Vector3(0.08, 0.2, 0.02), Color(0.1, 0.1, 0.1))
		"haybale":
			k.box(Transform3D(), size, c)
			for x in [-0.35, 0.35]:
				k.box(MeshKit.at(Vector3(x * size.x, 0, 0)), Vector3(0.05, size.y + 0.02, size.z + 0.02), Color(0.6, 0.45, 0.25))
		_:
			k.box(Transform3D(), size, c)
			k.box(Transform3D(), Vector3(size.x + 0.02, 0.12, size.z + 0.02), c.darkened(0.25))
			k.box(Transform3D(), Vector3(0.12, size.y + 0.02, size.z + 0.02), c.darkened(0.25))
	_meshes[t] = k.commit()
	return _meshes[t]


func on_bonk(_g: Node, dir: Vector3, force: float) -> void:
	if type_id == "explosive_barrel":
		_explode_soon(0.25)
		GameState.toast("You bonked the explosive barrel. Why.", Color(1, 0.5, 0.3))
		return
	apply_central_impulse(dir * force * mass * 0.7)
	apply_torque_impulse(Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * mass)


func apply_explosion(center: Vector3, radius: float, force: float, _damage: int) -> void:
	var to := global_position - center
	if to.length() > radius * 1.3 or to.length() < 0.01:
		return
	if type_id == "explosive_barrel":
		_explode_soon(randf_range(0.12, 0.3))  # chain reaction!
		return
	var falloff := 1.0 - minf(to.length() / (radius * 1.3), 1.0)
	apply_central_impulse((to.normalized() + Vector3.UP * 0.6).normalized() * force * mass * falloff * 0.8)


func _on_body_entered(_body: Node) -> void:
	if linear_velocity.length() > 7.0:
		_explode_soon(0.05)


func _explode_soon(delay: float) -> void:
	if _exploding:
		return
	_exploding = true
	GameState.consume(placement_id)
	var tw := create_tween()
	tw.tween_property(_mi, "scale", Vector3.ONE * 1.3, delay)
	tw.tween_callback(func():
		var pos := global_position
		var tree := get_tree()
		queue_free()
		Explosion.explode(tree, pos, 5.5, 15.0, 2))
