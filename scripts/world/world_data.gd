class_name WorldData
extends RefCounted
## The generated world as pure data. Nothing here is a Node: the chunk
## streamer turns this into scenery only around the player.
##
## Coordinates: the region spans x,z in [0, SIZE] metres.

const SIZE := 512
const RES := SIZE + 1
const CHUNK := 32
const CHUNKS := SIZE / CHUNK
const FOREST_CELL := 4
const FOREST_RES := SIZE / FOREST_CELL + 1

enum Ground { GRASS, FOREST, ROAD, TRAIL, PLAZA, FIELD, SAND, SHORTCUT }

var world_seed := 0
var region_name := ""
var biome: BiomeDef
var heights := PackedFloat32Array()
var ground := PackedByteArray()
var occupied := PackedByteArray()
var forest := PackedFloat32Array()
var water_level := 0.6
var sites: Array = []
var roads: Array = []
var placements := {}  # Vector2i -> Array[Dictionary]
var jobs: Array = []
var events: Array = []
var dungeons := {}    # site id -> layout Dictionary
var start_pos := Vector3.ZERO
var start_yaw := 0.0
var gen_log: Array[String] = []


func _init() -> void:
	heights.resize(RES * RES)
	ground.resize(RES * RES)
	occupied.resize(RES * RES)
	forest.resize(FOREST_RES * FOREST_RES)


# ---------------------------------------------------------------------------
# Sampling
# ---------------------------------------------------------------------------

func idx(x: int, z: int) -> int:
	return clampi(z, 0, RES - 1) * RES + clampi(x, 0, RES - 1)


func h(x: int, z: int) -> float:
	return heights[idx(x, z)]


func height_at(x: float, z: float) -> float:
	var fx := clampf(x, 0.0, SIZE - 0.001)
	var fz := clampf(z, 0.0, SIZE - 0.001)
	var x0 := int(fx)
	var z0 := int(fz)
	var tx := fx - x0
	var tz := fz - z0
	var a := lerpf(h(x0, z0), h(x0 + 1, z0), tx)
	var b := lerpf(h(x0, z0 + 1), h(x0 + 1, z0 + 1), tx)
	return lerpf(a, b, tz)


func ground_height_at(x: float, z: float) -> float:
	## Matches the rendered/collision triangulation closely enough for placing props.
	return height_at(x, z)


func slope_at(x: float, z: float) -> float:
	var dx := height_at(x + 1.0, z) - height_at(x - 1.0, z)
	var dz := height_at(x, z + 1.0) - height_at(x, z - 1.0)
	return Vector2(dx, dz).length() * 0.5


func ground_at(x: float, z: float) -> int:
	return ground[idx(int(round(x)), int(round(z)))]


func is_occupied(x: float, z: float) -> bool:
	return occupied[idx(int(round(x)), int(round(z)))] != 0


func mark_occupied(center: Vector3, half_extents: Vector2, yaw: float) -> void:
	var r := half_extents.length() + 1.0
	var basis := Basis(Vector3.UP, -yaw)
	for z in range(int(center.z - r), int(center.z + r) + 1):
		for x in range(int(center.x - r), int(center.x + r) + 1):
			var local := basis * Vector3(x - center.x, 0, z - center.z)
			if absf(local.x) <= half_extents.x + 0.5 and absf(local.z) <= half_extents.y + 0.5:
				occupied[idx(x, z)] = 1


func forest_at(x: float, z: float) -> float:
	var gx := clampf(x / FOREST_CELL, 0.0, FOREST_RES - 1.001)
	var gz := clampf(z / FOREST_CELL, 0.0, FOREST_RES - 1.001)
	var x0 := int(gx)
	var z0 := int(gz)
	var tx := gx - x0
	var tz := gz - z0
	var f := func(ix: int, iz: int) -> float: return forest[iz * FOREST_RES + ix]
	return lerpf(lerpf(f.call(x0, z0), f.call(x0 + 1, z0), tx), lerpf(f.call(x0, z0 + 1), f.call(x0 + 1, z0 + 1), tx), tz)


func in_bounds(x: float, z: float, margin := 0.0) -> bool:
	return x >= margin and z >= margin and x <= SIZE - margin and z <= SIZE - margin


# ---------------------------------------------------------------------------
# Sites / placements
# ---------------------------------------------------------------------------

func site(id: String) -> Dictionary:
	for s in sites:
		if s["id"] == id:
			return s
	return {}


func sites_of(kind: String) -> Array:
	return sites.filter(func(s): return s["kind"] == kind)


func find_npc(npc_id: String) -> Dictionary:
	for s in sites:
		for n in s["npcs"]:
			if n["id"] == npc_id:
				return n
	return {}


static func chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(int(floor(pos.x / CHUNK)), 0, CHUNKS - 1), clampi(int(floor(pos.z / CHUNK)), 0, CHUNKS - 1))


func add_placement(p: Dictionary) -> void:
	var c := chunk_of(p["pos"])
	if not placements.has(c):
		placements[c] = []
	placements[c].append(p)


func placements_in(c: Vector2i) -> Array:
	return placements.get(c, [])


func all_placements() -> Array:
	var out := []
	var keys := placements.keys()
	keys.sort()
	for k in keys:
		out.append_array(placements[k])
	return out


## Distance from (x,z) to the nearest road centreline (brute force; only used
## at generation time).
func distance_to_roads(x: float, z: float, ignore_kind := "") -> float:
	var best := 1e9
	var p := Vector2(x, z)
	for r in roads:
		if r["kind"] == ignore_kind:
			continue
		var pts: PackedVector3Array = r["points"]
		for i in range(pts.size() - 1):
			var a := Vector2(pts[i].x, pts[i].z)
			var b := Vector2(pts[i + 1].x, pts[i + 1].z)
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			best = minf(best, p.distance_to(q))
	return best


## Stable hash of the generated content — used by tests to prove that the
## same seed always produces the same world.
func signature() -> int:
	var parts: Array[String] = [region_name, biome.id]
	for i in range(0, heights.size(), 997):
		parts.append("%.3f" % heights[i])
	for s in sites:
		parts.append("%s:%s:%.2f:%.2f:%d" % [s["id"], s["name"], s["pos"].x, s["pos"].z, s["npcs"].size()])
	for r in roads:
		parts.append("%s:%s:%d:%.2f" % [r["id"], r["kind"], r["points"].size(), r["danger"]])
	for p in all_placements():
		parts.append("%s@%.2f,%.2f" % [p["id"], p["pos"].x, p["pos"].z])
	for j in jobs:
		parts.append("%s:%s>%s:%s:%d" % [j["id"], j["from"], j["to"], j["package"], j["reward"]])
	for e in events:
		parts.append("%s:%s" % [e["id"], e["type"]])
	return "|".join(parts).hash()
