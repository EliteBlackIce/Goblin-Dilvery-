class_name Mats
extends RefCounted
## Shared material cache. Almost everything renders with the single
## vertex-colour material, so the whole world is a handful of materials.

static var _cache := {}


## Stylised lit material that takes albedo from vertex colours.
static func vertex(toon := true) -> StandardMaterial3D:
	var key := "vertex_%s" % toon
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if toon:
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.rim_enabled = true
			m.rim = 0.25
			m.rim_tint = 0.6
		_cache[key] = m
	return _cache[key]


## Flat colour, optionally glowing (magic packages, torches, explosions).
static func color(c: Color, emission := 0.0, transparent := false) -> StandardMaterial3D:
	var key := "c_%s_%s_%s" % [c.to_html(), emission, transparent]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		if emission > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emission
		if transparent or c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache[key] = m
	return _cache[key]


static func unshaded(c: Color) -> StandardMaterial3D:
	var key := "u_%s" % c.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if c.a < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cache[key] = m
	return _cache[key]


## Convenience: MeshInstance3D for a MeshKit mesh with the shared material.
static func instance(mesh: Mesh, toon := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = vertex(toon)
	return mi
