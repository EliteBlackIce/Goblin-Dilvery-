class_name InputSetup
extends RefCounted
## Registers the game's input actions at startup so project.godot stays readable
## and designers can still rebind everything in Project Settings if they prefer
## (actions that already exist are left untouched).

const KEYS := {
	"move_forward": [KEY_W, KEY_UP],
	"move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE],
	"sprint": [KEY_SHIFT],
	"interact": [KEY_E],
	"attack": [KEY_F],
	"toggle_map": [KEY_M],
	"pause": [KEY_ESCAPE],
	"new_world": [KEY_F5],
	"camera_recenter": [KEY_C],
	"debug_explode": [KEY_X],
}

const MOUSE := {
	"attack": [MOUSE_BUTTON_LEFT],
}

const JOY_BUTTONS := {
	"jump": [JOY_BUTTON_A],
	"interact": [JOY_BUTTON_X],
	"attack": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_B],
	"sprint": [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_LEFT_SHOULDER],
	"toggle_map": [JOY_BUTTON_BACK],
	"pause": [JOY_BUTTON_START],
	"camera_recenter": [JOY_BUTTON_RIGHT_STICK],
}

## [action, axis, direction]
const JOY_AXES := [
	["move_forward", JOY_AXIS_LEFT_Y, -1.0],
	["move_back", JOY_AXIS_LEFT_Y, 1.0],
	["move_left", JOY_AXIS_LEFT_X, -1.0],
	["move_right", JOY_AXIS_LEFT_X, 1.0],
	["look_left", JOY_AXIS_RIGHT_X, -1.0],
	["look_right", JOY_AXIS_RIGHT_X, 1.0],
	["look_up", JOY_AXIS_RIGHT_Y, -1.0],
	["look_down", JOY_AXIS_RIGHT_Y, 1.0],
]


static func ensure_actions() -> void:
	var all_actions: Array = []
	all_actions.append_array(KEYS.keys())
	all_actions.append_array(JOY_BUTTONS.keys())
	for a in JOY_AXES:
		all_actions.append(a[0])
	for action in all_actions:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for key in KEYS.get(action, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		for button in MOUSE.get(action, []):
			var mev := InputEventMouseButton.new()
			mev.button_index = button
			InputMap.action_add_event(action, mev)
		for button in JOY_BUTTONS.get(action, []):
			var jev := InputEventJoypadButton.new()
			jev.button_index = button
			InputMap.action_add_event(action, jev)
		for a in JOY_AXES:
			if a[0] == action:
				var aev := InputEventJoypadMotion.new()
				aev.axis = a[1]
				aev.axis_value = a[2]
				InputMap.action_add_event(action, aev)
