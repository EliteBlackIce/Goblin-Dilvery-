class_name TerrainChunk
extends Node3D
## One 32x32 m piece of the world: flat-shaded terrain mesh, heightmap
## collision, instanced vegetation, and whatever generated placements sit
## inside it. Created when the player gets near, freed when they leave.

const VEG_RANGES := {
	"grass": 45.0, "flower_r": 55.0, "flower_y": 55.0, "flower_w": 55.0, "mushroom": 45.0,
	"bush": 120.0, "rock": 150.0, "rock2": 170.0,
}
const TREE_RADIUS := {"oak": 0.35, "oak2": 0.35, "pine": 0.3, "birch": 0.25, "rock2": 1.0}

var coord := Vector2i.ZERO


func build(w: WorldData, c: Vector2i, color_noise: FastNoiseLite, spawn: Callable) -> void:
	coord = c
	name = "Chunk_%d_%d" % [c.x, c.y]
	_build_terrain(w, color_noise)
	_build_collision(w)
	_build_vegetation(w)
	for p in w.placements_in(c):
		spawn.call(p, self)


# ---------------------------------------------------------------------------
# Terrain mesh
# ---------------------------------------------------------------------------

func _build_terrain(w: WorldData, noise: FastNoiseLite) -> void:
	var n := WorldData.CHUNK
	var x0 := coord.x * n
	var z0 := coord.y * n
	var b := w.biome
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var tri_count := n * n * 2
	verts.resize(tri_count * 3)
	normals.resize(tri_count * 3)
	colors.resize(tri_count * 3)
	var vi := 0
	var jit := RandomNumberGenerator.new()
	jit.seed = hash(c_key(coord))
	for z in range(z0, z0 + n):
		for x in range(x0, x0 + n):
			var pa := Vector3(x, w.h(x, z), z)
			var pb := Vector3(x + 1, w.h(x + 1, z), z)
			var pc := Vector3(x + 1, w.h(x + 1, z + 1), z + 1)
			var pd := Vector3(x, w.h(x, z + 1), z + 1)
			for t in 2:
				var a := pa if t == 0 else pb
				var bb := pb if t == 0 else pc
				var cc := pd
				var nrm := (cc - a).cross(bb - a).normalized()
				var cen := (a + bb + cc) / 3.0
				var col := _ground_color(w, b, cen, nrm, noise)
				var j := jit.randf_range(-0.035, 0.035)
				col = Color(col.r + j, col.g + j, col.b + j)
				verts[vi] = a
				verts[vi + 1] = bb
				verts[vi + 2] = cc
				for k in 3:
					normals[vi + k] = nrm
					colors[vi + k] = col
				vi += 3
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = Mats.vertex(false)
	mi.name = "Terrain"
	add_child(mi)


static func c_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _ground_color(w: WorldData, b: BiomeDef, p: Vector3, nrm: Vector3, noise: FastNoiseLite) -> Color:
	var g := w.ground_at(p.x, p.z)
	var steep := 1.0 - nrm.y
	var col: Color
	match g:
		WorldData.Ground.ROAD:
			col = b.road
		WorldData.Ground.TRAIL:
			col = b.trail
		WorldData.Ground.SHORTCUT:
			col = b.trail.darkened(0.12)
		WorldData.Ground.PLAZA:
			col = b.plaza
		WorldData.Ground.FIELD:
			col = b.field_b if int(p.x + p.z) % 2 == 0 else b.field_b.lightened(0.08)
		WorldData.Ground.FOREST:
			col = b.forest_floor.lerp(b.grass_a, clampf(noise.get_noise_2d(p.x, p.z) * 0.5, 0.0, 0.4))
		_:
			col = b.grass_a.lerp(b.grass_b, clampf(noise.get_noise_2d(p.x, p.z) + 0.5, 0.0, 1.0))
	if g == WorldData.Ground.GRASS or g == WorldData.Ground.FOREST:
		if p.y < w.water_level + 0.7:
			col = b.sand
		elif steep > 0.45:
			col = b.rock
		elif steep > 0.22:
			col = b.cliff
	# Gentle height tint so hills read from a distance.
	col = col.lightened(clampf((p.y - 8.0) * 0.006, -0.05, 0.12))
	return col


func _build_collision(w: WorldData) -> void:
	var n := WorldData.CHUNK + 1
	var data := PackedFloat32Array()
	data.resize(n * n)
	var x0 := coord.x * WorldData.CHUNK
	var z0 := coord.y * WorldData.CHUNK
	for z in n:
		for x in n:
			data[z * n + x] = w.h(x0 + x, z0 + z)
	var shape := HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "Ground"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = Vector3(x0 + WorldData.CHUNK * 0.5, 0, z0 + WorldData.CHUNK * 0.5)
	body.add_child(cs)
	add_child(body)


# ---------------------------------------------------------------------------
# Vegetation (deterministic per chunk, generated on load)
# ---------------------------------------------------------------------------

func _blocked(w: WorldData, x: float, z: float) -> bool:
	if not w.in_bounds(x, z, 1.0) or w.is_occupied(x, z):
		return true
	for o in [Vector2.ZERO, Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
		var g := w.ground_at(x + o.x, z + o.y)
		if g != WorldData.Ground.GRASS and g != WorldData.Ground.FOREST:
			return true
	return false


func _build_vegetation(w: WorldData) -> void:
	var rng := WorldRng.stream(w.world_seed, "veg:%d:%d" % [coord.x, coord.y])
	var x0 := float(coord.x * WorldData.CHUNK)
	var z0 := float(coord.y * WorldData.CHUNK)
	var xforms := {}
	var colliders := []
	var tree_weights: Dictionary = w.biome.tree_kinds

	# Trees, bushes, rocks on a jittered 4 m grid.
	for gz in 8:
		for gx in 8:
			var x := x0 + gx * 4.0 + rng.randf_range(0.3, 3.7)
			var z := z0 + gz * 4.0 + rng.randf_range(0.3, 3.7)
			var roll := rng.randf()
			var yaw := rng.randf() * TAU
			var s := rng.randf_range(0.8, 1.35)
			var h := w.height_at(x, z)
			if h < w.water_level + 0.5 or _blocked(w, x, z):
				continue
			var slope := w.slope_at(x, z)
			var forest := w.forest_at(x, z)
			var kind := ""
			if roll < forest * 0.8 + 0.03 and slope < 0.8:
				kind = WorldRng.pick_weighted(rng, tree_weights)
				if kind == "oak" and rng.randf() < 0.4:
					kind = "oak2"
			elif roll < forest * 0.8 + 0.03 + 0.07 + forest * 0.1:
				kind = "bush"
			elif roll > 0.965 - slope * 0.1:
				kind = "rock2" if rng.randf() < 0.35 else "rock"
			if kind == "":
				continue
			_add(xforms, kind, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * s), Vector3(x, h - 0.1, z)))
			if TREE_RADIUS.has(kind):
				colliders.append([Vector3(x, h, z), TREE_RADIUS[kind] * s, kind])

	# Ground cover on a 2 m grid.
	for gz in 16:
		for gx in 16:
			var x := x0 + gx * 2.0 + rng.randf_range(0.2, 1.8)
			var z := z0 + gz * 2.0 + rng.randf_range(0.2, 1.8)
			var roll := rng.randf()
			var pick := rng.randf()
			var yaw := rng.randf() * TAU
			if roll > 0.42:
				continue
			var g := w.ground_at(x, z)
			if g != WorldData.Ground.GRASS and g != WorldData.Ground.FOREST:
				continue
			if w.is_occupied(x, z):
				continue
			var h := w.height_at(x, z)
			if h < w.water_level + 0.6:
				continue
			var kind := "grass"
			if g == WorldData.Ground.FOREST:
				kind = "mushroom" if pick < 0.12 else ("grass" if pick < 0.5 else "")
			elif pick < 0.1:
				kind = ["flower_r", "flower_y", "flower_w"][int(pick * 30.0) % 3]
			if kind == "":
				continue
			_add(xforms, kind, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.8, 1.3)), Vector3(x, h - 0.05, z)))

	for kind in xforms.keys():
		var list: Array = xforms[kind]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = Vegetation.mesh(kind)
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		if not Assets.is_custom(mm.mesh):
			mmi.material_override = Mats.vertex()
		mmi.visibility_range_end = VEG_RANGES.get(kind, 210.0)
		if kind in ["grass", "flower_r", "flower_y", "flower_w", "mushroom"]:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

	if not colliders.is_empty():
		var body := StaticBody3D.new()
		body.name = "Trees"
		body.collision_layer = 1
		body.collision_mask = 0
		for c in colliders:
			var cs := CollisionShape3D.new()
			if c[2] == "rock2":
				var sph := SphereShape3D.new()
				sph.radius = c[1]
				cs.shape = sph
				cs.position = c[0] + Vector3(0, c[1] * 0.4, 0)
			else:
				var cyl := CylinderShape3D.new()
				cyl.radius = c[1]
				cyl.height = 3.0
				cs.shape = cyl
				cs.position = c[0] + Vector3(0, 1.5, 0)
			body.add_child(cs)
		add_child(body)


func _add(xforms: Dictionary, kind: String, xf: Transform3D) -> void:
	if not xforms.has(kind):
		xforms[kind] = []
	xforms[kind].append(xf)
