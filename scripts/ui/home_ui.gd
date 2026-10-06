class_name HomeUI
extends PanelContainer
## Post office menus, opened from physical stations in the building:
## Shop (buy gear/furniture/materials), Storage (unload backpack, equip, sell),
## Upgrades (build annexes), Room (place furniture in your room's spots).

var _tabs: TabContainer
var _lists := {}
var _header: Label


func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.09, 0.95)
	sb.border_color = Color(0.85, 0.7, 0.35)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(980, 640)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -490
	offset_right = 490
	offset_top = -320
	offset_bottom = 320
	visible = false
	var v := VBoxContainer.new()
	add_child(v)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 18)
	_header.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	v.add_child(_header)
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size = Vector2(950, 540)
	v.add_child(_tabs)
	for t in ["Shop", "Storage", "Upgrades", "Room"]:
		var sc := ScrollContainer.new()
		sc.name = t
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 4)
		sc.add_child(list)
		_tabs.add_child(sc)
		_lists[t] = list
	var close := Button.new()
	close.text = "Close (Esc)"
	close.pressed.connect(close_ui)
	v.add_child(close)
	_tabs.tab_changed.connect(func(_i): _refresh())
	GameState.inventory_changed.connect(func(): if visible: _refresh())
	GameState.gold_changed.connect(func(_g): if visible: _refresh())


func open(tab: String) -> void:
	if tab == "storage":
		var n := GameState.deposit_backpack()
		if n > 0:
			GameState.toast("Unloaded %d item%s into storage." % [n, "" if n == 1 else "s"], Color(0.8, 1, 0.8))
			GameState.save_profile()
	_tabs.current_tab = ["shop", "storage", "upgrades", "room"].find(tab)
	visible = true
	GameState.input_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close_ui() -> void:
	visible = false
	GameState.input_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	_header.text = "Gold %d   ·   Reputation level %d (%d pts)   ·   Storage %d/%d   ·   Backpack %d/%d" % [
		GameState.gold, GameState.rep_level(), GameState.rep, GameState.storage_count(), GameState.storage_capacity(),
		GameState.backpack.size(), GameState.backpack_capacity()]
	var tab: String = _tabs.get_child(_tabs.current_tab).name
	var list: VBoxContainer = _lists[tab]
	for c in list.get_children():
		c.queue_free()
	match tab:
		"Shop": _shop(list)
		"Storage": _storage(list)
		"Upgrades": _upgrades(list)
		"Room": _room(list)


func _row(list: VBoxContainer, title: String, desc: String, color := Color.WHITE) -> HBoxContainer:
	var h := HBoxContainer.new()
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", color)
	v.add_child(t)
	var d := Label.new()
	d.text = desc
	d.add_theme_font_size_override("font_size", 13)
	d.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	v.add_child(d)
	h.add_child(v)
	list.add_child(h)
	return h


func _button(h: HBoxContainer, text: String, enabled: bool, fn: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(150, 0)
	b.pressed.connect(fn)
	h.add_child(b)


func _section(list: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	list.add_child(l)


func _shop(list: VBoxContainer) -> void:
	for cat in ["equipment", "furniture", "material"]:
		_section(list, {"equipment": "Gear", "furniture": "Furniture", "material": "Building materials"}[cat])
		for id in Items.ALL:
			var it: Dictionary = Items.ALL[id]
			if it["cat"] != cat or int(it.get("price", 0)) <= 0:
				continue
			if it.get("workshop", false) and not GameState.has_upgrade("workshop"):
				continue
			var need := int(it.get("rep", 1))
			var locked := GameState.rep_level() < need
			var owned := GameState.count_owned(id) + (1 if GameState.equipped.values().has(id) else 0)
			var h := _row(list, "%s%s" % [it["name"], ("   (owned: %d)" % owned) if owned > 0 else ""], it["desc"] + (("   [needs reputation %d]" % need) if locked else ""))
			_button(h, "Buy  %dg" % it["price"], not locked and GameState.gold >= int(it["price"]), func(): GameState.buy(id))
	if not GameState.has_upgrade("workshop"):
		_section(list, "Build the Gadget Workshop to unlock gadgets.")


func _storage(list: VBoxContainer) -> void:
	_section(list, "Equipped")
	for slot in GameState.SLOTS:
		var id: String = GameState.equipped.get(slot, "")
		var h := _row(list, "%s: %s" % [slot.capitalize(), Items.name_of(id) if id != "" else "(nothing)"], Items.get_item(id)["desc"] if id != "" else "")
		if id != "":
			_button(h, "Unequip", true, func(): GameState.unequip(slot))
	_section(list, "Your stuff (storage + backpack)")
	var ids := {}
	for id in GameState.storage:
		ids[id] = true
	for id in GameState.backpack:
		ids[id] = true
	if ids.is_empty():
		list.add_child(Label.new())
		_row(list, "Nothing yet!", "Deliver parcels, open chests and explore dungeons to find loot.")
	for id in ids:
		var it := Items.get_item(id)
		var h := _row(list, "%s  x%d   [%s]" % [it["name"], GameState.count_owned(id), it["cat"]], it["desc"], Items.rarity_color(id))
		if it["cat"] == "equipment":
			_button(h, "Equip", true, func(): GameState.equip(id))
		var price: int = it.get("sell", int(it.get("price", 10) * 0.4))
		if it["cat"] in ["valuable", "equipment", "furniture", "material"]:
			_button(h, "Sell  %dg" % price, true, func(): GameState.sell(id))


func _upgrades(list: VBoxContainer) -> void:
	_section(list, "Post office upgrades — these physically change the building")
	for id in Items.UPGRADES:
		var u: Dictionary = Items.UPGRADES[id]
		var mats: Array[String] = []
		for m in u["mats"]:
			mats.append("%s %d/%d" % [Items.name_of(m), GameState.count_owned(m), u["mats"][m]])
		var cost := "%d gold, %s, reputation %d" % [u["gold"], ", ".join(mats), u["rep"]]
		var built := GameState.has_upgrade(id)
		var h := _row(list, u["name"] + ("   [BUILT]" if built else ""), u["desc"] + "\nCost: " + cost, Color(0.6, 1, 0.6) if built else Color.WHITE)
		if not built:
			_button(h, "Build", GameState.can_afford_upgrade(id), func(): GameState.buy_upgrade(id))
	_row(list, "Tip", "Materials come from delivery rewards, chests and the shop. Blueprints are rare: try special contracts and dungeons.")


func _room(list: VBoxContainer) -> void:
	_section(list, "Furniture spots in your room (%d)" % PostOffice.slot_count())
	var owned: Array = []
	for id in GameState.storage:
		if Items.get_item(id)["cat"] == "furniture":
			owned.append(id)
	for i in PostOffice.slot_count():
		var cur: String = GameState.furniture.get(str(i), "")
		var h := _row(list, "Spot %d" % (i + 1), "Currently: %s" % (Items.name_of(cur) if cur != "" else "empty"))
		var ob := OptionButton.new()
		ob.custom_minimum_size = Vector2(260, 0)
		var choices: Array = [""]
		if cur != "":
			choices.append(cur)
		for id in owned:
			if not choices.has(id):
				choices.append(id)
		for c in choices:
			ob.add_item("(empty)" if c == "" else Items.name_of(c))
		ob.selected = 1 if cur != "" else 0
		ob.item_selected.connect(func(idx: int):
			GameState.place_furniture(i, choices[idx])
			GameState.save_profile())
		h.add_child(ob)
	if owned.is_empty():
		_row(list, "No spare furniture in storage", "Buy some at the shop or find it in chests and special deliveries.")
