class_name Chest
extends StaticBody3D
## Treasure chest with pre-rolled (seeded) loot.

var placement_id := ""
var loot := {}
var interact_radius := 2.4
var opened := false
var _lid: Node3D


func _ready() -> void:
	collision_layer = 1
	add_to_group("interactable")
	opened = GameState.is_consumed(placement_id)
	var wood := Color(0.55, 0.35, 0.2)
	var band := Color(0.85, 0.7, 0.3)
	var k := MeshKit.new(6)
	k.box(MeshKit.at(Vector3(0, 0.3, 0)), Vector3(1.1, 0.6, 0.7), wood)
	k.box(MeshKit.at(Vector3(-0.4, 0.3, 0)), Vector3(0.08, 0.62, 0.72), band)
	k.box(MeshKit.at(Vector3(0.4, 0.3, 0)), Vector3(0.08, 0.62, 0.72), band)
	add_child(Mats.instance(k.commit()))
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.6, 0.35)
	add_child(_lid)
	var lk := MeshKit.new(7)
	lk.cylinder(MeshKit.rot(Vector3(0, 0.0, -0.35), Vector3(0, 0, PI * 0.5)), 0.35, 0.35, 1.1, wood.lightened(0.05), 8)
	lk.box(MeshKit.at(Vector3(0, 0.0, -0.72)), Vector3(0.18, 0.2, 0.06), band)
	_lid.add_child(Mats.instance(lk.commit()))
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.1, 0.9, 0.7)
	cs.shape = b
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)
	if opened:
		_lid.rotation.x = -1.9


func can_interact(_g: Goblin) -> bool:
	return not opened


func get_interact_prompt(_g: Goblin) -> String:
	return "Open chest"


func interact(_g: Goblin) -> void:
	if opened:
		return
	var item: String = loot.get("item", "")
	if item != "" and GameState.backpack.size() >= GameState.backpack_capacity():
		GameState.toast("Something good is in here, but your backpack is full. Unload at the post office!", Color(1, 0.7, 0.5))
		return
	opened = true
	GameState.consume(placement_id)
	var tw := create_tween()
	tw.tween_property(_lid, "rotation:x", -2.1, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.sparkle(global_position + Vector3.UP * 0.8)
	var parts: Array[String] = []
	var gold: int = loot.get("gold", 0)
	if gold > 0:
		GameState.add_gold(gold)
		parts.append("%d gold" % gold)
	var potions: int = loot.get("potions", 0)
	if potions > 0:
		GameState.player.heal(potions * 2)
		parts.append("%d potion%s (gulp)" % [potions, "s" if potions > 1 else ""])
	GameState.toast("Chest: " + (", ".join(parts) if not parts.is_empty() else "...a single moth."), Color(1, 0.9, 0.4))
	if item != "":
		GameState.give_item(item)
