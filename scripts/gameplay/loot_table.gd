class_name LootTable
extends RefCounted
## Procedural loot. Chest contents are rolled at world-generation time from
## the biome's loot weights, so a seed always hides the same treasure.
## Trinkets tweak the goblin's movement stats — loot that changes how you move.

const TRINKETS := {
	"sticky_socks": {"name": "Sticky Socks", "desc": "+40% stability", "stability": 1.4},
	"feather_cap": {"name": "Feather in Cap", "desc": "+15% jump", "jump": 1.15},
	"greased_boots": {"name": "Greased Boots", "desc": "+12% speed, -15% stability", "speed": 1.12, "stability": 0.85},
	"strong_back": {"name": "Strong-Back Belt", "desc": "+50% carry capacity", "carry": 1.5},
}


static func trinket_ids() -> Array:
	var k := TRINKETS.keys()
	k.sort()
	return k


static func roll_chest(rng: RandomNumberGenerator, biome: BiomeDef, tier: int) -> Dictionary:
	var out := {"gold": rng.randi_range(5, 12) * tier, "potions": 0, "item": ""}
	for i in tier:
		match WorldRng.pick_weighted(rng, biome.loot):
			"gold":
				out["gold"] += rng.randi_range(6, 15) * tier
			"potion":
				out["potions"] += 1
			"trinket":
				if out["item"] == "":
					out["item"] = Items.roll(rng, ["common", "good", "rare"][clampi(tier - 1, 0, 2)])
	if out["item"] == "" and tier >= 2 and rng.randf() < 0.6:
		out["item"] = Items.roll(rng, "common" if tier == 2 else "good")
	return out
