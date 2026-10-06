extends Node3D
## Movement Playground: a small handmade test level for tuning the goblin's
## feel without generating a world. Ramps, a steep hill to tumble down, a tall
## tower to jump off, crates, explosive barrels, a boar, a bandit, spike traps.
##
##   1-8  give yourself a package of each type (see how it changes movement)
##   0    drop all packages        X  explosion at your feet
##   T    trip on purpose          R  reset position

const PKGS := ["small", "heavy", "huge", "fragile", "unstable", "magical", "explosive", "living"]

var goblin: Goblin
var camera: GoblinCamera
var _prompt: Label
var _toasts: VBoxContainer
var _info: Label
var _n := 0


func _ready() -> void:
	GameState.world = null
	GameState.jobs.clear()
	_env()
	_level()
	goblin = Goblin.new()
	add_child(goblin)
	GameState.player = goblin
	goblin.teleport(Vector3(0, 1, 6))
	goblin.respawn_point = Vector3(0, 1, 6)
	goblin.kill_y = -30.0
	camera = GoblinCamera.new()
	add_child(camera)
	camera.attach(goblin)
	_ui()
	GameState.toast_requested.connect(_toast)
	goblin.knocked_out.connect(func(): _toast("Knocked out! Back to the start.", Color(1, 0.6, 0.5)))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_toast("Movement Playground — press 1-8 for packages, X for a boom, T to trip.", Color(1, 0.95, 0.7))


func _env() -> void:
	Atmosphere.create(self, Biomes.get_biome("green_fields"))


func _solid(pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var k := MeshKit.new(_n)
	_n += 1
	k.box(Transform3D(), size, color)
	body.add_child(Mats.instance(k.commit()))
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	body.add_child(cs)
	body.position = pos
	body.rotation = rot
	add_child(body)


func _level() -> void:
	var grass := Color(0.42, 0.66, 0.3)
	_solid(Vector3(0, -0.5, 0), Vector3(90, 1, 90), grass)
	# Checker patches so speed is readable.
	for i in 12:
		_solid(Vector3(-40 + i * 7, -0.48, -20), Vector3(3.5, 1, 3.5), grass.darkened(0.08))
	# Gentle ramp, steep ramp, a hill too steep to stand on.
	_solid(Vector3(-12, 1.0, -8), Vector3(5, 0.5, 12), Color(0.75, 0.62, 0.45), Vector3(deg_to_rad(18), 0, 0))
	_solid(Vector3(-4, 2.0, -10), Vector3(4, 0.5, 12), Color(0.7, 0.55, 0.4), Vector3(deg_to_rad(35), 0, 0))
	_solid(Vector3(12, 5.0, -14), Vector3(10, 0.6, 18), Color(0.6, 0.58, 0.55), Vector3(deg_to_rad(58), 0, 0))
	# Steps and a tall tower for big landings.
	for i in 6:
		_solid(Vector3(-20, 0.35 + i * 0.7, 4 - i * 1.6), Vector3(3, 0.7 + i * 1.4, 1.6), Color(0.65, 0.62, 0.6))
	_solid(Vector3(-20, 4.5, -8), Vector3(4, 9, 4), Color(0.62, 0.6, 0.58))
	_solid(Vector3(-20, 9.2, -8), Vector3(4.6, 0.4, 4.6), Color(0.7, 0.5, 0.35))
	# Props to bonk and barrels to regret.
	for i in 8:
		var pr := PhysicsProp.new()
		pr.type_id = ["crate", "barrel", "haybale", "crate"][i % 4]
		pr.position = Vector3(6 + (i % 4) * 1.4, 0.6 + (i / 4) * 1.0, 6)
		add_child(pr)
	for i in 3:
		var eb := PhysicsProp.new()
		eb.type_id = "explosive_barrel"
		eb.position = Vector3(14 + i * 1.2, 0.6, 10)
		add_child(eb)
	for i in 3:
		var st := SpikeTrap.new()
		st.position = Vector3(-6 + i * 2.2, 0, 14)
		st.phase = i * 0.8
		add_child(st)
	var boar := Enemy.new()
	boar.setup("boar", "pg_boar")
	boar.position = Vector3(18, 0.5, 24)
	add_child(boar)
	var bandit := Enemy.new()
	bandit.setup("bandit", "pg_bandit")
	bandit.position = Vector3(-14, 0.5, 24)
	add_child(bandit)
	# A few chunky trees for scale.
	for i in 6:
		var mi := Mats.instance(Vegetation.mesh(["oak", "pine", "birch"][i % 3]))
		mi.position = Vector3(-35 + i * 13, 0, 32)
		add_child(mi)


func _ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.position = Vector2(16, 16)
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_constant_override("outline_size", 4)
	_info.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_info)
	_prompt = Label.new()
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.position = Vector2(-200, -90)
	_prompt.add_theme_font_size_override("font_size", 20)
	layer.add_child(_prompt)
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-350, 16)
	_toasts.size = Vector2(700, 10)
	layer.add_child(_toasts)


func _toast(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 4)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(700, 0)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_8:
			var t: String = PKGS[k - KEY_1]
			if goblin.carrier.can_take(t):
				_n += 1
				var job := {"id": "pg_%d" % _n, "package": t, "recipient_id": "", "recipient_name": "nobody", "to": "", "to_name": "", "item": PackageTypes.get_def(t)["items"][0], "reward": 0}
				goblin.carrier.add_package(job)
				_toast("Picked up: %s" % PackageTypes.get_def(t)["name"], Color(0.9, 0.95, 1))
			else:
				_toast("Can't carry that too.", Color(1, 0.7, 0.5))
		elif k == KEY_0:
			for p in goblin.carrier.packages.duplicate():
				goblin.carrier.remove_job(p["job"]["id"])
		elif k == KEY_X:
			Explosion.explode(get_tree(), goblin.global_position + Vector3(0.6, 0.2, 0.6), 5.0, 15.0, 0)
		elif k == KEY_T:
			goblin.trip()
		elif k == KEY_R:
			goblin.teleport(Vector3(0, 1, 6))
		elif k == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file("res://scenes/main.tscn")


func _process(_delta: float) -> void:
	var m := goblin.carrier.get_modifiers()
	_info.text = "MOVEMENT PLAYGROUND\nspeed %.1f m/s · balance %.2f · state %s\nweight %.1f · speed x%.2f · instability %.2f\n1-8 packages · 0 drop · X boom · T trip · R reset · Esc title" % [
		Vector2(goblin.velocity.x, goblin.velocity.z).length(), goblin.balance, Goblin.State.keys()[goblin.state],
		m["weight"], m["speed"], m["instability"]]
	var it := goblin.current_interactable
	_prompt.text = ("[E] " + it.get_interact_prompt(goblin)) if it and is_instance_valid(it) else ""
	if goblin.health <= 1:
		goblin.heal(6)
