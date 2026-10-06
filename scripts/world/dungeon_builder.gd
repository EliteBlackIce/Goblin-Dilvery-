class_name DungeonBuilder
extends RefCounted
## Turns a DungeonGenerator layout into geometry. All static walls/floors are
## merged into ONE vertex-coloured mesh + one StaticBody, then the room
## contents (enemies, traps, chests, the stranded recipient...) are spawned.

const WALL_H := 4.5
const DOOR_W := 3.6
const WALL_T := 1.0


static func build(layout: Dictionary, site: Dictionary, world: Node) -> Dictionary:
	var root := Node3D.new()
	root.name = "Dungeon_" + str(layout["site"])
	var theme: Dictionary = layout["theme"]
	var floor_c: Color = theme.get("floor", Color(0.45, 0.45, 0.45))
	var wall_c: Color = theme.get("wall", Color(0.4, 0.4, 0.42))
	var accent: Color = theme.get("accent", Color(0.3, 0.5, 0.25))
	var k := MeshKit.new(str(layout["site"]).hash(), 0.06)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	root.add_child(body)
	var rooms: Array = layout["rooms"]
	var by_cell := {}
	for r in rooms:
		by_cell[r["cell"]] = r
	var site_pos: Vector3 = site["pos"]
	var half := DungeonGenerator.ROOM_SIZE * 0.5
	var spawn := Vector3.ZERO
	var secret_walls := []
	var rng := RandomNumberGenerator.new()
	rng.seed = str(layout["site"]).hash()

	for r in rooms:
		var o := DungeonGenerator.room_origin(site_pos, r["cell"])
		_box(k, body, o + Vector3(0, -0.5, 0), Vector3(DungeonGenerator.ROOM_SIZE + WALL_T * 2, 1.0, DungeonGenerator.ROOM_SIZE + WALL_T * 2), floor_c)
		# Floor tiles for texture.
		for i in 6:
			k.box(MeshKit.at(o + Vector3(rng.randf_range(-half, half), 0.01, rng.randf_range(-half, half))), Vector3(rng.randf_range(1.0, 2.5), 0.03, rng.randf_range(1.0, 2.5)), floor_c.darkened(0.08))
		for d in DungeonGenerator.DIRS:
			var door: String = r["doors"].get(d, "")
			var dir3 := Vector3(d.x, 0, -d.y)
			var wall_center := o + dir3 * (half + WALL_T * 0.5) + Vector3(0, WALL_H * 0.5, 0)
			var along := Vector3(absf(dir3.z), 0, absf(dir3.x))  # perpendicular to the wall normal
			var full_len := DungeonGenerator.ROOM_SIZE + WALL_T * 2
			if door == "":
				_box(k, body, wall_center, along * full_len + Vector3(0, WALL_H, 0) + dir3.abs() * WALL_T, wall_c)
			else:
				var seg := (full_len - DOOR_W) * 0.5
				for s in [-1.0, 1.0]:
					_box(k, body, wall_center + along * s * (DOOR_W * 0.5 + seg * 0.5), along * seg + Vector3(0, WALL_H, 0) + dir3.abs() * WALL_T, wall_c)
				_box(k, body, wall_center + Vector3(0, WALL_H * 0.5 - 0.4, 0), along * DOOR_W + Vector3(0, 0.8, 0) + dir3.abs() * WALL_T, wall_c.darkened(0.1))
				# Corridor to the neighbour (built once, from the +x / +y side).
				if d == Vector2i(1, 0) or d == Vector2i(0, 1):
					var corr_len := DungeonGenerator.SPACING - DungeonGenerator.ROOM_SIZE - WALL_T * 2
					var cc := o + dir3 * (half + WALL_T + corr_len * 0.5)
					_box(k, body, cc + Vector3(0, -0.5, 0), dir3.abs() * (corr_len + 0.1) + along * (DOOR_W + 2.0) + Vector3(0, 1.0, 0), floor_c.darkened(0.05))
					for s in [-1.0, 1.0]:
						_box(k, body, cc + along * s * (DOOR_W * 0.5 + 0.5) + Vector3(0, WALL_H * 0.5, 0), dir3.abs() * (corr_len + 0.1) + along * 1.0 + Vector3(0, WALL_H, 0), wall_c)
					if door == "secret":
						secret_walls.append({"pos": cc + Vector3(0, WALL_H * 0.5, 0), "size": along * DOOR_W + Vector3(0, WALL_H, 0) + dir3.abs() * 0.8})
		# Moss + rubble dressing.
		for i in 4:
			var mp := o + Vector3(rng.randf_range(-half, half), WALL_H * rng.randf_range(0.2, 0.9), (half + 0.05) * (1.0 if i % 2 == 0 else -1.0))
			k.sphere(MeshKit.at(mp, 0, Vector3(1.2, 0.6, 0.4)), rng.randf_range(0.4, 0.8), accent, 6, 4)
		_contents(r, o, root, world, k, body, rng, site)
		if r["template"] == "entry":
			spawn = o + Vector3(0, 0.3, half - 5.0)

	for sw in secret_walls:
		var w := BreakableWall.new()
		w.size = sw["size"]
		w.color = wall_c.lightened(0.04)
		root.add_child(w)
		w.position = sw["pos"]

	var mi := Mats.instance(k.commit(), false)
	root.add_child(mi)
	return {"root": root, "spawn": spawn}


static func _box(k: MeshKit, body: StaticBody3D, center: Vector3, size: Vector3, color: Color) -> void:
	k.box(MeshKit.at(center), size, color)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = center
	body.add_child(cs)


static func _contents(r: Dictionary, o: Vector3, root: Node3D, world: Node, k: MeshKit, body: StaticBody3D, rng: RandomNumberGenerator, site: Dictionary) -> void:
	var n := 0
	for c in r["contents"]:
		var pid := "%s:room%d_%d:%d" % [site["id"], r["cell"].x, r["cell"].y, n]
		n += 1
		var p: Vector3 = o + (c["pos"] as Vector3)
		match c["kind"]:
			"torch":
				var t := FlickerLight.new()
				t.light_color = Color(1.0, 0.65, 0.35)
				t.omni_range = 18.0
				t.light_energy = 2.6
				root.add_child(t)
				t.position = p + Vector3(0, 0, -0.8)
				k.box(MeshKit.at(p + Vector3(0, -0.3, -0.3)), Vector3(0.15, 0.6, 0.15), Color(0.35, 0.25, 0.15))
				var fl := MeshInstance3D.new()
				var fk := MeshKit.new(1, 0.0)
				fk.cylinder(Transform3D(), 0.14, 0.0, 0.4, Color(1, 0.6, 0.2), 5)
				fl.mesh = fk.commit()
				fl.material_override = Mats.color(Color(1, 0.6, 0.2), 3.0)
				root.add_child(fl)
				fl.position = p + Vector3(0, 0.15, -0.3)
			"pillar":
				_box(k, body, p + Vector3(0, WALL_H * 0.5, 0), Vector3(1.2, WALL_H, 1.2), Color(0.5, 0.49, 0.5))
			"rubble":
				k.sphere(MeshKit.at(p + Vector3(0, 0.2, 0), rng.randf() * 3.0, Vector3(1, 0.6, 1)), rng.randf_range(0.3, 0.6), Color(0.45, 0.44, 0.44), 6, 4)
			"exit":
				var arch := Color(0.35, 0.55, 0.9)
				k.box(MeshKit.at(p + Vector3(0, 1.5, 0)), Vector3(2.2, 3.0, 0.3), Color(0.05, 0.05, 0.1))
				for sx in [-1.25, 1.25]:
					k.box(MeshKit.at(p + Vector3(sx, 1.6, 0)), Vector3(0.4, 3.2, 0.5), arch)
				var glow := OmniLight3D.new()
				glow.light_color = Color(0.6, 0.8, 1.0)
				glow.omni_range = 4.0
				glow.light_energy = 0.7
				root.add_child(glow)
				glow.position = p + Vector3(0, 1.5, -1.0)
				var ip := InteractPoint.new()
				ip.action = "exit"
				ip.prompt = "Climb back out"
				root.add_child(ip)
				ip.position = p + Vector3(0, 0, -0.8)
				ip.used.connect(func(_g): world.exit_dungeon())
			"enemy":
				if GameState.is_consumed(pid):
					continue
				var e := Enemy.new()
				e.setup(c["type"], pid)
				root.add_child(e)
				e.position = p
			"chest":
				var ch := Chest.new()
				ch.placement_id = pid
				ch.loot = c["loot"]
				root.add_child(ch)
				ch.position = p
			"spikes":
				var st := SpikeTrap.new()
				st.phase = c.get("phase", 0.0)
				root.add_child(st)
				st.position = p
			"coins":
				if GameState.is_consumed(pid):
					continue
				var pk := Pickup.new()
				pk.amount = c["amount"]
				pk.placement_id = pid
				root.add_child(pk)
				pk.position = p
			"prop":
				if GameState.is_consumed(pid):
					continue
				var pr := PhysicsProp.new()
				pr.type_id = c["type"]
				pr.placement_id = pid
				root.add_child(pr)
				pr.position = p
			"npc":
				var v := Villager.new()
				v.setup(c["npc"])
				root.add_child(v)
				v.position = p
