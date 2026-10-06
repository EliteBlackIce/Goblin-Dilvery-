extends Node
## Boots a world, drives the goblin around with simulated input and saves
## screenshots. Needs a real renderer (e.g. xvfb-run ... --rendering-driver opengl3):
##   godot --path . res://tests/visual_check.tscn -- --out /tmp/shots --seed 48291736

var out_dir := "user://shots"
var main: Node
var shots := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var seed_value := 48291736
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
		if args[i] == "--seed" and i + 1 < args.size():
			seed_value = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(out_dir)
	GameState.pending_seed = seed_value
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run()


func _wait(frames: int) -> void:
	for i in frames:
		await get_tree().process_frame


func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join("%02d_%s.png" % [shots, name_]))
	shots += 1
	print("shot ", name_)


func _run() -> void:
	await _wait(90)
	var g: Goblin = GameState.player
	var cam: GoblinCamera = get_tree().get_first_node_in_group("game_camera")
	await _shot("spawn_post_office")
	# Look at the goblin from the front for a portrait.
	cam.yaw = g.facing_yaw + PI
	cam.pitch = deg_to_rad(-8)
	cam.base_distance = 3.2
	await _wait(40)
	await _shot("goblin_portrait")
	cam.base_distance = 6.2
	cam.yaw = g.facing_yaw + PI * 0.6
	cam.pitch = deg_to_rad(-25)
	await _wait(30)
	await _shot("village_overview")
	# Sprint around.
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _wait(50)
	await _shot("sprinting")
	Input.action_press("move_left")
	await _wait(12)
	await _shot("sprint_turn")
	Input.action_release("move_left")
	Input.action_press("jump")
	await _wait(10)
	await _shot("jumping")
	Input.action_release("jump")
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _wait(40)
	# Explosion -> ragdoll.
	Explosion.explode(get_tree(), g.global_position + Vector3(0.8, 0.2, 0.5), 5.0, 15.0, 0)
	await _wait(8)
	await _shot("explosion_ragdoll")
	await _wait(40)
	await _shot("ragdoll_tumble")
	await _wait(240)
	print("state after ragdoll: ", Goblin.State.keys()[g.state])
	await _shot("recovered")
	# Accept some jobs so the HUD shows parcels.
	var jobs := GameState.jobs_at("village")
	for j in jobs.slice(0, 3):
		GameState.accept_job(j["id"])
	await _wait(30)
	await _shot("carrying_parcels")
	# Visit the dungeon.
	var world: World = main.get_node("World")
	world.enter_dungeon("dungeon_0")
	await _wait(60)
	cam.pitch = deg_to_rad(-35)
	await _wait(20)
	await _shot("dungeon")
	world.exit_dungeon()
	await _wait(60)
	await _shot("dungeon_entrance")
	# Board UI.
	GameState.board_requested.emit("village")
	await _wait(10)
	await _shot("delivery_board")
	get_tree().quit()
