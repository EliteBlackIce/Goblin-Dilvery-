class_name DeliveryGenerator
extends RefCounted
## Procedural delivery jobs, built from the world's actual places and people.
##
## Jobs consider distance, danger (destination + roads), the biome's package
## mix and who the recipient is (dungeon prisoners get weird magical stuff,
## bandit chiefs get explosives...). Some jobs form CHAINS: the destination of
## one leg is the origin of the next, so a planner can do
##     Village -> Farm -> Hamlet -> Dungeon -> Village
## in one trip instead of running home after every parcel.


static func generate_initial(w: WorldData) -> Array:
	var rng := WorldRng.stream(w.world_seed, "deliveries:0")
	var jobs: Array = []
	var origins := _origins(w)
	if origins.is_empty():
		return jobs

	# Chains first (they start at the home village).
	var village: Dictionary = w.site("village")
	for chain_i in 2:
		var cur := village
		var visited := [village["id"]]
		var legs := rng.randi_range(3, 4)
		for leg in legs:
			var dest := _pick_destination_site(w, rng, cur, visited)
			if dest.is_empty():
				break
			var npc := _pick_npc(rng, dest)
			if npc.is_empty():
				break
			var j := _make_job(w, rng, cur, dest, npc, "0_c%d_%d" % [chain_i, leg])
			j["chain"] = "chain_%d" % chain_i
			j["leg"] = leg
			if leg > 0:
				j["reward"] = int(j["reward"] * 1.2)
				j["note"] = "Part of a delivery route — pick it up where the last leg ends."
			jobs.append(j)
			visited.append(dest["id"])
			# Only settlements have boards to pick up the next leg.
			if not dest["has_board"]:
				break
			cur = dest

	# Guaranteed spice: one job into the dungeon, one to a bandit chief.
	for kind in ["dungeon", "camp"]:
		var targets := w.sites_of(kind)
		if targets.is_empty():
			continue
		var dest: Dictionary = targets[rng.randi_range(0, targets.size() - 1)]
		var npc := _pick_npc(rng, dest)
		if not npc.is_empty():
			jobs.append(_make_job(w, rng, village, dest, npc, "0_%s" % kind))

	# Singles from every board.
	var n := 0
	for o in origins:
		for i in (4 if o["id"] == "village" else 2):
			var dest := _pick_destination_site(w, rng, o, [o["id"]])
			if dest.is_empty():
				continue
			var npc := _pick_npc(rng, dest)
			if npc.is_empty():
				continue
			jobs.append(_make_job(w, rng, o, dest, npc, "0_s%d" % n))
			n += 1
	return jobs


## More work appears as jobs are completed. Deterministic per seed + round.
static func generate_round(w: WorldData, round_i: int) -> Array:
	var rng := WorldRng.stream(w.world_seed, "deliveries:%d" % round_i)
	var jobs: Array = []
	var origins := _origins(w)
	for i in 5:
		var o: Dictionary = origins[rng.randi_range(0, origins.size() - 1)]
		var dest := _pick_destination_site(w, rng, o, [o["id"]])
		if dest.is_empty():
			continue
		var npc := _pick_npc(rng, dest)
		if npc.is_empty():
			continue
		jobs.append(_make_job(w, rng, o, dest, npc, "%d_%d" % [round_i, i]))
	return jobs


static func _origins(w: WorldData) -> Array:
	return w.sites.filter(func(s): return s["has_board"])


static func _pick_destination_site(w: WorldData, rng: RandomNumberGenerator, from: Dictionary, exclude: Array) -> Dictionary:
	var weights := {}
	for s in w.sites:
		if exclude.has(s["id"]) or s["npcs"].is_empty():
			continue
		# Settlements are common destinations; dangerous places less so.
		weights[s["id"]] = {"village": 4.0, "hamlet": 4.0, "landmark": 1.2, "camp": 0.8, "dungeon": 0.8}.get(s["kind"], 1.0)
	if weights.is_empty():
		return {}
	return w.site(WorldRng.pick_weighted(rng, weights))


static func _pick_npc(rng: RandomNumberGenerator, site: Dictionary) -> Dictionary:
	var npcs: Array = site["npcs"]
	if npcs.is_empty():
		return {}
	return npcs[rng.randi_range(0, npcs.size() - 1)]


static func _make_job(w: WorldData, rng: RandomNumberGenerator, from: Dictionary, to: Dictionary, npc: Dictionary, suffix: String) -> Dictionary:
	var weights: Dictionary = w.biome.packages.duplicate()
	match to["kind"]:
		"dungeon":
			weights["magical"] = weights.get("magical", 1) + 4
			weights["living"] = weights.get("living", 1) + 3
		"camp":
			weights["explosive"] = weights.get("explosive", 1) + 4
			weights["heavy"] = weights.get("heavy", 1) + 2
	if to["personality"] == "wealthy":
		weights["fragile"] = weights.get("fragile", 1) + 3
	if to["personality"] == "farm":
		weights["living"] = weights.get("living", 1) + 2
		weights["heavy"] = weights.get("heavy", 1) + 2
	var pkg: String = WorldRng.pick_weighted(rng, weights)
	var def := PackageTypes.get_def(pkg)
	var a: Vector3 = from["pos"]
	var b: Vector3 = to["pos"]
	var dist := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))
	var danger: float = maxf(float(to["danger"]), _route_danger(w, from["id"], to["id"]))
	var reward := int(round(10.0 + dist * 0.07 + danger * 25.0 + float(def["bonus"])))
	var sender_pool: Array = from["npcs"] if not from["npcs"].is_empty() else [{"name": "Someone"}]
	var sender: Dictionary = sender_pool[rng.randi_range(0, sender_pool.size() - 1)]
	var item: String = WorldRng.pick(rng, def["items"])
	var note := ""
	match to["kind"]:
		"dungeon":
			note = "The package recipient is unfortunately inside the dungeon."
		"camp":
			note = "Recipient is a bandit chief. The bandits may not know you're expected."
		"landmark":
			note = "Recipient lives out in the wilds. Bring snacks."
	return {
		"id": "job_" + suffix, "from": from["id"], "to": to["id"], "from_name": from["name"], "to_name": to["name"],
		"recipient_id": npc["id"], "recipient_name": npc["name"], "sender_name": sender["name"],
		"package": pkg, "item": item, "distance": dist, "danger": danger, "reward": reward,
		"status": "available", "note": note, "chain": "", "leg": 0,
	}


static func _route_danger(w: WorldData, a: String, b: String) -> float:
	var best := 1.0
	var found := false
	for r in w.roads:
		if (r["from"] == a and r["to"] == b) or (r["from"] == b and r["to"] == a):
			best = minf(best, r["danger"]) if found else r["danger"]
			found = true
	return best if found else 0.3
