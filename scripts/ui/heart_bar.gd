class_name HeartBar
extends Control
## Health as chunky little hearts (drawn, so no font glyphs needed).

var hp := 6
var max_hp := 6
var _bump := 0.0


func set_hp(v: int, mx: int) -> void:
	if v < hp:
		_bump = 1.0
	hp = v
	max_hp = mx
	queue_redraw()


func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = maxf(0.0, _bump - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	var hearts := int(ceil(max_hp / 2.0))
	for i in hearts:
		var c := Vector2(14 + i * 26, 12)
		var s := 1.0 + _bump * 0.25 * float(i == int(hp / 2.0))
		var fill := clampi(hp - i * 2, 0, 2)
		_heart(c, 9.0 * s, Color(0.25, 0.1, 0.1))
		if fill == 2:
			_heart(c, 7.5 * s, Color(0.95, 0.25, 0.3))
		elif fill == 1:
			_heart(c, 7.5 * s, Color(0.95, 0.25, 0.3), true)


func _heart(c: Vector2, r: float, col: Color, half := false) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		var p := c + Vector2(x, y) * (r / 16.0)
		if half and p.x > c.x:
			p.x = c.x
		pts.append(p)
	draw_colored_polygon(pts, col)
