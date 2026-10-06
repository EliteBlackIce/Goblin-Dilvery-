class_name SettlementGenerator
extends RefCounted
## Lays out a village/hamlet from handcrafted building pieces.
##
## Streets radiate from a central plaza and line up with the roads that
## arrive at the settlement. Lots are cut along both sides of each street;
## important buildings claim the lots nearest the plaza, houses fill the rest.
## The settlement's PERSONALITY decides the building mix, palette, props,
## species of the villagers and how they talk.

const FOOTPRINTS := {
	"post_office": Vector2(4.0, 3.5), "tavern": Vector2(4.5, 4.0), "blacksmith": Vector2(3.6, 3.0),
	"shop": Vector2(3.2, 2.8), "temple": Vector2(3.8, 5.0), "town_hall": Vector2(5.0, 4.0),
	"stable": Vector2(4.0, 2.8), "house_small": Vector2(2.4, 2.4), "house_medium": Vector2(3.0, 2.6),
	"house_tall": Vector2(2.5, 2.5), "goblin_hut": Vector2(2.5, 2.5), "ruined_house": Vector2(2.6, 2.6),
	"farmhouse": Vector2(3.6, 3.0), "barn": Vector2(4.5, 3.5), "windmill": Vector2(2.6, 2.6),
	"guard_tower": Vector2(1.8, 1.8), "tent": Vector2(1.9, 1.9),
}

const ROLES := {
	"post_office": "postmaster", "tavern": "innkeeper", "blacksmith": "smith", "shop": "shopkeeper",
	"temple": "priest", "town_hall": "mayor", "stable": "stablehand", "farmhouse": "farmer",
	"barn": "farmer", "windmill": "miller", "house_small": "resident", "house_medium": "resident",
	"house_tall": "resident", "goblin_hut": "resident", "tent": "resident",
}


static func layout(w: WorldData, site: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Vector3 = site["pos"]
	var pers: String = site["personality"]
	var is_village: bool = site["kind"] == "village"
	var plaza_r := 10.0 if is_village else 7.0
	var street_len: float = site["radius"] - 3.0
	var id: String = site["id"]
	var placed: Array = []  # {pos, r}

	# --- Streets follow the roads that arrive here -------------------------
	var streets: Array = []
	for r in w.roads:
		if r["from"] == id or r["to"] == id:
			var a := _exit_angle(c, r["points"], plaza_r + 12.0)
			if not _angle_taken(streets, a, 0.6):
				streets.append(a)
	var want := 4 if is_village else 2
	var guard := 0
	while streets.size() < want and guard < 50:
		guard += 1
		var a := rng.randf() * TAU
		if not _angle_taken(streets, a, 1.0):
			streets.append(a)
	site["streets"] = streets

	_paint_disc(w, c, plaza_r, WorldData.Ground.PLAZA)
	for a in streets:
		_paint_street(w, c, a, plaza_r, street_len, 1.7)

	# --- Plaza centrepiece --------------------------------------------------
	var center_piece := "statue" if pers == "wealthy" else ("well" if pers != "abandoned" else "dead_tree")
	w.add_placement({"id": id + ":center", "kind": "piece", "piece": center_piece, "pos": c, "yaw": rng.randf() * TAU, "data": {"palette": pers}})
	placed.append({"pos": c, "r": 2.0})

	# --- Post office claims the plaza (home village only) ------------------
	if is_village:
		var gap := _largest_gap_angle(streets)
		var half: Vector2 = FOOTPRINTS["post_office"]
		var dir := Vector3(cos(gap), 0, sin(gap))
		var pos := c + dir * (plaza_r + half.y + 1.0)
		pos.y = w.height_at(pos.x, pos.z)
		var yaw := atan2(dir.x, dir.z)  # front (-Z) faces the plaza
		_add_building(w, site, rng, "post_office", pos, yaw, half, placed, pers)
		site["post_office"] = {"pos": pos, "yaw": yaw, "depth": half.y * 2.0}
		# Notice board next to the door.
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var bp := pos - dir * (half.y + 1.5) + right * (half.x + 0.5)
		bp.y = w.height_at(bp.x, bp.z)
		w.add_placement({"id": id + ":board", "kind": "board", "pos": bp, "yaw": yaw, "data": {"site": id}})
		placed.append({"pos": bp, "r": 1.0})
		# Market stalls in the other gaps around the plaza.
		var stall_angles := _gap_angles(streets, gap)
		for i in mini(3, stall_angles.size()):
			var sa: float = stall_angles[i]
			var sd := Vector3(cos(sa), 0, sin(sa))
			var sp := c + sd * (plaza_r - 2.0)
			sp.y = w.height_at(sp.x, sp.z)
			w.add_placement({"id": "%s:stall%d" % [id, i], "kind": "piece", "piece": "market_stall", "pos": sp, "yaw": atan2(sd.x, sd.z), "data": {"seed": rng.randi()}})
			placed.append({"pos": sp, "r": 1.8})
	else:
		var a0: float = streets[0] + 0.8
		var bp := c + Vector3(cos(a0), 0, sin(a0)) * (plaza_r + 0.5)
		bp.y = w.height_at(bp.x, bp.z)
		w.add_placement({"id": id + ":board", "kind": "board", "pos": bp, "yaw": atan2(cos(a0), sin(a0)), "data": {"site": id}})
		placed.append({"pos": bp, "r": 1.0})

	# --- Building mix by personality ----------------------------------------
	var queue: Array = []
	match pers:
		"farm":
			queue = ["farmhouse", "barn", "windmill", "house_small", "house_medium"]
		"abandoned":
			queue = ["house_small", "ruined_house", "ruined_house", "ruined_house", "ruined_house", "ruined_house"]
		"bandit":
			queue = ["house_medium", "house_small", "tent", "tent", "house_small", "tent"]
		"goblin":
			queue = ["tavern", "blacksmith", "shop", "temple", "town_hall", "stable"]
			for i in rng.randi_range(9, 12):
				queue.append("goblin_hut")
		"wealthy":
			queue = ["town_hall", "temple", "tavern", "shop", "blacksmith", "stable", "guard_tower", "guard_tower"]
			for i in rng.randi_range(9, 12):
				queue.append("house_tall" if rng.randf() < 0.5 else "house_medium")
		_:
			if is_village:
				queue = ["tavern", "blacksmith", "shop", "temple", "town_hall", "stable"]
				for i in rng.randi_range(8, 11):
					queue.append(WorldRng.pick(rng, ["house_small", "house_medium", "house_tall"]))
			else:
				queue = ["shop", "house_small", "house_medium", "house_small", "house_tall"]

	# --- Lots along both sides of every street ------------------------------
	var lots: Array = []
	for si in streets.size():
		var a: float = streets[si]
		var dir := Vector3(cos(a), 0, sin(a))
		var perp := Vector3(-dir.z, 0, dir.x)
		var d := plaza_r + 5.5
		while d < street_len:
			for side in [-1.0, 1.0]:
				lots.append({"street_pt": c + dir * d, "perp": perp * side, "dist": d + side * 0.01 + si * 0.001})
			d += rng.randf_range(8.0, 10.5)
	lots.sort_custom(func(x, y): return x["dist"] < y["dist"])

	for btype in queue:
		var half: Vector2 = FOOTPRINTS[btype]
		for li in lots.size():
			var lot: Dictionary = lots[li]
			var perp: Vector3 = lot["perp"]
			var pos: Vector3 = lot["street_pt"] + perp * (2.4 + half.y)
			pos.y = w.height_at(pos.x, pos.z)
			var face := -perp
			var yaw := atan2(-face.x, -face.z)
			if _lot_ok(w, site, pos, half, placed):
				_add_building(w, site, rng, btype, pos, yaw, half, placed, pers)
				lots.remove_at(li)
				break

	# --- Fields, palisades, lamps and clutter -------------------------------
	if pers == "farm":
		_farm_fields(w, site, rng, streets, placed)
	if pers == "bandit":
		w.add_placement({"id": id + ":palisade", "kind": "piece", "piece": "palisade_ring", "pos": c, "yaw": 0.0,
			"data": {"radius": site["radius"] - 1.0, "gaps": streets}})
	if is_village and pers != "abandoned":
		var n := 0
		for a in streets:
			var dir := Vector3(cos(a), 0, sin(a))
			var perp := Vector3(-dir.z, 0, dir.x)
			var d := plaza_r + 3.0
			var side := 1.0
			while d < street_len:
				var lp: Vector3 = c + dir * d + perp * side * 2.6
				lp.y = w.height_at(lp.x, lp.z)
				if _clear(placed, lp, 0.8) and w.distance_to_roads(lp.x, lp.z) > 2.6:
					w.add_placement({"id": "%s:lamp%d" % [id, n], "kind": "piece", "piece": "lamp_post", "pos": lp, "yaw": 0.0, "data": {"lit": n % 3 == 0}})
					n += 1
				d += 12.0
				side = -side
	_clutter(w, site, rng, placed)

	# --- Wandering villagers on the plaza -----------------------------------
	var extra := 0
	match pers:
		"abandoned":
			extra = 0
		_:
			extra = rng.randi_range(3, 5) if is_village else rng.randi_range(1, 2)
	for i in extra:
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(3.5, plaza_r - 1.0)
		p.y = w.height_at(p.x, p.z)
		_add_npc(w, site, rng, "villager", p, rng.randf() * TAU)


static func _add_building(w: WorldData, site: Dictionary, rng: RandomNumberGenerator, btype: String, pos: Vector3, yaw: float, half: Vector2, placed: Array, pers: String) -> void:
	var bid := "%s:b%d" % [site["id"], placed.size()]
	w.add_placement({"id": bid, "kind": "building", "piece": btype, "pos": pos, "yaw": yaw,
		"data": {"palette": pers, "seed": rng.randi_range(0, 3), "half": half}})
	w.mark_occupied(pos, half + Vector2(0.8, 0.8), yaw)
	placed.append({"pos": pos, "r": half.length()})
	var role: String = ROLES.get(btype, "")
	if role != "" and not (pers == "abandoned" and btype == "ruined_house"):
		var face := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var np := pos + face * (half.y + 1.7) + right * rng.randf_range(-1.0, 1.0)
		np.y = w.height_at(np.x, np.z)
		var npc_yaw := yaw + rng.randf_range(-0.6, 0.6)
		_add_npc(w, site, rng, role, np, npc_yaw)


static func _add_npc(w: WorldData, site: Dictionary, rng: RandomNumberGenerator, role: String, pos: Vector3, yaw: float) -> void:
	var pers: String = site["personality"]
	var goblin := pers == "goblin" and rng.randf() < 0.8
	var shirt := Color.from_hsv(rng.randf(), rng.randf_range(0.35, 0.6), rng.randf_range(0.5, 0.85))
	var pants := Color.from_hsv(rng.randf_range(0.05, 0.12), rng.randf_range(0.3, 0.5), rng.randf_range(0.25, 0.45))
	var hat := Color.from_hsv(rng.randf(), rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 0.8))
	if pers == "bandit":
		shirt = Color(0.32, 0.25, 0.2)
		hat = Color(0.6, 0.12, 0.1)
	elif pers == "wealthy":
		shirt = Color.from_hsv(rng.randf_range(0.55, 0.85), 0.5, 0.6)
	if role == "postmaster":
		shirt = GoblinRig.VEST
		hat = GoblinRig.CAP
	var npc := {
		"id": "%s:npc%d" % [site["id"], site["npcs"].size()],
		"name": WorldText.person_name(rng, goblin), "role": role, "site": site["id"],
		"pos": pos, "yaw": yaw, "species": "goblin" if goblin else "human",
		"personality": pers, "colors": [shirt, pants, hat], "hat_style": rng.randi_range(0, 3),
	}
	site["npcs"].append(npc)
	w.add_placement({"id": npc["id"], "kind": "npc", "pos": pos, "yaw": yaw, "data": npc})


static func _lot_ok(w: WorldData, site: Dictionary, pos: Vector3, half: Vector2, placed: Array) -> bool:
	var c: Vector3 = site["pos"]
	var r := half.length()
	if Vector2(pos.x, pos.z).distance_to(Vector2(c.x, c.z)) > float(site["radius"]) - r * 0.4:
		return false
	if not _clear(placed, pos, r):
		return false
	if absf(pos.y - c.y) > 2.2:
		return false
	if pos.y < w.water_level + 0.8:
		return false
	if w.distance_to_roads(pos.x, pos.z) < r + 1.2:
		return false
	return true


static func _clear(placed: Array, pos: Vector3, r: float) -> bool:
	for p in placed:
		if Vector2(pos.x, pos.z).distance_to(Vector2(p["pos"].x, p["pos"].z)) < float(p["r"]) + r + 0.8:
			return false
	return true


static func _farm_fields(w: WorldData, site: Dictionary, rng: RandomNumberGenerator, streets: Array, placed: Array) -> void:
	var c: Vector3 = site["pos"]
	var n := 0
	for attempt in 24:
		if n >= 3:
			break
		var a := rng.randf() * TAU
		if _angle_taken(streets, a, 0.5):
			continue
		var dist := rng.randf_range(16.0, float(site["radius"]) + 4.0)
		var fp := c + Vector3(cos(a), 0, sin(a)) * dist
		fp.y = w.height_at(fp.x, fp.z)
		var half := Vector2(rng.randf_range(6.0, 9.0), rng.randf_range(4.5, 6.0))
		if not _clear(placed, fp, half.length() * 0.85) or w.distance_to_roads(fp.x, fp.z) < half.length():
			continue
		var yaw := a + PI * 0.5
		var basis := Basis(Vector3.UP, -yaw)
		for z in range(int(fp.z - 11), int(fp.z + 12)):
			for x in range(int(fp.x - 11), int(fp.x + 12)):
				var l := basis * Vector3(x - fp.x, 0, z - fp.z)
				if absf(l.x) <= half.x and absf(l.z) <= half.y and x >= 0 and z >= 0 and x < WorldData.RES and z < WorldData.RES:
					w.ground[z * WorldData.RES + x] = WorldData.Ground.FIELD
		w.add_placement({"id": "%s:field%d" % [site["id"], n], "kind": "piece", "piece": "crop_field", "pos": fp, "yaw": yaw,
			"data": {"half": half, "seed": rng.randi_range(0, 3)}})
		w.mark_occupied(fp, half + Vector2(1, 1), yaw)
		placed.append({"pos": fp, "r": half.length()})
		n += 1
	for i in rng.randi_range(3, 5):
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(6.0, 14.0)
		p.y = w.height_at(p.x, p.z)
		if _clear(placed, p, 0.8):
			w.add_placement({"id": "%s:hay%d" % [site["id"], i], "kind": "prop", "pos": p + Vector3.UP * 0.6, "yaw": a, "data": {"type": "haybale"}})


static func _clutter(w: WorldData, site: Dictionary, rng: RandomNumberGenerator, placed: Array) -> void:
	var c: Vector3 = site["pos"]
	var pers: String = site["personality"]
	var count := 8 if site["kind"] == "village" else 4
	var types := ["crate", "barrel", "crate", "barrel"]
	if pers == "goblin":
		types.append("explosive_barrel")
	for i in count:
		var a := rng.randf() * TAU
		var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, float(site["radius"]) * 0.7)
		p.y = w.height_at(p.x, p.z)
		if not _clear(placed, p, 0.6) or w.distance_to_roads(p.x, p.z) < 3.0:
			continue
		var t: String = WorldRng.pick(rng, types)
		for k in rng.randi_range(1, 3):
			var q := p + Vector3(rng.randf_range(-0.8, 0.8), 0.5 + k * 0.9, rng.randf_range(-0.8, 0.8))
			w.add_placement({"id": "%s:prop%d_%d" % [site["id"], i, k], "kind": "prop", "pos": q, "yaw": rng.randf() * TAU, "data": {"type": t}})


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

static func _exit_angle(c: Vector3, pts: PackedVector3Array, ring: float) -> float:
	# Walk from the end of the road nearest the settlement outward.
	var first: Vector3 = pts[0]
	var last: Vector3 = pts[pts.size() - 1]
	var forward := Vector2(first.x, first.z).distance_to(Vector2(c.x, c.z)) < Vector2(last.x, last.z).distance_to(Vector2(c.x, c.z))
	var n := pts.size()
	for k in n:
		var p: Vector3 = pts[k] if forward else pts[n - 1 - k]
		var d := Vector2(p.x - c.x, p.z - c.z)
		if d.length() >= ring:
			return atan2(d.y, d.x)
	var e: Vector3 = last if forward else first
	return atan2(e.z - c.z, e.x - c.x)


static func _angle_taken(angles: Array, a: float, min_sep: float) -> bool:
	for b in angles:
		if absf(wrapf(a - b, -PI, PI)) < min_sep:
			return true
	return false


static func _largest_gap_angle(angles: Array) -> float:
	var sorted := angles.duplicate()
	sorted = sorted.map(func(x): return fposmod(x, TAU))
	sorted.sort()
	var best := 0.0
	var best_mid := 0.0
	for i in sorted.size():
		var a: float = sorted[i]
		var b: float = sorted[(i + 1) % sorted.size()] + (TAU if i == sorted.size() - 1 else 0.0)
		if b - a > best:
			best = b - a
			best_mid = (a + b) * 0.5
	return best_mid


static func _gap_angles(angles: Array, exclude: float) -> Array:
	var sorted := angles.map(func(x): return fposmod(x, TAU))
	sorted.sort()
	var out := []
	for i in sorted.size():
		var a: float = sorted[i]
		var b: float = sorted[(i + 1) % sorted.size()] + (TAU if i == sorted.size() - 1 else 0.0)
		var mid := (a + b) * 0.5
		if absf(wrapf(mid - exclude, -PI, PI)) > 0.4 and b - a > 0.9:
			out.append(mid)
	return out


static func _paint_disc(w: WorldData, c: Vector3, r: float, g: int) -> void:
	for z in range(int(c.z - r), int(c.z + r) + 1):
		for x in range(int(c.x - r), int(c.x + r) + 1):
			if Vector2(x - c.x, z - c.z).length() <= r and x >= 0 and z >= 0 and x < WorldData.RES and z < WorldData.RES:
				w.ground[z * WorldData.RES + x] = g
				w.occupied[z * WorldData.RES + x] = 1


static func _paint_street(w: WorldData, c: Vector3, a: float, from: float, to: float, hw: float) -> void:
	var dir := Vector2(cos(a), sin(a))
	var d := from
	while d <= to:
		var p := Vector2(c.x, c.z) + dir * d
		for z in range(int(p.y - hw), int(p.y + hw) + 1):
			for x in range(int(p.x - hw), int(p.x + hw) + 1):
				if x < 0 or z < 0 or x >= WorldData.RES or z >= WorldData.RES:
					continue
				if Vector2(x, z).distance_to(p) <= hw:
					var k := z * WorldData.RES + x
					if w.ground[k] != WorldData.Ground.ROAD:
						w.ground[k] = WorldData.Ground.PLAZA
					w.occupied[k] = 1
		d += 1.0
