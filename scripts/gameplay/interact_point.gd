class_name InteractPoint
extends Node3D
## Generic interactable attached to a piece: notice boards, dungeon doors,
## lost parcels. Behaviour is chosen by `action`.

signal used(goblin: Goblin)

var action := ""
var prompt := ""
var data := {}
var interact_radius := 2.6
var enabled := true


func _ready() -> void:
	add_to_group("interactable")


func can_interact(_g: Goblin) -> bool:
	return enabled


func get_interact_prompt(_g: Goblin) -> String:
	if action == "board":
		var n := GameState.jobs_at(data.get("site", "")).size()
		return "Check the delivery board (%d parcel%s)" % [n, "" if n == 1 else "s"]
	return prompt


func interact(g: Goblin) -> void:
	used.emit(g)
