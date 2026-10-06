extends Node
## Builds every code-generated model in the game and saves each one as a .glb
## (open in Blender etc.) into res://assets/source/<id>.glb, plus the biome as
## an editable .tres. Needs a real renderer:
##   godot --path . res://tools/export_assets.tscn
##   (headless servers: xvfb-run godot --rendering-driver opengl3 --path . res://tools/export_assets.tscn)
##
## To replace a model: copy assets/source/<id>.glb -> assets/models/<id>.glb,
## edit it, and the game uses yours automatically (see Assets).

const OUT := "res://assets/source/"


func _ready() -> void:
	await get_tree().process_frame
	_build_everything()
	await get_tree().process_frame
	var n := 0
	var ids := Assets.seen.keys()
	ids.sort()
	for id in ids:
		if id.begins_with("dungeon/layout_"):
			continue  # per-seed dungeon geometry, not reusable art
		if _export(id, Assets.seen[id]):
			n += 1
	var biome := Biomes.get_biome("green_fields")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "biomes"))
	ResourceSaver.save(biome.duplicate(true), OUT + "biomes/green_fields.tres")
	print("Exported %d models to %s" % [n, OUT])
	get_tree().quit()


func _build_everything() -> void:
	GameState.delete_save()
	# Pieces (cozy palette for shared building styles).
	var piece_ids := ["house_small", "house_medium", "house_tall", "goblin_hut", "ruined_house", "farmhouse", "tavern",
		"blacksmith", "shop", "temple", "town_hall", "stable", "barn", "windmill", "guard_tower", "tent", "market_stall",
		"well", "statue", "dead_tree", "campfire", "log_seat", "lamp_post", "crop_field", "palisade_ring", "cart",
		"cart_broken", "bridge_segment", "signpost", "dungeon_entrance", "standing_stones", "ruined_tower",
		"giant_tree", "notice_board"]
	for id in piece_ids:
		var pal := "goblin" if id == "goblin_hut" else ("abandoned" if id == "ruined_house" else ("farm" if id in ["farmhouse", "barn", "windmill"] else "cozy"))
		PieceLibrary.get_entry(id, {"palette": pal, "half": SettlementGenerator.FOOTPRINTS.get(id, Vector2(3, 3)), "radius": 20.0, "gaps": [0.5, 2.5], "width": 4.0})
	PieceLibrary.windmill_blades()
	for kind in Vegetation.KINDS:
		Vegetation.mesh(kind)
	for t in PackageTypes.ids():
		PackageTypes.build_mesh(t)
	for t in PhysicsProp.TYPES:
		PhysicsProp._mesh_for(t)
	# Characters, props and the post office build their meshes in _ready.
	var rig := GoblinRig.new()
	add_child(rig)
	for style in ["pot", "wizard", "crown", "cap"]:
		rig.set_hat(style)
	for t in Enemy.TYPES:
		var e := Enemy.new()
		e.setup(t, "export")
		add_child(e)
	for sp in ["human", "goblin"]:
		var v := Villager.new()
		v.setup({"id": "export_" + sp, "name": "x", "role": "villager", "species": sp, "colors": [Color(0.6, 0.4, 0.7), Color(0.4, 0.3, 0.2), Color(0.8, 0.3, 0.2)], "hat_style": 1})
		add_child(v)
	for node in [Chest.new(), SpikeTrap.new(), Pickup.new(), BreakableWall.new()]:
		add_child(node)
	FX.puff(Vector3.ZERO, Color.WHITE, 1.0, 0.0, 0.1)
	var ex := Explosion.new()
	add_child(ex)
	# Post office with every upgrade, every furniture item and every trophy.
	for u in Items.UPGRADES:
		GameState.upgrades[u] = true
	var slot := 0
	for id in Items.ALL:
		var cat: String = Items.ALL[id]["cat"]
		if cat == "furniture" and slot < 8:
			GameState.furniture[str(slot)] = id
			slot += 1
		elif cat == "collectible":
			GameState.storage[id] = 1
	add_child(PostOffice.new())
	# Furniture beyond the 8 room slots.
	for id in Items.ALL:
		if Items.ALL[id]["cat"] == "furniture" and not Assets.seen.has("furniture/" + id):
			var po := PostOffice.new()
			po._built = Node3D.new()
			po.add_child(po._built)
			po._furniture(id, Vector3.ZERO, StaticBody3D.new())
	GameState.delete_save()


func _export(id: String, mesh: Mesh) -> bool:
	if mesh == null or mesh.get_surface_count() == 0:
		return false
	var root := Node3D.new()
	root.name = id.get_file()
	var mi := MeshInstance3D.new()
	mi.name = id.get_file()
	mi.mesh = mesh
	if not Assets.is_custom(mesh):
		mi.material_override = Mats.vertex()
	root.add_child(mi)
	add_child(root)
	var path := ProjectSettings.globalize_path(OUT + id + ".glb")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_scene(root, state)
	if err == OK:
		err = doc.write_to_filesystem(state, path)
	root.queue_free()
	if err != OK:
		push_warning("Failed to export %s (%d)" % [id, err])
	return err == OK
