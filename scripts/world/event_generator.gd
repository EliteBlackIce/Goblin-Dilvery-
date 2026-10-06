class_name EventGenerator
extends RefCounted
## Seeded world events placed along the road network. Each event type knows
## which kind of road it belongs on (ambushes on shortcuts, merchants on main
## roads...), so the same seed always tells the same little stories.

const ROAD_PREF := {
	"bandit_ambush": ["shortcut", "trail"],
	"traveling_merchant": ["main"],
	"lost_package": ["trail", "main", "shortcut"],
	"broken_cart": ["main", "trail"],
	"rival_courier": ["main"],
	"stranded_villager": ["trail", "shortcut", "main"],
}


static func generate(w: WorldData) -> void:
	var rng := WorldRng.stream(w.world_seed, "events")
	var count := rng.randi_range(4, 6)
	var used := {}
	var guard := 0
	while w.events.size() < count and guard < 60:
		guard += 1
		var type: String = WorldRng.pick_weighted(rng, w.biome.events)
		if used.get(type, 0) >= 2:
			continue
		var road := _pick_road(w, rng, ROAD_PREF[type])
		if road.is_empty():
			continue
		var pts: PackedVector3Array = road["points"]
		var i := int(pts.size() * rng.randf_range(0.25, 0.75))
		var p: Vector3 = pts[clampi(i, 1, pts.size() - 2)]
		var along: Vector3 = (pts[clampi(i + 1, 0, pts.size() - 1)] - pts[clampi(i - 1, 0, pts.size() - 1)]).normalized()
		var side := Vector3(-along.z, 0, along.x)
		var ev := {"id": "event_%d" % w.events.size(), "type": type, "pos": p, "road": road["id"]}
		w.events.append(ev)
		used[type] = used.get(type, 0) + 1
		_spawn(w, rng, ev, p, along, side, float(road["half_width"]))


static func _pick_road(w: WorldData, rng: RandomNumberGenerator, kinds: Array) -> Dictionary:
	for k in kinds:
		var candidates := w.roads.filter(func(r): return r["kind"] == k)
		if not candidates.is_empty():
			return candidates[rng.randi_range(0, candidates.size() - 1)]
	return {}


static func _ground(w: WorldData, p: Vector3) -> Vector3:
	return Vector3(p.x, w.height_at(p.x, p.z), p.z)


static func _spawn(w: WorldData, rng: RandomNumberGenerator, ev: Dictionary, p: Vector3, along: Vector3, side: Vector3, hw: float) -> void:
	var id: String = ev["id"]
	var yaw_along := atan2(-along.x, -along.z)
	match ev["type"]:
		"bandit_ambush":
			for k in rng.randi_range(2, 3):
				var q := _ground(w, p + side * (hw + rng.randf_range(5.0, 8.0)) * (1.0 if k % 2 == 0 else -1.0) + along * rng.randf_range(-4, 4))
				w.add_placement({"id": "%s:bandit%d" % [id, k], "kind": "enemy", "pos": q, "yaw": 0.0, "data": {"type": "bandit", "ambush": true}})
		"traveling_merchant":
			var mp := _ground(w, p + side * (hw + 3.0))
			w.add_placement({"id": id + ":cart", "kind": "piece", "piece": "cart", "pos": _ground(w, mp + along * 2.5), "yaw": yaw_along, "data": {}})
			var npc := _event_npc(rng, id + ":merchant", "merchant", mp, yaw_along + PI * 0.5, Color(0.55, 0.3, 0.6))
			w.add_placement({"id": npc["id"], "kind": "npc", "pos": mp, "yaw": npc["yaw"], "data": npc})
		"lost_package":
			var lp := _ground(w, p + side * (hw + 1.5)) + Vector3.UP * 0.3
			w.add_placement({"id": id + ":parcel", "kind": "lost_package", "pos": lp, "yaw": rng.randf() * TAU, "data": {"seed": rng.randi()}})
		"broken_cart":
			var cp := _ground(w, p + side * (hw + 2.0))
			w.add_placement({"id": id + ":cart", "kind": "piece", "piece": "cart_broken", "pos": cp, "yaw": yaw_along + 0.4, "data": {}})
			for k in 4:
				var t := "explosive_barrel" if k < 2 else "crate"
				var q := _ground(w, cp + Vector3(rng.randf_range(-2, 2), 0, rng.randf_range(-2, 2))) + Vector3.UP * 0.6
				w.add_placement({"id": "%s:prop%d" % [id, k], "kind": "prop", "pos": q, "yaw": rng.randf() * TAU, "data": {"type": t}})
		"stranded_villager":
			var sp := _ground(w, p + side * (hw + 2.2))
			w.add_placement({"id": id + ":cart", "kind": "piece", "piece": "cart_broken", "pos": _ground(w, sp + along * 2.5), "yaw": yaw_along + 0.6, "data": {}})
			var npc := _event_npc(rng, id + ":stranded", "stranded", sp, yaw_along, Color(0.4, 0.55, 0.75))
			w.add_placement({"id": npc["id"], "kind": "npc", "pos": sp, "yaw": npc["yaw"], "data": npc})
		"rival_courier":
			var rp := _ground(w, p + side * (hw + 1.8))
			var npc := _event_npc(rng, id + ":rival", "rival", rp, yaw_along, Color(0.75, 0.55, 0.1))
			npc["species"] = "goblin"
			w.add_placement({"id": npc["id"], "kind": "npc", "pos": rp, "yaw": npc["yaw"], "data": npc})


static func _event_npc(rng: RandomNumberGenerator, id: String, role: String, pos: Vector3, yaw: float, shirt: Color) -> Dictionary:
	return {
		"id": id, "name": WorldText.person_name(rng, role == "rival"), "role": role, "site": "",
		"pos": pos, "yaw": yaw, "species": "human", "personality": "cozy",
		"colors": [shirt, Color(0.3, 0.25, 0.2), shirt.darkened(0.3)], "hat_style": rng.randi_range(0, 3),
	}
