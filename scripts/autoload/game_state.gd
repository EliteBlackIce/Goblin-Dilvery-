extends Node
## Session-wide state: the current world, the player's gold and trinkets,
## delivery jobs, and which placements have been looted/defeated so they
## stay that way when their chunk streams out and back in.

signal toast_requested(text: String, color: Color)
signal gold_changed(gold: int)
signal jobs_changed
signal inventory_changed
signal board_requested(site_id: String)

var world_seed := 0
var pending_seed := -1  # set before reloading main.tscn to start a new world
var world: WorldData
var player: Goblin
var gold := 0
var clumsiness := 1.0  # 0 = never trips randomly, 1 = default, 2 = chaos
var input_locked := false
var consumed := {}   # placement id -> true (looted chests, defeated enemies, picked pickups)
var jobs := {}       # job id -> job Dictionary
var trinkets: Array[String] = []
var deliveries_done := 0
var _job_round := 0

const TRINKETS := LootTable.TRINKETS


func _ready() -> void:
	InputSetup.ensure_actions()
	process_mode = Node.PROCESS_MODE_ALWAYS


func reset_for_world(seed_value: int, data: WorldData) -> void:
	world_seed = seed_value
	world = data
	gold = 0
	consumed.clear()
	jobs.clear()
	trinkets.clear()
	deliveries_done = 0
	_job_round = 0
	for j in data.jobs:
		jobs[j["id"]] = j
	gold_changed.emit(gold)
	jobs_changed.emit()
	inventory_changed.emit()


func toast(text: String, color := Color.WHITE) -> void:
	toast_requested.emit(text, color)


func add_gold(amount: int) -> void:
	gold = maxi(0, gold + amount)
	gold_changed.emit(gold)


func stat(name_: String) -> float:
	var v := 1.0
	for t in trinkets:
		v *= float(TRINKETS[t].get(name_, 1.0))
	return v


func give_trinket(id: String) -> void:
	if trinkets.has(id):
		add_gold(25)
		toast("Another %s? Sold it for 25 gold." % TRINKETS[id]["name"], Color(1, 0.9, 0.4))
		return
	trinkets.append(id)
	inventory_changed.emit()
	toast("Found %s! (%s)" % [TRINKETS[id]["name"], TRINKETS[id]["desc"]], Color(0.6, 1, 0.8))


func is_consumed(id: String) -> bool:
	return consumed.has(id)


func consume(id: String) -> void:
	consumed[id] = true


# ---------------------------------------------------------------------------
# Jobs
# ---------------------------------------------------------------------------

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


func accept_job(job_id: String) -> bool:
	var j: Dictionary = jobs.get(job_id, {})
	if j.is_empty() or j["status"] != "available" or player == null:
		return false
	if not player.carrier.can_take(j["package"]):
		toast("Your arms are full! (max %d parcels, one huge one)" % PackageCarrier.MAX_PACKAGES, Color(1, 0.7, 0.5))
		return false
	j["status"] = "accepted"
	player.carrier.add_package(j)
	jobs_changed.emit()
	toast("Accepted: %s for %s" % [j["item"], j["recipient_name"]], Color(0.9, 0.95, 1))
	return true


func try_deliver(recipient_id: String) -> bool:
	if player == null:
		return false
	var p := player.carrier.find_for_recipient(recipient_id)
	if p.is_empty():
		return false
	var j: Dictionary = p["job"]
	var integrity: float = p["integrity"]
	player.carrier.remove_job(j["id"])
	j["status"] = "delivered"
	var pay := int(round(float(j["reward"]) * (0.35 + 0.65 * integrity)))
	add_gold(pay)
	deliveries_done += 1
	jobs_changed.emit()
	var quality := "pristine!" if integrity > 0.95 else ("a bit dented" if integrity > 0.6 else "...mostly intact")
	toast("Delivered %s — %s  +%d gold" % [j["item"], quality, pay], Color(1, 0.9, 0.35))
	player.rig.set_expression("happy", 1.5)
	_refill_jobs_if_needed()
	return true


func fail_job(job_id: String, _reason: String) -> void:
	var j: Dictionary = jobs.get(job_id, {})
	if j.is_empty():
		return
	j["status"] = "failed"
	jobs_changed.emit()
	_refill_jobs_if_needed()


## Adds a job created at runtime (e.g. the "lost package" event).
func add_runtime_job(j: Dictionary) -> void:
	jobs[j["id"]] = j
	jobs_changed.emit()


func _refill_jobs_if_needed() -> void:
	var open := 0
	for j in jobs.values():
		if j["status"] == "available":
			open += 1
	if open < 4 and world != null:
		_job_round += 1
		for j in DeliveryGenerator.generate_round(world, _job_round):
			jobs[j["id"]] = j
		jobs_changed.emit()
		toast("New parcels have arrived at the notice boards.", Color(0.8, 0.9, 1))
