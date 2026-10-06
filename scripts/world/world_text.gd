class_name WorldText
extends RefCounted
## Name generators and flavour text. Everything that takes an rng is
## deterministic for a given world seed.

const PLACE_A := ["Mud", "Puddle", "Bramble", "Turnip", "Moss", "Wobble", "Crumb", "Goose", "Muddle", "Thistle",
	"Pickle", "Bog", "Honey", "Badger", "Copper", "Oaken", "Wonky", "Dumpling", "Sprocket", "Fern"]
const PLACE_B := ["brook", "ford", "bottom", "wick", "ton", "hollow", "stead", "field", "dale", "burrow",
	"by", "mere", "cross", "well", "knoll", "end", "shire", "hatch"]
const REGION_A := ["The Mumbling", "The Soggy", "The Lesser", "The Grumbling", "The Sleepy", "The Wobbly", "The Green", "The Forgotten"]
const REGION_B := ["Vale", "Downs", "Meadows", "Lowlands", "Hills", "Reach", "Shires", "Fields"]
const FIRST := ["Bramble", "Nettle", "Odo", "Hilda", "Gus", "Marigold", "Pip", "Wendel", "Agnes", "Barnaby", "Tilly",
	"Ludo", "Morwen", "Fennick", "Dot", "Humbert", "Ivy", "Grub", "Snaggle", "Ottoline", "Berta", "Cedric", "Winnie", "Mungo"]
const LAST := ["Puddlefoot", "Turnipseed", "Crumblewick", "Mossbottom", "Underbough", "Thistledown", "Gristle",
	"Applebarrow", "Fennel", "Hogswallow", "Pebblesworth", "Muddlecombe", "Quill", "Brambleback", "Sootwhistle"]
const GOBLIN_FIRST := ["Snik", "Grizzle", "Nob", "Skab", "Wort", "Ziggle", "Mok", "Flem", "Gak", "Rizzle", "Bogg"]
const GOBLIN_LAST := ["the Damp", "Toenail", "Mudgulper", "the Lesser", "Sniffwhistle", "Rattooth", "Knobbly"]
const DUNGEON_A := ["Grumbling", "Damp", "Forgotten", "Bottomless", "Moldy", "Echoing", "Stinky", "Old"]
const DUNGEON_B := ["Cellar", "Crypt", "Burrow", "Cave", "Tunnels", "Hole", "Vault"]
const LANDMARK := {
	"standing_stones": ["The Whispering Stones", "The Tipsy Stones", "Old Ring of Rocks"],
	"ruined_tower": ["The Leaning Tower", "Old Watchtower", "Crookback Tower"],
	"giant_tree": ["The Elder Oak", "Grandmother Tree", "The Big Tree (Official Name)"],
}

const TRIP_LINES := ["*trip*", "Oof!", "Who put a rock there?!", "Graceful.", "The ground attacked first.", "Whoopsie-daisy."]


static func pick(arr: Array) -> Variant:
	return arr[randi() % arr.size()]


static func pick_trip_line() -> String:
	return pick(TRIP_LINES)


static func place_name(rng: RandomNumberGenerator) -> String:
	return WorldRng.pick(rng, PLACE_A) + WorldRng.pick(rng, PLACE_B)


static func region_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [WorldRng.pick(rng, REGION_A), WorldRng.pick(rng, REGION_B)]


static func person_name(rng: RandomNumberGenerator, goblin := false) -> String:
	if goblin:
		return "%s %s" % [WorldRng.pick(rng, GOBLIN_FIRST), WorldRng.pick(rng, GOBLIN_LAST)]
	return "%s %s" % [WorldRng.pick(rng, FIRST), WorldRng.pick(rng, LAST)]


static func dungeon_name(rng: RandomNumberGenerator) -> String:
	return "The %s %s" % [WorldRng.pick(rng, DUNGEON_A), WorldRng.pick(rng, DUNGEON_B)]


static func landmark_name(rng: RandomNumberGenerator, kind: String) -> String:
	return WorldRng.pick(rng, LANDMARK.get(kind, ["The Thing"]))


## Villager small-talk, flavoured by settlement personality. This is the hook
## where AI-voiced dialogue would plug in later (same inputs, richer output).
static func villager_line(personality: String, role: String) -> String:
	var lines := {
		"postmaster": ["Parcels don't deliver themselves! Well. Some do. Not these.",
			"Sign here, here, and... that's a drawing of a frog. Fine.",
			"Remember: 'Fragile' means 'please don't do a backflip'."],
		"cozy": ["Lovely day for not being chased by bandits.", "Mind the geese.", "You're the new courier? You're very... green."],
		"wealthy": ["Do wipe your feet, courier.", "My parcel had better arrive unbonked.", "We have TWO wells. Two."],
		"goblin": ["Oi! You smell like a postman.", "Is that parcel edible? Asking for me.", "We built the houses ourselves. You can tell."],
		"abandoned": ["...", "Nobody lives here anymore. Except me. And the rats.", "Keep your voice down. The roof listens."],
		"bandit": ["Courier, eh? Nice satchel. Shame if someone... delivered it.", "We're not bandits. We're 'roadside entrepreneurs'."],
		"farm": ["Those turnips won't pick themselves.", "Seen a chicken? Big one. Angry.", "Watch the cow. She kicks couriers."],
		"hermit": ["You found me! Nobody ever finds me. That's the point.", "The stones told me you'd come. Also the pigeon."],
		"chief": ["Don't mind the lads. They only stab people without receipts.", "Package for me? Put it down slowly."],
		"dungeon": ["Oh thank goodness, a courier. I've been down here since spring.", "Don't touch the walls. Or the floor. Or me."],
	}
	var key := role if lines.has(role) else personality
	return pick(lines.get(key, lines["cozy"]))
