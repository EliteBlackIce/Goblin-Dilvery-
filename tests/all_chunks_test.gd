extends Node
## Builds EVERY chunk (terrain, vegetation, every placement) and every dungeon
## for several seeds, to catch errors in rarely-generated pieces:
##   godot --headless --path . res://tests/all_chunks_test.tscn

const SEEDS := [1, 99, 777, 2024, 31337, 48291736]


func _ready() -> void:
	var counts := {}
	for s in SEEDS:
		var w := WorldGenerator.generate(s)
		GameState.reset_for_world(s, w)
		var goblin := Goblin.new()
		add_child(goblin)
		GameState.player = goblin
		var world := World.new()
		add_child(world)
		world.setup(w, goblin, Environment.new(), DirectionalLight3D.new())
		var t := Time.get_ticks_msec()
		for cz in WorldData.CHUNKS:
			for cx in WorldData.CHUNKS:
				world.chunks._build(Vector2i(cx, cz))
		var personalities := []
		for site in w.sites:
			if site["kind"] in ["village", "hamlet"]:
				personalities.append(site["personality"])
		for p in w.all_placements():
			var key: String = p["kind"] + ":" + str(p.get("piece", p.get("data", {}).get("type", "")))
			counts[key] = counts.get(key, 0) + 1
		for site_id in w.dungeons.keys():
			var built := DungeonBuilder.build(w.dungeons[site_id], w.site(site_id), world)
			world.add_child(built["root"])
			built["root"].queue_free()
		print("seed %d: %s, %d chunks in %d ms, settlements %s" % [s, w.region_name, world.chunks.loaded_count(), Time.get_ticks_msec() - t, personalities])
		world.queue_free()
		goblin.queue_free()
		await get_tree().process_frame
	# Every piece type, including ones a given seed may not generate.
	var ids := ["house_small", "house_medium", "house_tall", "goblin_hut", "ruined_house", "farmhouse", "post_office",
		"tavern", "blacksmith", "shop", "temple", "town_hall", "stable", "barn", "windmill", "guard_tower", "tent",
		"market_stall", "well", "statue", "dead_tree", "campfire", "log_seat", "lamp_post", "crop_field",
		"palisade_ring", "cart", "cart_broken", "bridge_segment", "signpost", "dungeon_entrance", "standing_stones",
		"ruined_tower", "giant_tree", "notice_board"]
	for pal in ["cozy", "wealthy", "goblin", "farm", "abandoned", "bandit"]:
		for id in ids:
			var n := PieceLibrary.spawn(id, {"palette": pal, "half": Vector2(3, 3), "radius": 20.0, "gaps": [0.5, 2.0], "text": "x", "lit": true, "width": 4.0})
			add_child(n)
			n.queue_free()
	print("spawned %d piece types x 6 palettes" % ids.size())
	var keys := counts.keys()
	keys.sort()
	print("placement kinds built: ", keys.size())
	for k in keys:
		print("  %-28s %d" % [k, counts[k]])
	get_tree().quit()
