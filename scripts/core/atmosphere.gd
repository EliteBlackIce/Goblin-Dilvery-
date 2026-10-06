class_name Atmosphere
extends RefCounted
## Shared stylised lighting setup: bright readable sky, warm sun with crisp
## shadows, soft sky ambient, light fog for depth, filmic tonemap, a touch of
## glow and saturation.


static func create(parent: Node, biome: BiomeDef) -> Dictionary:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = biome.sky_top
	sky_mat.sky_horizon_color = biome.sky_horizon
	sky_mat.ground_horizon_color = biome.sky_horizon
	sky_mat.ground_bottom_color = Color(0.35, 0.45, 0.35)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = biome.ambient
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 2.2
	env.fog_enabled = true
	env.fog_light_color = biome.fog_color
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.05
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = biome.sun_color
	sun.light_energy = 1.05
	sun.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(-38.0), 0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	return {"env": env, "sun": sun}
