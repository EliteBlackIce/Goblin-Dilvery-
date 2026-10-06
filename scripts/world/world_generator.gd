class_name WorldGenerator
extends RefCounted
## The world generation pipeline. One seed in, one WorldData out.
##
##   World Seed
##     -> Biome Selection
##     -> Terrain Generation (heightmap + forest map)
##     -> Site Selection (where the village, hamlets, dungeon, camps, landmarks go)
##     -> Terrain Shaping (flatten building sites)
##     -> Road Generation (main roads, trails, dangerous shortcuts, bridges, signposts)
##     -> Settlement Placement (handcrafted building pieces on generated lots)
##     -> Dungeon Placement (entrance + room-graph layout)
##     -> Enemy Camps
##     -> NPC Locations
##     -> Delivery Locations / Jobs
##     -> Loot
##     -> Random Events
##     -> Final World
##
## Every stage pulls from its own named random stream (WorldRng), so the same
## seed always yields the same world and stages don't disturb each other.
## Vegetation is NOT generated here: chunks scatter it deterministically when
## they stream in, so it costs no memory for far-away land.

const S := WorldData.SIZE
const RES := WorldData.RES


static func generate(world_seed: int) -> WorldData:
	var w := WorldData.new()
	w.world_seed = world_seed
	var t_all := Time.get_ticks_usec()
	_stage(w, "biome", func(): _select_biome(w))
	_stage(w, "terrain", func(): _terrain(w))
	_stage(w, "sites", func(): _select_sites(w))
	_stage(w, "shaping", func(): _shape_sites(w))
	_stage(w, "roads", func(): RoadGenerator.generate(w, WorldRng.stream(world_seed, "roads")))
	_stage(w, "settlements", func(): _settlements(w))
	_stage(w, "dungeon", func(): _dungeons(w))
	_stage(w, "camps", func(): _camps(w))
	_stage(w, "landmarks", func(): _landmarks(w))
	_stage(w, "enemies", func(): _wild_enemies(w))
	_stage(w, "deliveries", func(): w.jobs = DeliveryGenerator.generate_initial(w))
	_stage(w, "loot", func(): _loot(w))
	_stage(w, "events", func(): EventGenerator.generate(w))
	_stage(w, "finalize", func(): _finalize(w))
	w.gen_log.append("TOTAL %.1f ms" % ((Time.get_ticks_usec() - t_all) / 1000.0))
	return w


static func _stage(w: WorldData, name: String, fn: Callable) -> void:
	var t := Time.get_ticks_usec()
	fn.call()
	w.gen_log.append("%-12s %7.1f ms" % [name, (Time.get_ticks_usec() - t) / 1000.0])


# ---------------------------------------------------------------------------
# Biome + terrain
# ---------------------------------------------------------------------------

static func _select_biome(w: WorldData) -> void:
	w.biome = Biomes.select(WorldRng.stream(w.world_seed, "biome"))
	w.region_name = WorldText.region_name(WorldRng.stream(w.world_seed, "names:region"))


static func _terrain(w: WorldData) -> void:
	var rng := WorldRng.stream(w.world_seed, "terrain")
	var base := FastNoiseLite.new()
	base.seed = rng.randi()
	base.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	base.frequency = 0.0045
	base.fractal_octaves = 4
	base.fractal_gain = 0.45
	var detail := FastNoiseLite.new()
	detail.seed = rng.randi()
	detail.frequency = 0.06
	detail.fractal_octaves = 1
	var rim := FastNoiseLite.new()
	rim.seed = rng.randi()
	rim.frequency = 0.025
	var amp := w.biome.hill_height
	var terr := w.biome.terrace_strength
	var step := 2.5
	for z in RES:
		for x in RES:
			var hgt := base.get_noise_2d(x, z) * amp + 6.0
			var edge := float(mini(mini(x, S - x), mini(z, S - z)))
			if edge < 64.0:
				var t := 1.0 - edge / 64.0
				hgt += t * t * 30.0 + t * (rim.get_noise_2d(x, z) * 0.5 + 0.5) * 12.0
			# Stylised terraces: flat shelves joined by short steep ramps.
			var b := floorf(hgt / step) * step
			var f := smoothstep(0.25, 0.75, (hgt - b) / step)
			hgt = lerpf(hgt, b + f * step, terr)
			hgt += detail.get_noise_2d(x, z) * 0.3
			w.heights[z * RES + x] = hgt

	var fnoise := FastNoiseLite.new()
	fnoise.seed = rng.randi()
	fnoise.frequency = 0.011
	fnoise.fractal_octaves = 3
	var thresh := 0.3 - w.biome.forest_coverage * 0.55
	for fz in WorldData.FOREST_RES:
		for fx in WorldData.FOREST_RES:
			var v := fnoise.get_noise_2d(fx * WorldData.FOREST_CELL, fz * WorldData.FOREST_CELL)
			w.forest[fz * WorldData.FOREST_RES + fx] = smoothstep(thresh, thresh + 0.15, v)

	for z in RES:
		for x in RES:
			w.ground[z * RES + x] = WorldData.Ground.FOREST if w.forest_at(x, z) > 0.55 else WorldData.Ground.GRASS


# ---------------------------------------------------------------------------
# Sites
# ---------------------------------------------------------------------------

static func _flatness(w: WorldData, x: float, z: float, r: float) -> float:
	var mn := w.height_at(x, z)
	var mx := mn
	for i in 12:
		var a := TAU * i / 12.0
		for rr in [r * 0.5, r]:
			var hh := w.height_at(x + cos(a) * rr, z + sin(a) * rr)
			mn = minf(mn, hh)
			mx = maxf(mx, hh)
	return mx - mn


static func _min_dist_ok(w: WorldData, p: Vector3, rules: Dictionary, relax: float) -> bool:
	for s in w.sites:
		var need: float = rules.get(s["kind"], rules.get("*", 0.0)) * relax
		if Vector2(p.x, p.z).distance_to(Vector2(s["pos"].x, s["pos"].z)) < need:
			return false
	return true


## Generic "best of N random candidates" site finder.
static func _find_site(w: WorldData, rng: RandomNumberGenerator, lo: float, hi: float, tries: int, rules: Dictionary, score: Callable) -> Vector3:
	var relax := 1.0
	for attempt in 6:
		var best := Vector3.INF
		var best_score := -1e9
		for i in tries:
			var x := rng.randf_range(lo, hi)
			var z := rng.randf_range(lo, hi)
			var p := Vector3(x, w.height_at(x, z), z)
			if p.y < w.water_level + 1.2:
				continue
			if not _min_dist_ok(w, p, rules, relax):
				continue
			var sc: float = score.call(p)
			if sc > best_score:
				best_score = sc
				best = p
		if best != Vector3.INF:
			return best
		relax *= 0.8
	return Vector3(rng.randf_range(lo, hi), 0, rng.randf_range(lo, hi))


static func _new_site(w: WorldData, id: String, kind: String, pos: Vector3, radius: float, name_: String, personality := "") -> Dictionary:
	var s := {
		"id": id, "kind": kind, "pos": pos, "radius": radius, "name": name_,
		"personality": personality, "npcs": [], "danger": 0.0, "has_board": false, "streets": [],
	}
	w.sites.append(s)
	return s


static func _select_sites(w: WorldData) -> void:
	var rng := WorldRng.stream(w.world_seed, "sites")
	var names := WorldRng.stream(w.world_seed, "names:places")
	var center := Vector2(S * 0.5, S * 0.5)

	# The home village (and its post office) — central-ish, flat, open.
	var vp := _find_site(w, rng, 150, S - 150, 90, {}, func(p: Vector3) -> float:
		return -_flatness(w, p.x, p.z, 40) * 1.2 - Vector2(p.x, p.z).distance_to(center) * 0.03 - w.forest_at(p.x, p.z) * 8.0)
	var village := _new_site(w, "village", "village", vp, 46.0, WorldText.place_name(names), WorldRng.pick_weighted(rng, w.biome.village_personalities))
	village["has_board"] = true

	# Two hamlets: one is always a farm, the other's personality is rolled.
	var others: Dictionary = w.biome.hamlet_personalities.duplicate()
	others.erase("farm")
	var hamlet_kinds := ["farm", WorldRng.pick_weighted(rng, others)]
	for i in 2:
		var hp := _find_site(w, rng, 80, S - 80, 140, {"village": 150.0, "hamlet": 130.0}, func(p: Vector3) -> float:
			return -_flatness(w, p.x, p.z, 26) - w.forest_at(p.x, p.z) * 5.0 - absf(Vector2(p.x, p.z).distance_to(Vector2(vp.x, vp.z)) - 190.0) * 0.02)
		var hs := _new_site(w, "hamlet_%d" % i, "hamlet", hp, 30.0, WorldText.place_name(names), hamlet_kinds[i])
		hs["has_board"] = true
		hs["danger"] = {"farm": 0.05, "cozy": 0.05, "abandoned": 0.25, "bandit": 0.45}.get(hamlet_kinds[i], 0.1)

	# Dungeon: up in the hills, far from home.
	var dp := _find_site(w, rng, 70, S - 70, 140, {"village": 165.0, "hamlet": 90.0}, func(p: Vector3) -> float:
		return p.y * 0.6 + w.forest_at(p.x, p.z) * 3.0 - _flatness(w, p.x, p.z, 8) * 0.2)
	var ds := _new_site(w, "dungeon_0", "dungeon", dp, 10.0, WorldText.dungeon_name(WorldRng.stream(w.world_seed, "names:dungeon")))
	ds["danger"] = 1.0

	# Enemy camps hide in the woods.
	var camp_count := rng.randi_range(2, 3)
	for i in camp_count:
		var cp := _find_site(w, rng, 60, S - 60, 120, {"village": 115.0, "hamlet": 85.0, "dungeon": 70.0, "camp": 95.0}, func(p: Vector3) -> float:
			return w.forest_at(p.x, p.z) * 5.0 - _flatness(w, p.x, p.z, 12) * 0.5 + rng.randf() * 1.5)
		var cs := _new_site(w, "camp_%d" % i, "camp", cp, 15.0, "Bandit Camp")
		cs["danger"] = 0.9

	# Landmarks give the region memorable, navigable shapes.
	var kinds: Array = w.biome.landmarks.duplicate()
	WorldRng.shuffle(rng, kinds)
	for i in kinds.size():
		var kind: String = kinds[i]
		var lp := _find_site(w, rng, 60, S - 60, 80, {"*": 75.0}, func(p: Vector3) -> float:
			return -_flatness(w, p.x, p.z, 8) * 0.3 + rng.randf() * 3.0 + (p.y * 0.2 if kind == "ruined_tower" else 0.0))
		var ls := _new_site(w, "landmark_%d" % i, "landmark", lp, 9.0, WorldText.landmark_name(names, kind), kind)
		ls["danger"] = 0.3


static func _shape_sites(w: WorldData) -> void:
	var params := {"village": [46.0, 26.0], "hamlet": [30.0, 18.0], "camp": [15.0, 10.0], "landmark": [9.0, 8.0], "dungeon": [9.0, 8.0]}
	for s in w.sites:
		var pr: Array = params[s["kind"]]
		var r: float = pr[0]
		var fall: float = pr[1]
		var c: Vector3 = s["pos"]
		var sum := 0.0
		var n := 0
		for i in 25:
			var a := TAU * i / 25.0
			var rr := r * 0.6 * float(i % 5) / 4.0
			sum += w.height_at(c.x + cos(a) * rr, c.z + sin(a) * rr)
			n += 1
		var target := maxf(sum / n, w.water_level + 1.4)
		var reach := r + fall
		for z in range(int(c.z - reach), int(c.z + reach) + 1):
			for x in range(int(c.x - reach), int(c.x + reach) + 1):
				if x < 0 or z < 0 or x >= RES or z >= RES:
					continue
				var d := Vector2(x - c.x, z - c.z).length()
				if d > reach:
					continue
				var wt := 1.0 if d <= r else smoothstep(reach, r, d)
				var i := z * RES + x
				w.heights[i] = lerpf(w.heights[i], target, wt)
		s["pos"] = Vector3(c.x, target, c.z)


# ---------------------------------------------------------------------------
# Settlements, dungeon, camps, landmarks
# ---------------------------------------------------------------------------

static func _settlements(w: WorldData) -> void:
	for s in w.sites:
		if s["kind"] == "village" or s["kind"] == "hamlet":
			SettlementGenerator.layout(w, s, WorldRng.stream(w.world_seed, "settlement:" + s["id"]))


static func _dungeons(w: WorldData) -> void:
	for s in w.sites_of("dungeon"):
		var rng := WorldRng.stream(w.world_seed, "dungeon:" + s["id"])
		var c: Vector3 = s["pos"]
		# Face the entrance toward the trail that leads to it.
		var yaw := rng.randf() * TAU
		for r in w.roads:
			if r["to"] == s["id"] or r["from"] == s["id"]:
				var pts: PackedVector3Array = r["points"]
				var near: Vector3 = pts[pts.size() - 1] if r["to"] == s["id"] else pts[0]
				var idx := maxi(0, pts.size() - 6) if r["to"] == s["id"] else mini(pts.size() - 1, 5)
				var toward: Vector3 = pts[idx] - near
				if toward.length() > 0.1:
					yaw = atan2(-toward.x, -toward.z)
				break
		s["yaw"] = yaw
		w.add_placement({"id": s["id"] + ":entrance", "kind": "dungeon_entrance", "pos": c, "yaw": yaw, "data": {"site": s["id"]}})
		w.mark_occupied(c, Vector2(5, 5), yaw)
		w.dungeons[s["id"]] = DungeonGenerator.generate(w, s, rng)


static func _camps(w: WorldData) -> void:
	for s in w.sites_of("camp"):
		var rng := WorldRng.stream(w.world_seed, "camp:" + s["id"])
		var c: Vector3 = s["pos"]
		var id: String = s["id"]
		w.add_placement({"id": id + ":fire", "kind": "piece", "piece": "campfire", "pos": c, "yaw": 0.0, "data": {}})
		var tents := rng.randi_range(2, 4)
		for i in tents:
			var a := TAU * i / tents + rng.randf_range(-0.3, 0.3)
			var p := c + Vector3(cos(a), 0, sin(a)) * 7.0
			p.y = w.height_at(p.x, p.z)
			var yaw := atan2(-(c.x - p.x), -(c.z - p.z))
			w.add_placement({"id": "%s:tent%d" % [id, i], "kind": "piece", "piece": "tent", "pos": p, "yaw": yaw, "data": {"variant": i}})
			w.mark_occupied(p, Vector2(2, 2), yaw)
		for i in 3:
			var a := TAU * i / 3.0 + 0.5
			var p := c + Vector3(cos(a), 0, sin(a)) * 3.2
			p.y = w.height_at(p.x, p.z)
			w.add_placement({"id": "%s:log%d" % [id, i], "kind": "piece", "piece": "log_seat", "pos": p, "yaw": a, "data": {}})
		var chest_a := rng.randf() * TAU
		var cp := c + Vector3(cos(chest_a), 0, sin(chest_a)) * 10.0
		cp.y = w.height_at(cp.x, cp.z)
		w.add_placement({"id": id + ":chest", "kind": "chest", "pos": cp, "yaw": chest_a, "data": {"loot": LootTable.roll_chest(rng, w.biome, 2)}})
		for i in rng.randi_range(3, 4):
			var a := rng.randf() * TAU
			var p := c + Vector3(cos(a), 0, sin(a)) * rng.randf_range(4.0, 9.0)
			p.y = w.height_at(p.x, p.z)
			w.add_placement({"id": "%s:bandit%d" % [id, i], "kind": "enemy", "pos": p, "yaw": a, "data": {"type": "bandit"}})
		# The camp chief is (surprisingly) a delivery recipient.
		var chief_p := c + Vector3(2.5, 0, -2.0)
		chief_p.y = w.height_at(chief_p.x, chief_p.z)
		var chief := {
			"id": id + ":chief", "name": WorldText.person_name(rng), "role": "chief", "site": id,
			"pos": chief_p, "yaw": rng.randf() * TAU, "species": "human", "personality": "bandit",
			"colors": [Color(0.3, 0.25, 0.22), Color(0.2, 0.18, 0.16), Color(0.6, 0.1, 0.1)],
		}
		s["npcs"].append(chief)
		w.add_placement({"id": chief["id"], "kind": "npc", "pos": chief_p, "yaw": chief["yaw"], "data": chief})


static func _landmarks(w: WorldData) -> void:
	var rng := WorldRng.stream(w.world_seed, "landmarks")
	var hermit_done := false
	for s in w.sites_of("landmark"):
		var c: Vector3 = s["pos"]
		w.add_placement({"id": s["id"] + ":piece", "kind": "piece", "piece": s["personality"], "pos": c, "yaw": rng.randf() * TAU, "data": {}})
		w.mark_occupied(c, Vector2(6, 6), 0.0)
		if not hermit_done and s["personality"] != "giant_tree":
			hermit_done = true
			var hp := c + Vector3(3.5, 0, 3.5)
			hp.y = w.height_at(hp.x, hp.z)
			var hermit := {
				"id": s["id"] + ":hermit", "name": WorldText.person_name(rng), "role": "hermit", "site": s["id"],
				"pos": hp, "yaw": rng.randf() * TAU, "species": "human", "personality": "hermit",
				"colors": [Color(0.45, 0.4, 0.55), Color(0.35, 0.3, 0.3), Color(0.5, 0.45, 0.6)],
			}
			s["npcs"].append(hermit)
			w.add_placement({"id": hermit["id"], "kind": "npc", "pos": hp, "yaw": hermit["yaw"], "data": hermit})
		else:
			# Secret: a cache tucked behind the landmark.
			var a := rng.randf() * TAU
			var cp := c + Vector3(cos(a), 0, sin(a)) * 6.5
			cp.y = w.height_at(cp.x, cp.z)
			w.add_placement({"id": s["id"] + ":cache", "kind": "chest", "pos": cp, "yaw": a, "data": {"loot": LootTable.roll_chest(rng, w.biome, 2)}})


## Basic procedural enemy placement: wild animals in the open, bandits by
## the dangerous shortcuts. Safe roads stay (mostly) safe.
static func _wild_enemies(w: WorldData) -> void:
	var rng := WorldRng.stream(w.world_seed, "enemies")
	var village: Dictionary = w.site("village")
	var placed := 0
	var tries := 0
	var target := rng.randi_range(5, 7)
	while placed < target and tries < 400:
		tries += 1
		var x := rng.randf_range(70, S - 70)
		var z := rng.randf_range(70, S - 70)
		var p := Vector3(x, w.height_at(x, z), z)
		if p.y < w.water_level + 0.5 or w.slope_at(x, z) > 0.5:
			continue
		if Vector2(x, z).distance_to(Vector2(village["pos"].x, village["pos"].z)) < 80.0:
			continue
		var near_site := false
		for s in w.sites:
			if s["kind"] == "hamlet" and Vector2(x, z).distance_to(Vector2(s["pos"].x, s["pos"].z)) < 50.0:
				near_site = true
		if near_site or w.distance_to_roads(x, z, "shortcut") < 10.0:
			continue
		var kind: String = WorldRng.pick_weighted(rng, w.biome.enemies)
		w.add_placement({"id": "wild:%d" % placed, "kind": "enemy", "pos": p, "yaw": rng.randf() * TAU, "data": {"type": kind}})
		placed += 1
	for r in w.roads:
		if r["kind"] != "shortcut":
			continue
		var pts: PackedVector3Array = r["points"]
		for k in 2:
			var i := int(pts.size() * (0.35 + 0.3 * k))
			var p: Vector3 = pts[clampi(i, 0, pts.size() - 1)]
			var side := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * 6.0
			var q := p + side
			q.y = w.height_at(q.x, q.z)
			w.add_placement({"id": "%s:guard%d" % [r["id"], k], "kind": "enemy", "pos": q, "yaw": rng.randf() * TAU, "data": {"type": "bandit"}})


static func _loot(w: WorldData) -> void:
	var rng := WorldRng.stream(w.world_seed, "loot")
	var n := 0
	# Coins reward taking risky routes: more on shortcuts and trails.
	for r in w.roads:
		var count: int = {"shortcut": 4, "trail": 2, "main": 1}.get(r["kind"], 1)
		var pts: PackedVector3Array = r["points"]
		for k in count:
			var p: Vector3 = pts[rng.randi_range(0, pts.size() - 1)]
			var off := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(2.5, 5.0)
			var q := p + off
			q.y = w.height_at(q.x, q.z)
			var amount := rng.randi_range(2, 5) * (2 if r["kind"] == "shortcut" else 1)
			w.add_placement({"id": "coins:%d" % n, "kind": "coins", "pos": q, "yaw": 0.0, "data": {"amount": amount}})
			n += 1


static func _finalize(w: WorldData) -> void:
	var village: Dictionary = w.site("village")
	var po: Dictionary = village.get("post_office", {})
	if po.is_empty():
		w.start_pos = village["pos"] + Vector3(0, 1, 0)
		return
	var front := Vector3(-sin(po["yaw"]), 0, -cos(po["yaw"]))
	var p: Vector3 = po["pos"] + front * (po["depth"] * 0.5 + 4.0)
	p.y = w.height_at(p.x, p.z) + 0.5
	w.start_pos = p
	w.start_yaw = po["yaw"] + PI  # facing the post office: "this is home"
