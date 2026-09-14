extends Control
## Saved layout and button template; new options are Resources with independent action IDs.
signal option_selected(id: StringName)
@export var options: Array[RestMenuOption] = []
var closing := false
var busy := false
var message_age := 0.0
var transient_message := false
@onready var panel: PanelContainer = $Panel
@onready var buttons: VBoxContainer = $Panel/Margin/Column/Options
@onready var status: Label = $Panel/Margin/Column/Status
const BUTTON := preload("res://scenes/ui/RestMenuButton.tscn")


func _ready() -> void:
	hide()
	option_selected.connect(Checkpoints.menu_action)
	for entry in options:
		var button := BUTTON.instantiate() as Button
		button.name = String(entry.id)
		button.text = entry.label
		buttons.add_child(button)
		button.pressed.connect(
			func():
				if not closing and not busy:
					option_selected.emit(entry.id)
		)
		button.mouse_entered.connect(button.grab_focus)
	for i in buttons.get_child_count():
		var button := buttons.get_child(i) as Button
		button.focus_neighbor_top = button.get_path_to(
			buttons.get_child(posmod(i - 1, buttons.get_child_count()))
		)
		button.focus_neighbor_bottom = button.get_path_to(
			buttons.get_child((i + 1) % buttons.get_child_count())
		)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var factor := minf(1, size.y / 850.0)
	panel.scale = Vector2.ONE * factor
	panel.position = Vector2(size.x - 500 * factor, maxf(24, (size.y - 470 * factor) * .5))


func open(location: String) -> void:
	closing = false
	set_busy(false)
	$Panel/Margin/Column/Location.text = location
	show_message("", false)
	show()
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, .2).set_trans(Tween.TRANS_SINE)
	buttons.get_node("rest").grab_focus()


func show_message(message: String, success: bool) -> void:
	status.text = message
	status.tooltip_text = message
	status.modulate = Color("dbc697") if success else Color("edb39c")
	message_age = 0.0
	transient_message = success


func _process(delta: float) -> void:
	if not visible:
		return
	InputRouter.block_gameplay_input()
	message_age += delta
	if transient_message and message_age > 2.3:
		status.modulate.a = maxf(0.0, 1.0 - (message_age - 2.3) / .3)


func _unhandled_input(event: InputEvent) -> void:
	if (
		visible
		and not closing
		and not busy
		and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"))
	):
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if closing or busy:
		return
	closing = true
	InputRouter.block_gameplay_input()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, .16)
	await tween.finished
	hide()
	Checkpoints.cancel_rest()


func set_busy(value: bool) -> void:
	busy = value
	for button: Button in buttons.get_children():
		button.disabled = value
	if not value and visible:
		buttons.get_node("rest").grab_focus()
