extends Node
## Device ownership and prompts are shared by gameplay and menus; bindings live in project.godot.
signal device_changed(kind: String)
signal controller_disconnected
var kind := "controller"
var controller_family := "playstation"
var controller_id := -1
var vibration_enabled := true
var blocked_through_frame := -1
var last_axes: Dictionary = {}
const KEYBOARD_PROMPTS := {
	"light": "LMB",
	"heavy": "MMB / B",
	"dodge": "Space",
	"interact": "E",
	"lock_on": "F",
	"bow_aim": "Q / RMB",
	"bow_shoot": "Q / RMB",
	"pause": "Esc",
	"accept": "Enter",
	"cancel": "Q / RMB",
	"tabs": "Z / X"
}
const PLAYSTATION_PROMPTS := {
	"light": "□",
	"heavy": "R2",
	"dodge": "✕",
	"interact": "△",
	"lock_on": "R3",
	"bow_aim": "L2",
	"bow_shoot": "○",
	"pause": "Options",
	"accept": "✕",
	"cancel": "○",
	"tabs": "L1 / R1"
}
const XBOX_PROMPTS := {
	"light": "X",
	"heavy": "RT",
	"dodge": "A",
	"interact": "Y",
	"lock_on": "RS",
	"bow_aim": "LT",
	"bow_shoot": "B",
	"pause": "Menu",
	"accept": "A",
	"cancel": "B",
	"tabs": "LB / RB"
}
const PLAYSTATION_ICONS := {"□": "square", "○": "circle", "✕": "cross", "△": "triangle"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Avoid merging aim/trigger changes until the next rendered frame.
	Input.use_accumulated_input = false
	Input.joy_connection_changed.connect(_controller_connection_changed)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		_select_controller(pads[0])


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.pressed:
		_select_controller(event.device)
	elif event is InputEventJoypadMotion:
		var key := Vector2i(event.device, event.axis)
		var previous: float = last_axes.get(key, 0.0)
		last_axes[key] = event.axis_value
		var magnitude: float = (
			event.axis_value
			if event.axis in [JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]
			else absf(event.axis_value)
		)
		if magnitude > .18 and absf(previous - event.axis_value) > .015:
			_select_controller(event.device)
	elif event is InputEventMouseButton and event.pressed:
		_set_kind("mouse")
	elif event is InputEventMouseMotion and event.relative.length_squared() > .5:
		_set_kind("mouse")
	elif event is InputEventKey and event.pressed and not event.echo:
		_set_kind("keyboard")


func _select_controller(device: int) -> void:
	controller_id = device
	var device_name := Input.get_joy_name(device).to_lower()
	controller_family = (
		"xbox" if "xbox" in device_name or "xinput" in device_name else "playstation"
	)
	_set_kind("controller")


func _set_kind(value: String) -> void:
	if kind != value:
		kind = value
		device_changed.emit(kind)


func block_gameplay_input() -> void:
	# Input's global action state survives handled GUI events. Fence the transition tick explicitly.
	blocked_through_frame = Engine.get_physics_frames() + 2


func gameplay_input_blocked() -> bool:
	return Engine.get_physics_frames() <= blocked_through_frame


func _controller_connection_changed(device: int, connected: bool) -> void:
	if connected:
		if controller_id < 0:
			_select_controller(device)
	elif device == controller_id:
		controller_id = -1
		last_axes.clear()
		block_gameplay_input()
		if kind == "controller":
			controller_disconnected.emit()


func feedback(weak: float, strong: float, duration: float) -> void:
	if (
		vibration_enabled
		and kind == "controller"
		and controller_id in Input.get_connected_joypads()
	):
		Input.start_joy_vibration(controller_id, weak, strong, duration)


func prompt(action: String) -> String:
	var prompts: Dictionary = KEYBOARD_PROMPTS
	if kind == "controller":
		prompts = XBOX_PROMPTS if controller_family == "xbox" else PLAYSTATION_PROMPTS
	return str(prompts.get(action, action))


func controls_text() -> String:
	if kind != "controller":
		return "WASD / arrows  Move\nLMB / V / J  Sword\nMMB / B / K  Heavy charge\nQ / RMB  Draw bow; release to fire\nSpace  Dodge · E  Interact\nF  Lock on · Z / X or wheel  Switch target\n1–4  Ranged slot · R  Restart\nF3  Debug · F4  Camera shake\n\nFull charge releases once automatically."
	return (
		"Left stick  Move / aim · Right stick  Look\n%s  Sword · %s  Dodge\n%s  Hold for heavy · %s then %s  Roll attack\n%s  Aim + %s  Hold to draw; release to fire\n%s  Interact · D-pad  Ranged slot\n%s  Lock on · flick right stick  Switch target\n%s / touchpad  Menu\n\nFull charge releases once automatically."
		% [
			prompt("light"),
			prompt("dodge"),
			prompt("heavy"),
			prompt("dodge"),
			prompt("heavy"),
			prompt("bow_aim"),
			prompt("bow_shoot"),
			prompt("interact"),
			prompt("lock_on"),
			prompt("pause")
		]
	)


func rich_text(text: String) -> String:
	if kind != "controller" or controller_family != "playstation":
		return text
	for symbol in PLAYSTATION_ICONS:
		text = text.replace(
			symbol, "[img=24x24]res://assets/ui/controller/ps_%s.svg[/img]" % PLAYSTATION_ICONS[symbol]
		)
	for trigger in ["L1", "R1", "L2", "R2"]:
		text = text.replace(
			trigger, "[img=32x24]res://assets/ui/controller/ps_%s.svg[/img]" % trigger.to_lower()
		)
	return text
