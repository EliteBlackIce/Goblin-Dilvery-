extends Node3D
## Entry point. Shows the title screen, then builds a world from a seed:
##   WorldGenerator (pure data)  ->  World (streams chunks)  +  Goblin  +  Camera  +  HUD
##
## Starting a new world reloads this scene with GameState.pending_seed set.
## Command line: `-- --seed 123` skips the title screen.

var env: Environment
var sun: DirectionalLight3D
var world: World
var goblin: Goblin
var camera: GoblinCamera
var hud: HUD
var _menu: CanvasLayer


func _ready() -> void:
	_setup_environment()
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seed" and i + 1 < args.size() and GameState.pending_seed < 0:
			GameState.pending_seed = int(args[i + 1])
	if GameState.pending_seed >= 0:
		var s := GameState.pending_seed
		GameState.pending_seed = -1
		_start(s)
	else:
		_show_title()


func _setup_environment() -> void:
	var a := Atmosphere.create(self, Biomes.get_biome("green_fields"))
	env = a["env"]
	sun = a["sun"]


func _show_title() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 6)
	add_child(cam)
	_menu = CanvasLayer.new()
	add_child(_menu)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.09, 0.92)
	sb.border_color = Color(0.85, 0.7, 0.35)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(620, 420)
	panel.position = Vector2(-310, -210)
	_menu.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	var title := Label.new()
	title.text = "GOBLIN DELIVERY CO."
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.35))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Every world is different. Where the heck is your post office this time?"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sub)
	var edit := LineEdit.new()
	edit.placeholder_text = "World seed (blank = random, words work too)"
	v.add_child(edit)
	if GameState.has_save() and GameState.last_seed() >= 0:
		var cont := Button.new()
		cont.text = "Continue  (world %d · %d gold · reputation %d)" % [GameState.last_seed(), GameState.gold, GameState.rep_level()]
		cont.custom_minimum_size = Vector2(0, 48)
		cont.pressed.connect(func(): _start(GameState.last_seed()))
		v.add_child(cont)
	var start := Button.new()
	start.text = "Start Delivering (new world, keeps your progress)" if GameState.has_save() else "Start Delivering"
	start.custom_minimum_size = Vector2(0, 48)
	start.pressed.connect(func(): _start_from_text(edit.text))
	v.add_child(start)
	var example := Button.new()
	example.text = "Try the example seed 48291736"
	example.pressed.connect(func(): _start(48291736))
	v.add_child(example)
	var play := Button.new()
	play.text = "Movement Playground (test the floppy goblin)"
	play.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/movement_playground.tscn"))
	v.add_child(play)
	edit.text_submitted.connect(func(t): _start_from_text(t))
	if GameState.has_save():
		var wipe := Button.new()
		wipe.text = "Reset ALL progress"
		wipe.pressed.connect(func():
			if wipe.text.begins_with("Really"):
				GameState.delete_save()
				get_tree().reload_current_scene()
			else:
				wipe.text = "Really? Click again to erase your save")
		v.add_child(wipe)


func _start_from_text(text: String) -> void:
	var t := text.strip_edges()
	var s := randi() % 100000000
	if t.is_valid_int():
		s = int(t)
	elif t != "":
		s = absi(t.hash()) % 100000000
	_start(s)


func _start(seed_value: int) -> void:
	if _menu:
		_menu.queue_free()
		for c in get_children():
			if c is Camera3D:
				c.queue_free()
	var loading := CanvasLayer.new()
	var l := Label.new()
	l.text = "Generating world %d...\n(sorting the mail)" % seed_value
	l.add_theme_font_size_override("font_size", 28)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.position = Vector2(-300, -40)
	l.size = Vector2(600, 80)
	loading.add_child(l)
	add_child(loading)
	await get_tree().process_frame
	await get_tree().process_frame

	var data := WorldGenerator.generate(seed_value)
	for line in data.gen_log:
		print("[worldgen] ", line)
	GameState.reset_for_world(seed_value, data)

	goblin = Goblin.new()
	goblin.name = "Goblin"
	world = World.new()
	world.name = "World"
	add_child(world)
	add_child(goblin)
	GameState.player = goblin
	world.setup(data, goblin, env, sun)
	goblin.teleport(data.start_pos)
	goblin.facing_yaw = data.start_yaw
	world.chunks.build_now(data.start_pos, 2)

	camera = GoblinCamera.new()
	add_child(camera)
	camera.attach(goblin)
	camera.yaw = data.start_yaw

	hud = HUD.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	hud.setup(data, world, goblin)
	hud.new_world_requested.connect(_new_world)
	hud.quit_requested.connect(func():
		get_tree().paused = false
		GameState.input_locked = false
		get_tree().reload_current_scene())
	loading.queue_free()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	GameState.save_profile()
	GameState.toast("Welcome to %s, courier! Walk into your post office: contracts at the counter, shop and upgrades inside." % data.site("village")["name"], Color(1, 0.95, 0.7))


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and GameState.world != null:
		GameState.save_profile()


func _new_world(seed_value: int) -> void:
	GameState.save_profile()
	get_tree().paused = false
	GameState.input_locked = false
	GameState.pending_seed = seed_value
	get_tree().reload_current_scene()
