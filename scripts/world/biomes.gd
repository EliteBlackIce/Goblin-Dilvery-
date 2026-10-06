class_name Biomes
extends RefCounted
## Biome registry. Only GREEN FIELDS is implemented for the first vertical
## slice (per the generation roadmap); the others are listed so the pipeline's
## "biome selection" stage already works with weights and can grow by data.

const ROADMAP := ["green_fields", "dark_forest", "swamp", "mountains", "desert", "snow", "haunted_lands", "goblin_lands", "kingdom"]

static var _cache := {}


static func get_biome(id: String) -> BiomeDef:
	if not _cache.has(id):
		var custom := "res://assets/biomes/%s.tres" % id
		if ResourceLoader.exists(custom):
			_cache[id] = load(custom)  # edit colours/tables in the Inspector
		else:
			_cache[id] = _green_fields()
	return _cache[id]


## Biome selection stage. With one biome implemented this always returns
## Green Fields, but it is already seed-driven and weight-based.
static func select(rng: RandomNumberGenerator) -> BiomeDef:
	var available := {"green_fields": 1.0}
	return get_biome(WorldRng.pick_weighted(rng, available))


static func _green_fields() -> BiomeDef:
	var b := BiomeDef.new()
	b.id = "green_fields"
	b.display_name = "Green Fields"
	b.hill_height = 15.0
	b.plaza = Color(0.6, 0.53, 0.43)
	b.road = Color(0.66, 0.53, 0.36)
	b.forest_coverage = 0.33
	b.music = "green_fields_theme"
	b.weather = {"clear": 4, "breezy": 2, "drizzle": 1}
	b.tree_kinds = {"oak": 5, "pine": 2, "birch": 2}
	b.enemies = {"boar": 3, "bandit": 2}
	b.dungeon_enemies = {"bandit": 3, "rat": 4}
	b.village_personalities = {"cozy": 3, "wealthy": 2, "goblin": 2}
	b.hamlet_personalities = {"farm": 3, "abandoned": 2, "bandit": 2, "cozy": 1}
	b.packages = {"small": 6, "heavy": 3, "fragile": 3, "huge": 2, "unstable": 2, "living": 2, "magical": 2, "explosive": 1, "valuable": 1, "cursed": 1}
	b.events = {"bandit_ambush": 3, "traveling_merchant": 3, "lost_package": 3, "broken_cart": 2, "rival_courier": 2, "stranded_villager": 3}
	b.loot = {"gold": 60, "potion": 25, "trinket": 15}
	b.landmarks = ["standing_stones", "ruined_tower", "giant_tree"]
	b.dungeon_theme = {
		"floor": Color(0.48, 0.47, 0.45), "wall": Color(0.4, 0.4, 0.43), "accent": Color(0.33, 0.5, 0.26),
		"light": Color(1.0, 0.7, 0.4), "ambient": Color(0.42, 0.38, 0.4),
	}
	b.secrets = ["cracked_wall_room", "landmark_cache"]
	return b
