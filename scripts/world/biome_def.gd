class_name BiomeDef
extends Resource
## Everything that makes a biome feel distinct, as data. The generator reads
## these tables; adding a biome means adding a BiomeDef (see Biomes), not
## writing new generation code.

@export var id := ""
@export var display_name := ""

@export_group("Terrain look")
@export var grass_a := Color(0.45, 0.72, 0.3)
@export var grass_b := Color(0.55, 0.78, 0.32)
@export var forest_floor := Color(0.3, 0.52, 0.24)
@export var road := Color(0.72, 0.6, 0.42)
@export var trail := Color(0.6, 0.5, 0.36)
@export var plaza := Color(0.68, 0.62, 0.52)
@export var field_a := Color(0.78, 0.68, 0.3)
@export var field_b := Color(0.55, 0.45, 0.25)
@export var sand := Color(0.86, 0.8, 0.58)
@export var rock := Color(0.55, 0.53, 0.5)
@export var cliff := Color(0.62, 0.5, 0.38)
@export var water := Color(0.25, 0.55, 0.8, 0.8)

@export_group("Terrain shape")
@export var hill_height := 14.0
@export var forest_coverage := 0.35
@export var terrace_strength := 0.45

@export_group("Atmosphere")
@export var sky_top := Color(0.35, 0.6, 0.92)
@export var sky_horizon := Color(0.75, 0.88, 0.98)
@export var fog_color := Color(0.75, 0.86, 0.95)
@export var sun_color := Color(1.0, 0.93, 0.8)
@export var ambient := Color(0.6, 0.68, 0.8)
@export var music := ""
@export var weather := {}

@export_group("Content tables (weights)")
@export var tree_kinds := {}
@export var enemies := {}
@export var dungeon_enemies := {}
@export var village_personalities := {}
@export var hamlet_personalities := {}
@export var packages := {}
@export var events := {}
@export var loot := {}
@export var landmarks: Array[String] = []
@export var dungeon_theme := {}
@export var secrets: Array[String] = []
