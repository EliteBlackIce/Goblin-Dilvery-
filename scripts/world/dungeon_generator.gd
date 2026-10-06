class_name DungeonGenerator
extends RefCounted
## Dungeon layouts as a graph of modular rooms on a grid.
##
## Rooms grow outward from the entry, biased toward extending the deepest
## branch so there's a real journey. The deepest room is where the package
## recipient is (unfortunately) stuck; the room before it gets a boss; dead
## ends become treasure rooms; one secret room hides behind a cracked wall.
## Output is pure data — DungeonBuilder turns it into geometry on entry.

const ROOM_SIZE := 14.0
const SPACING := 21.0
const DUNGEON_Y := -300.0
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


static func generate(w: WorldData, site: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var rooms := {}
	var start := Vector2i(0, 0)
	rooms[start] = _room(start, 0)
	var target := rng.randi_range(7, 10)
	var guard := 0
	while rooms.size() < target and guard < 500:
		guard += 1
		var keys := _sorted_keys(rooms)
		var src: Dictionary
		if rng.randf() < 0.6:
			src = rooms[keys[0]]
			for k in keys:
				if rooms[k]["depth"] > src["depth"]:
					src = rooms[k]
		else:
			src = rooms[keys[rng.randi_range(0, keys.size() - 1)]]
		var d: Vector2i = DIRS[rng.randi_range(0, 3)]
		var n: Vector2i = src["cell"] + d
		if rooms.has(n) or n.y < 0 or n.y > 5 or absi(n.x) > 3:
			continue
		rooms[n] = _room(n, src["depth"] + 1)
		src["doors"][d] = "open"
		rooms[n]["doors"][-d] = "open"

	# One loop so it isn't a pure tree.
	for k in _sorted_keys(rooms):
		var r: Dictionary = rooms[k]
		var done := false
		for d in DIRS:
			var n: Vector2i = k + d
			if rooms.has(n) and not r["doors"].has(d) and absi(rooms[n]["depth"] - r["depth"]) >= 2:
				if rng.randf() < 0.6:
					r["doors"][d] = "open"
					rooms[n]["doors"][-d] = "open"
					done = true
					break
		if done:
			break

	# Templates.
	var keys := _sorted_keys(rooms)
	var deepest: Dictionary = rooms[start]
	for k in keys:
		if rooms[k]["depth"] > deepest["depth"]:
			deepest = rooms[k]
	rooms[start]["template"] = "entry"
	deepest["template"] = "recipient"
	if deepest["depth"] >= 2:
		for d in deepest["doors"].keys():
			var p: Dictionary = rooms[deepest["cell"] + d]
			if p["depth"] == deepest["depth"] - 1 and p["template"] == "":
				p["template"] = "boss"
				break
	var treasure := 0
	var traps := 0
	for k in keys:
		var r: Dictionary = rooms[k]
		if r["template"] != "":
			continue
		if r["doors"].size() == 1 and treasure < 2:
			r["template"] = "treasure"
			treasure += 1
		else:
			var t: String = WorldRng.pick(rng, ["hall", "pillars", "trap", "junk"])
			if t == "trap":
				traps += 1
				if traps > 2:
					t = "pillars"
			r["template"] = t

	# Secret room behind a cracked wall.
	for k in keys:
		var r: Dictionary = rooms[k]
		if r["template"] == "entry" or r["template"] == "recipient":
			continue
		var placed := false
		for d in DIRS:
			var n: Vector2i = k + d
			if not rooms.has(n) and n.y >= 0 and absi(n.x) <= 4:
				rooms[n] = _room(n, r["depth"] + 1)
				rooms[n]["template"] = "secret"
				r["doors"][d] = "secret"
				rooms[n]["doors"][-d] = "secret"
				placed = true
				break
		if placed:
			break

	# Recipient NPC lives inside.
	var npc := {
		"id": site["id"] + ":recipient", "name": WorldText.person_name(rng, rng.randf() < 0.5), "role": "dungeon",
		"site": site["id"], "pos": site["pos"], "yaw": 0.0, "species": "human", "personality": "dungeon",
		"colors": [Color(0.55, 0.5, 0.35), Color(0.3, 0.28, 0.25), Color(0.4, 0.35, 0.3)], "in_dungeon": true,
	}
	if rng.randf() < 0.5:
		npc["species"] = "goblin"
	site["npcs"].append(npc)

	for k in _sorted_keys(rooms):
		_fill(rooms[k], rng, w.biome, npc)

	var room_list := []
	for k in _sorted_keys(rooms):
		room_list.append(rooms[k])
	return {"site": site["id"], "name": site["name"], "rooms": room_list, "recipient": npc, "theme": w.biome.dungeon_theme}


static func _room(cell: Vector2i, depth: int) -> Dictionary:
	return {"cell": cell, "depth": depth, "doors": {}, "template": "", "contents": []}


static func _sorted_keys(rooms: Dictionary) -> Array:
	var keys := rooms.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i): return a.y < b.y or (a.y == b.y and a.x < b.x))
	return keys


static func room_origin(site_pos: Vector3, cell: Vector2i) -> Vector3:
	return Vector3(site_pos.x + cell.x * SPACING, DUNGEON_Y, site_pos.z - cell.y * SPACING)


static func _fill(r: Dictionary, rng: RandomNumberGenerator, biome: BiomeDef, npc: Dictionary) -> void:
	var c: Array = r["contents"]
	var half := ROOM_SIZE * 0.5 - 1.5
	var rnd := func() -> Vector3: return Vector3(rng.randf_range(-half, half), 0, rng.randf_range(-half, half))
	c.append({"kind": "torch", "pos": Vector3(0, 2.6, half + 1.0)})
	match r["template"]:
		"entry":
			c.append({"kind": "exit", "pos": Vector3(0, 0, half)})
			c.append({"kind": "prop", "type": "barrel", "pos": Vector3(-half, 0.5, half - 1.0)})
		"hall":
			for i in rng.randi_range(2, 3):
				c.append({"kind": "enemy", "type": WorldRng.pick_weighted(rng, biome.dungeon_enemies), "pos": rnd.call()})
			for i in 3:
				c.append({"kind": "rubble", "pos": rnd.call()})
		"pillars":
			for x in [-3.5, 3.5]:
				for z in [-3.5, 3.5]:
					c.append({"kind": "pillar", "pos": Vector3(x, 0, z)})
			for i in rng.randi_range(1, 2):
				c.append({"kind": "enemy", "type": WorldRng.pick_weighted(rng, biome.dungeon_enemies), "pos": rnd.call()})
		"trap":
			for x in [-3.0, 0.0, 3.0]:
				for z in [-1.5, 1.5]:
					c.append({"kind": "spikes", "pos": Vector3(x, 0, z), "phase": rng.randf() * 3.0})
			c.append({"kind": "coins", "amount": rng.randi_range(5, 10), "pos": Vector3(0, 0.3, -half + 0.5)})
		"junk":
			for i in rng.randi_range(4, 7):
				c.append({"kind": "prop", "type": WorldRng.pick(rng, ["crate", "barrel", "crate", "explosive_barrel"]), "pos": rnd.call() + Vector3.UP * 0.6})
			for i in rng.randi_range(1, 2):
				c.append({"kind": "enemy", "type": "rat", "pos": rnd.call()})
		"treasure":
			c.append({"kind": "chest", "pos": Vector3(0, 0, -half + 1.0), "loot": LootTable.roll_chest(rng, biome, 2)})
			c.append({"kind": "enemy", "type": WorldRng.pick_weighted(rng, biome.dungeon_enemies), "pos": Vector3(0, 0, 1.0)})
		"boss":
			c.append({"kind": "enemy", "type": "brute", "pos": Vector3(0, 0, 0)})
			for i in 2:
				c.append({"kind": "enemy", "type": "rat", "pos": rnd.call()})
		"recipient":
			c.append({"kind": "npc", "npc": npc, "pos": Vector3(0, 0, -1.0)})
			c.append({"kind": "prop", "type": "crate", "pos": Vector3(2.5, 0.5, -3.0)})
			c.append({"kind": "prop", "type": "crate", "pos": Vector3(-3.0, 0.5, -2.0)})
		"secret":
			var loot := LootTable.roll_chest(rng, biome, 3)
			if loot["trinket"] == "":
				loot["trinket"] = WorldRng.pick(rng, LootTable.trinket_ids())
			c.append({"kind": "chest", "pos": Vector3.ZERO, "loot": loot})
