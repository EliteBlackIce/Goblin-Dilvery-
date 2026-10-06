class_name Vegetation
extends RefCounted
## Chunky low-poly vegetation meshes (rendered with MultiMesh instancing).

static var _meshes := {}

const KINDS := ["oak", "oak2", "pine", "birch", "bush", "rock", "rock2", "grass", "flower_r", "flower_y", "flower_w", "mushroom"]


static func mesh(kind: String) -> ArrayMesh:
	if not _meshes.has(kind):
		_meshes[kind] = _build(kind)
	return _meshes[kind]


static func _build(kind: String) -> ArrayMesh:
	var k := MeshKit.new(kind.hash(), 0.05)
	var bark := Color(0.48, 0.33, 0.2)
	match kind:
		"oak", "oak2":
			var g := Color(0.33, 0.62, 0.26) if kind == "oak" else Color(0.42, 0.66, 0.24)
			k.cylinder(MeshKit.at(Vector3(0, 1.2, 0)), 0.32, 0.24, 2.4, bark, 6)
			k.cylinder_between(Vector3(0, 1.8, 0), Vector3(0.8, 2.6, 0.2), 0.12, bark, 5)
			k.sphere(MeshKit.at(Vector3(0, 3.3, 0), 0.3, Vector3(1, 0.85, 1)), 1.7, g, 7, 5)
			k.sphere(MeshKit.at(Vector3(0.9, 2.8, 0.3), 1.0, Vector3(1, 0.8, 1)), 1.15, g.darkened(0.08), 6, 4)
			k.sphere(MeshKit.at(Vector3(-0.7, 3.0, -0.5), 2.0, Vector3(1, 0.85, 1)), 1.2, g.lightened(0.06), 6, 4)
		"pine":
			var g := Color(0.2, 0.47, 0.3)
			k.cylinder(MeshKit.at(Vector3(0, 0.9, 0)), 0.26, 0.2, 1.8, bark.darkened(0.1), 6)
			for i in 3:
				var y := 1.6 + i * 1.25
				k.cylinder(MeshKit.at(Vector3(0, y + 0.8, 0), i * 0.5), 1.7 - i * 0.42, 0.0, 2.0, g.lightened(i * 0.05), 7)
		"birch":
			k.cylinder(MeshKit.at(Vector3(0, 1.8, 0)), 0.2, 0.15, 3.6, Color(0.92, 0.9, 0.85), 6)
			for i in 3:
				k.box(MeshKit.at(Vector3(0, 0.8 + i * 0.9, -0.18)), Vector3(0.18, 0.08, 0.04), Color(0.2, 0.2, 0.2))
			k.sphere(MeshKit.at(Vector3(0, 4.1, 0), 0, Vector3(0.85, 1.25, 0.85)), 1.3, Color(0.62, 0.78, 0.3), 7, 5)
		"bush":
			var g := Color(0.3, 0.58, 0.24)
			k.sphere(MeshKit.at(Vector3(0, 0.45, 0), 0, Vector3(1.2, 0.8, 1.0)), 0.7, g, 6, 4)
			k.sphere(MeshKit.at(Vector3(0.5, 0.35, 0.2)), 0.45, g.lightened(0.08), 6, 4)
			k.sphere(MeshKit.at(Vector3(0.2, 0.75, -0.3)), 0.12, Color(0.9, 0.2, 0.25), 4, 3)
			k.sphere(MeshKit.at(Vector3(-0.4, 0.65, 0.35)), 0.12, Color(0.9, 0.2, 0.25), 4, 3)
		"rock":
			k.sphere(MeshKit.at(Vector3(0, 0.3, 0), 0.4, Vector3(1.3, 0.8, 1.0)), 0.7, Color(0.6, 0.58, 0.56), 6, 4)
		"rock2":
			k.sphere(MeshKit.at(Vector3(0, 0.5, 0), 1.0, Vector3(1.0, 1.1, 0.9)), 1.0, Color(0.55, 0.54, 0.53), 6, 4)
			k.sphere(MeshKit.at(Vector3(0.9, 0.25, 0.3), 0.2, Vector3(1, 0.7, 1)), 0.5, Color(0.6, 0.58, 0.55), 5, 3)
			k.sphere(MeshKit.at(Vector3(-0.2, 1.05, -0.1), 0, Vector3(1.3, 0.3, 1.1)), 0.55, Color(0.38, 0.58, 0.28), 5, 3)
		"grass":
			var g := Color(0.45, 0.72, 0.28)
			for i in 4:
				var a := TAU * i / 4.0 + 0.4
				k.cylinder(MeshKit.rot(Vector3(cos(a) * 0.12, 0.22, sin(a) * 0.12), Vector3(cos(a) * 0.3, 0, sin(a) * 0.3)), 0.07, 0.0, 0.45, g.lightened(i * 0.04), 3, false)
		"flower_r", "flower_y", "flower_w":
			var c: Color = {"flower_r": Color(0.95, 0.3, 0.35), "flower_y": Color(1.0, 0.85, 0.25), "flower_w": Color(0.98, 0.97, 0.95)}[kind]
			for i in 3:
				var p := Vector3(cos(i * 2.1) * 0.25, 0, sin(i * 2.1) * 0.25)
				k.cylinder(MeshKit.at(p + Vector3(0, 0.18, 0)), 0.02, 0.02, 0.36, Color(0.35, 0.6, 0.25), 3, false)
				k.sphere(MeshKit.at(p + Vector3(0, 0.38, 0), 0, Vector3(1, 0.5, 1)), 0.09, c, 5, 3)
		"mushroom":
			k.cylinder(MeshKit.at(Vector3(0, 0.15, 0)), 0.06, 0.05, 0.3, Color(0.95, 0.92, 0.85), 5)
			k.sphere(MeshKit.at(Vector3(0, 0.32, 0), 0, Vector3(1, 0.55, 1)), 0.18, Color(0.85, 0.2, 0.15), 6, 3)
	return k.commit()
