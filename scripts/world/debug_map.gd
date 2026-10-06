class_name DebugMap
extends RefCounted
## Renders a WorldData to a top-down Image. Used by tests and handy when
## tuning the generator ("what does seed 123 look like?").

static func render(w: WorldData, scale := 2) -> Image:
	var n := WorldData.SIZE
	var img := Image.create(n * scale, n * scale, false, Image.FORMAT_RGB8)
	var b := w.biome
	for z in n:
		for x in n:
			var hh := w.h(x, z)
			var col: Color
			if hh < w.water_level:
				col = Color(b.water.r, b.water.g, b.water.b)
			else:
				match w.ground[w.idx(x, z)]:
					WorldData.Ground.ROAD: col = b.road
					WorldData.Ground.TRAIL: col = b.trail
					WorldData.Ground.SHORTCUT: col = Color(0.75, 0.35, 0.3)
					WorldData.Ground.PLAZA: col = b.plaza
					WorldData.Ground.FIELD: col = b.field_a
					WorldData.Ground.FOREST: col = b.forest_floor
					_: col = b.grass_a
				var shade := clampf(0.75 + (hh - 6.0) * 0.012 + (w.h(x + 1, z) - hh) * 0.25, 0.4, 1.3)
				col = col * shade
			img.fill_rect(Rect2i(x * scale, z * scale, scale, scale), col)
	for p in w.all_placements():
		var pc := Color.WHITE
		var size := 2
		match p["kind"]:
			"building": pc = Color(0.85, 0.3, 0.2); size = 4
			"npc": pc = Color(1, 1, 0.2)
			"enemy": pc = Color(0.9, 0, 0.9); size = 3
			"chest": pc = Color(1, 0.8, 0); size = 3
			"dungeon_entrance": pc = Color(0, 0, 0); size = 6
			_: continue
		var pp: Vector3 = p["pos"]
		img.fill_rect(Rect2i(int(pp.x * scale) - size / 2, int(pp.z * scale) - size / 2, size, size), pc)
	return img
