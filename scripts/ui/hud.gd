class_name HUD
extends CanvasLayer
## All in-game UI, built in code: status panel (seed, region, gold, health),
## carried parcels with integrity bars, interaction prompt, toasts, minimap,
## full map, delivery board and pause menu.

signal new_world_requested(seed_value: int)
signal quit_requested

var world: WorldData
var world_node: World
var player: Goblin

var _status: Label
var _hearts: HeartBar
var _gold: Label
var _trinkets: Label
var _parcels: VBoxContainer
var _prompt: Label
var _toasts: VBoxContainer
var _minimap: MapView
var _bigmap: Control
var _bigmap_view: MapView
var _board: PanelContainer
var _board_list: VBoxContainer
var _board_title: Label
var _board_site := ""
var _pause: PanelContainer
var _seed_edit: LineEdit
var _hint: Label


func setup(w: WorldData, wn: World, goblin: Goblin) -> void:
	world = w
	world_node = wn
	player = goblin
	_build()
	_minimap.set_world(w, goblin, wn)
	_bigmap_view.set_world(w, goblin, wn)
	GameState.toast_requested.connect(_on_toast)
	GameState.gold_changed.connect(func(_g): _refresh_status())
	GameState.inventory_changed.connect(_refresh_status)
	GameState.jobs_changed.connect(_refresh_parcels)
	GameState.board_requested.connect(open_board)
	goblin.health_changed.connect(func(hp, mx): _hearts.set_hp(hp, mx))
	goblin.carrier.changed.connect(_refresh_parcels)
	goblin.knocked_out.connect(_on_knocked_out)
	_hearts.set_hp(goblin.health, goblin.max_health)
	_refresh_status()
	_refresh_parcels()


func _panel_style(alpha := 0.72) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.09, alpha)
	sb.border_color = Color(0.85, 0.7, 0.35, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _label(text: String, size := 16, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# --- Status panel (top-left) ---
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", _panel_style())
	sp.position = Vector2(16, 16)
	root.add_child(sp)
	var sv := VBoxContainer.new()
	sp.add_child(sv)
	_status = _label("", 15, Color(1, 0.95, 0.8))
	sv.add_child(_status)
	var row := HBoxContainer.new()
	sv.add_child(row)
	_hearts = HeartBar.new()
	_hearts.custom_minimum_size = Vector2(170, 24)
	row.add_child(_hearts)
	_gold = _label("", 18, Color(1, 0.85, 0.3))
	row.add_child(_gold)
	_trinkets = _label("", 13, Color(0.7, 1, 0.85))
	sv.add_child(_trinkets)

	# --- Parcels (left) ---
	_parcels = VBoxContainer.new()
	_parcels.position = Vector2(16, 150)
	_parcels.add_theme_constant_override("separation", 6)
	root.add_child(_parcels)

	# --- Prompt (bottom centre) ---
	_prompt = _label("", 22, Color(1, 1, 0.85))
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-300, -110)
	_prompt.size = Vector2(600, 30)
	root.add_child(_prompt)

	# --- Toasts (top centre) ---
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.position = Vector2(-350, 20)
	_toasts.size = Vector2(700, 10)
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toasts)

	# --- Minimap (top right) ---
	_minimap = MapView.new()
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.position = Vector2(-236, 16)
	_minimap.size = Vector2(220, 220)
	_minimap.meters_per_px = 1.0
	root.add_child(_minimap)

	_hint = _label("WASD move · Shift sprint · Space jump (mash when floppy) · F/Click bonk · E interact · M map · Esc menu", 13, Color(1, 1, 1, 0.7))
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.position = Vector2(16, -30)
	root.add_child(_hint)

	# --- Big map ---
	_bigmap = PanelContainer.new()
	_bigmap.add_theme_stylebox_override("panel", _panel_style(0.9))
	_bigmap.set_anchors_preset(Control.PRESET_CENTER)
	_bigmap.custom_minimum_size = Vector2(760, 800)
	_bigmap.position = Vector2(-380, -400)
	_bigmap.visible = false
	root.add_child(_bigmap)
	var bv := VBoxContainer.new()
	_bigmap.add_child(bv)
	bv.add_child(_label("%s — %s" % [world.region_name, world.biome.display_name], 22, Color(1, 0.9, 0.6)))
	_bigmap_view = MapView.new()
	_bigmap_view.follow = false
	_bigmap_view.custom_minimum_size = Vector2(720, 700)
	bv.add_child(_bigmap_view)
	bv.add_child(_label("Yellow ring = a parcel you carry goes there.  Red roads = dangerous shortcuts.  Purple = dungeon, red dots = bandit camps.", 13, Color(1, 1, 1, 0.85)))

	# --- Delivery board ---
	_board = PanelContainer.new()
	_board.add_theme_stylebox_override("panel", _panel_style(0.94))
	_board.set_anchors_preset(Control.PRESET_CENTER)
	_board.custom_minimum_size = Vector2(900, 560)
	_board.position = Vector2(-450, -280)
	_board.visible = false
	root.add_child(_board)
	var bvb := VBoxContainer.new()
	_board.add_child(bvb)
	_board_title = _label("", 24, Color(1, 0.9, 0.6))
	bvb.add_child(_board_title)
	bvb.add_child(_label("Heavier and weirder parcels pay more — and change how you move. Plan a route: some jobs continue from where others end.", 13, Color(0.9, 0.9, 0.85)))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 430)
	bvb.add_child(scroll)
	_board_list = VBoxContainer.new()
	_board_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_board_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_board_list)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(close_board)
	bvb.add_child(close)

	# --- Pause menu ---
	_pause = PanelContainer.new()
	_pause.add_theme_stylebox_override("panel", _panel_style(0.94))
	_pause.set_anchors_preset(Control.PRESET_CENTER)
	_pause.custom_minimum_size = Vector2(560, 520)
	_pause.position = Vector2(-280, -260)
	_pause.visible = false
	root.add_child(_pause)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_pause.add_child(pv)
	pv.add_child(_label("Paused", 28, Color(1, 0.9, 0.6)))
	pv.add_child(_label("World seed: %d   (share it — same seed, same world)" % world.world_seed, 15))
	var resume := Button.new()
	resume.text = "Resume"
	resume.pressed.connect(toggle_pause)
	pv.add_child(resume)
	var srow := HBoxContainer.new()
	pv.add_child(srow)
	_seed_edit = LineEdit.new()
	_seed_edit.placeholder_text = "seed (e.g. 48291736)"
	_seed_edit.custom_minimum_size = Vector2(260, 0)
	srow.add_child(_seed_edit)
	var gen := Button.new()
	gen.text = "Generate this seed"
	gen.pressed.connect(func(): _request_world(_seed_edit.text))
	srow.add_child(gen)
	var rnd := Button.new()
	rnd.text = "New random world (F5)"
	rnd.pressed.connect(func(): _request_world(""))
	pv.add_child(rnd)
	var crow := HBoxContainer.new()
	pv.add_child(crow)
	crow.add_child(_label("Clumsiness (random trips):", 15))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 2.0
	slider.step = 0.25
	slider.value = GameState.clumsiness
	slider.custom_minimum_size = Vector2(200, 0)
	slider.value_changed.connect(func(v): GameState.clumsiness = v)
	crow.add_child(slider)
	pv.add_child(_label("Controls\n  WASD / left stick: move     Mouse / right stick: camera\n  Shift: sprint     Space: jump (in ragdoll: wiggle free)\n  F / click: satchel bonk     E: interact / deliver\n  M: map     C: recentre camera     F5: new world", 14, Color(0.9, 0.9, 0.85)))
	var quit := Button.new()
	quit.text = "Quit to title"
	quit.pressed.connect(func(): quit_requested.emit())
	pv.add_child(quit)


func _process(_delta: float) -> void:
	if player == null:
		return
	var it := player.current_interactable
	if it != null and is_instance_valid(it) and not GameState.input_locked:
		_prompt.text = "[E]  " + it.get_interact_prompt(player)
	else:
		_prompt.text = ""
	if Engine.get_process_frames() % 15 == 0:
		_refresh_parcel_distances()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _board.visible:
			close_board()
		elif _bigmap.visible:
			_bigmap.visible = false
		else:
			toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_map") and not _pause.visible and not _board.visible:
		_bigmap.visible = not _bigmap.visible
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("new_world"):
		_request_world("")


func _request_world(text: String) -> void:
	var s := int(text) if text.strip_edges().is_valid_int() else randi() % 100000000
	if text.strip_edges() != "" and not text.strip_edges().is_valid_int():
		s = absi(text.strip_edges().hash()) % 100000000  # words work as seeds too
	new_world_requested.emit(s)


func toggle_pause() -> void:
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible
	GameState.input_locked = _pause.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _pause.visible else Input.MOUSE_MODE_CAPTURED


# ---------------------------------------------------------------------------
# Status / parcels
# ---------------------------------------------------------------------------

func _refresh_status() -> void:
	_status.text = "Seed %d  ·  %s  ·  %s" % [world.world_seed, world.region_name, world.biome.display_name]
	_gold.text = "   %d gold   ·   %d delivered" % [GameState.gold, GameState.deliveries_done]
	var names: Array[String] = []
	for t in GameState.trinkets:
		names.append(LootTable.TRINKETS[t]["name"])
	_trinkets.text = ("Trinkets: " + ", ".join(names)) if not names.is_empty() else ""


func _refresh_parcels() -> void:
	for c in _parcels.get_children():
		c.queue_free()
	if player == null:
		return
	var pk: Array = player.carrier.packages
	if pk.is_empty():
		var l := _label("No parcels. Visit a delivery board!", 14, Color(1, 1, 1, 0.75))
		_parcels.add_child(l)
		return
	var mods := player.carrier.get_modifiers()
	var head := _label("Carrying %d  ·  weight %.1f%s" % [pk.size(), mods["weight"], "  (OVERLOADED!)" if mods["overloaded"] else ""], 14, Color(1, 0.8, 0.5) if mods["overloaded"] else Color(1, 1, 1, 0.9))
	_parcels.add_child(head)
	for p in pk:
		var j: Dictionary = p["job"]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _panel_style(0.6))
		var v := VBoxContainer.new()
		panel.add_child(v)
		var top := HBoxContainer.new()
		v.add_child(top)
		var sw := ColorRect.new()
		sw.color = p["def"]["color"]
		sw.custom_minimum_size = Vector2(14, 14)
		top.add_child(sw)
		top.add_child(_label(" %s → %s (%s)" % [p["def"]["name"], j["recipient_name"], j["to_name"]], 14))
		var dist := _label("", 13, Color(0.85, 0.9, 1.0))
		dist.name = "Dist"
		dist.set_meta("job", j)
		v.add_child(dist)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = p["integrity"] * 100.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(260, 6)
		v.add_child(bar)
		_parcels.add_child(panel)
	_refresh_parcel_distances()


func _refresh_parcel_distances() -> void:
	if player == null or world == null:
		return
	for panel in _parcels.get_children():
		if not panel is PanelContainer:
			continue
		var l: Label = panel.find_child("Dist", true, false)
		if l == null:
			continue
		var j: Dictionary = l.get_meta("job")
		var site := world.site(j["to"])
		if site.is_empty():
			continue
		var target: Vector3 = site["pos"]
		var npc := world.find_npc(j["recipient_id"])
		if not npc.is_empty() and not npc.get("in_dungeon", false):
			target = npc["pos"]
		var from := player.global_position
		if world_node and world_node.in_dungeon:
			from = world.site("dungeon_0")["pos"]
		var d := Vector2(target.x - from.x, target.z - from.z)
		var dir := _compass(d)
		var extra := "  (inside the dungeon!)" if npc.get("in_dungeon", false) else ""
		l.text = "   %dm %s%s  ·  %dg" % [int(d.length()), dir, extra, j["reward"]]


static func _compass(d: Vector2) -> String:
	if d.length() < 12.0:
		return "(here!)"
	var a := atan2(d.x, -d.y)  # 0 = north (-Z)
	var names := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	return names[int(round(fposmod(a, TAU) / (TAU / 8.0))) % 8]


# ---------------------------------------------------------------------------
# Board
# ---------------------------------------------------------------------------

func open_board(site_id: String) -> void:
	_board_site = site_id
	var site := world.site(site_id)
	_board_title.text = "Delivery Board — %s" % site.get("name", "?")
	_fill_board()
	_board.visible = true
	GameState.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_board() -> void:
	_board.visible = false
	GameState.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _fill_board() -> void:
	for c in _board_list.get_children():
		c.queue_free()
	var jobs := GameState.jobs_at(_board_site)
	if jobs.is_empty():
		_board_list.add_child(_label("No parcels here right now. Try another board — or deliver something to make room.", 15))
		return
	for j in jobs:
		var def := PackageTypes.get_def(j["package"])
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _panel_style(0.5))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		row.add_child(h)
		var sw := ColorRect.new()
		sw.color = def["color"]
		sw.custom_minimum_size = Vector2(18, 18)
		h.add_child(sw)
		var v := VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var danger := ""
		for i in int(round(float(j["danger"]) * 3.0)):
			danger += "!"
		v.add_child(_label("%s  —  %s" % [def["name"], j["item"]], 16, Color(1, 0.95, 0.8)))
		v.add_child(_label("To %s at %s  ·  %dm  ·  danger %s  ·  %s" % [j["recipient_name"], j["to_name"], int(j["distance"]), danger if danger != "" else "-", _effect_text(j["package"])], 13, Color(0.85, 0.9, 1)))
		if j["note"] != "":
			v.add_child(_label(j["note"], 13, Color(1, 0.75, 0.55)))
		var btn := Button.new()
		btn.text = "Accept  (%d gold)" % j["reward"]
		var jid: String = j["id"]
		btn.pressed.connect(func():
			if GameState.accept_job(jid):
				_fill_board())
		h.add_child(btn)
		_board_list.add_child(row)


static func _effect_text(pkg: String) -> String:
	match pkg:
		"heavy": return "slows you down"
		"huge": return "blocks your view"
		"fragile": return "don't fall over"
		"unstable": return "wobbles your balance"
		"magical": return "floats behind you"
		"explosive": return "do NOT fall over"
		"living": return "it moves"
	return "easy"


# ---------------------------------------------------------------------------
# Toasts
# ---------------------------------------------------------------------------

func _on_toast(text: String, color: Color) -> void:
	var l := _label(text, 19, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 4:
		_toasts.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func _on_knocked_out() -> void:
	var lost := GameState.gold / 10
	GameState.add_gold(-lost)
	_on_toast("You were knocked out! A kind farmer wheelbarrowed you home. (-%d gold)" % lost, Color(1, 0.6, 0.5))
