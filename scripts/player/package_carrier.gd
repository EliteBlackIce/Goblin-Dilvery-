class_name PackageCarrier
extends Node3D
## Holds the packages the goblin is carrying and makes them PHYSICAL:
##  * back-stack packages sit on springs and sway (unstable ones a LOT)
##  * a huge package is hugged in front and blocks the view
##  * magical packages float behind on a lazy spring
##  * living packages jolt around and shove the goblin
##  * fragile / explosive packages lose integrity on impacts
## and reports movement modifiers (speed, accel, jump, turn, instability).

signal changed


var goblin: Goblin
var packages: Array = []  # of Dictionary: {job, type, def, integrity, node, spring, tilt, jolt_t}
var _time := 0.0


func _ready() -> void:
	top_level = true


func max_packages() -> int:
	return 3 + int(GameState.stat_add("parcels"))


func has_room() -> bool:
	return packages.size() < max_packages()


func can_take(type_id: String) -> bool:
	if not has_room():
		return false
	if PackageTypes.get_def(type_id)["carry"] == "front":
		for p in packages:
			if p["def"]["carry"] == "front":
				return false
	return true


func add_package(job: Dictionary) -> void:
	var type_id: String = job["package"]
	var def := PackageTypes.get_def(type_id)
	var node := Node3D.new()
	node.top_level = true
	var mi := Mats.instance(PackageTypes.build_mesh(type_id))
	node.add_child(mi)
	if type_id == "magical":
		var glow := OmniLight3D.new()
		glow.light_color = Color(0.7, 0.45, 1.0)
		glow.light_energy = 1.2
		glow.omni_range = 3.0
		node.add_child(glow)
	add_child(node)
	var start: Vector3 = goblin.global_position + Vector3.UP * 1.2 if goblin else Vector3.ZERO
	node.global_position = start
	var stiff := lerpf(380.0, 55.0, clampf(def["wobble"], 0.0, 1.0))
	if def["carry"] == "float":
		stiff = 25.0
	var spring := Spring3.new(stiff, 7.0 if def["carry"] != "float" else 5.0, start)
	packages.append({
		"job": job, "type": type_id, "def": def, "integrity": 1.0,
		"node": node, "spring": spring, "jolt_t": randf_range(2.0, 5.0), "warned": false,
	})
	changed.emit()


func remove_job(job_id: String) -> Dictionary:
	for i in packages.size():
		var p: Dictionary = packages[i]
		if p["job"]["id"] == job_id:
			(p["node"] as Node3D).queue_free()
			packages.remove_at(i)
			changed.emit()
			return p
	return {}


func find_for_recipient(recipient_id: String) -> Dictionary:
	for p in packages:
		if p["job"]["recipient_id"] == recipient_id:
			return p
	return {}


func total_weight() -> float:
	var w := 0.0
	for p in packages:
		w += float(p["def"]["weight"])
	return w


func carry_pose() -> String:
	var pose := "none"
	for p in packages:
		var c: String = p["def"]["carry"]
		if c == "front":
			return "front"
		if c == "back":
			pose = "back"
	return pose


func blocks_view() -> bool:
	return carry_pose() == "front"


func get_modifiers() -> Dictionary:
	var weight := total_weight() * GameState.stat("strength")
	var capacity := 9.0 * GameState.stat("carry")
	var overloaded := weight > capacity
	var wobble := 0.0
	for p in packages:
		wobble += float(p["def"]["wobble"])
	var m := {
		"speed": clampf(1.0 - maxf(0.0, weight - 1.5) * 0.055, 0.5, 1.0),
		"accel": clampf(1.0 - weight * 0.045, 0.5, 1.0),
		"jump": clampf(1.0 - weight * 0.035, 0.62, 1.0),
		"turn": clampf(1.0 - weight * 0.04, 0.55, 1.0),
		"instability": wobble + weight * 0.03 + (0.6 if overloaded else 0.0),
		"weight": weight,
		"overloaded": overloaded,
		"gravity": 1.0,
		"noise": 1.0,
	}
	for p in packages:
		if p["type"] == "magical":
			m["gravity"] *= 0.62 / GameState.stat("float")  # it pulls you upward!
			m["jump"] *= 1.15
		elif p["type"] in ["cursed", "valuable"]:
			m["noise"] *= 1.7  # enemies smell it from far away
	if overloaded:
		m["speed"] *= 0.75
	return m


# ---------------------------------------------------------------------------
# Damage
# ---------------------------------------------------------------------------

func on_impact(impact: float) -> void:
	if impact > 11.0:
		_damage_all((impact - 11.0) * 0.045, "landing")
	for p in packages:
		(p["spring"] as Spring3).kick(Vector3.DOWN * impact * 0.8)


func on_hit(force: float) -> void:
	_damage_all(force * 0.03, "hit")
	for p in packages:
		var k := 0.35 if p["def"]["carry"] == "front" else 0.6
		(p["spring"] as Spring3).kick(Vector3(randf_range(-1, 1), 0.5, randf_range(-1, 1)) * force * k)


func on_ragdoll() -> void:
	_damage_all(0.22, "ragdoll")
	if not packages.is_empty() and randf() < 0.6:
		drop_one("Your parcel went flying! Go grab it.")


## Knocks the top back-stack parcel off into the world as a physical object.
func drop_one(msg: String, escaping := false) -> void:
	for i in range(packages.size() - 1, -1, -1):
		var p: Dictionary = packages[i]
		if p["def"]["carry"] == "front" and not escaping:
			continue
		var node: Node3D = p["node"]
		var dp := DroppedPackage.new()
		dp.data = p
		dp.escaping = escaping
		goblin.get_parent().add_child(dp)
		dp.global_position = node.global_position + Vector3.UP * 0.3
		dp.linear_velocity = goblin.velocity * 0.5 + Vector3(randf_range(-3, 3), 4.5, randf_range(-3, 3))
		node.queue_free()
		packages.remove_at(i)
		changed.emit()
		GameState.toast(msg, Color(1, 0.8, 0.5))
		return


## Picks a dropped parcel back up (keeps its job, integrity and timer).
func restore(p: Dictionary) -> void:
	var job: Dictionary = p["job"]
	add_package(job)
	packages[packages.size() - 1]["integrity"] = p["integrity"]
	changed.emit()


func on_bonk() -> void:
	# Swinging your satchel at things while carrying glassware: bold.
	for p in packages.duplicate():
		if p["type"] == "fragile":
			_damage(p, 0.12, "bonk")


func _damage_all(amount: float, cause: String) -> void:
	for p in packages.duplicate():
		_damage(p, amount * float(p["def"]["fragility"]), cause)


func _damage(p: Dictionary, amount: float, _cause: String) -> void:
	amount *= GameState.stat("package_damage")
	if p["type"] in ["fragile", "valuable"]:
		amount *= GameState.stat("fragile_care")
	if amount <= 0.001 or not packages.has(p):
		return
	p["integrity"] = maxf(0.0, p["integrity"] - amount)
	changed.emit()
	if p["type"] == "fragile" and amount > 0.05:
		GameState.toast("*clink*  (%s at %d%%)" % [p["def"]["name"], int(p["integrity"] * 100)], Color(0.7, 0.9, 1))
	if p["type"] == "explosive" and p["integrity"] < 0.4 and not p["warned"]:
		p["warned"] = true
		GameState.toast("The explosive parcel is hissing. That's bad.", Color(1, 0.5, 0.3))
	if p["integrity"] <= 0.0:
		_destroy(p)


func _destroy(p: Dictionary) -> void:
	var job: Dictionary = p["job"]
	remove_job(job["id"])
	GameState.fail_job(job["id"], "destroyed")
	if p["type"] == "explosive":
		GameState.toast("KA-BOOM. The package has been... delivered to everywhere.", Color(1, 0.4, 0.2))
		Explosion.explode(goblin.get_tree(), goblin.global_position + Vector3.UP * 0.8, 6.0, 16.0, 2)
	elif p["type"] == "fragile":
		GameState.toast("You hear the unmistakable sound of %s becoming gravel." % job["item"], Color(1, 0.6, 0.6))
	else:
		GameState.toast("The %s fell apart." % p["def"]["name"].to_lower(), Color(1, 0.6, 0.6))


func _curse_effect() -> void:
	match randi() % 3:
		0:
			GameState.toast("The cursed parcel giggles. A bandit somewhere sneezes.", Color(0.8, 0.6, 1))
		1:
			goblin.velocity.y = 7.0
			goblin.rig.set_expression("scared", 0.8)
			GameState.toast("*the parcel hiccups and you hop*", Color(0.8, 0.6, 1))
		2:
			goblin.rig.set_expression("dizzy", 1.0)
			GameState.toast("Spooky whispers: 'deliver... meee...'", Color(0.8, 0.6, 1))
	FX.puff(goblin.global_position + Vector3.UP * 1.5, Color(0.6, 0.3, 0.8), 0.6, 1.0, 0.8)


# ---------------------------------------------------------------------------
# Visual simulation
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if goblin == null:
		return
	_time += delta
	var dt := minf(delta, 0.05)
	var rig := goblin.rig
	var ragdolled := goblin.ragdoll != null
	var yaw := goblin.facing_yaw
	var basis := Basis(Vector3.UP, yaw)
	var stack_h := 0.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))

	for p in packages:
		var node: Node3D = p["node"]
		var spring: Spring3 = p["spring"]
		var def: Dictionary = p["def"]
		var size: Vector3 = def["size"]
		var target_pos: Vector3
		var target_basis := basis
		match def["carry"]:
			"front":
				var a: Transform3D = rig.front_anchor.global_transform
				target_pos = a.origin
				if ragdolled:
					target_pos = goblin.ragdoll.center() + Vector3.UP * 0.4
			"float":
				target_pos = goblin.camera_target() - fwd * 1.2 + Vector3.UP * (0.5 + sin(_time * 2.2) * 0.18)
				target_basis = Basis(Vector3.UP, _time * 0.8)
			_:
				var anchor: Transform3D = rig.back_anchor.global_transform
				var base := anchor.origin
				if ragdolled:
					base = goblin.ragdoll.center() + Vector3.UP * 0.2
				target_pos = base + Vector3.UP * (stack_h + size.y * 0.5) + anchor.basis.z.normalized() * size.z * 0.35
				stack_h += size.y * 0.92

		if p["type"] == "cursed":
			p["jolt_t"] -= dt
			if p["jolt_t"] <= 0.0:
				p["jolt_t"] = randf_range(6.0, 12.0)
				_curse_effect()
		# Living packages: random jolts that shove the goblin, sometimes escape.
		if p["type"] == "living":
			p["jolt_t"] -= dt
			if p["jolt_t"] <= 0.0:
				p["jolt_t"] = randf_range(2.5, 6.0)
				var j := Vector3(randf_range(-1, 1), randf_range(0.5, 1.5), randf_range(-1, 1)).normalized()
				spring.kick(j * 6.0)
				if goblin.state == Goblin.State.NORMAL and goblin.grounded:
					goblin.velocity += Vector3(j.x, 0, j.z) * 2.0
					goblin.balance += 0.18
					goblin.rig.set_expression("scared", 0.5)
				if randf() < 0.12 and goblin.state == Goblin.State.NORMAL:
					call_deferred("drop_one", "The living parcel ESCAPED! Catch it!", true)
					return
				if randf() < 0.35:
					GameState.toast(WorldText.pick(["*angry clucking*", "*scritch scritch*", "*something sneezed*", "*thump*"]), Color(0.8, 1, 0.7))

		var pos := spring.step(target_pos, dt)
		# Sway, but never visually detach from the goblin.
		if def["carry"] != "float":
			var max_lag := 0.22 if def["carry"] == "front" else 0.25 + float(def["wobble"]) * 0.3
			var off := pos - target_pos
			if off.length() > max_lag:
				pos = target_pos + off.normalized() * max_lag
				spring.value = pos
				spring.velocity *= 0.5
		# Tilt each package in the direction it lags behind (= visible sway).
		var lag := pos - target_pos
		var tilt_axis := Vector3.UP.cross(-lag)
		var tilt_amt := clampf(lag.length() * 2.5, 0.0, 0.8)
		var b := target_basis
		if tilt_axis.length_squared() > 1e-6:
			b = Basis(tilt_axis.normalized(), tilt_amt) * target_basis
		if p["type"] == "explosive" and p["warned"]:
			b = b.rotated(Vector3.UP, sin(_time * 40.0) * 0.05)
		node.global_transform = Transform3D(b, pos)
