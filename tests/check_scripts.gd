extends Node
## Loads every script so parse/compile errors show up in CI. Run as a scene
## (so the GameState autoload exists):
##   godot --headless --path . res://tests/check_scripts.tscn

func _ready() -> void:
	var bad := 0
	for path in _scripts("res://scripts") + _scripts("res://tests"):
		var s = load(path)
		if s == null or (s is GDScript and not s.can_instantiate()):
			print("BROKEN: ", path)
			bad += 1
	print("checked scripts, %d broken" % bad)
	get_tree().quit(1 if bad > 0 else 0)


func _scripts(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out
