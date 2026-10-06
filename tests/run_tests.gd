extends SceneTree
## Headless generator tests.
##   godot --headless --path . -s res://tests/run_tests.gd
##   godot --headless --path . -s res://tests/run_tests.gd -- --map out.png --seed 123
## Exits with code 1 on any failure.

var failures := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_path := ""
	var map_seed := 48291736
	for i in args.size():
		if args[i] == "--map" and i + 1 < args.size():
			map_path = args[i + 1]
		if args[i] == "--seed" and i + 1 < args.size():
			map_seed = int(args[i + 1])

	var a := WorldGenerator.generate(48291736)
	print("\n".join(a.gen_log))
	var b := WorldGenerator.generate(48291736)
	var c := WorldGenerator.generate(777)
	check(a.signature() == b.signature(), "same seed -> identical world")
	check(a.signature() != c.signature(), "different seed -> different world")

	for w in [a, c, WorldGenerator.generate(1), WorldGenerator.generate(2024)]:
		_validate(w)

	if map_path != "":
		var w := a if map_seed == 48291736 else WorldGenerator.generate(map_seed)
		DebugMap.render(w).save_png(map_path)
		print("map written to ", map_path)

	print("\n%s (%d failure%s)" % ["PASS" if failures == 0 else "FAIL", failures, "" if failures == 1 else "s"])
	quit(1 if failures > 0 else 0)


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


func _validate(w: WorldData) -> void:
	print("\nseed %d — %s (%s)" % [w.world_seed, w.region_name, w.biome.display_name])
	var village := w.site("village")
	check(not village.is_empty(), "has a home village")
	check(village.has("post_office"), "village has a post office")
	check(w.sites_of("hamlet").size() == 2, "two hamlets")
	check(w.sites_of("dungeon").size() == 1, "one dungeon")
	check(w.sites_of("camp").size() >= 2, "enemy camps")
	check(w.roads.size() >= 4, "road network (%d roads)" % w.roads.size())
	var kinds := {}
	for r in w.roads:
		kinds[r["kind"]] = true
		check(r["points"].size() >= 2, "road %s has points" % r["id"])
	check(kinds.has("main") and kinds.has("trail"), "main roads and trails")
	check(kinds.has("shortcut"), "at least one dangerous shortcut")
	# Every hamlet and the dungeon must be reachable from the village by road.
	var reach := {"village": true}
	var grew := true
	while grew:
		grew = false
		for r in w.roads:
			if reach.has(r["from"]) != reach.has(r["to"]):
				reach[r["from"]] = true
				reach[r["to"]] = true
				grew = true
	for s in w.sites:
		if s["kind"] in ["hamlet", "dungeon", "landmark"]:
			check(reach.has(s["id"]), "%s connected by road" % s["id"])
	var buildings := 0
	var npcs := 0
	var enemies := 0
	var chests := 0
	for p in w.all_placements():
		match p["kind"]:
			"building": buildings += 1
			"npc": npcs += 1
			"enemy": enemies += 1
			"chest": chests += 1
	check(buildings >= 12, "buildings placed (%d)" % buildings)
	check(npcs >= 8, "NPCs placed (%d)" % npcs)
	check(enemies >= 6, "enemies placed (%d)" % enemies)
	check(chests >= 2, "chests placed (%d)" % chests)
	var d: Dictionary = w.dungeons.get("dungeon_0", {})
	check(not d.is_empty() and d["rooms"].size() >= 7, "dungeon layout (%d rooms)" % (d["rooms"].size() if not d.is_empty() else 0))
	var templates := {}
	for r in d.get("rooms", []):
		templates[r["template"]] = true
	check(templates.has("entry") and templates.has("recipient") and templates.has("secret"), "dungeon has entry, recipient and secret rooms")
	check(w.jobs.size() >= 8, "delivery jobs (%d)" % w.jobs.size())
	var chained := w.jobs.filter(func(j): return j["chain"] != "")
	check(chained.size() >= 3, "chained delivery routes (%d legs)" % chained.size())
	var to_dungeon := w.jobs.filter(func(j): return j["to"] == "dungeon_0")
	check(to_dungeon.size() >= 1, "a delivery into the dungeon")
	for j in w.jobs:
		if w.find_npc(j["recipient_id"]).is_empty():
			check(false, "job %s recipient exists" % j["id"])
	check(w.events.size() >= 4, "world events (%d)" % w.events.size())
	check(w.start_pos.y > w.water_level, "start position above water")
