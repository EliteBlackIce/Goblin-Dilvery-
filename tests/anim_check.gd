extends Node
## Films the goblin in the Movement Playground and builds contact sheets so the
## procedural animation can be reviewed frame by frame (needs a renderer):
##   xvfb-run godot --rendering-driver opengl3 --path . res://tests/anim_check.tscn -- --out /tmp/anim

var out_dir := "user://anim"
var pg: Node
var frames: Array[Image] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(out_dir)
	pg = load("res://scenes/movement_playground.tscn").instantiate()
	add_child(pg)
	_run()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _grab() -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.resize(480, 270)
	frames.append(img)


func _sheet(name_: String) -> void:
	var cols := 4
	var rows := int(ceil(frames.size() / float(cols)))
	var sheet := Image.create(480 * cols, 270 * rows, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, 480, 270), Vector2i((i % cols) * 480, (i / cols) * 270))
	sheet.save_png(out_dir.path_join(name_ + ".png"))
	print("sheet ", name_)
	frames.clear()


func _side_cam(g: Goblin, cam: GoblinCamera, dist := 4.0) -> void:
	cam.yaw = g.facing_yaw + PI * 0.5
	cam.pitch = deg_to_rad(-10)
	cam.base_distance = dist


func _run() -> void:
	await _wait(30)
	var g: Goblin = GameState.player
	var cam: GoblinCamera = get_tree().get_first_node_in_group("game_camera")
	cam.auto_follow = false
	# Idle wobble.
	_side_cam(g, cam, 3.0)
	await _wait(30)
	for i in 4:
		await _grab()
		await _wait(8)
	# Start running, sprint.
	# Camera looks along -Z; "right" runs the goblin across the screen.
	cam.yaw = 0.0
	cam.pitch = deg_to_rad(-8)
	cam.base_distance = 4.5
	Input.action_press("move_right")
	for i in 4:
		await _wait(5)
		await _grab()
	Input.action_press("sprint")
	for i in 4:
		await _wait(8)
		await _grab()
	_sheet("1_idle_run_sprint")
	# Sharp reversal -> skid.
	Input.action_release("move_right")
	Input.action_press("move_left")
	for i in 8:
		await _wait(4)
		await _grab()
	Input.action_release("move_left")
	Input.action_release("sprint")
	await _wait(30)
	# Jump + land.
	Input.action_press("jump")
	for i in 8:
		await _wait(5)
		await _grab()
	Input.action_release("jump")
	_sheet("2_skid_jump")
	# Big fall from the tower.
	g.teleport(Vector3(-20, 9.6, -8))
	await _wait(10)
	cam.yaw = PI * 0.5
	g.camera_yaw = PI * 0.5
	Input.action_press("move_left")
	await _wait(25)
	Input.action_release("move_left")
	for i in 8:
		await _wait(5)
		await _grab()
	_sheet("3_tower_fall")
	# Stumble + carrying a huge package and an unstable one.
	g.teleport(Vector3(0, 1, 6))
	await _wait(20)
	g.carrier.add_package({"id": "a", "package": "huge", "recipient_id": "", "recipient_name": "", "to": "", "to_name": "", "item": "", "reward": 0})
	g.carrier.add_package({"id": "b", "package": "unstable", "recipient_id": "", "recipient_name": "", "to": "", "to_name": "", "item": "", "reward": 0})
	g.carrier.add_package({"id": "c", "package": "magical", "recipient_id": "", "recipient_name": "", "to": "", "to_name": "", "item": "", "reward": 0})
	await _wait(20)
	g.camera_yaw = 0.0
	cam.yaw = PI * 0.3
	cam.base_distance = 5.0
	Input.action_press("move_forward")
	await _wait(20)
	for i in 4:
		await _wait(6)
		await _grab()
	g.start_stumble(1.0)
	for i in 4:
		await _wait(5)
		await _grab()
	Input.action_release("move_forward")
	await _wait(20)
	g.take_hit(Vector3(1, 0, 0), 7.0, 0)
	for i in 4:
		await _wait(4)
		await _grab()
	_sheet("4_carry_stumble_hit")
	get_tree().quit()
