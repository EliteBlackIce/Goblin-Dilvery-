class_name MeshKit
extends RefCounted
## Tiny "modelling kit" that builds chunky, flat-shaded, vertex-coloured meshes
## out of primitives (boxes, low-poly spheres, cylinders/cones, roof prisms).
##
## Every handcrafted piece in the game (buildings, trees, props, characters) is
## authored with this kit. Because colour lives in the vertices, an entire
## building is ONE mesh with ONE shared material — one draw call — which keeps
## procedurally assembled villages cheap to render.
##
## Faces get a small deterministic brightness jitter for a hand-painted look.

var st := SurfaceTool.new()
var jitter := 0.04
var _rng := RandomNumberGenerator.new()
var _verts := 0


func _init(seed_value := 1, color_jitter := 0.04) -> void:
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_rng.seed = seed_value
	jitter = color_jitter


func is_empty() -> bool:
	return _verts == 0


## Appends another MeshKit-built mesh (surface 0) with a transform.
func append(mesh: ArrayMesh, xf := Transform3D()) -> void:
	if mesh.get_surface_count() == 0:
		return
	st.append_from(mesh, 0, xf)
	_verts += mesh.surface_get_array_len(0)


func commit() -> ArrayMesh:
	if _verts == 0:
		return ArrayMesh.new()
	return st.commit()


# ---------------------------------------------------------------------------
# Low level
# ---------------------------------------------------------------------------

func face_color(c: Color) -> Color:
	if jitter <= 0.0:
		return c
	var j := _rng.randf_range(-jitter, jitter)
	return Color(clampf(c.r + j, 0.0, 1.0), clampf(c.g + j, 0.0, 1.0), clampf(c.b + j, 0.0, 1.0), c.a)


## Adds one triangle. `outward` is any vector pointing roughly away from the
## solid; winding is fixed up so the face is front-facing from that side
## (Godot treats clockwise triangles as front faces).
func tri(a: Vector3, b: Vector3, c: Vector3, color: Color, outward: Vector3) -> void:
	var cr := (b - a).cross(c - a)
	if cr.length_squared() < 1e-12:
		return
	if cr.dot(outward) > 0.0:
		var t := b
		b = c
		c = t
		cr = -cr
	var n := -cr.normalized()
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(color)
	st.add_vertex(c)
	_verts += 3


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color, outward: Vector3) -> void:
	var fc := face_color(color)
	tri(a, b, c, fc, outward)
	tri(a, c, d, fc, outward)


# ---------------------------------------------------------------------------
# Primitives. All take a Transform3D placing the primitive's local space.
# ---------------------------------------------------------------------------

## Box centred on the transform origin.
func box(xf: Transform3D, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var p := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces := [
		[[0, 1, 2, 3], Vector3.DOWN], [[4, 5, 6, 7], Vector3.UP],
		[[0, 1, 5, 4], Vector3.FORWARD], [[3, 2, 6, 7], Vector3.BACK],
		[[0, 3, 7, 4], Vector3.LEFT], [[1, 2, 6, 5], Vector3.RIGHT],
	]
	for f in faces:
		var idx: Array = f[0]
		quad(xf * p[idx[0]], xf * p[idx[1]], xf * p[idx[2]], xf * p[idx[3]], color, xf.basis * f[1])


## Box whose bottom face sits on the transform origin (handy for walls/posts).
func box_base(xf: Transform3D, size: Vector3, color: Color) -> void:
	box(xf * Transform3D(Basis(), Vector3(0, size.y * 0.5, 0)), size, color)


## Low-poly sphere. Non-uniform scale via the transform gives blobs/eggs.
func sphere(xf: Transform3D, radius: float, color: Color, segs := 8, rings := 5) -> void:
	var pts := []
	for r in range(rings + 1):
		var phi := PI * float(r) / float(rings)
		var row := []
		for s in range(segs):
			var th := TAU * float(s) / float(segs)
			row.append(Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * radius)
		pts.append(row)
	for r in range(rings):
		for s in range(segs):
			var s2 := (s + 1) % segs
			var a: Vector3 = pts[r][s]
			var b: Vector3 = pts[r][s2]
			var c: Vector3 = pts[r + 1][s2]
			var d: Vector3 = pts[r + 1][s]
			var mid := (a + b + c + d) * 0.25
			if r == 0:
				tri(xf * a, xf * c, xf * d, face_color(color), xf.basis * mid)
			elif r == rings - 1:
				tri(xf * a, xf * b, xf * c, face_color(color), xf.basis * mid)
			else:
				quad(xf * a, xf * b, xf * c, xf * d, color, xf.basis * mid)


## Cylinder/cone centred on origin along local Y. r_top = 0 makes a cone.
func cylinder(xf: Transform3D, r_bottom: float, r_top: float, height: float, color: Color, segs := 8, caps := true) -> void:
	var hy := height * 0.5
	var bot := []
	var top := []
	for s in range(segs):
		var th := TAU * float(s) / float(segs)
		var dir := Vector3(cos(th), 0, sin(th))
		bot.append(dir * r_bottom + Vector3(0, -hy, 0))
		top.append(dir * r_top + Vector3(0, hy, 0))
	for s in range(segs):
		var s2 := (s + 1) % segs
		var mid: Vector3 = (bot[s] + bot[s2] + top[s] + top[s2]) * 0.25
		var out := Vector3(mid.x, 0, mid.z)
		if r_top <= 0.0001:
			tri(xf * bot[s], xf * bot[s2], xf * top[s], face_color(color), xf.basis * out)
		elif r_bottom <= 0.0001:
			tri(xf * bot[s], xf * top[s2], xf * top[s], face_color(color), xf.basis * out)
		else:
			quad(xf * bot[s], xf * bot[s2], xf * top[s2], xf * top[s], color, xf.basis * out)
	if caps:
		var cb := face_color(color)
		var ct := face_color(color)
		for s in range(1, segs - 1):
			if r_bottom > 0.0001:
				tri(xf * bot[0], xf * bot[s], xf * bot[s + 1], cb, xf.basis * Vector3.DOWN)
			if r_top > 0.0001:
				tri(xf * top[0], xf * top[s], xf * top[s + 1], ct, xf.basis * Vector3.UP)


## Cylinder from point a to point b — for limbs, beams, ropes.
func cylinder_between(a: Vector3, b: Vector3, radius: float, color: Color, segs := 6) -> void:
	cone_between(a, b, radius, radius, color, segs)


## Tapered cylinder/cone from a to b. `flatten` squashes it sideways (ears!).
func cone_between(a: Vector3, b: Vector3, r_a: float, r_b: float, color: Color, segs := 6, flatten := 1.0) -> void:
	var dir := b - a
	var length := dir.length()
	if length < 0.0001:
		return
	var y := dir / length
	var ref := Vector3.UP if absf(y.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
	var z := y.cross(ref).normalized()
	var x := y.cross(z).normalized()
	var basis := Basis(x, y, z * flatten)
	cylinder(Transform3D(basis, (a + b) * 0.5), r_a, r_b, length, color, segs)


## Triangular roof prism: base width size.x, ridge height size.y, length size.z.
## Base sits on the origin; ridge runs along local Z.
func prism(xf: Transform3D, size: Vector3, color: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var l0 := Vector3(-hx, 0, -hz)
	var r0 := Vector3(hx, 0, -hz)
	var t0 := Vector3(0, size.y, -hz)
	var l1 := Vector3(-hx, 0, hz)
	var r1 := Vector3(hx, 0, hz)
	var t1 := Vector3(0, size.y, hz)
	var c := Vector3(0, size.y / 3.0, 0)
	quad(xf * l0, xf * t0, xf * t1, xf * l1, color, xf.basis * ((l0 + t0 + t1 + l1) * 0.25 - c))
	quad(xf * r0, xf * t0, xf * t1, xf * r1, color, xf.basis * ((r0 + t0 + t1 + r1) * 0.25 - c))
	tri(xf * l0, xf * r0, xf * t0, face_color(color), xf.basis * Vector3.FORWARD)
	tri(xf * l1, xf * r1, xf * t1, face_color(color), xf.basis * Vector3.BACK)
	quad(xf * l0, xf * r0, xf * r1, xf * l1, color, xf.basis * Vector3.DOWN)


## Pyramid (4-sided cone) with square base on origin.
func pyramid(xf: Transform3D, base: float, height: float, color: Color) -> void:
	var h := base * 0.5
	var p := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	var apex := Vector3(0, height, 0)
	for i in range(4):
		var a: Vector3 = p[i]
		var b: Vector3 = p[(i + 1) % 4]
		var mid := (a + b) * 0.5
		tri(xf * a, xf * b, xf * apex, face_color(color), xf.basis * Vector3(mid.x, 0.2, mid.z))
	quad(xf * p[0], xf * p[1], xf * p[2], xf * p[3], color, xf.basis * Vector3.DOWN)


# ---------------------------------------------------------------------------
# Transform helpers
# ---------------------------------------------------------------------------

static func at(pos: Vector3, yaw := 0.0, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), pos)


static func rot(pos: Vector3, euler: Vector3, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(euler) * Basis.from_scale(scale), pos)
