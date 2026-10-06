class_name MapView
extends Control
## Courier's map: terrain + roads (pre-rendered texture), settlements, the
## dungeon, your deliveries' destinations and you. Used both as the corner
## minimap (follows the player) and the full-screen map (whole region).

var world: WorldData
var world_node: World
var player: Goblin
var follow := true
var meters_per_px := 1.2
var _tex: ImageTexture
const ICONS := {"village": Color(1, 0.85, 0.3), "hamlet": Color(0.95, 0.75, 0.45), "dungeon": Color(0.6, 0.3, 0.8),
	"camp": Color(0.9, 0.25, 0.2), "landmark": Color(0.7, 0.85, 1.0)}


func set_world(w: WorldData, p: Goblin, wn: World) -> void:
	world = w
	world_node = wn
	player = p
	var step := 2
	var n := WorldData.SIZE / step
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var b := w.biome
	for z in n:
		for x in n:
			var wx := x * step
			var wz := z * step
			var hh := w.h(wx, wz)
			var col: Color
			if hh < w.water_level:
				col = Color(0.35, 0.6, 0.85)
			else:
				match w.ground[w.idx(wx, wz)]:
					WorldData.Ground.ROAD: col = Color(0.9, 0.8, 0.6)
					WorldData.Ground.TRAIL: col = Color(0.78, 0.66, 0.48)
					WorldData.Ground.SHORTCUT: col = Color(0.85, 0.4, 0.35)
					WorldData.Ground.PLAZA: col = Color(0.85, 0.8, 0.7)
					WorldData.Ground.FIELD: col = b.field_a
					WorldData.Ground.FOREST: col = b.forest_floor.darkened(0.1)
					_: col = b.grass_a
				col = col * clampf(0.8 + (hh - 6.0) * 0.012 + (w.h(wx + step, wz) - hh) * 0.2, 0.5, 1.25)
			col.a = 1.0
			img.set_pixel(x, z, col)
	_tex = ImageTexture.create_from_image(img)
	queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _to_map(p: Vector3, center: Vector2) -> Vector2:
	return (Vector2(p.x, p.z) - center) / meters_per_px + size * 0.5


func _draw() -> void:
	if world == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.12, 0.1, 0.85))
	var center := Vector2(WorldData.SIZE * 0.5, WorldData.SIZE * 0.5)
	if follow and player:
		center = Vector2(player.global_position.x, player.global_position.z)
		if world_node and world_node.in_dungeon:
			var site: Dictionary = world.site("dungeon_0")
			center = Vector2(site["pos"].x, site["pos"].z)
	else:
		meters_per_px = WorldData.SIZE / minf(size.x, size.y) * 1.02
	var origin := _to_map(Vector3.ZERO, center)
	var full := Vector2(WorldData.SIZE, WorldData.SIZE) / meters_per_px
	draw_set_transform(Vector2.ZERO)
	# Clip by drawing the texture region that's visible.
	var tex_rect := Rect2(origin, full)
	var vis := tex_rect.intersection(Rect2(Vector2.ZERO, size))
	if vis.size.x > 0 and vis.size.y > 0:
		var src_pos := (vis.position - origin) / full * Vector2(_tex.get_width(), _tex.get_height())
		var src_size := vis.size / full * Vector2(_tex.get_width(), _tex.get_height())
		draw_texture_rect_region(_tex, vis, Rect2(src_pos, src_size))

	var font := get_theme_default_font()
	var targets := {}
	for j in GameState.carried_jobs():
		targets[j["to"]] = true
	for s in world.sites:
		var mp := _to_map(s["pos"], center)
		if not Rect2(Vector2.ZERO, size).grow(-4).has_point(mp):
			continue
		var c: Color = ICONS.get(s["kind"], Color.WHITE)
		var r := 5.0 if s["kind"] == "village" else 4.0
		draw_circle(mp, r + 1.5, Color(0, 0, 0, 0.7))
		draw_circle(mp, r, c)
		if targets.has(s["id"]):
			var pulse := 8.0 + sin(Time.get_ticks_msec() / 150.0) * 2.0
			draw_arc(mp, pulse, 0, TAU, 20, Color(1, 0.9, 0.2), 2.0)
		if not follow or s["kind"] == "village":
			var label: String = s["name"]
			if s["kind"] == "village":
				label += " (Post Office)"
			draw_string(font, mp + Vector2(8, 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13 if not follow else 11, Color(1, 1, 1, 0.95))
	if player:
		var pp := player.global_position
		if world_node and world_node.in_dungeon:
			pp = world.site("dungeon_0")["pos"]
		var mp := _to_map(pp, center)
		var yaw := player.facing_yaw
		var fwd := Vector2(-sin(yaw), -cos(yaw))
		var right := Vector2(-fwd.y, fwd.x)
		var pts := PackedVector2Array([mp + fwd * 8.0, mp - fwd * 5.0 + right * 5.0, mp - fwd * 2.5, mp - fwd * 5.0 - right * 5.0])
		draw_colored_polygon(pts, Color(0.2, 0.9, 0.3))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0, 0, 0), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.05), false, 2.0)
	if follow:
		draw_string(font, Vector2(6, 14), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.8))
