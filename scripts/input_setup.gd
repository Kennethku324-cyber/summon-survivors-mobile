extends Node

func _ready():
	var actions = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"ui_cancel": [KEY_ESCAPE]
	}

	for action_name in actions:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			for keycode in actions[action_name]:
				var event = InputEventKey.new()
				event.keycode = keycode
				InputMap.action_add_event(action_name, event)
