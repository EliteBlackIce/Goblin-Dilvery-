class_name Items
extends RefCounted
## Every item in the game, as data. Each one has a job:
##   equipment   (slot) changes how the goblin plays — stats multiply GameState.stat()
##   furniture   placed in the personal room at the post office
##   collectible shown on the trophy shelf
##   valuable    sold at the shop
##   material    spent on post office building upgrades
## "rep" = reputation level needed to buy it. price 0 = loot only.

const ALL := {
	# --- Equipment ---------------------------------------------------------
	"pack_big": {"name": "Big Backpack", "cat": "equipment", "slot": "pack", "price": 120, "rep": 1,
		"desc": "+1 parcel slot, +3 loot slots, carries heavy stuff better.", "stats": {"parcels": 1.0, "loot": 3.0, "carry": 1.3}},
	"pack_hauler": {"name": "Hauler Frame", "cat": "equipment", "slot": "pack", "price": 320, "rep": 3,
		"desc": "+2 parcel slots, +6 loot slots. Slightly slower.", "stats": {"parcels": 2.0, "loot": 6.0, "carry": 1.7, "speed": 0.95}},
	"boots_sticky": {"name": "Sticky Socks", "cat": "equipment", "slot": "boots", "price": 80, "rep": 1,
		"desc": "Much harder to knock over. Shorter foot-slides.", "stats": {"stability": 1.45}},
	"boots_spring": {"name": "Spring Boots", "cat": "equipment", "slot": "boots", "price": 160, "rep": 2,
		"desc": "Boing. +25% jump height, softer landings.", "stats": {"jump": 1.25, "landing": 1.3}},
	"boots_greased": {"name": "Greased Boots", "cat": "equipment", "slot": "boots", "price": 170, "rep": 2,
		"desc": "+14% speed. Faster recovery after falls.", "stats": {"speed": 1.14, "recovery": 1.5}},
	"gloves_grip": {"name": "Grippy Gloves", "cat": "equipment", "slot": "gloves", "price": 100, "rep": 1,
		"desc": "Fragile and valuable parcels take 40% less damage.", "stats": {"fragile_care": 0.6}},
	"gloves_iron": {"name": "Iron Mitts", "cat": "equipment", "slot": "gloves", "price": 220, "rep": 3,
		"desc": "Heavy and huge parcels barely slow you down.", "stats": {"strength": 0.5}},
	"gadget_bubble": {"name": "Bubble Wrap Dispenser", "cat": "equipment", "slot": "gadget", "price": 260, "rep": 2, "workshop": true,
		"desc": "All parcel damage halved. Pop pop.", "stats": {"package_damage": 0.5}},
	"gadget_whistle": {"name": "Bandit Whistle", "cat": "equipment", "slot": "gadget", "price": 180, "rep": 2, "workshop": true,
		"desc": "Enemies notice you from much shorter range (sneak past!).", "stats": {"noise": 0.55}},
	"gadget_compass": {"name": "Treasure Compass", "cat": "equipment", "slot": "gadget", "price": 140, "rep": 1, "workshop": true,
		"desc": "Shows unopened chests on the map and minimap.", "stats": {"compass": 1.0}},
	"hat_pot": {"name": "Pot Helmet", "cat": "equipment", "slot": "hat", "price": 60, "rep": 1,
		"desc": "A cooking pot. Takes the edge off hits.", "stats": {"armor": 1.0}, "hat": "pot"},
	"hat_wizard": {"name": "Wizard Hat", "cat": "equipment", "slot": "hat", "price": 0,
		"desc": "Found, not bought. Floating parcels float you even more.", "stats": {"float": 1.3}, "hat": "wizard"},
	"hat_crown": {"name": "Tiny Crown", "cat": "equipment", "slot": "hat", "price": 0,
		"desc": "Purely cosmetic. Villagers are mildly impressed.", "stats": {}, "hat": "crown"},
	# --- Furniture ----------------------------------------------------------
	"furn_bed": {"name": "Straw Bed", "cat": "furniture", "price": 30, "rep": 1, "desc": "Rest here to heal and save.", "color": Color(0.9, 0.78, 0.35)},
	"furn_bed_fancy": {"name": "Four-Poster Bed", "cat": "furniture", "price": 220, "rep": 3, "desc": "Rest in luxury. Heals and saves.", "color": Color(0.7, 0.2, 0.25)},
	"furn_table": {"name": "Wobbly Table", "cat": "furniture", "price": 40, "rep": 1, "desc": "One leg is shorter. On purpose.", "color": Color(0.6, 0.42, 0.25)},
	"furn_chair": {"name": "Stool", "cat": "furniture", "price": 25, "rep": 1, "desc": "For sitting. In theory.", "color": Color(0.55, 0.38, 0.22)},
	"furn_lamp": {"name": "Lantern", "cat": "furniture", "price": 35, "rep": 1, "desc": "Cozy light.", "color": Color(1.0, 0.8, 0.4)},
	"furn_rug": {"name": "Round Rug", "cat": "furniture", "price": 45, "rep": 1, "desc": "Ties the room together.", "color": Color(0.75, 0.3, 0.3)},
	"furn_shelf": {"name": "Bookshelf", "cat": "furniture", "price": 90, "rep": 2, "desc": "Books about parcels.", "color": Color(0.5, 0.33, 0.2)},
	"furn_plant": {"name": "Potted Fern", "cat": "furniture", "price": 30, "rep": 1, "desc": "It judges you silently.", "color": Color(0.3, 0.65, 0.3)},
	"furn_painting": {"name": "Portrait of a Goose", "cat": "furniture", "price": 0, "desc": "Rare loot. The goose watches.", "color": Color(0.9, 0.85, 0.7)},
	"furn_throne": {"name": "Goblin Throne", "cat": "furniture", "price": 0, "desc": "Bandit loot. Made of spoons.", "color": Color(0.85, 0.7, 0.3)},
	"furn_cauldron": {"name": "Bubbling Cauldron", "cat": "furniture", "price": 0, "desc": "Dungeon loot. Smells of soup and regret.", "color": Color(0.25, 0.25, 0.28)},
	# --- Collectibles (trophy shelf) ----------------------------------------
	"col_sock": {"name": "Lucky Odd Sock", "cat": "collectible", "desc": "Its partner is out there somewhere."},
	"col_mushroom": {"name": "Glowing Mushroom Jar", "cat": "collectible", "desc": "Do not eat. Probably."},
	"col_badge": {"name": "Bandit Badge", "cat": "collectible", "desc": "'Roadside Entrepreneur of the Month'."},
	"col_coin": {"name": "Ancient Coin", "cat": "collectible", "desc": "Older than the post office. Barely."},
	"col_tooth": {"name": "Dragon Tooth", "cat": "collectible", "desc": "Or a very big goose tooth."},
	"col_stamp": {"name": "Golden Stamp", "cat": "collectible", "desc": "The rarest stamp. Licks of legend."},
	# --- Valuables -----------------------------------------------------------
	"val_spoon": {"name": "Silver Spoon", "cat": "valuable", "sell": 25, "desc": "Sell it at the shop."},
	"val_gem": {"name": "Shiny Gem", "cat": "valuable", "sell": 60, "desc": "Sell it at the shop."},
	"val_idol": {"name": "Golden Idol", "cat": "valuable", "sell": 150, "desc": "Sell it. Run if it rumbles."},
	# --- Materials -------------------------------------------------------------
	"mat_planks": {"name": "Planks", "cat": "material", "price": 15, "rep": 1, "desc": "For building upgrades."},
	"mat_nails": {"name": "Bag of Nails", "cat": "material", "price": 25, "rep": 1, "desc": "For building upgrades."},
	"mat_blueprint": {"name": "Blueprint", "cat": "material", "price": 0, "desc": "Rare plans from a far-off guild. Unlocks big upgrades."},
}

## Post office building upgrades: visibly change the building.
const UPGRADES := {
	"storage_room": {"name": "Storage Annex", "gold": 150, "mats": {"mat_planks": 4}, "rep": 1,
		"desc": "Adds a storage annex at the back. Storage 12 -> 30 slots."},
	"fancy_counter": {"name": "Brass Delivery Counter", "gold": 200, "mats": {"mat_nails": 2}, "rep": 2,
		"desc": "Fancier counter: +15% delivery pay and SPECIAL contracts."},
	"workshop": {"name": "Gadget Workshop", "gold": 250, "mats": {"mat_planks": 4, "mat_nails": 2, "mat_blueprint": 1}, "rep": 2,
		"desc": "Adds a workshop wing. Gadgets appear in the shop."},
	"bedroom": {"name": "Bedroom Extension", "gold": 300, "mats": {"mat_planks": 6, "mat_nails": 2}, "rep": 3,
		"desc": "Knocks out a wall: personal room gets 4 more furniture spots."},
}

const REP_LEVELS := [0, 3, 8, 15, 25, 40, 60]
const LOOT_POOLS := {
	"common": ["mat_planks", "mat_planks", "mat_nails", "val_spoon", "col_sock", "furn_chair", "furn_plant"],
	"good": ["mat_nails", "mat_planks", "val_gem", "col_mushroom", "col_coin", "furn_lamp", "furn_rug", "hat_pot", "mat_blueprint"],
	"rare": ["mat_blueprint", "val_idol", "col_tooth", "col_stamp", "furn_painting", "furn_throne", "furn_cauldron", "hat_wizard", "hat_crown", "boots_spring"],
}


static func get_item(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "cat": "valuable", "desc": "?"})


static func name_of(id: String) -> String:
	return get_item(id)["name"]


static func rarity(id: String) -> String:
	for r in ["rare", "good"]:
		if LOOT_POOLS[r].has(id):
			return r
	return "common"


static func rarity_color(id: String) -> Color:
	return {"rare": Color(1.0, 0.65, 0.2), "good": Color(0.5, 0.8, 1.0)}.get(rarity(id), Color(0.85, 0.95, 0.85))


static func roll(rng: RandomNumberGenerator, pool: String) -> String:
	var arr: Array = LOOT_POOLS[pool]
	return arr[rng.randi_range(0, arr.size() - 1)]


static func rep_level(points: int) -> int:
	var lvl := 1
	for i in REP_LEVELS.size():
		if points >= REP_LEVELS[i]:
			lvl = i + 1
	return lvl
