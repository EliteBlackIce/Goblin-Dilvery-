class_name Assets
extends RefCounted
## Art override system for a graphical overhaul.
##
## Every mesh the game builds in code goes through Assets.pick("<id>", mesh).
## If you put a model at  res://assets/models/<id>.glb  (or .gltf/.tscn/.tres/
## .res/.obj) it is used instead. Example: res://assets/models/goblin/skull.glb
## replaces the goblin's head. The ids are exactly the file names exported to
## res://assets/source/ by tools/export_assets.tscn — edit a copy, drop it into
## assets/models/ under the same name, done.
##
## Custom models keep their own materials/textures; built-in ones use the
## shared vertex-colour material.

const OVERRIDE_DIR := "res://assets/models/"
const EXTS := [".glb", ".gltf", ".tscn", ".scn", ".tres", ".res", ".obj"]

static var _overrides := {}  # id -> Mesh or null (cached lookups)
static var seen := {}        # id -> built-in Mesh (used by the exporter)


static func pick(id: String, built_in: Mesh) -> Mesh:
	if not seen.has(id):
		seen[id] = built_in
	var custom := override(id)
	return custom if custom != null else built_in


static func override(id: String) -> Mesh:
	if _overrides.has(id):
		return _overrides[id]
	var found: Mesh = null
	for ext in EXTS:
		var path: String = OVERRIDE_DIR + id + ext
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is Mesh:
				found = res
			elif res is PackedScene:
				var n: Node = (res as PackedScene).instantiate()
				found = _first_mesh(n)
				n.free()
			break
	_overrides[id] = found
	return found


static func _first_mesh(n: Node) -> Mesh:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var mi := n as MeshInstance3D
		var m: Mesh = mi.mesh
		# Bake per-instance surface overrides into the mesh so they survive.
		for i in mi.get_surface_override_material_count():
			var mat := mi.get_surface_override_material(i)
			if mat != null and m is ArrayMesh:
				m = m.duplicate()
				(m as ArrayMesh).surface_set_material(i, mat)
		return m
	for c in n.get_children():
		var m := _first_mesh(c)
		if m != null:
			return m
	return null


static func is_custom(m: Mesh) -> bool:
	return m != null and m.get_surface_count() > 0 and m.surface_get_material(0) != null
