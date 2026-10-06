extends Node
## Session + persistent state.
##
## PROFILE (saved to user://goblin_save.json, survives new worlds):
##   gold, reputation, storage, backpack, equipped gear, placed furniture,
##   post office upgrades, deliveries done.
## PER WORLD (saved under the world seed): looted/defeated placements and job states.

signal toast_requested(text: String, color: Color)
signal gold_changed(gold: int)
signal jobs_changed
signal inventory_changed
signal board_requested(site_id: String)
signal home_requested(tab: String)
signal upgrades_changed
signal rep_changed(level: int)

const SAVE_PATH := "user://goblin_save.json"
const SLOTS := ["pack", "boots", "gloves", "gadget", "hat"]

var world_seed := 0
var pending_seed := -1  # set before reloading main.tscn to start a new world
var world: WorldData
var player: Goblin
var input_locked := false
var indoors := false
var play_time := 0.0

# Profile
var gold := 0
var rep := 0
var deliveries_done := 0
var storage := {}        # item id -> count
var backpack: Array = [] # item ids carried while adventuring
var equipped := {}       # slot -> item id
var furniture := {}      # "slot index" -> item id
var upgrades := {}       # upgrade id -> true
var _worlds := {}        # seed string -> {consumed, jobs, round}

# Current world
var consumed := {}
var jobs := {}
var _job_round := 0


func _ready() -> void:
	InputSetup.ensure_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_profile()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


func toast(text: String, color := Color.WHITE) -> void:
	toast_requested.emit(text, color)


# ===========================================================================
# Save / load
# ===========================================================================

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func last_seed() -> int:
	return int(_worlds.get("_last", -1))


func save_profile() -> void:
	if world != null:
		_worlds[str(world_seed)] = {"consumed": consumed, "jobs": _saveable_jobs(), "round": _job_round}
		_worlds["_last"] = world_seed
	var data := {
		"version": 1, "gold": gold, "rep": rep, "deliveries": deliveries_done, "storage": storage,
		"backpack": backpack, "equipped": equipped, "furniture": furniture, "upgrades": upgrades, "worlds": _worlds,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_profile() -> void:
	_reset_profile()
	if not has_save():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if typeof(d) != TYPE_DICTIONARY:
		return
	gold = int(d.get("gold", 0))
	rep = int(d.get("rep", 0))
	deliveries_done = int(d.get("deliveries", 0))
	for k in d.get("storage", {}):
		storage[k] = int(d["storage"][k])
	backpack = d.get("backpack", [])
	equipped = d.get("equipped", {})
	furniture = d.get("furniture", {})
	upgrades = d.get("upgrades", {})
	_worlds = d.get("worlds", {})


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_reset_profile()


func _reset_profile() -> void:
	gold = 40
	rep = 0
	deliveries_done = 0
	storage = {}
	backpack = []
	equipped = {}
	furniture = {"0": "furn_bed"}  # a humble straw bed to start
	upgrades = {}
	_worlds = {}


func _saveable_jobs() -> Dictionary:
	var out := {}
	for id in jobs:
		var j: Dictionary = jobs[id].duplicate()
		if j["status"] == "accepted":
			j["status"] = "available"  # parcels in hand aren't saved; they go back on the board
		out[id] = j
	return out


func reset_for_world(seed_value: int, data: WorldData) -> void:
	world_seed = seed_value
	world = data
	consumed.clear()
	jobs.clear()
	_job_round = 0
	for j in data.jobs:
		jobs[j["id"]] = j
	var saved: Dictionary = _worlds.get(str(seed_value), {})
	if not saved.is_empty():
		consumed = saved.get("consumed", {})
		_job_round = int(saved.get("round", 0))
		var sj: Dictionary = saved.get("jobs", {})
		for id in sj:
			jobs[id] = sj[id]
	gold_changed.emit(gold)
	jobs_changed.emit()
	inventory_changed.emit()


# ===========================================================================
# Money, reputation, stats
# ===========================================================================

func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)


func rep_level() -> int:
	return Items.rep_level(rep)


func add_rep(points: int) -> void:
	var before := rep_level()
	rep += points
	if rep_level() > before:
		toast("REPUTATION UP! You're now a level %d courier. Better contracts unlocked!" % rep_level(), Color(1, 0.85, 0.3))
		# A guaranteed gift so progress never depends on luck alone.
		var gift: String = ["mat_planks", "mat_nails", "mat_blueprint", "furn_painting", "col_stamp", "hat_crown"][mini(rep_level() - 2, 5)]
		give_item(gift, true)
	rep_changed.emit(rep_level())


## Multiplicative stat from equipped gear (1.0 = no effect).
func stat(name_: String) -> float:
	var v := 1.0
	for slot in equipped:
		var st: Dictionary = Items.get_item(equipped[slot]).get("stats", {})
		if st.has(name_) and name_ not in ["parcels", "loot", "compass", "armor"]:
			v *= float(st[name_])
	return v


## Additive stat (extra slots, flags).
func stat_add(name_: String) -> float:
	var v := 0.0
	for slot in equipped:
		v += float(Items.get_item(equipped[slot]).get("stats", {}).get(name_, 0.0))
	return v


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


# ===========================================================================
# Inventory: backpack (carried loot) -> storage (post office)
# ===========================================================================

func backpack_capacity() -> int:
	return 6 + int(stat_add("loot"))


func storage_capacity() -> int:
	return 30 if has_upgrade("storage_room") else 12


func storage_count() -> int:
	var n := 0
	for k in storage:
		n += storage[k]
	return n


func count_owned(id: String) -> int:
	return int(storage.get(id, 0)) + backpack.count(id)


## Adds an item to the backpack. `mail_overflow` sends it to storage instead
## of losing it (used for guaranteed rewards).
func give_item(id: String, mail_overflow := false) -> bool:
	var it := Items.get_item(id)
	if backpack.size() < backpack_capacity():
		backpack.append(id)
	elif mail_overflow:
		storage[id] = int(storage.get(id, 0)) + 1
		toast("Backpack full — %s was mailed to your post office." % it["name"], Color(0.9, 0.9, 1))
	else:
		toast("Backpack full! Drop off loot at your post office storage.", Color(1, 0.7, 0.5))
		return false
	var c := Items.rarity_color(id)
	toast("%s %s!" % ["RARE:" if Items.rarity(id) == "rare" else "Got", it["name"]], c)
	if player:
		FX.sparkle(player.global_position + Vector3.UP * 1.6, c)
	inventory_changed.emit()
	return true


func deposit_backpack() -> int:
	var moved := 0
	for id in backpack.duplicate():
		if storage_count() >= storage_capacity():
			break
		backpack.erase(id)
		storage[id] = int(storage.get(id, 0)) + 1
		moved += 1
	if moved > 0:
		inventory_changed.emit()
	return moved


func take_from_storage(id: String) -> bool:
	if int(storage.get(id, 0)) > 0:
		storage[id] -= 1
		if storage[id] <= 0:
			storage.erase(id)
		return true
	if backpack.has(id):
		backpack.erase(id)
		return true
	return false


func put_in_storage(id: String) -> void:
	storage[id] = int(storage.get(id, 0)) + 1


func equip(id: String) -> void:
	var it := Items.get_item(id)
	var slot: String = it.get("slot", "")
	if slot == "" or not take_from_storage(id):
		return
	if equipped.has(slot):
		put_in_storage(equipped[slot])
	equipped[slot] = id
	inventory_changed.emit()
	if player:
		player.rig.set_hat(it.get("hat", "cap") if slot == "hat" else player.rig.hat_style)
	save_profile()


func unequip(slot: String) -> void:
	if equipped.has(slot):
		put_in_storage(equipped[slot])
		equipped.erase(slot)
		if slot == "hat" and player:
			player.rig.set_hat("cap")
		inventory_changed.emit()
		save_profile()


func sell(id: String) -> void:
	var price: int = Items.get_item(id).get("sell", int(Items.get_item(id).get("price", 10) * 0.4))
	if take_from_storage(id):
		add_gold(price)
		toast("Sold %s for %d gold." % [Items.name_of(id), price], Color(1, 0.9, 0.4))
		inventory_changed.emit()
		save_profile()


func buy(id: String) -> bool:
	var it := Items.get_item(id)
	var price: int = it.get("price", 0)
	if price <= 0 or gold < price or rep_level() < int(it.get("rep", 1)):
		return false
	if storage_count() >= storage_capacity():
		toast("Storage is full! Sell something or build the Storage Annex.", Color(1, 0.7, 0.5))
		return false
	add_gold(-price)
	put_in_storage(id)
	toast("Bought %s." % it["name"], Color(0.8, 1, 0.8))
	inventory_changed.emit()
	save_profile()
	return true


func can_afford_upgrade(id: String) -> bool:
	var u: Dictionary = Items.UPGRADES[id]
	if has_upgrade(id) or gold < int(u["gold"]) or rep_level() < int(u["rep"]):
		return false
	for m in u["mats"]:
		if count_owned(m) < int(u["mats"][m]):
			return false
	return true


func buy_upgrade(id: String) -> bool:
	if not can_afford_upgrade(id):
		return false
	var u: Dictionary = Items.UPGRADES[id]
	add_gold(-int(u["gold"]))
	for m in u["mats"]:
		for i in int(u["mats"][m]):
			take_from_storage(m)
	upgrades[id] = true
	toast("Built: %s! *hammering noises*" % u["name"], Color(1, 0.85, 0.3))
	upgrades_changed.emit()
	inventory_changed.emit()
	save_profile()
	return true


func place_furniture(slot: int, id: String) -> void:
	var key := str(slot)
	if furniture.has(key):
		put_in_storage(furniture[key])
		furniture.erase(key)
	if id != "" and take_from_storage(id):
		furniture[key] = id
	inventory_changed.emit()
	upgrades_changed.emit()


func consume(id: String) -> void:
	consumed[id] = true


func is_consumed(id: String) -> bool:
	return consumed.has(id)


# ===========================================================================
# Jobs
# ===========================================================================

func jobs_at(site_id: String) -> Array:
	var out := []
	for j in jobs.values():
		if j["from"] == site_id and j["status"] == "available":
			out.append(j)
	out.sort_custom(func(a, b): return a["id"] < b["id"])
	return out


func carried_jobs() -> Array:
	var out := []
	if player:
		for p in player.carrier.packages:
			out.append(p["job"])
	return out


func job_locked_reason(j: Dictionary) -> String:
	var need := int(j.get("min_rep", 1))
	if rep_level() < need:
		return "Needs reputation level %d" % need
	if j.get("tier", "normal") == "special" and not has_upgrade("fancy_counter"):
		return "Needs the Brass Delivery Counter upgrade"
	return ""


func accept_job(job_id: String) -> bool:
	var j: Dictionary = jobs.get(job_id, {})
	if j.is_empty() or j["status"] != "available" or player == null:
		return false
	var why := job_locked_reason(j)
	if why != "":
		toast(why + ".", Color(1, 0.7, 0.5))
		return false
	if not player.carrier.can_take(j["package"]):
		toast("Your arms are full! (max %d parcels, one huge one)" % player.carrier.max_packages(), Color(1, 0.7, 0.5))
		return false
	j["status"] = "accepted"
	j["accepted_at"] = play_time
	j["hits"] = 0
	player.carrier.add_package(j)
	jobs_changed.emit()
	toast("Accepted: %s for %s" % [j["item"], j["recipient_name"]], Color(0.9, 0.95, 1))
	return true


## Called by the goblin when it gets hit, for "untouched" objectives.
func note_hit() -> void:
	for j in carried_jobs():
		j["hits"] = int(j.get("hits", 0)) + 1


func time_left(j: Dictionary) -> float:
	if float(j.get("time_limit", 0.0)) <= 0.0:
		return INF
	return float(j["time_limit"]) - (play_time - float(j.get("accepted_at", play_time)))


## Live status of each optional objective: [{label, ok, failed}]
func objective_status(j: Dictionary, integrity: float) -> Array:
	var out := []
	for o in j.get("objectives", []):
		var ok := true
		var failed := false
		match o["type"]:
			"pristine":
				ok = integrity >= 0.95
				failed = not ok
			"time":
				ok = time_left(j) > 0.0
				failed = not ok
			"untouched":
				ok = int(j.get("hits", 0)) == 0
				failed = not ok
		out.append({"label": o["label"], "ok": ok, "failed": failed, "bonus": o["bonus"]})
	return out


func try_deliver(recipient_id: String) -> bool:
	if player == null:
		return false
	var p := player.carrier.find_for_recipient(recipient_id)
	if p.is_empty():
		return false
	var j: Dictionary = p["job"]
	var integrity: float = p["integrity"]
	var objs := objective_status(j, integrity)
	player.carrier.remove_job(j["id"])
	j["status"] = "delivered"
	var pay := float(j["reward"]) * (0.35 + 0.65 * integrity)
	if has_upgrade("fancy_counter"):
		pay *= 1.15
	var bonus := 0
	var met := 0
	for o in objs:
		if o["ok"]:
			bonus += int(o["bonus"])
			met += 1
	add_gold(int(round(pay)) + bonus)
	deliveries_done += 1
	var quality := "pristine!" if integrity > 0.95 else ("a bit dented" if integrity > 0.6 else "...mostly intact")
	toast("Delivered %s — %s  +%d gold%s" % [j["item"], quality, int(round(pay)), ("  (+%d bonus, %d/%d goals)" % [bonus, met, objs.size()]) if objs.size() > 0 else ""], Color(1, 0.9, 0.35))
	# Item rewards: guaranteed ones always, plus a tier-based chance.
	if j.get("reward_item", "") != "":
		give_item(j["reward_item"], true)
	var rng := RandomNumberGenerator.new()
	rng.seed = str(j["id"]).hash() + deliveries_done
	var tier: String = j.get("tier", "normal")
	var chance: float = {"normal": 0.25, "dangerous": 0.55, "special": 1.0}.get(tier, 0.25)
	if rng.randf() < chance:
		give_item(Items.roll(rng, {"normal": "common", "dangerous": "good", "special": "rare"}.get(tier, "common")), true)
	add_rep(1 + met + {"normal": 0, "dangerous": 1, "special": 2}.get(tier, 0))
	player.rig.set_expression("happy", 1.5)
	jobs_changed.emit()
	_refill_jobs_if_needed()
	save_profile()
	return true


func fail_job(job_id: String, _reason: String) -> void:
	var j: Dictionary = jobs.get(job_id, {})
	if j.is_empty():
		return
	j["status"] = "failed"
	jobs_changed.emit()
	_refill_jobs_if_needed()


## Puts a carried job back on its board (e.g. a parcel that escaped for good).
func return_job(job_id: String) -> void:
	var j: Dictionary = jobs.get(job_id, {})
	if not j.is_empty():
		j["status"] = "available"
		jobs_changed.emit()


func add_runtime_job(j: Dictionary) -> void:
	jobs[j["id"]] = j
	jobs_changed.emit()


func _refill_jobs_if_needed() -> void:
	var open := 0
	for j in jobs.values():
		if j["status"] == "available":
			open += 1
	if open < 5 and world != null:
		_job_round += 1
		for j in DeliveryGenerator.generate_round(world, _job_round):
			jobs[j["id"]] = j
		jobs_changed.emit()
		toast("New contracts have arrived at the boards.", Color(0.8, 0.9, 1))
