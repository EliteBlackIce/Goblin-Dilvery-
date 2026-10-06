class_name PostOffice
extends Node3D
## The goblin's home base: a real building you walk into.
##
##   Lobby         delivery counter (postmaster), mission board, upgrade desk,
##                 quartermaster's shop
##   Personal room furniture spots + trophy shelf + decorating catalogue
##   Storage       storage chest (deposits your backpack)
## Upgrades physically change it: a storage annex, a workshop wing, a bedroom
## extension (new furniture spots) and a brass counter. The roof hides while
## you're inside so the third-person camera can see you.
##
## Local space: door faces -Z. Main hall spans x [-8, 8], z [-6, 6].

const WALL_H := 4.2
const WALL_T := 0.35
const ROOM_SLOTS := [Vector3(4.4, 0, -4.9), Vector3(7.0, 0, -4.8), Vector3(7.0, 0, -1.3), Vector3(5.2, 0, -2.6)]
const BEDROOM_SLOTS := [Vector3(9.2, 0, -5.0), Vector3(12.2, 0, -5.0), Vector3(12.2, 0, -1.2), Vector3(10.6, 0, -3.0)]
const WOOD := Color(0.55, 0.38, 0.22)
const WALL := Color(0.86, 0.78, 0.64)
const FLOOR := Color(0.5, 0.36, 0.24)

var _roof: Node3D
var _built: Node3D
var _bounds: Array[Rect2] = []


func _ready() -> void:
	add_to_group("post_office")
	GameState.upgrades_changed.connect(_rebuild)
	_rebuild()


func _rebuild() -> void:
	if _built:
		_built.queue_free()
	_built = Node3D.new()
	add_child(_built)
	_bounds = [Rect2(-8, -6, 16, 12)]
	var k := MeshKit.new(77, 0.03)
	var roofk := MeshKit.new(78, 0.03)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	_built.add_child(body)
	var up := GameState.upgrades

	# --- Floor + outer shell ---------------------------------------------------
	_box(k, body, Vector3(0, -0.5, 0), Vector3(16.4, 1.1, 12.4), FLOOR)
	for i in 8:
		k.box(MeshKit.at(Vector3(-7.5 + i * 2.0, 0.06, 0)), Vector3(0.05, 0.02, 12.0), FLOOR.darkened(0.15))
	_wall_x(k, body, -6.0, -8.0, 8.0, [[-3.3, -0.7]])                     # front, with the door
	_wall_x(k, body, 6.0, -8.0, 8.0, [[4.4, 6.6]] if up.has("storage_room") else [])
	_wall_z(k, body, -8.0, -6.0, 6.0, [[0.5, 2.7]] if up.has("workshop") else [])
	_wall_z(k, body, 8.0, -6.0, 6.0, [[-4.2, -2.0]] if up.has("bedroom") else [])
	# Interior walls: personal room (front right) and storage (back right).
	_wall_z(k, body, 3.0, -6.0, 6.0, [[-4.4, -2.4], [1.4, 3.4]])
	_wall_x(k, body, 0.0, 3.0, 8.0, [])
	_roof_over(roofk, Rect2(-8, -6, 16, 12), GoblinRig.CAP)
	# Front windows with shutters.
	for wx in [-6.3, 1.5, 5.5]:
		k.box(MeshKit.at(Vector3(wx, 2.0, -6.2)), Vector3(1.3, 1.2, 0.1), WOOD.darkened(0.2))
		k.box(MeshKit.at(Vector3(wx, 2.0, -6.26)), Vector3(1.0, 0.9, 0.05), PieceLibrary.GLASS_LIT)
		for sx in [-0.85, 0.85]:
			k.box(MeshKit.at(Vector3(wx + sx, 2.0, -6.24)), Vector3(0.4, 1.2, 0.06), GoblinRig.VEST)
	for cx in [-8.0, 8.0]:
		k.box(MeshKit.at(Vector3(cx, WALL_H * 0.5, -6.0)), Vector3(0.5, WALL_H, 0.5), WOOD.darkened(0.25))
	# Sign + flag outside so home is easy to find.
	k.box(MeshKit.at(Vector3(-2.0, 3.4, -6.3)), Vector3(3.2, 0.9, 0.12), GoblinRig.VEST)
	k.box(MeshKit.at(Vector3(-2.0, 3.4, -6.38)), Vector3(1.2, 0.6, 0.04), Color(0.98, 0.96, 0.9))
	k.cylinder(MeshKit.at(Vector3(9.0, 6.0, -6.5)), 0.1, 0.08, 12.0, Color(0.85, 0.85, 0.8), 6)
	k.box(MeshKit.at(Vector3(10.0, 11.0, -6.5)), Vector3(1.9, 1.1, 0.05), GoblinRig.VEST)
	k.box(MeshKit.at(Vector3(10.0, 11.0, -6.53)), Vector3(1.9, 0.3, 0.04), GoblinRig.CAP)
	var door_label := Label3D.new()
	door_label.text = "POST OFFICE"
	door_label.font_size = 64
	door_label.outline_size = 12
	door_label.pixel_size = 0.008
	door_label.position = Vector3(-2.0, 4.15, -6.45)
	door_label.rotation.y = PI
	_built.add_child(door_label)

	# --- Lobby: counter, board, desk, shop -------------------------------------
	var fancy := up.has("fancy_counter")
	_box(k, body, Vector3(-4.5, 0.55, 1.5), Vector3(5.0, 1.1, 0.9), WOOD)
	k.box(MeshKit.at(Vector3(-4.5, 1.12, 1.5)), Vector3(5.2, 0.08, 1.05), Color(0.85, 0.65, 0.25) if fancy else WOOD.lightened(0.15))
	if fancy:
		k.sphere(MeshKit.at(Vector3(-3.0, 1.25, 1.3), 0, Vector3(1, 0.6, 1)), 0.12, Color(1, 0.85, 0.3), 6, 4)
		k.box(MeshKit.at(Vector3(-4.5, 0.08, -2.5)), Vector3(1.6, 0.04, 7.0), Color(0.7, 0.15, 0.2))
		_label("PREMIUM CONTRACTS", Vector3(-4.5, 3.9, 5.3), 40, Color(1, 0.85, 0.3), PI)
	for i in 4:
		k.box(MeshKit.at(Vector3(-6.6 + i * 1.3, 1.2 + (i % 2) * 0.12, 4.6)), Vector3(1.0, 0.7, 0.6), Color(0.78, 0.6, 0.38))
	_box(k, body, Vector3(-4.5, 1.8, 5.6), Vector3(6.0, 3.6, 0.5), WOOD.darkened(0.2))  # pigeon-hole wall
	for x in 6:
		for y in 3:
			k.box(MeshKit.at(Vector3(-7.0 + x * 1.0, 0.8 + y * 1.0, 5.33)), Vector3(0.8, 0.8, 0.05), WOOD.darkened(0.45))
	_npc("postmaster", "Postmaster Gristlebeard", Vector3(-4.5, 0, 2.6), 0.0)
	_station(Vector3(-4.5, 0, 0.6), "Delivery counter: contracts & reputation", func(): GameState.board_requested.emit("village"), 2.0)

	var board := PieceLibrary.spawn("notice_board", {})
	board.position = Vector3(-7.6, 0, -2.5)
	board.rotation.y = -PI * 0.5
	_built.add_child(board)
	_station(Vector3(-6.6, 0, -2.5), "Mission board", func(): GameState.board_requested.emit("village"))

	_box(k, body, Vector3(0.8, 0.5, -4.4), Vector3(1.8, 0.9, 1.1), WOOD)
	k.box(MeshKit.rot(Vector3(0.8, 0.97, -4.4), Vector3(0, 0.2, 0)), Vector3(1.2, 0.02, 0.8), Color(0.35, 0.55, 0.85))
	_station(Vector3(0.8, 0, -3.3), "Upgrade desk: improve the post office", func(): GameState.home_requested.emit("upgrades"))

	_box(k, body, Vector3(0.5, 0.5, 3.6), Vector3(3.0, 1.0, 0.8), WOOD)
	_box(k, body, Vector3(0.5, 1.5, 5.6), Vector3(3.2, 3.0, 0.5), WOOD.darkened(0.1))
	for i in 6:
		k.box(MeshKit.at(Vector3(-0.6 + (i % 3) * 1.1, 1.2 + (i / 3) * 1.0, 5.25)), Vector3(0.5, 0.35, 0.3), Color.from_hsv(i * 0.17, 0.5, 0.8))
	_npc("quartermaster", "Quartermaster Fizzwick", Vector3(0.5, 0, 4.6), 0.0)
	_station(Vector3(0.5, 0, 2.7), "Shop: gear, furniture, materials", func(): GameState.home_requested.emit("shop"), 2.0)

	# --- Personal room -----------------------------------------------------------
	_box(k, body, Vector3(5.5, 1.6, -0.35), Vector3(3.6, 0.12, 0.5), WOOD)  # trophy shelf
	_box(k, body, Vector3(5.5, 2.4, -0.35), Vector3(3.6, 0.12, 0.5), WOOD)
	_label("TROPHIES", Vector3(5.5, 3.0, -0.55), 32, Color(1, 0.9, 0.6), PI)
	var trophies := []
	for id in Items.ALL:
		if Items.ALL[id]["cat"] == "collectible" and GameState.count_owned(id) > 0:
			trophies.append(id)
	for i in trophies.size():
		_trophy(trophies[i], Vector3(4.2 + (i % 3) * 1.3, 1.66 + (i / 3) * 0.8, -0.35))
	_box(k, body, Vector3(7.6, 0.45, -3.0), Vector3(0.6, 0.9, 1.0), WOOD.lightened(0.1))
	_station(Vector3(6.8, 0, -3.0), "Decorate your room", func(): GameState.home_requested.emit("room"))
	var slots: Array = ROOM_SLOTS.duplicate()
	if up.has("bedroom"):
		slots.append_array(BEDROOM_SLOTS)
	for i in slots.size():
		var id: String = GameState.furniture.get(str(i), "")
		if id != "":
			_furniture(id, slots[i], body)

	# --- Storage ------------------------------------------------------------------
	_box(k, body, Vector3(6.8, 0.4, 3.0), Vector3(1.0, 0.8, 1.6), Color(0.5, 0.33, 0.2))
	k.box(MeshKit.at(Vector3(6.8, 0.85, 3.0)), Vector3(1.1, 0.12, 1.7), Color(0.85, 0.7, 0.3))
	_station(Vector3(5.6, 0, 3.0), "Storage chest (unload your backpack)", func(): GameState.home_requested.emit("storage"))
	for z in [1.2, 5.5]:
		_box(k, body, Vector3(7.6, 1.2, z), Vector3(0.6, 2.4, 1.2), WOOD.darkened(0.15))

	# --- Upgrade annexes (visible building changes) ---------------------------------
	if up.has("storage_room"):
		_annex(k, roofk, body, Rect2(3, 6, 5, 5), [[4.4, 6.6]], "back")
		for x in [3.6, 7.4]:
			for zz in [7.2, 9.2]:
				_box(k, body, Vector3(x, 1.4, zz), Vector3(0.7, 2.8, 1.6), WOOD.darkened(0.1))
				for y in 3:
					k.box(MeshKit.at(Vector3(x, 0.6 + y * 0.9, zz)), Vector3(0.6, 0.45, 1.3), Color.from_hsv(randf(), 0.3, 0.75))
		_label("STORAGE ANNEX", Vector3(5.5, 3.4, 11.25), 36, Color(1, 0.95, 0.8))
	if up.has("workshop"):
		_annex(k, roofk, body, Rect2(-13, -2, 5, 7), [[0.5, 2.7]], "left")
		_box(k, body, Vector3(-11.5, 0.5, 3.8), Vector3(2.6, 1.0, 1.0), WOOD)
		k.box(MeshKit.at(Vector3(-11.5, 1.1, 3.8)), Vector3(0.6, 0.2, 0.3), Color(0.35, 0.35, 0.38))
		k.box(MeshKit.at(Vector3(-12.0, 1.05, 3.6)), Vector3(0.5, 0.1, 0.5), Color(0.8, 0.5, 0.2))
		_box(k, body, Vector3(-12.3, 0.6, -0.8), Vector3(1.0, 1.2, 1.0), Color(0.45, 0.45, 0.48))
		_station(Vector3(-11.5, 0, 2.7), "Workshop: gadgets", func(): GameState.home_requested.emit("shop"))
		_label("WORKSHOP", Vector3(-10.5, 3.4, -2.25), 36, Color(1, 0.95, 0.8), PI)
	if up.has("bedroom"):
		_annex(k, roofk, body, Rect2(8, -6, 5, 6), [[-4.2, -2.0]], "right")
		k.box(MeshKit.at(Vector3(13.05, 2.0, -3.0)), Vector3(0.05, 1.2, 1.4), PieceLibrary.GLASS_LIT)

	var mi := Mats.instance(k.commit())
	_built.add_child(mi)
	_roof = Mats.instance(roofk.commit())
	_built.add_child(_roof)
	for p in [Vector3(-4, 3.6, -1), Vector3(5.5, 3.6, -3), Vector3(5.5, 3.6, 3)]:
		var l := OmniLight3D.new()
		l.position = p
		l.light_color = Color(1, 0.85, 0.6)
		l.omni_range = 7.0
		l.light_energy = 0.5
		_built.add_child(l)


func _process(_delta: float) -> void:
	var g := GameState.player
	if g == null or _roof == null:
		return
	var lp := to_local(g.global_position)
	var inside := false
	for r in _bounds:
		if r.grow(0.2).has_point(Vector2(lp.x, lp.z)) and lp.y < WALL_H:
			inside = true
	_roof.visible = not inside
	if inside != GameState.indoors:
		GameState.indoors = inside
		if inside:
			GameState.toast("Home sweet post office.", Color(1, 0.95, 0.8))
			GameState.save_profile()


# ---------------------------------------------------------------------------
# Building helpers
# ---------------------------------------------------------------------------

func _box(k: MeshKit, body: StaticBody3D, c: Vector3, size: Vector3, col: Color) -> void:
	k.box(MeshKit.at(c), size, col)
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = c
	body.add_child(cs)


## Wall running along X at depth z, from x0 to x1, with door gaps [[a, b], ...].
func _wall_x(k: MeshKit, body: StaticBody3D, z: float, x0: float, x1: float, gaps: Array) -> void:
	var cuts := [x0]
	for g in gaps:
		cuts.append(g[0])
		cuts.append(g[1])
	cuts.append(x1)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		if b - a > 0.05:
			_box(k, body, Vector3((a + b) * 0.5, WALL_H * 0.5, z), Vector3(b - a + WALL_T, WALL_H, WALL_T), WALL)
	for g in gaps:
		_box(k, body, Vector3((g[0] + g[1]) * 0.5, WALL_H - 0.6, z), Vector3(g[1] - g[0], 1.2, WALL_T), WALL)
		k.box(MeshKit.at(Vector3((g[0] + g[1]) * 0.5, WALL_H - 1.25, z)), Vector3(g[1] - g[0] + 0.3, 0.15, WALL_T + 0.1), GoblinRig.VEST)
	k.box(MeshKit.at(Vector3((x0 + x1) * 0.5, 0.2, z)), Vector3(x1 - x0, 0.4, WALL_T + 0.04), WOOD.darkened(0.2))


## Wall running along Z at x, from z0 to z1, with door gaps.
func _wall_z(k: MeshKit, body: StaticBody3D, x: float, z0: float, z1: float, gaps: Array) -> void:
	var cuts := [z0]
	for g in gaps:
		cuts.append(g[0])
		cuts.append(g[1])
	cuts.append(z1)
	for i in range(0, cuts.size(), 2):
		var a: float = cuts[i]
		var b: float = cuts[i + 1]
		if b - a > 0.05:
			_box(k, body, Vector3(x, WALL_H * 0.5, (a + b) * 0.5), Vector3(WALL_T, WALL_H, b - a + WALL_T), WALL)
	for g in gaps:
		_box(k, body, Vector3(x, WALL_H - 0.6, (g[0] + g[1]) * 0.5), Vector3(WALL_T, 1.2, g[1] - g[0]), WALL)
		k.box(MeshKit.at(Vector3(x, WALL_H - 1.25, (g[0] + g[1]) * 0.5)), Vector3(WALL_T + 0.1, 0.15, g[1] - g[0] + 0.3), GoblinRig.VEST)
	k.box(MeshKit.at(Vector3(x, 0.2, (z0 + z1) * 0.5)), Vector3(WALL_T + 0.04, 0.4, z1 - z0), WOOD.darkened(0.2))


func _roof_over(rk: MeshKit, r: Rect2, col: Color) -> void:
	var c := r.get_center()
	rk.box(MeshKit.at(Vector3(c.x, WALL_H + 0.1, c.y)), Vector3(r.size.x + 0.6, 0.25, r.size.y + 0.6), col.darkened(0.25))
	rk.prism(MeshKit.at(Vector3(c.x, WALL_H + 0.2, c.y)), Vector3(r.size.x + 0.8, minf(r.size.x, r.size.y) * 0.35, r.size.y + 0.8), col)


## An added wing: floor, three outer walls, roof. `gaps` is the doorway on the shared wall.
func _annex(k: MeshKit, rk: MeshKit, body: StaticBody3D, r: Rect2, _gaps: Array, side: String) -> void:
	_bounds.append(r)
	var c := r.get_center()
	_box(k, body, Vector3(c.x, -0.5, c.y), Vector3(r.size.x, 1.1, r.size.y), FLOOR.darkened(0.08))
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	if side != "back":
		_wall_x(k, body, z0, x0, x1, [])
	if side != "front":
		_wall_x(k, body, z1, x0, x1, [])
	if side != "right":
		_wall_z(k, body, x1, z0, z1, [])
	if side != "left":
		_wall_z(k, body, x0, z0, z1, [])
	_roof_over(rk, r, GoblinRig.CAP.darkened(0.1))


func _station(pos: Vector3, prompt: String, fn: Callable, radius := 1.8) -> void:
	var ip := InteractPoint.new()
	ip.prompt = prompt
	ip.interact_radius = radius
	ip.position = pos
	ip.used.connect(func(_g): fn.call())
	_built.add_child(ip)


func _npc(role: String, name_: String, pos: Vector3, yaw: float) -> void:
	var v := Villager.new()
	v.setup({"id": "po:" + role, "name": name_, "role": role, "site": "village", "species": "goblin",
		"personality": "goblin", "colors": [GoblinRig.VEST, Color(0.3, 0.25, 0.2), GoblinRig.CAP], "hat_style": 1})
	v.position = pos
	v.rotation.y = yaw
	_built.add_child(v)


func _label(text: String, pos: Vector3, size: int, col: Color, yaw := 0.0) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.outline_size = 10
	l.pixel_size = 0.006
	l.modulate = col
	l.position = pos
	l.rotation.y = yaw
	_built.add_child(l)


func _trophy(id: String, pos: Vector3) -> void:
	var k := MeshKit.new(id.hash())
	var c := Items.rarity_color(id)
	match id:
		"col_sock":
			k.box(MeshKit.at(Vector3(0, 0.2, 0)), Vector3(0.15, 0.35, 0.12), Color(0.9, 0.3, 0.3))
			k.box(MeshKit.at(Vector3(0.08, 0.04, 0)), Vector3(0.3, 0.12, 0.12), Color(0.9, 0.3, 0.3))
		"col_mushroom":
			k.cylinder(MeshKit.at(Vector3(0, 0.2, 0)), 0.15, 0.15, 0.4, Color(0.7, 0.9, 1.0, 1.0), 8)
			k.sphere(MeshKit.at(Vector3(0, 0.22, 0)), 0.09, Color(0.5, 1.0, 0.5), 6, 4)
		"col_tooth":
			k.cylinder(MeshKit.at(Vector3(0, 0.25, 0)), 0.12, 0.0, 0.5, Color(1, 0.97, 0.88), 6)
		_:
			k.cylinder(MeshKit.rot(Vector3(0, 0.2, 0), Vector3(PI * 0.5, 0, 0)), 0.18, 0.18, 0.05, c, 10)
	var spin := Spinner.new()
	spin.speed = 0.8
	spin.position = pos
	spin.add_child(Mats.instance(k.commit()))
	_built.add_child(spin)


func _furniture(id: String, pos: Vector3, body: StaticBody3D) -> void:
	var it := Items.get_item(id)
	var c: Color = it.get("color", WOOD)
	var k := MeshKit.new(id.hash())
	var solid := Vector3.ZERO
	match id:
		"furn_bed", "furn_bed_fancy":
			k.box(MeshKit.at(Vector3(0, 0.25, 0)), Vector3(1.3, 0.5, 2.1), WOOD)
			k.box(MeshKit.at(Vector3(0, 0.55, 0.15)), Vector3(1.2, 0.2, 1.7), c)
			k.box(MeshKit.at(Vector3(0, 0.62, -0.75)), Vector3(0.8, 0.18, 0.4), Color(0.95, 0.95, 0.9))
			if id == "furn_bed_fancy":
				for sx in [-0.6, 0.6]:
					for sz in [-1.0, 1.0]:
						k.box(MeshKit.at(Vector3(sx, 1.1, sz)), Vector3(0.1, 2.2, 0.1), WOOD.darkened(0.2))
				k.box(MeshKit.at(Vector3(0, 2.2, 0)), Vector3(1.4, 0.08, 2.2), c)
			solid = Vector3(1.3, 0.7, 2.1)
			var ip := InteractPoint.new()
			ip.prompt = "Rest (heal + save)"
			ip.interact_radius = 1.9
			ip.position = pos
			ip.used.connect(func(g: Goblin):
				g.heal(99)
				GameState.save_profile()
				GameState.toast("Zzz... You feel refreshed. (Game saved)", Color(0.8, 0.9, 1)))
			_built.add_child(ip)
		"furn_table":
			k.box(MeshKit.rot(Vector3(0, 0.8, 0), Vector3(0, 0, 0.04)), Vector3(1.4, 0.1, 0.9), c)
			for sx in [-0.6, 0.6]:
				for sz in [-0.35, 0.35]:
					k.box(MeshKit.at(Vector3(sx, 0.38, sz)), Vector3(0.1, 0.76 - (0.08 if sx > 0 and sz > 0 else 0.0), 0.1), c.darkened(0.2))
			solid = Vector3(1.4, 0.85, 0.9)
		"furn_chair":
			k.cylinder(MeshKit.at(Vector3(0, 0.45, 0)), 0.3, 0.3, 0.1, c, 8)
			for i in 3:
				var a := TAU * i / 3.0
				k.cylinder_between(Vector3(cos(a) * 0.2, 0.42, sin(a) * 0.2), Vector3(cos(a) * 0.28, 0, sin(a) * 0.28), 0.04, c.darkened(0.2), 4)
		"furn_lamp":
			k.cylinder(MeshKit.at(Vector3(0, 0.6, 0)), 0.06, 0.06, 1.2, Color(0.25, 0.25, 0.27), 6)
			k.box(MeshKit.at(Vector3(0, 1.3, 0)), Vector3(0.3, 0.35, 0.3), PieceLibrary.GLASS_LIT)
			var l := OmniLight3D.new()
			l.position = pos + Vector3.UP * 1.3
			l.light_color = Color(1, 0.8, 0.5)
			l.omni_range = 5.0
			_built.add_child(l)
		"furn_rug":
			k.cylinder(MeshKit.at(Vector3(0, 0.02, 0)), 1.2, 1.2, 0.03, c, 12)
			k.cylinder(MeshKit.at(Vector3(0, 0.03, 0)), 0.7, 0.7, 0.03, Color(0.95, 0.85, 0.4), 12)
		"furn_shelf":
			k.box(MeshKit.at(Vector3(0, 1.0, 0)), Vector3(1.4, 2.0, 0.45), c)
			for y in 3:
				for b in 5:
					k.box(MeshKit.at(Vector3(-0.5 + b * 0.25, 0.45 + y * 0.6, -0.15)), Vector3(0.15, 0.4, 0.3), Color.from_hsv(b * 0.2 + y * 0.1, 0.6, 0.7))
			solid = Vector3(1.4, 2.0, 0.5)
		"furn_plant":
			k.cylinder(MeshKit.at(Vector3(0, 0.2, 0)), 0.25, 0.2, 0.4, Color(0.75, 0.4, 0.25), 8)
			k.sphere(MeshKit.at(Vector3(0, 0.75, 0), 0, Vector3(1, 1.2, 1)), 0.45, c, 7, 4)
		"furn_painting":
			k.box(MeshKit.at(Vector3(0, 1.5, 0)), Vector3(1.1, 0.9, 0.08), Color(0.6, 0.45, 0.2))
			k.box(MeshKit.at(Vector3(0, 1.5, -0.05)), Vector3(0.9, 0.7, 0.02), c)
			k.sphere(MeshKit.at(Vector3(0, 1.45, -0.07), 0, Vector3(1, 1.3, 0.3)), 0.18, Color.WHITE, 6, 4)
			k.box(MeshKit.at(Vector3(0, 0.75, 0)), Vector3(0.1, 1.5, 0.1), WOOD)
		"furn_throne":
			k.box(MeshKit.at(Vector3(0, 0.4, 0)), Vector3(1.0, 0.8, 0.9), c)
			k.box(MeshKit.at(Vector3(0, 1.3, 0.38)), Vector3(1.0, 1.8, 0.15), c)
			for i in 5:
				k.cylinder(MeshKit.at(Vector3(-0.4 + i * 0.2, 2.3, 0.38)), 0.05, 0.0, 0.3, Color(0.85, 0.85, 0.9), 4)
			solid = Vector3(1.0, 0.8, 0.9)
		"furn_cauldron":
			k.sphere(MeshKit.at(Vector3(0, 0.5, 0), 0, Vector3(1, 0.8, 1)), 0.6, c, 10, 6)
			k.cylinder(MeshKit.at(Vector3(0, 0.9, 0)), 0.5, 0.5, 0.05, Color(0.4, 0.9, 0.3), 10)
			solid = Vector3(1.1, 1.0, 1.1)
		_:
			k.box(MeshKit.at(Vector3(0, 0.4, 0)), Vector3(0.8, 0.8, 0.8), c)
	var mi := Mats.instance(k.commit())
	mi.position = pos
	_built.add_child(mi)
	if solid != Vector3.ZERO:
		var cs := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = solid
		cs.shape = b
		cs.position = pos + Vector3(0, solid.y * 0.5, 0)
		body.add_child(cs)


static func slot_count() -> int:
	return ROOM_SLOTS.size() + (BEDROOM_SLOTS.size() if GameState.has_upgrade("bedroom") else 0)
