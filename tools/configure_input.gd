extends SceneTree


## Author editor-visible bindings. Run explicitly after a deliberate control-layout change.
func _initialize() -> void:
	var bindings: Dictionary = {}
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"light": [KEY_J, KEY_V],
		"heavy": [KEY_K, KEY_B],
		"dodge": [KEY_SPACE],
		"bow_fire": [KEY_Q],
		"interact": [KEY_E],
		"restart": [KEY_R],
		"pause": [KEY_ESCAPE],
		"debug": [KEY_F3],
		"shake": [KEY_F4],
		"ability_1": [KEY_1],
		"ability_2": [KEY_2],
		"ability_3": [KEY_3],
		"ability_4": [KEY_4],
		"ui_accept": [KEY_ENTER, KEY_SPACE],
		"ui_cancel": [KEY_ESCAPE, KEY_Q],
		"ui_left": [KEY_A, KEY_LEFT],
		"ui_right": [KEY_D, KEY_RIGHT],
		"ui_up": [KEY_W, KEY_UP],
		"ui_down": [KEY_S, KEY_DOWN],
		"ui_page_up": [KEY_Z],
		"ui_page_down": [KEY_X],
		"ui_focus_next": [KEY_TAB]
	}
	for action in keys:
		for key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			append(bindings, action, event)
	for pair in [
		["light", MOUSE_BUTTON_LEFT],
		["heavy", MOUSE_BUTTON_MIDDLE],
		["bow_fire", MOUSE_BUTTON_RIGHT],
		["ui_cancel", MOUSE_BUTTON_RIGHT]
	]:
		var event := InputEventMouseButton.new()
		event.button_index = pair[1]
		append(bindings, pair[0], event)
	# Godot uses positional names: A=south/cross, B=east/circle, X=west/square, Y=north/triangle.
	var buttons := {
		"dodge": [JOY_BUTTON_A],
		"light": [JOY_BUTTON_X],
		"interact": [JOY_BUTTON_Y],
		"bow_shoot": [JOY_BUTTON_B],
		"pause": [JOY_BUTTON_START, JOY_BUTTON_TOUCHPAD],
		"ability_1": [JOY_BUTTON_DPAD_UP],
		"ability_2": [JOY_BUTTON_DPAD_RIGHT],
		"ability_3": [JOY_BUTTON_DPAD_DOWN],
		"ability_4": [JOY_BUTTON_DPAD_LEFT],
		"ui_accept": [JOY_BUTTON_A],
		"ui_cancel": [JOY_BUTTON_B],
		"ui_up": [JOY_BUTTON_DPAD_UP],
		"ui_down": [JOY_BUTTON_DPAD_DOWN],
		"ui_left": [JOY_BUTTON_DPAD_LEFT],
		"ui_right": [JOY_BUTTON_DPAD_RIGHT],
		"ui_page_up": [JOY_BUTTON_LEFT_SHOULDER],
		"ui_page_down": [JOY_BUTTON_RIGHT_SHOULDER]
	}
	for action in buttons:
		for button in buttons[action]:
			var event := InputEventJoypadButton.new()
			event.device = -1
			event.button_index = button
			append(bindings, action, event)
	for pair in [
		["bow_aim", JOY_AXIS_TRIGGER_LEFT, 1.0],
		["heavy", JOY_AXIS_TRIGGER_RIGHT, 1.0],
		["move_left", JOY_AXIS_LEFT_X, -1.0],
		["move_right", JOY_AXIS_LEFT_X, 1.0],
		["move_up", JOY_AXIS_LEFT_Y, -1.0],
		["move_down", JOY_AXIS_LEFT_Y, 1.0],
		["look_left", JOY_AXIS_RIGHT_X, -1.0],
		["look_right", JOY_AXIS_RIGHT_X, 1.0],
		["look_up", JOY_AXIS_RIGHT_Y, -1.0],
		["look_down", JOY_AXIS_RIGHT_Y, 1.0],
		["ui_left", JOY_AXIS_LEFT_X, -1.0],
		["ui_right", JOY_AXIS_LEFT_X, 1.0],
		["ui_up", JOY_AXIS_LEFT_Y, -1.0],
		["ui_down", JOY_AXIS_LEFT_Y, 1.0]
	]:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = pair[1]
		event.axis_value = pair[2]
		append(bindings, pair[0], event)
	for action in bindings:
		ProjectSettings.set_setting(
			"input/" + action,
			{"deadzone": .25 if action in ["heavy", "bow_aim"] else .18, "events": bindings[action]}
		)
	ProjectSettings.save()
	print("Authored ", bindings.size(), " input actions in project.godot")
	quit()


func append(bindings: Dictionary, action: String, event: InputEvent) -> void:
	if not bindings.has(action):
		bindings[action] = []
	bindings[action].append(event)
