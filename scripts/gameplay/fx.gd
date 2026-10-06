class_name FX
extends RefCounted
## Cheap, pooled, tween-driven visual effects (dust puffs, poofs, sparks).
## No particle systems needed: a few low-poly spheres that pop and fade.

static var _puff_mesh: ArrayMesh
static var _pool: Array[MeshInstance3D] = []
static var _root: Node3D
const POOL_SIZE := 48


static func _ensure(tree: SceneTree) -> void:
	if _root != null and is_instance_valid(_root) and _root.is_inside_tree():
		return
	_root = Node3D.new()
	_root.name = "FXRoot"
	tree.current_scene.add_child(_root)
	_pool.clear()
	if _puff_mesh == null:
		var k := MeshKit.new(5, 0.0)
		k.sphere(Transform3D(), 0.5, Color.WHITE, 6, 4)
		_puff_mesh = Assets.pick("fx/puff", k.commit())


static func _get_puff(tree: SceneTree) -> MeshInstance3D:
	_ensure(tree)
	for mi in _pool:
		if not mi.visible:
			return mi
	if _pool.size() < POOL_SIZE:
		var mi := MeshInstance3D.new()
		mi.mesh = _puff_mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		_root.add_child(mi)
		_pool.append(mi)
		return mi
	return null


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func puff(pos: Vector3, color: Color, size: float, rise: float, life: float) -> void:
	var tree := _tree()
	if tree == null or tree.current_scene == null:
		return
	var mi := _get_puff(tree)
	if mi == null:
		return
	mi.material_override = Mats.color(color)
	mi.visible = true
	mi.global_position = pos
	mi.scale = Vector3.ONE * size * 0.4
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(mi, "global_position", pos + Vector3(randf_range(-0.3, 0.3), rise, randf_range(-0.3, 0.3)), life)
	tw.chain().tween_property(mi, "scale", Vector3.ZERO, life * 0.5)
	tw.chain().tween_callback(func(): mi.visible = false)


static func dust(pos: Vector3, strength: float) -> void:
	var n := clampi(int(2 + strength * 3), 2, 7)
	for i in n:
		var a := TAU * float(i) / float(n) + randf() * 0.5
		var off := Vector3(cos(a), 0.05, sin(a)) * 0.35 * strength
		puff(pos + off + Vector3.UP * 0.1, Color(0.85, 0.78, 0.62), 0.35 * strength + 0.15, 0.3 * strength, 0.35)


static func poof(pos: Vector3, color := Color(0.95, 0.95, 0.95)) -> void:
	for i in 8:
		var off := Vector3(randf_range(-0.6, 0.6), randf_range(0.0, 0.8), randf_range(-0.6, 0.6))
		puff(pos + off, color, randf_range(0.5, 0.9), 0.6, 0.45)


static func sparkle(pos: Vector3, color := Color(1, 0.9, 0.3)) -> void:
	for i in 6:
		var off := Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), randf_range(-0.4, 0.4))
		puff(pos + off, color, 0.18, 1.0, 0.6)
