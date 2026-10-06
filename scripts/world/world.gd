class_name World
extends Node3D
## Runtime side of the world: owns the WorldData, streams chunks around the
## player, turns placements into nodes, and handles going in/out of dungeons.

signal entered_dungeon(name: String)
signal exited_dungeon

var data: WorldData
var player: Goblin
var chunks: ChunkManager
var environment: Environment
var sun: DirectionalLight3D
var in_dungeon := false
var _dungeon_root: Node3D
var _dungeon_site := ""
var _overworld_root: Node3D
var _saved_env := {}


func setup(w: WorldData, goblin: Goblin, env: Environment, sun_light: DirectionalLight3D) -> void:
	data = w
	player = goblin
	environment = env
	sun = sun_light
	_overworld_root = Node3D.new()
	_overworld_root.name = "Overworld"
	add_child(_overworld_root)
	chunks = ChunkManager.new()
	chunks.name = "Chunks"
	_overworld_root.add_child(chunks)
	chunks.setup(w, spawn_placement)
	_build_static_scenery()
	player.kill_y = -40.0
	player.respawn_point = w.start_pos
	player.teleported.connect(func(pos: Vector3):
		if not in_dungeon:
			chunks.build_now(pos, 1))


func _process(_delta: float) -> void:
	if player and not in_dungeon:
		chunks.update_focus(player.global_position)


func ground_height(pos: Vector3) -> float:
	if in_dungeon:
		return pos.y
	return data.height_at(pos.x, pos.z)


# ---------------------------------------------------------------------------
# Static, always-loaded scenery: water, the mountain ring around the region,
# invisible walls at the edge.
# ---------------------------------------------------------------------------

func _build_static_scenery() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(WorldData.SIZE + 400, WorldData.SIZE + 400)
	water.mesh = plane
	var wm := StandardMaterial3D.new()
	wm.albedo_color = data.biome.water
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.15
	wm.metallic_specular = 0.6
	water.material_override = wm
	water.position = Vector3(WorldData.SIZE * 0.5, data.water_level, WorldData.SIZE * 0.5)
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overworld_root.add_child(water)

	var k := MeshKit.new(data.world_seed, 0.05)
	var rng := WorldRng.stream(data.world_seed, "horizon")
	var c := Vector3(WorldData.SIZE * 0.5, 0, WorldData.SIZE * 0.5)
	for i in 48:
		var a := TAU * i / 48.0 + rng.randf_range(-0.05, 0.05)
		var r := rng.randf_range(WorldData.SIZE * 0.62, WorldData.SIZE * 0.78)
		var p := c + Vector3(cos(a), 0, sin(a)) * r
		var h := rng.randf_range(45.0, 95.0)
		var base := rng.randf_range(70.0, 110.0)
		k.cylinder(MeshKit.at(p + Vector3(0, h * 0.5 - 5.0, 0), rng.randf() * TAU), base, base * 0.15, h, Color(0.42, 0.6, 0.38).lerp(Color(0.55, 0.6, 0.62), rng.randf()), 7)
		if h > 75.0:
			k.cylinder(MeshKit.at(p + Vector3(0, h - 9.0, 0)), base * 0.3, 0.0, 18.0, Color(0.97, 0.98, 1.0), 7)
	var ring := Mats.instance(k.commit(), false)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overworld_root.add_child(ring)

	var walls := StaticBody3D.new()
	walls.collision_layer = 1
	for side in 4:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(WorldData.SIZE + 20, 200, 4) if side < 2 else Vector3(4, 200, WorldData.SIZE + 20)
		cs.shape = b
		match side:
			0: cs.position = Vector3(WorldData.SIZE * 0.5, 50, -2)
			1: cs.position = Vector3(WorldData.SIZE * 0.5, 50, WorldData.SIZE + 2)
			2: cs.position = Vector3(-2, 50, WorldData.SIZE * 0.5)
			3: cs.position = Vector3(WorldData.SIZE + 2, 50, WorldData.SIZE * 0.5)
		walls.add_child(cs)
	_overworld_root.add_child(walls)


# ---------------------------------------------------------------------------
# Placement -> Node
# ---------------------------------------------------------------------------

func spawn_placement(p: Dictionary, parent: Node3D) -> void:
	var id: String = p["id"]
	var kind: String = p["kind"]
	var pos: Vector3 = p["pos"]
	var yaw: float = p.get("yaw", 0.0)
	var d: Dictionary = p.get("data", {})
	var node: Node3D = null
	match kind:
		"piece", "building":
			node = PostOffice.new() if p.get("piece", "") == "post_office" else PieceLibrary.spawn(p["piece"], d)
		"signpost":
			node = PieceLibrary.spawn("signpost", d)
		"npc":
			var v := Villager.new()
			v.setup(d)
			v.world = self
			node = v
		"enemy":
			if GameState.is_consumed(id):
				return
			var e := Enemy.new()
			e.setup(d.get("type", "bandit"), id, d.get("ambush", false))
			node = e
		"chest":
			var ch := Chest.new()
			ch.placement_id = id
			ch.loot = d.get("loot", {})
			node = ch
		"coins":
			if GameState.is_consumed(id):
				return
			var pk := Pickup.new()
			pk.amount = d.get("amount", 3)
			pk.placement_id = id
			node = pk
			pos += Vector3.UP * 0.3
		"prop":
			if GameState.is_consumed(id):
				return
			var pr := PhysicsProp.new()
			pr.type_id = d.get("type", "crate")
			pr.placement_id = id
			node = pr
		"board":
			node = PieceLibrary.spawn("notice_board", d)
			var ip := InteractPoint.new()
			ip.action = "board"
			ip.data = d
			ip.position = Vector3(0, 0, -0.8)
			ip.used.connect(func(_g): GameState.board_requested.emit(d.get("site", "")))
			node.add_child(ip)
		"dungeon_entrance":
			node = PieceLibrary.spawn("dungeon_entrance", d)
			var site: Dictionary = data.site(d.get("site", ""))
			var ip := InteractPoint.new()
			ip.action = "enter"
			ip.prompt = "Enter %s" % site.get("name", "the dungeon")
			ip.interact_radius = 3.2
			ip.position = Vector3(0, 0, -1.6)
			ip.used.connect(func(_g): enter_dungeon(d.get("site", "")))
			node.add_child(ip)
		"lost_package":
			if GameState.is_consumed(id):
				return
			node = _lost_package(id, d)
	if node == null:
		return
	node.position = pos
	node.rotation.y = yaw
	parent.add_child(node)


## Stranded villager event: their cart broke, so they hire you on the spot.
func stranded_help(v: Villager) -> void:
	var nid: String = v.npc["id"]
	if GameState.is_consumed(nid):
		v.say("Thanks again! I'll walk. Slowly. Forever.")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = nid.hash()
	var targets: Array = []
	for s in data.sites:
		if s["kind"] == "village" or s["kind"] == "hamlet":
			targets.append_array(s["npcs"])
	if targets.is_empty():
		return
	var npc: Dictionary = targets[rng.randi_range(0, targets.size() - 1)]
	var site := data.site(npc["site"])
	var pkg: String = ["heavy", "fragile", "living", "huge"][rng.randi_range(0, 3)]
	var dist := Vector2(v.global_position.x - npc["pos"].x, v.global_position.z - npc["pos"].z).length()
	var job := {
		"id": "help_" + nid, "from": "", "to": npc["site"], "from_name": "the roadside", "to_name": site.get("name", "?"),
		"recipient_id": npc["id"], "recipient_name": npc["name"], "sender_name": v.npc["name"],
		"package": pkg, "item": WorldRng.pick(rng, PackageTypes.get_def(pkg)["items"]), "distance": dist, "danger": 0.3,
		"reward": int(30 + dist * 0.08), "status": "available", "note": "Rescued from a broken cart.", "chain": "", "leg": 0,
		"tier": "dangerous", "min_rep": 1, "reward_item": Items.roll(rng, "good"), "time_limit": round(dist / 4.5 + 40.0),
		"objectives": [{"type": "time", "label": "Deliver before they worry", "bonus": 25}],
	}
	if not GameState.player.carrier.can_take(pkg):
		v.say("You look a bit full. Come back with free hands?")
		return
	GameState.add_runtime_job(job)
	if GameState.accept_job(job["id"]):
		GameState.consume(nid)
		v.say("Oh bless you! Please take this to %s in %s. Hurry!" % [npc["name"], site.get("name", "town")])


func _lost_package(id: String, d: Dictionary) -> Node3D:
	var root := Node3D.new()
	var mi := Mats.instance(PackageTypes.build_mesh("small"))
	mi.rotation = Vector3(0.3, 0.5, 0.2)
	root.add_child(mi)
	var ip := InteractPoint.new()
	ip.prompt = "Pick up the lost parcel"
	ip.interact_radius = 2.0
	root.add_child(ip)
	ip.used.connect(func(g: Goblin):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(d.get("seed", 1))
		var candidates: Array = []
		for s in data.sites:
			if s["kind"] == "village" or s["kind"] == "hamlet":
				candidates.append_array(s["npcs"])
		if candidates.is_empty():
			return
		var npc: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		var site := data.site(npc["site"])
		var job := {
			"id": "lost_" + id, "from": "", "to": npc["site"], "from_name": "the roadside", "to_name": site.get("name", "?"),
			"recipient_id": npc["id"], "recipient_name": npc["name"], "sender_name": "Unknown",
			"package": "small", "item": "a lost parcel addressed to %s" % npc["name"], "distance": 0.0,
			"danger": 0.2, "reward": 25, "status": "available", "note": "Found on the road. Finders deliverers!", "chain": "", "leg": 0,
		}
		GameState.add_runtime_job(job)
		if GameState.accept_job(job["id"]):
			GameState.consume(id)
			root.queue_free())
	return root


# ---------------------------------------------------------------------------
# Dungeons
# ---------------------------------------------------------------------------

func enter_dungeon(site_id: String) -> void:
	if in_dungeon:
		return
	var layout: Dictionary = data.dungeons.get(site_id, {})
	if layout.is_empty():
		return
	var site := data.site(site_id)
	in_dungeon = true
	_dungeon_site = site_id
	var built := DungeonBuilder.build(layout, site, self)
	_dungeon_root = built["root"]
	add_child(_dungeon_root)
	_overworld_root.visible = false
	chunks.paused = true
	_saved_env = {
		"ambient": environment.ambient_light_color, "energy": environment.ambient_light_energy,
		"fog": environment.fog_light_color, "fog_density": environment.fog_density, "sun": sun.light_energy,
		"bg": environment.background_mode, "bg_color": environment.background_color,
	}
	var theme: Dictionary = layout["theme"]
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.03, 0.05)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = theme.get("ambient", Color(0.2, 0.2, 0.25))
	environment.ambient_light_energy = 1.6
	environment.fog_light_color = Color(0.06, 0.05, 0.06)
	environment.fog_density = 0.012
	sun.light_energy = 0.0
	player.kill_y = DungeonGenerator.DUNGEON_Y - 30.0
	player.teleport(built["spawn"])
	player.respawn_point = built["spawn"]
	GameState.toast("You squeeze into %s..." % layout["name"], Color(0.8, 0.8, 1))
	entered_dungeon.emit(layout["name"])


func exit_dungeon() -> void:
	if not in_dungeon:
		return
	in_dungeon = false
	_dungeon_root.queue_free()
	_dungeon_root = null
	_overworld_root.visible = true
	chunks.paused = false
	environment.background_mode = _saved_env["bg"]
	environment.background_color = _saved_env["bg_color"]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_color = _saved_env["ambient"]
	environment.ambient_light_energy = _saved_env["energy"]
	environment.fog_light_color = _saved_env["fog"]
	environment.fog_density = _saved_env["fog_density"]
	sun.light_energy = _saved_env["sun"]
	var site := data.site(_dungeon_site)
	var yaw: float = site.get("yaw", 0.0)
	var front := Vector3(-sin(yaw), 0, -cos(yaw))
	var p: Vector3 = site["pos"] + front * 4.0
	p.y = data.height_at(p.x, p.z) + 0.5
	player.kill_y = -40.0
	player.respawn_point = data.start_pos
	player.teleport(p)
	player.facing_yaw = yaw
	GameState.toast("Fresh air! Mostly.", Color(0.8, 1, 0.8))
	exited_dungeon.emit()
