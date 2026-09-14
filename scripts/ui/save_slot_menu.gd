extends Control
signal closed
var busy := false
var confirming := -1
var new_game := true
var slots: Array[Control] = []
@onready var panel: Control = $Composition
@onready var status: Label = $Composition/Status


func _ready() -> void:
	hide()
	for i in SaveSchema.SLOT_COUNT:
		var row := $Composition/Slots.get_child(i) as Control
		slots.append(row)
		row.get_node("Select").pressed.connect(_select.bind(i))
		row.get_node("Delete").pressed.connect(_ask_delete.bind(i))
		for button: Button in [row.get_node("Select"), row.get_node("Delete")]:
			button.mouse_entered.connect(button.grab_focus)
	$Composition/Back.pressed.connect(close)
	$Confirm/Panel/Column/Cancel.pressed.connect(_cancel_delete)
	$Confirm/Panel/Column/Delete.pressed.connect(_confirm_delete)
	var confirm_buttons: Array[Control] = [
		$Confirm/Panel/Column/Cancel, $Confirm/Panel/Column/Delete
	]
	for i in confirm_buttons.size():
		var button := confirm_buttons[i]
		var other := button.get_path_to(confirm_buttons[1 - i])
		button.focus_next = other
		button.focus_previous = other
		button.focus_neighbor_top = other
		button.focus_neighbor_bottom = other
		button.focus_neighbor_left = other
		button.focus_neighbor_right = other
	Checkpoints.arrival_failed.connect(_failure)
	resized.connect(_fit)
	_fit()


func _fit() -> void:
	var factor := minf(size.x / 1280.0, size.y / 800.0)
	panel.scale = Vector2.ONE * factor
	panel.position = (size - Vector2(1280, 800) * factor) * .5


func open(for_new_game: bool) -> void:
	new_game = for_new_game
	busy = false
	confirming = -1
	$Confirm.hide()
	refresh()
	show()
	modulate.a = 0
	create_tween().tween_property(self, "modulate:a", 1.0, .2).set_trans(Tween.TRANS_SINE)
	slots[SaveStore.preferred_slot(new_game)].get_node("Select").grab_focus()


func refresh() -> void:
	var empty_count := 0
	var focusable: Array[Control] = []
	for i in SaveSchema.SLOT_COUNT:
		var summary := SaveStore.inspect_slot(i)
		var row := slots[i]
		row.get_node("Select/Slot").text = "Spel %d" % (i + 1)
		row.get_node("Delete").visible = summary.state != "empty"
		focusable.append(row.get_node("Select"))
		if summary.state != "empty":
			focusable.append(row.get_node("Delete"))
		if summary.state == "filled":
			row.get_node("Select/Location").text = summary.data.checkpoint.location
			row.get_node("Select/Details").text = (
				"%s  speeltijd     ·     %d  levens"
				% [
					SaveSchema.time_label(summary.data.play_seconds),
					int(summary.data.display_lives)
				]
			)
			row.get_node("Select/State").text = (
				"Herstelkopie beschikbaar" if summary.get("recovered", false) else "Verder spelen"
			)
		elif summary.state == "empty":
			empty_count += 1
			row.get_node("Select/Location").text = "Nieuw spel"
			row.get_node("Select/Details").text = "Een nieuw avontuur begint hier"
			row.get_node("Select/State").text = "Leeg slot"
		else:
			row.get_node("Select/Location").text = "Save niet beschikbaar"
			row.get_node("Select/Details").text = "De bestanden blijven behouden"
			row.get_node("Select/State").text = "Kan niet laden"
	focusable.append($Composition/Back)
	for i in focusable.size():
		focusable[i].focus_next = focusable[i].get_path_to(focusable[(i + 1) % focusable.size()])
		focusable[i].focus_previous = focusable[i].get_path_to(
			focusable[posmod(i - 1, focusable.size())]
		)
	for i in slots.size():
		var select: Control = slots[i].get_node("Select")
		select.focus_neighbor_top = select.get_path_to(
			slots[posmod(i - 1, slots.size())].get_node("Select")
		)
		select.focus_neighbor_bottom = select.get_path_to(
			slots[(i + 1) % slots.size()].get_node("Select")
		)
		select.focus_neighbor_right = (
			select.get_path_to(slots[i].get_node("Delete"))
			if slots[i].get_node("Delete").visible
			else NodePath("")
		)
		var remove: Control = slots[i].get_node("Delete")
		remove.focus_neighbor_left = remove.get_path_to(select)
	status.text = (
		"Alle slots zijn bezet. Verwijder eerst een spel om opnieuw te beginnen."
		if new_game and empty_count == 0
		else "Kies een spel om je reis te beginnen of verder te gaan."
	)


func _select(slot: int) -> void:
	if busy or confirming >= 0:
		return
	busy = true
	InputRouter.block_gameplay_input()
	if not Checkpoints.start_slot(slot):
		busy = false


func _failure(message: String) -> void:
	if not visible:
		return
	busy = false
	status.text = message


func _ask_delete(slot: int) -> void:
	if busy or confirming >= 0:
		return
	confirming = slot
	$Confirm/Panel/Column/Message.text = (
		"Spel %d verwijderen?\nDe voortgang van dit spel gaat verloren." % (slot + 1)
	)
	$Confirm.show()
	_set_rows_enabled(false)
	$Confirm/Panel/Column/Cancel.grab_focus()


func _cancel_delete() -> void:
	var slot := confirming
	confirming = -1
	$Confirm.hide()
	_set_rows_enabled(true)
	if slot >= 0:
		slots[slot].get_node("Select").grab_focus()


func _confirm_delete() -> void:
	if confirming < 0 or busy:
		return
	var slot := confirming
	if SaveStore.delete_slot(slot):
		_cancel_delete()
		refresh()
		slots[slot].get_node("Select").grab_focus()
	else:
		$Confirm/Panel/Column/Message.text = SaveStore.last_error


func _set_rows_enabled(value: bool) -> void:
	for row in slots:
		row.get_node("Select").disabled = not value
		row.get_node("Delete").disabled = not value
	$Composition/Back.disabled = not value


func _unhandled_input(event: InputEvent) -> void:
	if not visible or busy:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if confirming >= 0:
			_cancel_delete()
		else:
			close()
		get_viewport().set_input_as_handled()


func close() -> void:
	if busy:
		return
	busy = true
	InputRouter.block_gameplay_input()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, .16)
	await tween.finished
	hide()
	busy = false
	closed.emit()
