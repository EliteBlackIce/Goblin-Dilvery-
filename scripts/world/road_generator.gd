class_name RoadGenerator
extends RefCounted
## Builds the courier's road network with A* over a coarse grid.
##
##  main      settlement <-> settlement. Hates slopes, forest and bandit
##            country: SAFE but long and winding.
##  trail     out to the dungeon and landmarks.
##  shortcut  barely cares about terrain or danger, so it cuts straight
##            through the woods past bandit camps: FAST but DANGEROUS.
##
## New roads get a discount on cells that already carry road, so the network
## merges into natural junctions instead of parallel spaghetti. Water crossings
## become bridges; each road gets signposts where it leaves a settlement.

const CELL := 4
const GW := WorldData.SIZE / CELL + 1

const PROFILES := {
	"main": {"slope": 28.0, "water": 70.0, "forest": 3.5, "danger": 8.0, "reuse": 0.3, "half_width": 2.4},
	"trail": {"slope": 16.0, "water": 45.0, "forest": 1.2, "danger": 2.0, "reuse": 0.4, "half_width": 1.4},
	"shortcut": {"slope": 6.0, "water": 30.0, "forest": 0.0, "danger": 0.0, "reuse": 1.0, "half_width": 1.15},
}


static func generate(w: WorldData, rng: RandomNumberGenerator) -> void:
	var base := _base_costs(w)
	var road_mask := PackedByteArray()
	road_mask.resize(GW * GW)
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, GW, GW)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_AT_LEAST_ONE_WALKABLE
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()

	var village: Dictionary = w.site("village")
	var hamlets := w.sites_of("hamlet")
	var settlements := [village] + hamlets

	# 1. Main roads: every hamlet to the village, plus a loop between hamlets.
	for hm in hamlets:
		_add_road(w, astar, base, road_mask, "main", village, hm)
	if hamlets.size() >= 2:
		var d01 := _dist(hamlets[0], hamlets[1])
		if d01 < 300.0:
			_add_road(w, astar, base, road_mask, "main", hamlets[0], hamlets[1])

	# 2. Trails to the dungeon and landmarks (from the nearest settlement).
	for s in w.sites:
		if s["kind"] == "dungeon" or s["kind"] == "landmark":
			var nearest: Dictionary = settlements[0]
			for t in settlements:
				if _dist(s, t) < _dist(s, nearest):
					nearest = t
			_add_road(w, astar, base, road_mask, "trail", nearest, s)

	# 3. Dangerous shortcuts — kept only when they're meaningfully faster.
	var candidates := []
	for i in settlements.size():
		for j in range(i + 1, settlements.size()):
			candidates.append([settlements[i], settlements[j]])
	for s in w.sites_of("dungeon"):
		candidates.append([village, s])
	var options := []
	for pair in candidates:
		var safe_len := _network_length(w, pair[0]["id"], pair[1]["id"])
		var pts := _find_path(w, astar, base, road_mask, "shortcut", pair[0]["pos"], pair[1]["pos"])
		if pts.size() < 2:
			continue
		var length := _poly_len(pts)
		var danger := _danger_of(w, pts) + 0.2
		options.append({"pair": pair, "pts": pts, "ratio": length / maxf(safe_len, 1.0), "danger": danger})
	options.sort_custom(func(a, b): return a["ratio"] < b["ratio"])
	var kept := 0
	for o in options:
		if kept >= 2:
			break
		if o["ratio"] < 0.86 or kept == 0:
			_commit_road(w, road_mask, "shortcut", o["pair"][0], o["pair"][1], o["pts"])
			kept += 1

	# Roads are final: compute danger, carve them into the terrain, add props.
	for r in w.roads:
		r["danger"] = clampf(_danger_of(w, r["points"]) + (0.25 if r["kind"] == "shortcut" else 0.0), 0.0, 1.0)
	for r in w.roads:
		_carve(w, r)
	_bridges(w)
	_signposts(w)


# ---------------------------------------------------------------------------
# Costs and pathfinding
# ---------------------------------------------------------------------------

static func _base_costs(w: WorldData) -> Dictionary:
	var slope := PackedFloat32Array()
	var water := PackedFloat32Array()
	var forest := PackedFloat32Array()
	var danger := PackedFloat32Array()
	var edge := PackedFloat32Array()
	for arr in [slope, water, forest, danger, edge]:
		arr.resize(GW * GW)
	var camps := w.sites_of("camp")
	for gz in GW:
		for gx in GW:
			var i := gz * GW + gx
			var x := float(gx * CELL)
			var z := float(gz * CELL)
			var hc := w.height_at(x, z)
			var s := 0.0
			for o in [Vector2(CELL, 0), Vector2(-CELL, 0), Vector2(0, CELL), Vector2(0, -CELL)]:
				s = maxf(s, absf(w.height_at(x + o.x, z + o.y) - hc) / CELL)
			slope[i] = s
			water[i] = 1.0 if hc < w.water_level + 0.2 else 0.0
			forest[i] = w.forest_at(x, z)
			var dg := 0.0
			for c in camps:
				var d := Vector2(x, z).distance_to(Vector2(c["pos"].x, c["pos"].z))
				dg = maxf(dg, 1.0 - d / 80.0)
			danger[i] = dg
			var e := float(mini(mini(gx, GW - 1 - gx), mini(gz, GW - 1 - gz))) * CELL
			edge[i] = 60.0 if e < 40.0 else 0.0
	return {"slope": slope, "water": water, "forest": forest, "danger": danger, "edge": edge}


static func _cell(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int(round(p.x / CELL)), 0, GW - 1), clampi(int(round(p.z / CELL)), 0, GW - 1))


static func _find_path(w: WorldData, astar: AStarGrid2D, base: Dictionary, road_mask: PackedByteArray, kind: String, from: Vector3, to: Vector3) -> PackedVector3Array:
	var prof: Dictionary = PROFILES[kind]
	var slope: PackedFloat32Array = base["slope"]
	var water: PackedFloat32Array = base["water"]
	var forest: PackedFloat32Array = base["forest"]
	var danger: PackedFloat32Array = base["danger"]
	var edge: PackedFloat32Array = base["edge"]
	var reuse: float = prof["reuse"]
	for gz in GW:
		for gx in GW:
			var i := gz * GW + gx
			var cost: float = 1.0 + slope[i] * prof["slope"] + water[i] * prof["water"] + forest[i] * prof["forest"] + danger[i] * prof["danger"] + edge[i]
			if road_mask[i] != 0:
				cost *= reuse
			astar.set_point_weight_scale(Vector2i(gx, gz), maxf(cost, 0.2))
	var path := astar.get_id_path(_cell(from), _cell(to))
	var pts := PackedVector3Array()
	pts.append(Vector3(from.x, 0, from.z))
	for c in path:
		pts.append(Vector3(c.x * CELL, 0, c.y * CELL))
	pts.append(Vector3(to.x, 0, to.z))
	pts = _chaikin(_chaikin(pts))
	pts = _resample(pts, 2.0)
	# Sample + smooth heights so roads glide over bumps.
	var hs := PackedFloat32Array()
	for p in pts:
		hs.append(w.height_at(p.x, p.z))
	var smooth := PackedFloat32Array()
	smooth.resize(hs.size())
	for i in hs.size():
		var sum := 0.0
		var n := 0
		for k in range(-4, 5):
			var j := clampi(i + k, 0, hs.size() - 1)
			sum += hs[j]
			n += 1
		smooth[i] = maxf(sum / n, w.water_level + 0.45)
	for i in pts.size():
		pts[i].y = smooth[i]
	return pts


static func _add_road(w: WorldData, astar: AStarGrid2D, base: Dictionary, road_mask: PackedByteArray, kind: String, a: Dictionary, b: Dictionary) -> void:
	var pts := _find_path(w, astar, base, road_mask, kind, a["pos"], b["pos"])
	if pts.size() >= 2:
		_commit_road(w, road_mask, kind, a, b, pts)


static func _commit_road(w: WorldData, road_mask: PackedByteArray, kind: String, a: Dictionary, b: Dictionary, pts: PackedVector3Array) -> void:
	var r := {
		"id": "road_%d" % w.roads.size(), "kind": kind, "from": a["id"], "to": b["id"],
		"points": pts, "length": _poly_len(pts), "danger": 0.0, "half_width": PROFILES[kind]["half_width"],
	}
	var wet := PackedByteArray()
	for p in pts:
		wet.append(1 if w.height_at(p.x, p.z) < w.water_level + 0.1 else 0)
	r["wet"] = wet
	w.roads.append(r)
	for p in pts:
		var c := _cell(p)
		road_mask[c.y * GW + c.x] = 1


## Length of the safe route between two sites over main roads (direct road,
## or via the village).
static func _network_length(w: WorldData, a: String, b: String) -> float:
	var direct := 1e9
	var via := {}
	for r in w.roads:
		if r["kind"] == "shortcut":
			continue
		if (r["from"] == a and r["to"] == b) or (r["from"] == b and r["to"] == a):
			direct = minf(direct, r["length"])
		for s in [a, b]:
			if (r["from"] == s and r["to"] == "village") or (r["from"] == "village" and r["to"] == s):
				via[s] = r["length"]
	if a == "village" and via.has(b):
		direct = minf(direct, via[b])
	if b == "village" and via.has(a):
		direct = minf(direct, via[a])
	if via.has(a) and via.has(b):
		direct = minf(direct, via[a] + via[b])
	if direct >= 1e9:
		# Not on the main network (e.g. the dungeon): straight line x1.6.
		var sa := w.site(a)
		var sb := w.site(b)
		direct = Vector2(sa["pos"].x, sa["pos"].z).distance_to(Vector2(sb["pos"].x, sb["pos"].z)) * 1.6
		for r in w.roads:
			if r["to"] == b and r["kind"] == "trail":
				direct = minf(direct, r["length"] + (0.0 if r["from"] == a else _network_length(w, a, r["from"])))
	return direct


static func _danger_of(w: WorldData, pts: PackedVector3Array) -> float:
	if pts.is_empty():
		return 0.0
	var camps := w.sites_of("camp")
	var total := 0.0
	for p in pts:
		var dg := 0.0
		for c in camps:
			dg = maxf(dg, 1.0 - Vector2(p.x, p.z).distance_to(Vector2(c["pos"].x, c["pos"].z)) / 90.0)
		total += w.forest_at(p.x, p.z) * 0.6 + dg
	return clampf(total / pts.size() * 1.6, 0.0, 1.0)


static func _dist(a: Dictionary, b: Dictionary) -> float:
	return Vector2(a["pos"].x, a["pos"].z).distance_to(Vector2(b["pos"].x, b["pos"].z))


static func _poly_len(pts: PackedVector3Array) -> float:
	var l := 0.0
	for i in range(pts.size() - 1):
		l += Vector2(pts[i].x, pts[i].z).distance_to(Vector2(pts[i + 1].x, pts[i + 1].z))
	return l


static func _chaikin(pts: PackedVector3Array) -> PackedVector3Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector3Array()
	out.append(pts[0])
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		out.append(a.lerp(b, 0.25))
		out.append(a.lerp(b, 0.75))
	out.append(pts[pts.size() - 1])
	return out


static func _resample(pts: PackedVector3Array, spacing: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if pts.size() < 2:
		return pts
	out.append(pts[0])
	var carry := 0.0
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := spacing - carry
		while t <= seg:
			out.append(a.lerp(b, t / seg))
			t += spacing
		carry = seg - (t - spacing)
	if out[out.size() - 1].distance_to(pts[pts.size() - 1]) > 0.5:
		out.append(pts[pts.size() - 1])
	return out


# ---------------------------------------------------------------------------
# Terrain carving, bridges, signposts
# ---------------------------------------------------------------------------

static func _carve(w: WorldData, r: Dictionary) -> void:
	var pts: PackedVector3Array = r["points"]
	var hw: float = r["half_width"]
	var fall := 3.0
	var gtype: int = {"main": WorldData.Ground.ROAD, "trail": WorldData.Ground.TRAIL, "shortcut": WorldData.Ground.SHORTCUT}[r["kind"]]
	var res := WorldData.RES
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var reach := hw + fall
		var x0 := int(floor(minf(a.x, b.x) - reach))
		var x1 := int(ceil(maxf(a.x, b.x) + reach))
		var z0 := int(floor(minf(a.z, b.z) - reach))
		var z1 := int(ceil(maxf(a.z, b.z) + reach))
		var ab := b2 - a2
		var ab_len2 := maxf(ab.length_squared(), 0.0001)
		for z in range(z0, z1 + 1):
			if z < 0 or z >= res:
				continue
			for x in range(x0, x1 + 1):
				if x < 0 or x >= res:
					continue
				var p := Vector2(x, z)
				var t := clampf((p - a2).dot(ab) / ab_len2, 0.0, 1.0)
				var d := p.distance_to(a2 + ab * t)
				if d > reach:
					continue
				var road_h := lerpf(a.y, b.y, t)
				var k := z * res + x
				if d <= hw:
					w.heights[k] = road_h
					# Main roads win over trails where they overlap.
					var cur := w.ground[k]
					if cur != WorldData.Ground.ROAD and cur != WorldData.Ground.PLAZA:
						w.ground[k] = gtype
				else:
					var wt := smoothstep(reach, hw, d)
					w.heights[k] = lerpf(w.heights[k], road_h, wt * 0.85)


static func _bridges(w: WorldData) -> void:
	var n := 0
	for r in w.roads:
		var pts: PackedVector3Array = r["points"]
		var wet: PackedByteArray = r["wet"]
		for i in range(1, pts.size() - 1):
			var p := pts[i]
			# Crossing what used to be water -> plank bridge over a causeway.
			if wet[i] != 0 or wet[i - 1] != 0 or wet[i + 1] != 0:
				var dir := pts[i + 1] - pts[i - 1]
				var yaw := atan2(-dir.x, -dir.z)
				w.add_placement({"id": "bridge:%d" % n, "kind": "piece", "piece": "bridge_segment", "pos": Vector3(p.x, p.y + 0.05, p.z), "yaw": yaw, "data": {"width": r["half_width"] * 2.0 + 0.6}})
				n += 1


static func _signposts(w: WorldData) -> void:
	var n := 0
	var made := []
	for s in w.sites:
		if s["kind"] != "village" and s["kind"] != "hamlet":
			continue
		var c: Vector3 = s["pos"]
		var ring: float = s["radius"] + 3.0
		for r in w.roads:
			var other := ""
			if r["from"] == s["id"]:
				other = r["to"]
			elif r["to"] == s["id"]:
				other = r["from"]
			else:
				continue
			var pts: PackedVector3Array = r["points"]
			var best_i := -1
			for i in pts.size():
				if absf(Vector2(pts[i].x, pts[i].z).distance_to(Vector2(c.x, c.z)) - ring) < 1.5:
					best_i = i
					break
			if best_i < 1:
				continue
			var p := pts[best_i]
			var along := (pts[mini(best_i + 1, pts.size() - 1)] - pts[best_i - 1]).normalized()
			var side: Vector3 = Vector3(-along.z, 0, along.x) * (float(r["half_width"]) + 1.2)
			var sp: Vector3 = p + side
			sp.y = w.height_at(sp.x, sp.z)
			var dest: Dictionary = w.site(other)
			var to_dest: Vector3 = (dest["pos"] as Vector3) - sp
			var yaw := atan2(-to_dest.x, -to_dest.z)
			var skulls := ""
			for k in int(round(r["danger"] * 3.0)):
				skulls += "!"
			var text := "%s  %dm %s" % [dest["name"], int(r["length"]), skulls]
			if r["kind"] == "shortcut":
				text = "SHORTCUT -> %s\n(beware: bandits)" % dest["name"]
			var merged := false
			for prev in made:
				if (prev["pos"] as Vector3).distance_to(sp) < 6.0:
					prev["data"]["text"] += "\n" + text
					prev["data"]["danger"] = maxf(prev["data"]["danger"], r["danger"])
					merged = true
					break
			if merged:
				continue
			var sign := {"id": "sign:%d" % n, "kind": "signpost", "pos": sp, "yaw": yaw, "data": {"text": text, "danger": r["danger"]}}
			made.append(sign)
			w.add_placement(sign)
			n += 1
