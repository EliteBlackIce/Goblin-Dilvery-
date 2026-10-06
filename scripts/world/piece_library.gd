class_name PieceLibrary
extends RefCounted
## The handcrafted "LEGO pieces" the generator assembles: buildings, props,
## landmarks, vegetation. Each piece is modelled once (with MeshKit), cached,
## and shared by every instance, so a village of 20 houses is ~20 draw calls.
##
## OVERRIDES: drop a scene at res://pieces/<piece_id>.tscn and it is used
## instead of the code-built version — artists can replace pieces one by one
## without touching the generator.

const PALETTES := {
	"cozy": {"wall": [Color(0.96, 0.9, 0.76), Color(0.93, 0.84, 0.68), Color(0.9, 0.88, 0.8)], "timber": Color(0.42, 0.27, 0.16),
		"roof": [Color(0.78, 0.32, 0.2), Color(0.88, 0.52, 0.2), Color(0.3, 0.52, 0.58), Color(0.62, 0.28, 0.24)],
		"stone": Color(0.6, 0.57, 0.54), "trim": Color(0.36, 0.55, 0.32), "crooked": 0.0},
	"wealthy": {"wall": [Color(0.95, 0.94, 0.9), Color(0.89, 0.87, 0.83)], "timber": Color(0.55, 0.5, 0.45),
		"roof": [Color(0.24, 0.34, 0.6), Color(0.3, 0.32, 0.44), Color(0.2, 0.46, 0.48)],
		"stone": Color(0.72, 0.7, 0.66), "trim": Color(0.95, 0.78, 0.3), "crooked": 0.0},
	"goblin": {"wall": [Color(0.56, 0.42, 0.26), Color(0.46, 0.52, 0.3), Color(0.62, 0.5, 0.34)], "timber": Color(0.3, 0.21, 0.13),
		"roof": [Color(0.42, 0.56, 0.24), Color(0.64, 0.38, 0.2), Color(0.52, 0.46, 0.3)],
		"stone": Color(0.46, 0.46, 0.4), "trim": Color(0.82, 0.3, 0.2), "crooked": 0.13},
	"farm": {"wall": [Color(0.95, 0.88, 0.72), Color(0.9, 0.82, 0.66)], "timber": Color(0.45, 0.3, 0.18),
		"roof": [Color(0.72, 0.25, 0.18), Color(0.8, 0.6, 0.3)], "stone": Color(0.6, 0.56, 0.5), "trim": Color(0.75, 0.2, 0.15), "crooked": 0.02},
	"abandoned": {"wall": [Color(0.7, 0.68, 0.62), Color(0.62, 0.6, 0.56)], "timber": Color(0.34, 0.3, 0.26),
		"roof": [Color(0.42, 0.37, 0.33)], "stone": Color(0.5, 0.5, 0.48), "trim": Color(0.42, 0.48, 0.36), "crooked": 0.07},
	"bandit": {"wall": [Color(0.46, 0.36, 0.27), Color(0.4, 0.32, 0.24)], "timber": Color(0.25, 0.18, 0.12),
		"roof": [Color(0.5, 0.15, 0.12), Color(0.22, 0.2, 0.18)], "stone": Color(0.42, 0.41, 0.39), "trim": Color(0.62, 0.12, 0.1), "crooked": 0.04},
}

const GLASS_LIT := Color(1.0, 0.86, 0.5)
const GLASS := Color(0.45, 0.62, 0.78)
const DARK := Color(0.12, 0.1, 0.09)

static var _cache := {}


# ===========================================================================
# Public API
# ===========================================================================

static func spawn(piece: String, data: Dictionary) -> Node3D:
	var scene_path := "res://pieces/%s.tscn" % piece
	if ResourceLoader.exists(scene_path):
		return (load(scene_path) as PackedScene).instantiate()
	var entry := get_entry(piece, data)
	var root := StaticBody3D.new()
	root.name = piece
	root.collision_layer = 1
	root.collision_mask = 0
	var mi := Mats.instance(entry["mesh"])
	mi.visibility_range_end = 240.0
	mi.visibility_range_end_margin = 20.0
	root.add_child(mi)
	for s in entry["shapes"]:
		var cs := CollisionShape3D.new()
		cs.shape = s[0]
		cs.transform = s[1]
		root.add_child(cs)
	_extras(root, piece, data)
	return root


static func get_entry(piece: String, data: Dictionary) -> Dictionary:
	var key := "%s|%s|%s|%s|%s" % [piece, data.get("palette", ""), data.get("seed", 0), data.get("half", ""), data.get("width", "")]
	if piece == "palisade_ring" or piece == "signpost":
		key += "|%s|%s" % [data.get("radius", 0), data.get("gaps", [])]
	if not _cache.has(key):
		var rng := RandomNumberGenerator.new()
		rng.seed = key.hash()
		var k := MeshKit.new(key.hash())
		var shapes: Array = _build(piece, k, data, rng)
		_cache[key] = {"mesh": Assets.pick("pieces/" + piece, k.commit()), "shapes": shapes}
	return _cache[key]


static func clear_cache() -> void:
	_cache.clear()


static func palette(name_: String) -> Dictionary:
	return PALETTES.get(name_, PALETTES["cozy"])


# ===========================================================================
# Builders
# ===========================================================================

static func _build(piece: String, k: MeshKit, d: Dictionary, rng: RandomNumberGenerator) -> Array:
	var pal := palette(d.get("palette", "cozy"))
	var half: Vector2 = d.get("half", Vector2(2.5, 2.5))
	match piece:
		"house_small":
			return _house(k, rng, pal, half * 2.0, 1, {"chimney": rng.randf() < 0.6})
		"house_medium":
			return _house(k, rng, pal, half * 2.0, 1, {"chimney": true, "porch": rng.randf() < 0.5})
		"house_tall":
			return _house(k, rng, pal, half * 2.0, 2, {"chimney": rng.randf() < 0.7, "overhang": true})
		"goblin_hut":
			return _goblin_hut(k, rng, pal, half * 2.0)
		"ruined_house":
			return _ruin(k, rng, pal, half * 2.0)
		"farmhouse":
			return _house(k, rng, pal, half * 2.0, 2, {"chimney": true, "porch": true})
		"post_office":
			return _post_office(k, rng, half * 2.0)
		"tavern":
			return _tavern(k, rng, pal, half * 2.0)
		"blacksmith":
			return _blacksmith(k, rng, pal, half * 2.0)
		"shop":
			return _shop(k, rng, pal, half * 2.0)
		"temple":
			return _temple(k, rng, pal, half * 2.0)
		"town_hall":
			return _town_hall(k, rng, pal, half * 2.0)
		"stable":
			return _stable(k, rng, pal, half * 2.0)
		"barn":
			return _barn(k, rng, half * 2.0)
		"windmill":
			return _windmill(k, rng, pal)
		"guard_tower":
			return _guard_tower(k, rng, pal)
		"tent":
			return _tent(k, rng, d)
		"market_stall":
			return _market_stall(k, rng)
		"well":
			return _well(k, rng, pal)
		"statue":
			return _statue(k)
		"dead_tree":
			return _dead_tree(k, rng)
		"campfire":
			return _campfire(k)
		"log_seat":
			k.cylinder(MeshKit.rot(Vector3(0, 0.25, 0), Vector3(0, 0, PI * 0.5)), 0.28, 0.28, 1.8, Color(0.45, 0.3, 0.18), 7)
			return [[_box(Vector3(1.8, 0.5, 0.56)), MeshKit.at(Vector3(0, 0.25, 0))]]
		"lamp_post":
			return _lamp_post(k)
		"crop_field":
			return _crop_field(k, rng, d)
		"palisade_ring":
			return _palisade(k, rng, d)
		"cart", "cart_broken":
			return _cart(k, rng, piece == "cart_broken")
		"bridge_segment":
			return _bridge(k, rng, d)
		"signpost":
			return _signpost(k)
		"dungeon_entrance":
			return _dungeon_entrance(k, rng)
		"standing_stones":
			return _standing_stones(k, rng)
		"ruined_tower":
			return _ruined_tower(k, rng)
		"giant_tree":
			return _giant_tree(k, rng)
		"notice_board":
			return _notice_board(k)
		"chest":
			return []
	push_warning("Unknown piece '%s'" % piece)
	k.box(Transform3D(), Vector3.ONE, Color.MAGENTA)
	return []


# --- shape helpers ----------------------------------------------------------

static func _box(size: Vector3) -> BoxShape3D:
	var b := BoxShape3D.new()
	b.size = size
	return b


static func _prism_shape(size: Vector3) -> ConvexPolygonShape3D:
	var s := ConvexPolygonShape3D.new()
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	s.points = PackedVector3Array([
		Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(0, size.y, -hz),
		Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(0, size.y, hz)])
	return s


static func _cyl_shape(r: float, h: float) -> CylinderShape3D:
	var c := CylinderShape3D.new()
	c.radius = r
	c.height = h
	return c


static func _pick(rng: RandomNumberGenerator, arr: Array) -> Color:
	return arr[rng.randi_range(0, arr.size() - 1)]


static func _window(k: MeshKit, xf: Transform3D, pal: Dictionary, lit: bool) -> void:
	k.box(xf, Vector3(0.82, 0.82, 0.1), pal["timber"])
	k.box(xf * MeshKit.at(Vector3(0, 0, -0.04)), Vector3(0.6, 0.6, 0.06), GLASS_LIT if lit else GLASS)
	k.box(xf * MeshKit.at(Vector3(0, 0, -0.07)), Vector3(0.08, 0.6, 0.03), pal["timber"])
	k.box(xf * MeshKit.at(Vector3(-0.58, 0, -0.03)), Vector3(0.3, 0.8, 0.06), pal["trim"])
	k.box(xf * MeshKit.at(Vector3(0.58, 0, -0.03)), Vector3(0.3, 0.8, 0.06), pal["trim"])


static func _door(k: MeshKit, xf: Transform3D, pal: Dictionary, wide := 1.0) -> void:
	k.box(xf * MeshKit.at(Vector3(0, 0.9, 0)), Vector3(1.0 * wide, 1.8, 0.1), pal["timber"].darkened(0.25))
	k.box(xf * MeshKit.at(Vector3(0, 1.86, -0.02)), Vector3(1.25 * wide, 0.16, 0.14), pal["timber"])
	k.sphere(xf * MeshKit.at(Vector3(0.32 * wide, 0.9, -0.08)), 0.05, Color(0.85, 0.7, 0.3), 5, 3)


## The workhorse: timber-framed house. size = full footprint (x width, y depth).
static func _house(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2, floors: int, opts: Dictionary) -> Array:
	var w := size.x - 0.4
	var dep := size.y - 0.4
	var wall := _pick(rng, pal["wall"])
	var roof := _pick(rng, pal["roof"])
	var timber: Color = pal["timber"]
	var crook: float = pal["crooked"]
	var tilt := rng.randf_range(-crook, crook)
	var fh := 2.7
	var h := fh * floors
	k.box(MeshKit.at(Vector3(0, -0.45, 0)), Vector3(w + 0.35, 1.7, dep + 0.35), pal["stone"])
	var base := Transform3D(Basis(Vector3.FORWARD, tilt), Vector3(0, 0.4, 0))
	k.box(base * MeshKit.at(Vector3(0, h * 0.5, 0)), Vector3(w, h, dep), wall)
	if opts.get("overhang", false) and floors > 1:
		k.box(base * MeshKit.at(Vector3(0, fh + (h - fh) * 0.5, 0)), Vector3(w + 0.5, h - fh, dep + 0.5), wall)
	var wx := w * 0.5 + (0.25 if opts.get("overhang", false) and floors > 1 else 0.0)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(base * MeshKit.at(Vector3(sx * w * 0.5, h * 0.5, sz * dep * 0.5)), Vector3(0.24, h + 0.05, 0.24), timber)
	for f in range(1, floors + 1):
		k.box(base * MeshKit.at(Vector3(0, f * fh - 0.05, 0)), Vector3(w + 0.12 + (0.5 if f < floors and opts.get("overhang", false) else 0.0), 0.2, dep + 0.12), timber)
	# Diagonal braces for that half-timbered look.
	for sx in [-1.0, 1.0]:
		k.box(base * MeshKit.rot(Vector3(sx * w * 0.32, fh * 0.5, -dep * 0.5 - 0.02), Vector3(0, 0, sx * 0.75)), Vector3(0.14, fh * 0.95, 0.06), timber)
	var door_x := rng.randf_range(-w * 0.15, w * 0.15)
	_door(k, base * MeshKit.at(Vector3(door_x, 0, -dep * 0.5 - 0.04)), pal)
	for f in floors:
		var wy := f * fh + 1.5
		for side in [-1.0, 1.0]:
			var x: float = door_x + side * w * 0.3
			if absf(x) < w * 0.5 - 0.6:
				_window(k, base * MeshKit.at(Vector3(x, wy, -dep * 0.5 - 0.03)), pal, rng.randf() < 0.4)
		_window(k, base * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-w * 0.5 - 0.03, wy, 0)), pal, rng.randf() < 0.4)
		_window(k, base * Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(w * 0.5 + 0.03, wy, 0)), pal, rng.randf() < 0.4)
		if f > 0 or dep > 4.0:
			_window(k, base * Transform3D(Basis(Vector3.UP, PI), Vector3(0, wy, dep * 0.5 + 0.03)), pal, false)
	var roof_h := minf(w, dep) * 0.6 + 0.5
	var roof_xf: Transform3D
	var roof_size: Vector3
	if dep >= w:
		roof_xf = base * MeshKit.at(Vector3(0, h, 0))
		roof_size = Vector3(wx * 2.0 + 0.8, roof_h, dep + 0.9)
	else:
		roof_xf = base * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, h, 0))
		roof_size = Vector3(dep + 0.8 + (0.5 if opts.get("overhang", false) and floors > 1 else 0.0), roof_h, w + 0.9)
	k.prism(roof_xf, roof_size, roof)
	k.box(roof_xf * MeshKit.at(Vector3(0, roof_h + 0.03, 0)), Vector3(0.22, 0.12, roof_size.z + 0.05), roof.darkened(0.25))
	if opts.get("chimney", false):
		k.box(base * MeshKit.at(Vector3(w * 0.28, h + roof_h * 0.55, dep * 0.18)), Vector3(0.55, roof_h * 1.1 + 0.4, 0.55), pal["stone"])
	if opts.get("porch", false):
		var pz := -dep * 0.5 - 1.1
		for sx in [-1.0, 1.0]:
			k.box(MeshKit.at(Vector3(sx * w * 0.35, 1.15 + 0.4, pz)), Vector3(0.18, 2.3, 0.18), timber)
		k.box(MeshKit.rot(Vector3(0, 2.75 + 0.4, pz + 0.35), Vector3(-0.35, 0, 0)), Vector3(w * 0.85, 0.12, 1.8), roof)
		k.box(MeshKit.at(Vector3(0, 0.45, pz + 0.2)), Vector3(w * 0.8, 0.12, 1.6), timber)
	var shapes := []
	shapes.append([_box(Vector3(w + 0.35, h + 1.6, dep + 0.35)), MeshKit.at(Vector3(0, (h + 1.6) * 0.5 - 1.2, 0))])
	shapes.append([_prism_shape(roof_size), MeshKit.at(Vector3(0, 0.4, 0)) * Transform3D(roof_xf.basis.orthonormalized(), Vector3(0, h, 0))])
	return shapes


static func _goblin_hut(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	var pal2 := pal.duplicate()
	pal2["crooked"] = 0.16
	var shapes := _house(k, rng, pal2, size, 1, {"chimney": rng.randf() < 0.5})
	# Goblin flourishes: patched roof, spikes, a skull-ish lantern, junk.
	var h := 2.7 + 0.4
	k.box(MeshKit.rot(Vector3(size.x * 0.15, h + 0.9, -0.3), Vector3(0.4, 0.3, 0.2)), Vector3(1.2, 0.08, 1.0), _pick(rng, pal["roof"]).darkened(0.2))
	for i in rng.randi_range(2, 4):
		var x := rng.randf_range(-size.x * 0.4, size.x * 0.4)
		k.cylinder(MeshKit.rot(Vector3(x, h + 1.5 + rng.randf() * 0.5, rng.randf_range(-0.5, 0.5)), Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))), 0.08, 0.0, 0.9, Color(0.85, 0.82, 0.7), 5)
	k.box(MeshKit.rot(Vector3(-size.x * 0.5 - 0.4, 0.6, -size.y * 0.3), Vector3(0, 0.3, 0.1)), Vector3(0.8, 0.8, 0.8), pal["timber"])
	k.cylinder(MeshKit.at(Vector3(size.x * 0.5 + 0.3, 0.45, size.y * 0.2)), 0.35, 0.3, 0.9, Color(0.5, 0.35, 0.2), 8)
	return shapes


static func _ruin(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	var w := size.x - 0.4
	var dep := size.y - 0.4
	var wall := _pick(rng, pal["wall"])
	var shapes := []
	k.box(MeshKit.at(Vector3(0, -0.4, 0)), Vector3(w + 0.3, 1.4, dep + 0.3), pal["stone"])
	var walls := [[Vector3(0, 0, -dep * 0.5), Vector3(w, 0, 0.35)], [Vector3(0, 0, dep * 0.5), Vector3(w, 0, 0.35)],
		[Vector3(-w * 0.5, 0, 0), Vector3(0.35, 0, dep)], [Vector3(w * 0.5, 0, 0), Vector3(0.35, 0, dep)]]
	for wd in walls:
		var p: Vector3 = wd[0]
		var s: Vector3 = wd[1]
		var hh := rng.randf_range(0.6, 2.8)
		if rng.randf() < 0.75:
			var sz := Vector3(maxf(s.x, 0.35), hh, maxf(s.z, 0.35))
			if s.x > 1.0:
				sz.x = s.x * rng.randf_range(0.5, 1.0)
			else:
				sz.z = s.z * rng.randf_range(0.5, 1.0)
			k.box(MeshKit.at(p + Vector3(0, 0.3 + hh * 0.5, 0)), sz, wall.darkened(rng.randf() * 0.15))
			shapes.append([_box(sz), MeshKit.at(p + Vector3(0, 0.3 + hh * 0.5, 0))])
	for i in 3:
		k.box(MeshKit.rot(Vector3(rng.randf_range(-w, w) * 0.3, 0.6, rng.randf_range(-dep, dep) * 0.3), Vector3(rng.randf(), rng.randf(), rng.randf_range(0.3, 1.0))), Vector3(0.2, 0.2, rng.randf_range(2.0, 3.5)), pal["timber"])
	for i in 5:
		k.sphere(MeshKit.at(Vector3(rng.randf_range(-w, w) * 0.4, 0.35, rng.randf_range(-dep, dep) * 0.4), rng.randf() * 3.0, Vector3(1, 0.6, 1)), rng.randf_range(0.25, 0.5), pal["stone"], 6, 4)
	for i in 4:
		k.sphere(MeshKit.at(Vector3(rng.randf_range(-w, w) * 0.5, 0.4, rng.randf_range(-dep, dep) * 0.5), 0, Vector3(1, 0.7, 1)), rng.randf_range(0.35, 0.6), Color(0.35, 0.55, 0.28), 6, 4)
	return shapes


static func _post_office(k: MeshKit, rng: RandomNumberGenerator, size: Vector2) -> Array:
	var pal := {"wall": [Color(0.96, 0.92, 0.82)], "roof": [GoblinRig.CAP], "timber": Color(0.18, 0.28, 0.55),
		"stone": Color(0.62, 0.6, 0.58), "trim": GoblinRig.VEST_TRIM, "crooked": 0.0}
	var shapes := _house(k, rng, pal, size, 2, {"chimney": false})
	var dep := size.y - 0.4
	var w := size.x - 0.4
	var h := 2.7 * 2 + 0.4
	# Big sign over the door: an envelope.
	var sign_xf := MeshKit.at(Vector3(0, 2.75 + 0.4, -dep * 0.5 - 0.25))
	k.box(sign_xf, Vector3(2.4, 0.9, 0.12), Color(0.18, 0.28, 0.55))
	k.box(sign_xf * MeshKit.at(Vector3(0, 0, -0.08)), Vector3(1.1, 0.6, 0.04), Color(0.98, 0.96, 0.9))
	k.box(sign_xf * MeshKit.rot(Vector3(-0.27, 0.1, -0.11), Vector3(0, 0, -0.5)), Vector3(0.65, 0.06, 0.03), GoblinRig.CAP)
	k.box(sign_xf * MeshKit.rot(Vector3(0.27, 0.1, -0.11), Vector3(0, 0, 0.5)), Vector3(0.65, 0.06, 0.03), GoblinRig.CAP)
	# Little bell tower on the ridge so you can spot home from afar.
	var roof_h := minf(w, dep) * 0.6 + 0.5
	var tower := MeshKit.at(Vector3(0, h + roof_h * 0.4, 0))
	k.box(tower * MeshKit.at(Vector3(0, 1.0, 0)), Vector3(1.6, 2.0, 1.6), Color(0.96, 0.92, 0.82))
	k.box(tower * MeshKit.at(Vector3(0, 1.1, -0.81)), Vector3(0.9, 0.9, 0.05), Color(0.98, 0.98, 0.95))
	k.box(tower * MeshKit.rot(Vector3(0.0, 1.2, -0.85), Vector3(0, 0, 0.4)), Vector3(0.06, 0.4, 0.03), DARK)
	k.pyramid(tower * MeshKit.at(Vector3(0, 2.0, 0)), 2.1, 1.6, GoblinRig.CAP)
	# Flagpole with the courier banner — the tallest thing in the village.
	var fp := Vector3(w * 0.5 + 1.2, 0, -dep * 0.5 - 0.6)
	k.cylinder(MeshKit.at(fp + Vector3(0, 5.5, 0)), 0.09, 0.07, 11.0, Color(0.85, 0.85, 0.8), 6)
	k.sphere(MeshKit.at(fp + Vector3(0, 11.05, 0)), 0.16, GoblinRig.VEST_TRIM, 6, 4)
	k.box(MeshKit.at(fp + Vector3(0.95, 10.1, 0)), Vector3(1.8, 1.1, 0.05), GoblinRig.VEST)
	k.box(MeshKit.at(fp + Vector3(0.95, 10.1, -0.03)), Vector3(1.8, 0.3, 0.04), GoblinRig.CAP)
	# Giant mailbox by the door.
	var mb := Vector3(-w * 0.5 - 0.9, 0, -dep * 0.5 - 0.8)
	k.box(MeshKit.at(mb + Vector3(0, 0.5, 0)), Vector3(0.12, 1.0, 0.12), DARK)
	k.box(MeshKit.at(mb + Vector3(0, 1.25, 0)), Vector3(0.7, 0.55, 0.9), GoblinRig.CAP)
	k.cylinder(MeshKit.rot(mb + Vector3(0, 1.52, 0), Vector3(PI * 0.5, 0, 0)), 0.35, 0.35, 0.9, GoblinRig.CAP, 8)
	k.box(MeshKit.at(mb + Vector3(0.38, 1.7, 0.15)), Vector3(0.04, 0.5, 0.12), GoblinRig.VEST_TRIM)
	shapes.append([_cyl_shape(0.15, 11.0), MeshKit.at(fp + Vector3(0, 5.5, 0))])
	shapes.append([_box(Vector3(0.8, 1.9, 0.95)), MeshKit.at(mb + Vector3(0, 0.95, 0))])
	return shapes


static func _tavern(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	var shapes := _house(k, rng, pal, size, 2, {"chimney": true, "porch": true})
	var dep := size.y - 0.4
	var w := size.x - 0.4
	var sp := Vector3(w * 0.5 - 0.3, 0, -dep * 0.5 - 2.2)
	k.box(MeshKit.at(sp + Vector3(0, 1.8, 0)), Vector3(0.18, 3.6, 0.18), pal["timber"])
	k.box(MeshKit.at(sp + Vector3(-0.5, 3.45, 0)), Vector3(1.2, 0.12, 0.12), pal["timber"])
	k.box(MeshKit.at(sp + Vector3(-0.7, 2.85, 0)), Vector3(0.95, 0.85, 0.08), Color(0.55, 0.35, 0.2))
	k.cylinder(MeshKit.at(sp + Vector3(-0.7, 2.85, -0.07)), 0.2, 0.2, 0.42, Color(0.95, 0.75, 0.25), 7)
	k.box(MeshKit.at(sp + Vector3(-0.7, 3.1, -0.07)), Vector3(0.44, 0.1, 0.06), Color(1, 1, 0.95))
	for i in 3:
		k.cylinder(MeshKit.at(Vector3(-w * 0.5 + 0.6 + i * 0.75, 0.5, -dep * 0.5 - 0.6)), 0.34, 0.3, 1.0, Color(0.55, 0.36, 0.2), 8)
	shapes.append([_box(Vector3(2.3, 1.0, 0.8)), MeshKit.at(Vector3(-w * 0.5 + 1.35, 0.5, -dep * 0.5 - 0.6))])
	return shapes


static func _blacksmith(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	# Closed workshop at the back, open forge under a lean-to at the front.
	var back := Vector2(size.x, size.y * 0.55)
	var off := MeshKit.at(Vector3(0, 0, size.y * 0.22))
	var sub := MeshKit.new(rng.randi())
	var shapes := []
	for s in _house(sub, rng, pal, back, 1, {"chimney": true}):
		shapes.append([s[0], off * s[1]])
	k.append(sub.commit(), off)
	var front_z := -size.y * 0.5 + 0.3
	for sx in [-1.0, 1.0]:
		k.box(MeshKit.at(Vector3(sx * (size.x * 0.5 - 0.3), 1.4, front_z)), Vector3(0.22, 2.8, 0.22), pal["timber"])
	k.box(MeshKit.rot(Vector3(0, 2.9, front_z + size.y * 0.2), Vector3(0.25, 0, 0)), Vector3(size.x, 0.14, size.y * 0.5), _pick(rng, pal["roof"]).darkened(0.1))
	k.box(MeshKit.at(Vector3(0, -0.2, front_z + size.y * 0.2)), Vector3(size.x, 0.6, size.y * 0.45), pal["stone"])
	# Forge + anvil.
	k.box(MeshKit.at(Vector3(-size.x * 0.25, 0.5, front_z + 0.9)), Vector3(1.3, 1.0, 1.0), pal["stone"])
	k.box(MeshKit.at(Vector3(-size.x * 0.25, 1.05, front_z + 0.9)), Vector3(1.0, 0.1, 0.7), Color(1.0, 0.45, 0.1))
	k.box(MeshKit.at(Vector3(size.x * 0.2, 0.35, front_z + 0.9)), Vector3(0.4, 0.7, 0.4), Color(0.35, 0.25, 0.18))
	k.box(MeshKit.at(Vector3(size.x * 0.2, 0.8, front_z + 0.9)), Vector3(0.8, 0.22, 0.3), Color(0.3, 0.3, 0.33))
	k.cylinder(MeshKit.rot(Vector3(size.x * 0.2 - 0.45, 0.8, front_z + 0.9), Vector3(0, 0, PI * 0.5)), 0.11, 0.0, 0.3, Color(0.3, 0.3, 0.33), 5)
	shapes.append([_box(Vector3(1.3, 1.0, 1.0)), MeshKit.at(Vector3(-size.x * 0.25, 0.5, front_z + 0.9))])
	return shapes


static func _shop(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	var shapes := _house(k, rng, pal, size, 1, {"chimney": rng.randf() < 0.5})
	var dep := size.y - 0.4
	var w := size.x - 0.4
	var stripes := 7
	var a := _pick(rng, [Color(0.85, 0.2, 0.2), Color(0.2, 0.5, 0.8), Color(0.3, 0.6, 0.3)])
	for i in stripes:
		var x := -w * 0.45 + w * 0.9 * (i + 0.5) / stripes
		k.box(MeshKit.rot(Vector3(x, 2.5, -dep * 0.5 - 0.7), Vector3(-0.45, 0, 0)), Vector3(w * 0.9 / stripes + 0.01, 0.06, 1.5), a if i % 2 == 0 else Color(0.97, 0.95, 0.9))
	for i in 3:
		k.box(MeshKit.rot(Vector3(-w * 0.3 + i * 0.9, 0.35, -dep * 0.5 - 0.9), Vector3(0, rng.randf() * 0.5, 0)), Vector3(0.7, 0.7, 0.7), Color(0.7, 0.55, 0.35))
		k.sphere(MeshKit.at(Vector3(-w * 0.3 + i * 0.9, 0.8, -dep * 0.5 - 0.9)), 0.2, Color.from_hsv(rng.randf(), 0.7, 0.9), 6, 4)
	return shapes


static func _temple(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	var stone := pal["stone"].lightened(0.15) as Color
	var w := size.x - 0.4
	var dep := size.y - 0.4
	var roof := _pick(rng, pal["roof"])
	var h := 5.0
	k.box(MeshKit.at(Vector3(0, -0.4, 0)), Vector3(w + 0.5, 1.6, dep + 0.5), pal["stone"])
	k.box(MeshKit.at(Vector3(0, 0.4 + h * 0.5, 0)), Vector3(w, h, dep), stone)
	for z in [-dep * 0.25, dep * 0.25]:
		for sx in [-1.0, 1.0]:
			k.box(MeshKit.at(Vector3(sx * (w * 0.5 + 0.02), 2.6, z)), Vector3(0.06, 2.0, 0.8), GLASS_LIT)
	k.prism(MeshKit.at(Vector3(0, 0.4 + h, 0)), Vector3(w + 0.8, w * 0.75, dep + 0.8), roof)
	var t := MeshKit.at(Vector3(0, 0.4, -dep * 0.5 + 1.2))
	k.box(t * MeshKit.at(Vector3(0, 4.2, 0)), Vector3(2.6, 8.4, 2.6), stone)
	k.box(t * MeshKit.at(Vector3(0, 7.2, -1.31)), Vector3(1.0, 1.4, 0.05), DARK)
	k.pyramid(t * MeshKit.at(Vector3(0, 8.4, 0)), 3.0, 3.6, roof)
	k.box(t * MeshKit.at(Vector3(0, 12.4, 0)), Vector3(0.12, 0.9, 0.12), pal["trim"])
	k.box(t * MeshKit.at(Vector3(0, 12.5, 0)), Vector3(0.6, 0.12, 0.12), pal["trim"])
	k.cylinder(MeshKit.rot(Vector3(0, 4.6, -dep * 0.5 - 0.03), Vector3(PI * 0.5, 0, 0)), 0.7, 0.7, 0.08, GLASS_LIT, 10)
	_door(k, MeshKit.at(Vector3(0, 0.4, -dep * 0.5 - 0.06)), pal, 1.4)
	return [
		[_box(Vector3(w + 0.5, h + 1.6, dep + 0.5)), MeshKit.at(Vector3(0, (h + 1.6) * 0.5 - 1.2, 0))],
		[_box(Vector3(2.6, 8.4, 2.6)), t * MeshKit.at(Vector3(0, 4.2, 0))],
		[_prism_shape(Vector3(w + 0.8, w * 0.75, dep + 0.8)), MeshKit.at(Vector3(0, 0.4 + h, 0))],
	]


static func _town_hall(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	var shapes := _house(k, rng, pal, size, 2, {"chimney": true})
	var dep := size.y - 0.4
	var w := size.x - 0.4
	var t := MeshKit.at(Vector3(0, 6.0, -dep * 0.5 + 0.9))
	k.box(t * MeshKit.at(Vector3(0, 1.5, 0)), Vector3(2.2, 3.0, 2.2), pal["stone"].lightened(0.1))
	k.cylinder(t * MeshKit.rot(Vector3(0, 1.8, -1.12), Vector3(PI * 0.5, 0, 0)), 0.6, 0.6, 0.06, Color(0.98, 0.97, 0.9), 12)
	k.box(t * MeshKit.rot(Vector3(0.1, 1.9, -1.16), Vector3(0, 0, -0.6)), Vector3(0.06, 0.45, 0.03), DARK)
	k.pyramid(t * MeshKit.at(Vector3(0, 3.0, 0)), 2.6, 2.4, _pick(rng, pal["roof"]))
	for sx in [-1.0, 1.0]:
		k.box(MeshKit.at(Vector3(sx * w * 0.32, 3.6, -dep * 0.5 - 0.1)), Vector3(0.7, 2.6, 0.05), pal["trim"])
		k.box(MeshKit.at(Vector3(sx * w * 0.32, 2.35, -dep * 0.5 - 0.1)), Vector3(0.7, 0.2, 0.06), pal["trim"].darkened(0.3))
	for i in 3:
		k.box(MeshKit.at(Vector3(0, 0.1 + i * 0.15, -dep * 0.5 - 0.5 - i * 0.3 + 0.3)), Vector3(2.4, 0.15, 0.6), pal["stone"])
	shapes.append([_box(Vector3(2.2, 3.0, 2.2)), t * MeshKit.at(Vector3(0, 1.5, 0))])
	return shapes


static func _stable(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary, size: Vector2) -> Array:
	var w := size.x - 0.4
	var dep := size.y - 0.4
	var timber: Color = pal["timber"]
	k.box(MeshKit.at(Vector3(0, -0.3, 0)), Vector3(w, 0.8, dep), pal["stone"])
	k.box(MeshKit.at(Vector3(0, 1.6, dep * 0.5 - 0.15)), Vector3(w, 2.8, 0.3), timber.lightened(0.2))
	for sx in [-1.0, 1.0]:
		k.box(MeshKit.at(Vector3(sx * (w * 0.5 - 0.15), 1.6, 0)), Vector3(0.3, 2.8, dep), timber.lightened(0.2))
		k.box(MeshKit.at(Vector3(sx * (w * 0.5 - 0.15), 1.5, -dep * 0.5)), Vector3(0.25, 3.0, 0.25), timber)
	k.box(MeshKit.at(Vector3(0, 1.5, -dep * 0.5)), Vector3(0.25, 3.0, 0.25), timber)
	k.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 3.0, 0)), Vector3(dep + 0.8, 1.6, w + 0.8), _pick(rng, pal["roof"]))
	for i in 4:
		k.box(MeshKit.rot(Vector3(rng.randf_range(-w, w) * 0.35, 0.45, rng.randf_range(0.0, dep * 0.3)), Vector3(0, rng.randf(), 0)), Vector3(1.0, 0.6, 0.6), Color(0.9, 0.78, 0.35))
	return [
		[_box(Vector3(w, 3.0, 0.3)), MeshKit.at(Vector3(0, 1.5, dep * 0.5 - 0.15))],
		[_box(Vector3(0.3, 3.0, dep)), MeshKit.at(Vector3(-(w * 0.5 - 0.15), 1.5, 0))],
		[_box(Vector3(0.3, 3.0, dep)), MeshKit.at(Vector3(w * 0.5 - 0.15, 1.5, 0))],
		[_prism_shape(Vector3(dep + 0.8, 1.6, w + 0.8)), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 3.0, 0))],
	]


static func _barn(k: MeshKit, rng: RandomNumberGenerator, size: Vector2) -> Array:
	var w := size.x - 0.4
	var dep := size.y - 0.4
	var red := Color(0.72, 0.2, 0.15)
	var white := Color(0.96, 0.94, 0.9)
	var h := 4.2
	k.box(MeshKit.at(Vector3(0, -0.4, 0)), Vector3(w + 0.3, 1.4, dep + 0.3), Color(0.55, 0.52, 0.5))
	k.box(MeshKit.at(Vector3(0, 0.3 + h * 0.5, 0)), Vector3(w, h, dep), red)
	var dz := -dep * 0.5 - 0.05
	k.box(MeshKit.at(Vector3(0, 1.8, dz)), Vector3(2.8, 3.2, 0.08), red.darkened(0.15))
	for s in [-1.0, 1.0]:
		k.box(MeshKit.rot(Vector3(0, 1.8, dz - 0.03), Vector3(0, 0, s * 0.85)), Vector3(0.18, 4.0, 0.05), white)
	k.box(MeshKit.at(Vector3(0, 3.45, dz - 0.03)), Vector3(3.0, 0.18, 0.05), white)
	k.box(MeshKit.at(Vector3(0, 0.25, dz - 0.03)), Vector3(3.0, 0.18, 0.05), white)
	k.box(MeshKit.at(Vector3(0, 5.6, dz)), Vector3(1.2, 1.0, 0.08), DARK)
	var roof := Color(0.35, 0.33, 0.35)
	k.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.3 + h, 0)), Vector3(dep + 0.8, 2.6, w + 0.8), roof)
	return [
		[_box(Vector3(w + 0.3, h + 1.4, dep + 0.3)), MeshKit.at(Vector3(0, (h + 1.4) * 0.5 - 1.1, 0))],
		[_prism_shape(Vector3(dep + 0.8, 2.6, w + 0.8)), Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0.3 + h, 0))],
	]


static func _windmill(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary) -> Array:
	k.cylinder(MeshKit.at(Vector3(0, -0.3, 0)), 2.5, 2.5, 1.2, pal["stone"], 10)
	k.cylinder(MeshKit.at(Vector3(0, 4.3, 0)), 2.2, 1.5, 8.0, _pick(rng, pal["wall"]), 10)
	k.cylinder(MeshKit.at(Vector3(0, 9.3, 0)), 1.85, 0.0, 2.2, _pick(rng, pal["roof"]), 10)
	_door(k, MeshKit.at(Vector3(0, 0.3, -2.18)), pal)
	_window(k, MeshKit.rot(Vector3(0, 4.8, -1.9), Vector3(0.09, 0, 0)), pal, true)
	k.box(MeshKit.at(Vector3(0, 7.6, -1.6)), Vector3(0.5, 0.5, 0.8), pal["timber"])
	return [[_cyl_shape(2.2, 9.0), MeshKit.at(Vector3(0, 4.2, 0))]]


static func windmill_blades() -> ArrayMesh:
	var k := MeshKit.new(77)
	k.cylinder(MeshKit.rot(Vector3.ZERO, Vector3(PI * 0.5, 0, 0)), 0.3, 0.3, 0.5, Color(0.4, 0.28, 0.18), 8)
	for i in 4:
		var a := TAU * i / 4.0
		var dir := Vector3(cos(a), sin(a), 0)
		var b := Basis(Vector3.BACK, a - PI * 0.5)
		k.box(Transform3D(b, dir * 2.4), Vector3(0.18, 4.8, 0.12), Color(0.45, 0.32, 0.2))
		k.box(Transform3D(b, dir * 2.8 + b.x * 0.45), Vector3(0.8, 3.6, 0.05), Color(0.96, 0.93, 0.85))
	return Assets.pick("pieces/windmill_blades", k.commit())


static func _guard_tower(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary) -> Array:
	var s: Color = pal["stone"]
	k.box(MeshKit.at(Vector3(0, 3.0, 0)), Vector3(3.2, 7.0, 3.2), s)
	k.box(MeshKit.at(Vector3(0, 6.6, 0)), Vector3(3.8, 0.3, 3.8), s.darkened(0.1))
	for i in 4:
		for j in [-1.0, 0.0, 1.0]:
			var b := Basis(Vector3.UP, PI * 0.5 * i)
			k.box(Transform3D(b, b * Vector3(j * 1.3, 7.2, -1.75)), Vector3(0.6, 0.9, 0.3), s)
	k.box(MeshKit.at(Vector3(0, 4.5, -1.61)), Vector3(0.4, 0.9, 0.05), DARK)
	_door(k, MeshKit.at(Vector3(0, -0.5, -1.62)), pal)
	k.box(MeshKit.at(Vector3(1.2, 8.6, 1.2)), Vector3(0.08, 2.4, 0.08), Color(0.5, 0.4, 0.3))
	k.box(MeshKit.at(Vector3(1.7, 9.3, 1.2)), Vector3(1.0, 0.6, 0.04), pal["trim"])
	return [[_box(Vector3(3.2, 7.4, 3.2)), MeshKit.at(Vector3(0, 3.2, 0))]]


static func _tent(k: MeshKit, rng: RandomNumberGenerator, d: Dictionary) -> Array:
	var cloth: Color = [Color(0.55, 0.45, 0.32), Color(0.6, 0.2, 0.15), Color(0.42, 0.4, 0.3)][int(d.get("variant", 0)) % 3]
	k.prism(MeshKit.at(Vector3(0, 0, 0)), Vector3(3.2, 2.3, 3.4), cloth)
	k.prism(MeshKit.at(Vector3(0, 0, -1.72)), Vector3(1.0, 1.4, 0.04), DARK)
	for z in [-1.75, 1.75]:
		k.box(MeshKit.at(Vector3(0, 1.25, z)), Vector3(0.1, 2.5, 0.1), Color(0.4, 0.3, 0.2))
	return [[_prism_shape(Vector3(3.2, 2.3, 3.4)), Transform3D()]]


static func _market_stall(k: MeshKit, rng: RandomNumberGenerator) -> Array:
	var wood := Color(0.55, 0.38, 0.22)
	k.box(MeshKit.at(Vector3(0, 0.85, 0)), Vector3(2.4, 0.12, 1.1), wood)
	k.box(MeshKit.at(Vector3(0, 0.45, 0.3)), Vector3(2.3, 0.8, 0.5), wood.darkened(0.15))
	for sx in [-1.1, 1.1]:
		for sz in [-0.5, 0.5]:
			k.box(MeshKit.at(Vector3(sx, 1.2, sz)), Vector3(0.1, 2.4, 0.1), wood)
	var c := Color.from_hsv(rng.randf(), 0.65, 0.85)
	for i in 6:
		k.box(MeshKit.rot(Vector3(-1.05 + i * 0.42, 2.45, 0), Vector3(-0.25, 0, 0)), Vector3(0.43, 0.06, 1.5), c if i % 2 == 0 else Color(0.97, 0.95, 0.9))
	for i in 5:
		k.sphere(MeshKit.at(Vector3(-0.9 + i * 0.45, 1.02, -0.15)), 0.17, Color.from_hsv(rng.randf(), 0.7, 0.9), 6, 4)
	return [[_box(Vector3(2.4, 1.0, 1.1)), MeshKit.at(Vector3(0, 0.5, 0))]]


static func _well(k: MeshKit, rng: RandomNumberGenerator, pal: Dictionary) -> Array:
	k.cylinder(MeshKit.at(Vector3(0, 0.45, 0)), 1.15, 1.15, 0.9, pal["stone"], 10)
	k.cylinder(MeshKit.at(Vector3(0, 0.62, 0)), 0.85, 0.85, 0.6, Color(0.15, 0.25, 0.35), 10, true)
	for sx in [-1.0, 1.0]:
		k.box(MeshKit.at(Vector3(sx * 1.0, 1.4, 0)), Vector3(0.16, 1.9, 0.16), pal["timber"])
	k.cylinder(MeshKit.rot(Vector3(0, 1.85, 0), Vector3(0, 0, PI * 0.5)), 0.08, 0.08, 2.0, pal["timber"], 6)
	k.prism(MeshKit.at(Vector3(0, 2.25, 0)), Vector3(2.6, 0.9, 1.4), _pick(rng, pal["roof"]))
	k.cylinder(MeshKit.at(Vector3(0.3, 1.25, 0)), 0.15, 0.12, 0.25, Color(0.5, 0.35, 0.2), 6)
	return [[_cyl_shape(1.15, 1.0), MeshKit.at(Vector3(0, 0.5, 0))]]


static func _statue(k: MeshKit) -> Array:
	var stone := Color(0.78, 0.76, 0.72)
	var gold := Color(0.85, 0.7, 0.3)
	k.box(MeshKit.at(Vector3(0, 0.6, 0)), Vector3(1.8, 1.2, 1.8), stone.darkened(0.15))
	k.box(MeshKit.at(Vector3(0, 1.3, 0)), Vector3(1.4, 0.2, 1.4), stone)
	# The Founder of the Post: a heroic goblin, parcel raised high.
	k.sphere(MeshKit.at(Vector3(0, 2.1, 0), 0, Vector3(1, 1.15, 0.9)), 0.4, gold, 8, 5)
	k.sphere(MeshKit.at(Vector3(0, 2.95, 0), 0, Vector3(1.15, 0.95, 1)), 0.5, gold, 8, 6)
	k.cone_between(Vector3(0.45, 3.0, 0), Vector3(1.05, 3.2, 0), 0.15, 0.0, gold, 6, 0.5)
	k.cone_between(Vector3(-0.45, 3.0, 0), Vector3(-1.05, 3.2, 0), 0.15, 0.0, gold, 6, 0.5)
	k.cylinder(MeshKit.at(Vector3(0, 3.4, 0)), 0.42, 0.4, 0.22, gold.darkened(0.1), 8)
	k.cylinder_between(Vector3(0.35, 2.4, 0), Vector3(0.6, 3.6, -0.1), 0.07, gold, 6)
	k.box(MeshKit.at(Vector3(0.62, 3.85, -0.1)), Vector3(0.5, 0.4, 0.4), gold)
	return [[_box(Vector3(1.8, 1.4, 1.8)), MeshKit.at(Vector3(0, 0.7, 0))]]


static func _dead_tree(k: MeshKit, rng: RandomNumberGenerator) -> Array:
	var bark := Color(0.35, 0.3, 0.26)
	k.cylinder(MeshKit.at(Vector3(0, 1.8, 0)), 0.35, 0.18, 3.6, bark, 6)
	for i in 4:
		var a := rng.randf() * TAU
		var y := rng.randf_range(1.8, 3.4)
		k.cylinder_between(Vector3(0, y, 0), Vector3(cos(a) * 1.4, y + 1.0, sin(a) * 1.4), 0.08, bark, 5)
	return [[_cyl_shape(0.35, 3.6), MeshKit.at(Vector3(0, 1.8, 0))]]


static func _campfire(k: MeshKit) -> Array:
	for i in 8:
		var a := TAU * i / 8.0
		k.sphere(MeshKit.at(Vector3(cos(a) * 0.75, 0.12, sin(a) * 0.75), 0, Vector3(1, 0.7, 1)), 0.2, Color(0.5, 0.5, 0.5), 5, 3)
	for i in 3:
		var a := TAU * i / 3.0
		k.cylinder(MeshKit.rot(Vector3(cos(a) * 0.2, 0.25, sin(a) * 0.2), Vector3(0, -a, 1.1)), 0.09, 0.09, 1.0, Color(0.4, 0.26, 0.15), 5)
	return []


static func _lamp_post(k: MeshKit) -> Array:
	var iron := Color(0.2, 0.2, 0.22)
	k.cylinder(MeshKit.at(Vector3(0, 1.4, 0)), 0.08, 0.06, 2.8, iron, 6)
	k.box(MeshKit.at(Vector3(0, 2.85, 0)), Vector3(0.35, 0.08, 0.35), iron)
	k.box(MeshKit.at(Vector3(0, 3.1, 0)), Vector3(0.28, 0.4, 0.28), GLASS_LIT)
	k.pyramid(MeshKit.at(Vector3(0, 3.3, 0)), 0.42, 0.25, iron)
	return [[_cyl_shape(0.1, 3.0), MeshKit.at(Vector3(0, 1.5, 0))]]


static func _crop_field(k: MeshKit, rng: RandomNumberGenerator, d: Dictionary) -> Array:
	var half: Vector2 = d.get("half", Vector2(7, 5))
	var crop: Color = [Color(0.9, 0.75, 0.25), Color(0.45, 0.7, 0.25), Color(0.85, 0.45, 0.2)][int(d.get("seed", 0)) % 3]
	var rows := int(half.y * 2.0 / 1.2)
	for r in rows:
		var z := -half.y + 0.6 + r * 1.2
		var x := -half.x + 0.5
		while x < half.x - 0.4:
			k.cylinder(MeshKit.at(Vector3(x + rng.randf_range(-0.1, 0.1), 0.3, z)), 0.22, 0.0, 0.6 + rng.randf() * 0.3, crop.darkened(rng.randf() * 0.15), 5)
			x += 0.7
	var fence := Color(0.6, 0.45, 0.28)
	var shapes := []
	var edges := [[Vector3(0, 0, -half.y - 0.5), Vector3(half.x * 2 + 1, 0, 0)], [Vector3(0, 0, half.y + 0.5), Vector3(half.x * 2 + 1, 0, 0)],
		[Vector3(-half.x - 0.5, 0, 0), Vector3(0, 0, half.y * 2 + 1)], [Vector3(half.x + 0.5, 0, 0), Vector3(0, 0, half.y * 2 + 1)]]
	for i in edges.size():
		var c: Vector3 = edges[i][0]
		var ext: Vector3 = edges[i][1]
		var length := maxf(ext.x, ext.z)
		var along := Vector3(1, 0, 0) if ext.x > 0 else Vector3(0, 0, 1)
		var gap := i == 0  # gate on one side
		var n := int(length / 2.0)
		for j in n + 1:
			var p := c + along * (-length * 0.5 + j * length / n)
			if gap and absf(p.dot(along)) < 1.2:
				continue
			k.box(MeshKit.at(p + Vector3(0, 0.45, 0)), Vector3(0.14, 0.9, 0.14), fence)
		for y in [0.35, 0.75]:
			if gap:
				for s in [-1.0, 1.0]:
					var seg := (length * 0.5 - 1.2)
					k.box(MeshKit.at(c + along * s * (1.2 + seg * 0.5) + Vector3(0, y, 0)), (Vector3(seg, 0.08, 0.06) if ext.x > 0 else Vector3(0.06, 0.08, seg)), fence)
			else:
				k.box(MeshKit.at(c + Vector3(0, y, 0)), (Vector3(length, 0.08, 0.06) if ext.x > 0 else Vector3(0.06, 0.08, length)), fence)
		if not gap:
			shapes.append([_box(Vector3(maxf(ext.x, 0.2), 1.0, maxf(ext.z, 0.2))), MeshKit.at(c + Vector3(0, 0.5, 0))])
	return shapes


static func _palisade(k: MeshKit, rng: RandomNumberGenerator, d: Dictionary) -> Array:
	var radius: float = d.get("radius", 28.0)
	var gaps: Array = d.get("gaps", [])
	var wood := Color(0.42, 0.3, 0.2)
	var shapes := []
	var n := int(TAU * radius / 0.75)
	var seg_start := -1
	for i in n + 1:
		var a := TAU * i / n
		var in_gap := false
		for g in gaps:
			if absf(wrapf(a - float(g), -PI, PI)) < 0.12:
				in_gap = true
		if not in_gap and i < n:
			var p := Vector3(cos(a), 0, sin(a)) * radius
			var hh := rng.randf_range(2.4, 3.0)
			k.cylinder(MeshKit.at(p + Vector3(0, hh * 0.5 - 0.5, 0)), 0.32, 0.3, hh, wood.darkened(rng.randf() * 0.15), 6)
			k.cylinder(MeshKit.at(p + Vector3(0, hh - 0.5 + 0.25, 0)), 0.3, 0.0, 0.5, wood.lightened(0.1), 6)
			if seg_start < 0:
				seg_start = i
		if (in_gap or i == n) and seg_start >= 0:
			var a0 := TAU * seg_start / n
			var a1 := TAU * (i - 1) / n
			var steps := maxi(1, int((a1 - a0) * radius / 4.0))
			for s in steps:
				var sa := lerpf(a0, a1, (s + 0.5) / steps)
				var length := (a1 - a0) * radius / steps + 0.6
				shapes.append([_box(Vector3(length, 3.0, 0.7)), Transform3D(Basis(Vector3.UP, -sa + PI * 0.5), Vector3(cos(sa), 0, sin(sa)) * radius + Vector3(0, 1.0, 0))])
			seg_start = -1
	return shapes


static func _cart(k: MeshKit, rng: RandomNumberGenerator, broken: bool) -> Array:
	var wood := Color(0.55, 0.38, 0.22)
	var tilt := 0.25 if broken else 0.0
	var base := Transform3D(Basis(Vector3.BACK, tilt), Vector3(0, 0.0, 0))
	k.box(base * MeshKit.at(Vector3(0, 0.9, 0)), Vector3(1.6, 0.15, 2.6), wood)
	for sx in [-1.0, 1.0]:
		k.box(base * MeshKit.at(Vector3(sx * 0.8, 1.2, 0)), Vector3(0.08, 0.5, 2.6), wood.darkened(0.1))
	k.box(base * MeshKit.at(Vector3(0, 1.2, 1.3)), Vector3(1.6, 0.5, 0.08), wood.darkened(0.1))
	for sx in [-1.0, 1.0]:
		if broken and sx > 0:
			k.cylinder(MeshKit.rot(Vector3(1.6, 0.1, 0.8), Vector3(PI * 0.5, 0, 0.3)), 0.55, 0.55, 0.12, wood.darkened(0.25), 8)
			continue
		k.cylinder(base * MeshKit.rot(Vector3(sx * 0.9, 0.55, 0.3), Vector3(0, 0, PI * 0.5)), 0.55, 0.55, 0.12, wood.darkened(0.25), 8)
	k.box(base * MeshKit.rot(Vector3(0.35, 0.7, -2.0), Vector3(0.25, 0, 0)), Vector3(0.08, 0.08, 1.8), wood)
	k.box(base * MeshKit.rot(Vector3(-0.35, 0.7, -2.0), Vector3(0.25, 0, 0)), Vector3(0.08, 0.08, 1.8), wood)
	if not broken:
		for i in 3:
			k.box(base * MeshKit.at(Vector3(rng.randf_range(-0.4, 0.4), 1.25, -0.8 + i * 0.7)), Vector3(0.5, 0.5, 0.5), Color(0.7, 0.55, 0.35))
	return [[_box(Vector3(1.8, 1.3, 2.7)), base * MeshKit.at(Vector3(0, 0.75, 0))]]


static func _bridge(k: MeshKit, rng: RandomNumberGenerator, d: Dictionary) -> Array:
	var width: float = d.get("width", 4.0)
	var wood := Color(0.58, 0.42, 0.26)
	for i in 5:
		k.box(MeshKit.rot(Vector3(0, 0.0, -0.84 + i * 0.42), Vector3(0, 0, rng.randf_range(-0.03, 0.03))), Vector3(width, 0.14, 0.38), wood.darkened(rng.randf() * 0.12))
	for sx in [-1.0, 1.0]:
		k.box(MeshKit.at(Vector3(sx * width * 0.5, -0.6, 0)), Vector3(0.22, 1.6, 0.22), wood.darkened(0.3))
		k.box(MeshKit.at(Vector3(sx * width * 0.5, 0.55, 0)), Vector3(0.16, 1.0, 0.16), wood.darkened(0.15))
		k.box(MeshKit.at(Vector3(sx * width * 0.5, 0.95, 0)), Vector3(0.1, 0.1, 2.2), wood)
	return [
		[_box(Vector3(width, 0.2, 2.2)), Transform3D()],
		[_box(Vector3(0.2, 1.0, 2.2)), MeshKit.at(Vector3(-width * 0.5, 0.5, 0))],
		[_box(Vector3(0.2, 1.0, 2.2)), MeshKit.at(Vector3(width * 0.5, 0.5, 0))],
	]


static func _signpost(k: MeshKit) -> Array:
	var wood := Color(0.55, 0.4, 0.25)
	k.box(MeshKit.at(Vector3(0, 1.2, 0)), Vector3(0.15, 2.4, 0.15), wood.darkened(0.2))
	k.box(MeshKit.at(Vector3(0, 2.05, -0.2)), Vector3(0.1, 0.45, 1.3), wood)
	k.prism(MeshKit.rot(Vector3(0, 2.05, -0.95), Vector3(PI * 0.5, 0, 0)), Vector3(0.1, 0.3, 0.45), wood)
	return [[_box(Vector3(0.2, 2.4, 0.2)), MeshKit.at(Vector3(0, 1.2, 0))]]


static func _dungeon_entrance(k: MeshKit, rng: RandomNumberGenerator) -> Array:
	var rock := Color(0.5, 0.48, 0.46)
	for i in 7:
		var a := PI * 0.15 + PI * 0.7 * i / 6.0
		var p := Vector3(cos(a) * 3.4, 0.6, sin(a) * 2.6 + 1.2)
		k.sphere(MeshKit.at(p, rng.randf() * 3.0, Vector3(1.0, rng.randf_range(0.9, 1.5), 1.0)), rng.randf_range(1.6, 2.4), rock.darkened(rng.randf() * 0.15), 7, 5)
	k.sphere(MeshKit.at(Vector3(0, 2.2, 2.4), 0, Vector3(1.5, 1.0, 1.2)), 2.8, rock, 8, 5)
	var arch := Color(0.62, 0.6, 0.56)
	for sx in [-1.0, 1.0]:
		k.box(MeshKit.at(Vector3(sx * 1.3, 1.4, -0.8)), Vector3(0.7, 2.8, 0.7), arch)
	k.box(MeshKit.at(Vector3(0, 3.0, -0.8)), Vector3(3.4, 0.7, 0.8), arch)
	k.box(MeshKit.at(Vector3(0, 1.35, -0.45)), Vector3(1.9, 2.7, 0.2), Color(0.04, 0.03, 0.05))
	k.box(MeshKit.at(Vector3(0, 0.05, -1.4)), Vector3(2.2, 0.1, 1.4), arch.darkened(0.2))
	for i in 3:
		k.sphere(MeshKit.at(Vector3(rng.randf_range(-2.5, 2.5), 3.8 + rng.randf(), rng.randf_range(0.5, 2.5)), 0, Vector3(1, 0.4, 1)), 0.8, Color(0.35, 0.55, 0.28), 6, 4)
	return [[_box(Vector3(6.5, 4.5, 4.5)), MeshKit.at(Vector3(0, 2.0, 1.6))]]


static func _standing_stones(k: MeshKit, rng: RandomNumberGenerator) -> Array:
	var shapes := []
	var n := 7
	for i in n:
		var a := TAU * i / n
		var p := Vector3(cos(a), 0, sin(a)) * 5.0
		var fallen := i == 3
		var hh := rng.randf_range(2.6, 3.8)
		var xf: Transform3D
		if fallen:
			xf = Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, PI * 0.5), p + Vector3(0, 0.45, 0))
		else:
			xf = Transform3D(Basis(Vector3.UP, a + PI * 0.5) * Basis(Vector3.FORWARD, rng.randf_range(-0.12, 0.12)), p + Vector3(0, hh * 0.5 - 0.2, 0))
		k.box(xf, Vector3(1.1, hh, 0.8), Color(0.6, 0.6, 0.62).darkened(rng.randf() * 0.15))
		k.box(xf * MeshKit.at(Vector3(0, hh * 0.3, -0.41)), Vector3(0.5, 0.5, 0.02), Color(0.4, 0.7, 0.9))
		shapes.append([_box(Vector3(1.1, hh, 0.8)), xf])
	k.box(MeshKit.at(Vector3(0, 0.4, 0)), Vector3(2.0, 0.8, 1.2), Color(0.55, 0.55, 0.57))
	shapes.append([_box(Vector3(2.0, 0.8, 1.2)), MeshKit.at(Vector3(0, 0.4, 0))])
	return shapes


static func _ruined_tower(k: MeshKit, rng: RandomNumberGenerator) -> Array:
	var stone := Color(0.62, 0.6, 0.56)
	var tilt := Transform3D(Basis(Vector3.FORWARD, 0.08), Vector3.ZERO)
	k.cylinder(tilt * MeshKit.at(Vector3(0, 4.5, 0)), 3.0, 2.6, 10.0, stone, 10)
	k.cylinder(tilt * MeshKit.at(Vector3(0.6, 10.2, 0.3)), 2.6, 2.3, 1.4, stone.darkened(0.1), 7)
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		k.box(tilt * Transform3D(Basis(Vector3.UP, -a + PI * 0.5), Vector3(cos(a) * 2.75, 3.0 + i * 1.8, sin(a) * 2.75)), Vector3(0.6, 1.0, 0.2), DARK)
	k.box(MeshKit.at(Vector3(0, 1.0, -2.9)), Vector3(1.3, 2.0, 0.3), DARK)
	for i in 8:
		k.sphere(MeshKit.at(Vector3(rng.randf_range(-5, 5), 0.3, rng.randf_range(-5, 5)), rng.randf() * 3.0, Vector3(1, 0.7, 1)), rng.randf_range(0.3, 0.7), stone.darkened(0.1), 6, 4)
	for i in 3:
		k.sphere(MeshKit.at(Vector3(rng.randf_range(-2, 2), rng.randf_range(4, 9), -2.6), 0, Vector3(1, 0.6, 0.6)), 0.6, Color(0.35, 0.55, 0.28), 6, 4)
	return [[_cyl_shape(3.0, 11.0), MeshKit.at(Vector3(0, 5.0, 0))]]


static func _giant_tree(k: MeshKit, rng: RandomNumberGenerator) -> Array:
	var bark := Color(0.45, 0.32, 0.2)
	k.cylinder(MeshKit.at(Vector3(0, 5.0, 0)), 2.2, 1.4, 10.0, bark, 9)
	for i in 6:
		var a := TAU * i / 6.0 + rng.randf() * 0.4
		k.cone_between(Vector3(cos(a) * 1.2, 1.0, sin(a) * 1.2), Vector3(cos(a) * 3.6, -0.1, sin(a) * 3.6), 0.7, 0.2, bark.darkened(0.1), 6)
	for i in 3:
		var a := TAU * i / 3.0
		k.cylinder_between(Vector3(0, 8.0, 0), Vector3(cos(a) * 4.0, 11.0, sin(a) * 4.0), 0.5, bark, 6)
	var greens := [Color(0.3, 0.6, 0.25), Color(0.36, 0.66, 0.28), Color(0.26, 0.54, 0.24)]
	for i in 9:
		var p := Vector3(rng.randf_range(-5, 5), rng.randf_range(11, 15), rng.randf_range(-5, 5))
		k.sphere(MeshKit.at(p, rng.randf() * 3.0, Vector3(1, 0.8, 1)), rng.randf_range(3.0, 4.2), greens[i % 3], 8, 5)
	return [[_cyl_shape(2.2, 10.0), MeshKit.at(Vector3(0, 5.0, 0))]]


static func _notice_board(k: MeshKit) -> Array:
	var wood := Color(0.5, 0.36, 0.22)
	for sx in [-0.8, 0.8]:
		k.box(MeshKit.at(Vector3(sx, 1.1, 0)), Vector3(0.14, 2.2, 0.14), wood.darkened(0.2))
	k.box(MeshKit.at(Vector3(0, 1.5, 0)), Vector3(1.8, 1.1, 0.1), wood)
	k.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 2.15, 0)), Vector3(0.6, 0.35, 2.1), Color(0.6, 0.25, 0.18))
	var cols := [Color(0.98, 0.96, 0.85), Color(0.95, 0.9, 0.7), Color(0.9, 0.95, 1.0)]
	for i in 5:
		k.box(MeshKit.rot(Vector3(-0.6 + (i % 3) * 0.6, 1.25 + (i / 3) * 0.45, -0.07), Vector3(0, 0, (i - 2) * 0.06)), Vector3(0.38, 0.32, 0.02), cols[i % 3])
	return [[_box(Vector3(1.8, 2.2, 0.3)), MeshKit.at(Vector3(0, 1.1, 0))]]


# ===========================================================================
# Extras (lights, labels, moving parts) — added per instance
# ===========================================================================

static func _extras(root: Node3D, piece: String, data: Dictionary) -> void:
	match piece:
		"campfire":
			var flame := MeshInstance3D.new()
			var k := MeshKit.new(2, 0.0)
			k.cylinder(MeshKit.at(Vector3(0, 0.55, 0)), 0.35, 0.0, 0.9, Color(1.0, 0.55, 0.15), 6)
			k.cylinder(MeshKit.at(Vector3(0, 0.5, 0)), 0.2, 0.0, 0.6, Color(1.0, 0.9, 0.4), 5)
			flame.mesh = k.commit()
			flame.material_override = Mats.color(Color(1.0, 0.65, 0.2), 2.5)
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(flame)
			var light := FlickerLight.new()
			light.position = Vector3(0, 1.0, 0)
			light.light_color = Color(1.0, 0.6, 0.3)
			light.omni_range = 9.0
			light.light_energy = 1.6
			root.add_child(light)
		"lamp_post":
			if data.get("lit", false):
				var l := OmniLight3D.new()
				l.position = Vector3(0, 3.1, 0)
				l.light_color = Color(1.0, 0.8, 0.5)
				l.omni_range = 7.0
				l.light_energy = 0.8
				l.distance_fade_enabled = true
				l.distance_fade_begin = 50.0
				l.distance_fade_length = 20.0
				root.add_child(l)
		"blacksmith":
			var l := FlickerLight.new()
			var half: Vector2 = data.get("half", Vector2(3.6, 3.0))
			l.position = Vector3(-half.x * 0.5, 1.6, -half.y * 2.0 * 0.5 + 1.2)
			l.light_color = Color(1.0, 0.5, 0.2)
			l.omni_range = 6.0
			l.light_energy = 1.4
			root.add_child(l)
		"windmill":
			var blades := Spinner.new()
			blades.position = Vector3(0, 7.6, -2.1)
			blades.axis = Vector3.BACK
			blades.speed = 0.6
			var mi := Mats.instance(windmill_blades())
			blades.add_child(mi)
			root.add_child(blades)
		"signpost":
			var label := Label3D.new()
			label.text = data.get("text", "")
			label.position = Vector3(0, 2.75, 0)
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.font_size = 48
			label.pixel_size = 0.006
			label.outline_size = 10
			label.modulate = Color(1, 0.95, 0.8) if float(data.get("danger", 0.0)) < 0.5 else Color(1, 0.6, 0.5)
			label.visibility_range_end = 40.0
			root.add_child(label)
		"dungeon_entrance":
			for sx in [-1.0, 1.0]:
				var t := FlickerLight.new()
				t.position = Vector3(sx * 1.3, 2.4, -1.4)
				t.light_color = Color(1.0, 0.6, 0.3)
				t.omni_range = 5.0
				t.light_energy = 1.2
				root.add_child(t)
				var fl := MeshInstance3D.new()
				var fk := MeshKit.new(3, 0.0)
				fk.cylinder(Transform3D(), 0.12, 0.0, 0.35, Color(1, 0.6, 0.2), 5)
				fl.mesh = fk.commit()
				fl.material_override = Mats.color(Color(1, 0.6, 0.2), 3.0)
				fl.position = Vector3(sx * 1.3, 2.3, -1.25)
				root.add_child(fl)
