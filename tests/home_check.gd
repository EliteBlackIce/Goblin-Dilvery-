extends Node
## Screenshots of the post office home base (needs a renderer):
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/home_check.tscn -- --out /tmp/home

var out_dir := "user://home"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.delete_save()
	GameState.pending_seed = 48291736
	add_child(load("res://scenes/main.tscn").instantiate())
	_run()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name_ + ".png"))
	print("shot ", name_)


func _run() -> void:
	await _wait(90)
	var g: Goblin = GameState.player
	var cam: GoblinCamera = get_tree().get_first_node_in_group("game_camera")
	var po: PostOffice = get_tree().get_first_node_in_group("post_office")
	cam.auto_follow = false
	GameState.add_gold(5000)
	GameState.rep = 60
	for m in ["mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_planks", "mat_nails", "mat_nails", "mat_nails", "mat_nails", "mat_nails", "mat_nails", "mat_blueprint"]:
		GameState.put_in_storage(m)
	for u in Items.UPGRADES:
		GameState.buy_upgrade(u)
	for f in ["furn_table", "furn_lamp", "furn_rug", "furn_shelf", "furn_throne", "furn_plant", "col_tooth", "col_stamp", "col_sock"]:
		GameState.put_in_storage(f)
	var i := 1
	for f in ["furn_lamp", "furn_rug", "furn_shelf", "furn_throne", "furn_plant", "furn_table"]:
		GameState.place_furniture(i, f)
		i += 1
	await _wait(10)
	g.teleport(po.to_global(Vector3(-2.0, 0.3, -12.0)))
	cam.yaw = po.global_rotation.y + PI
	cam.pitch = deg_to_rad(-25)
	cam.base_distance = 16.0
	await _wait(40)
	await _shot("1_outside")
	g.teleport(po.to_global(Vector3(-2.0, 0.3, -3.5)))
	cam.base_distance = 6.2
	cam.yaw = po.global_rotation.y
	cam.pitch = deg_to_rad(-30)
	await _wait(40)
	await _shot("2_lobby")
	g.teleport(po.to_global(Vector3(5.5, 0.3, -2.0)))
	cam.yaw = po.global_rotation.y + PI * 0.5
	await _wait(40)
	await _shot("3_personal_room")
	GameState.home_requested.emit("shop")
	await _wait(10)
	await _shot("4_shop_ui")
	get_tree().quit()
