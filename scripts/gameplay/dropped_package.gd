class_name DroppedPackage
extends RigidBody3D
## A parcel that fell off the goblin (ragdoll, bandit mugging) or escaped
## (living parcels). It bounces and rolls; press E to pick it back up.
## Escaping parcels hop away from you. Abandoned ones return to their board.

var data: Dictionary = {}
var escaping := false
var interact_radius := 2.2
var _t := 0.0
var _hop_t := 0.5


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("hittable")
	collision_layer = 8
	collision_mask = 1 | 8
	mass = 1.5
	contact_monitor = true
	max_contacts_reported = 2
	var size: Vector3 = data["def"]["size"]
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	add_child(cs)
	add_child(Mats.instance(PackageTypes.build_mesh(data["type"])))
	var marker := Label3D.new()
	marker.text = "!"
	marker.modulate = Color(1, 0.6, 0.2)
	marker.font_size = 110
	marker.outline_size = 24
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.fixed_size = true
	marker.no_depth_test = true
	marker.pixel_size = 0.0008
	marker.position = Vector3.UP * 1.0
	add_child(marker)
	body_entered.connect(_on_hit_something)


func _physics_process(delta: float) -> void:
	_t += delta
	if global_position.y < -60.0 or _t > 240.0:
		_give_up()
		return
	if escaping and _t < 25.0 and GameState.player:
		_hop_t -= delta
		var away := global_position - GameState.player.global_position
		away.y = 0
		if _hop_t <= 0.0 and away.length() < 12.0:
			_hop_t = randf_range(0.6, 1.2)
			apply_central_impulse((away.normalized() + Vector3(randf_range(-0.6, 0.6), 1.6, randf_range(-0.6, 0.6))).normalized() * 6.0 * mass)


func _on_hit_something(_b: Node) -> void:
	if linear_velocity.length() > 9.0 and data["type"] == "explosive":
		GameState.fail_job(data["job"]["id"], "boom")
		Explosion.explode(get_tree(), global_position, 5.0, 14.0, 2)
		queue_free()


func _give_up() -> void:
	GameState.return_job(data["job"]["id"])
	GameState.toast("A lost parcel found its own way back to the board.", Color(0.9, 0.9, 1))
	queue_free()


func on_bonk(_g: Node, dir: Vector3, force: float) -> void:
	apply_central_impulse(dir * force * mass * 0.5)


func can_interact(g: Goblin) -> bool:
	return g.carrier.can_take(data["type"])


func get_interact_prompt(_g: Goblin) -> String:
	return "Grab the %s!" % data["def"]["name"].to_lower()


func interact(g: Goblin) -> void:
	g.carrier.restore(data)
	GameState.toast("Got it back!", Color(0.8, 1, 0.8))
	queue_free()
