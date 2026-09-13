extends "res://tests/forest_replay.gd"
## Native interactions, editable multi-page Resources, facing, prompts and modal input handoff.
var completed_count := 0


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func tap_key(code: Key) -> void:
	key(code, true)
	await step(3)
	key(code, false)
	await step(3)


func button(index: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)


func tap_button(index: JoyButton) -> void:
	button(index, true)
	await step(3)
	button(index, false)
	await step(3)


func faces_reader(keeper: Node3D) -> bool:
	var direction := (p.global_position - keeper.global_position).normalized()
	return (-keeper.get_node("CharacterVisual").global_basis.z).dot(direction) > .98


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/forest")
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	render_cap = Engine.max_fps
	for target in get_tree().get_nodes_in_group("damageable"):
		target.disabled = true
	p.respawn(Vector3(-.7, 0, -20.5))
	p.use_test_input = false
	arena.reset_camera()
	InputRouter.kind = "keyboard"
	var keeper := arena.get_node("ForestKeeper")
	var interaction := keeper.get_node("Conversation") as DialogueInteractable
	interaction.conversation_finished.connect(func(_actor): completed_count += 1)
	var pill := arena.get_node("HUD/Root/InteractionPrompt")
	await step(150)
	check("nearby NPC selected through its own body", p.interaction.target == interaction)
	check("NPC turns to the reader", faces_reader(keeper))
	check("world prompt appears beside the player", pill.visible and pill.modulate.a > .99)
	check("prompt is editable per object", interaction.prompt == "Praten")
	interaction.prompt = "Een praatje maken"
	await step(4)
	check(
		"custom prompt appears without code changes",
		pill.get_node("Margin/Row/Action").text == "Een praatje maken"
	)
	interaction.prompt = "Praten"
	await step(8)
	await capture("dialogue_prompt")
	p.respawn(Vector3(1, 0, -18.8))
	var old_angle: float = keeper.get_node("CharacterVisual").global_rotation.y
	await step(1)
	var new_angle: float = keeper.get_node("CharacterVisual").global_rotation.y
	check(
		"NPC look turns smoothly without snapping",
		absf(angle_difference(old_angle, new_angle)) < .25
	)
	await step(120)
	check("NPC follows a changed approach direction", faces_reader(keeper))
	await tap_key(KEY_E)
	check(
		"E starts the saved complete conversation", Dialogue.active and Dialogue.lines.size() == 3
	)
	var stopped_position := p.position
	await step(25)
	check(
		"dialogue pauses gameplay without opening pause menu",
		GameClock.paused and not arena.get_node("HUD/Root/PausePanel").visible
	)
	check("interaction prompt hides during conversation", not pill.visible)
	check(
		"text reveals progressively",
		(
			Dialogue.body.visible_characters > 0
			and Dialogue.body.visible_characters < Dialogue.body.get_total_character_count()
		)
	)
	key(KEY_W, true)
	await step(30)
	key(KEY_W, false)
	check("movement stays blocked while reading", p.position.is_equal_approx(stopped_position))
	await tap_key(KEY_ENTER)
	check(
		"first confirm finishes current text",
		(
			Dialogue.line_index == 0
			and Dialogue.body.visible_characters == Dialogue.body.get_total_character_count()
		)
	)
	await capture("dialogue_npc")
	await tap_key(KEY_ENTER)
	check("next confirm advances to next authored text block", Dialogue.line_index == 1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	Input.parse_input_event(click)
	await step(2)
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await step(2)
	check(
		"mouse click can reveal text",
		Dialogue.body.visible_characters == Dialogue.body.get_total_character_count()
	)
	check(
		"example dialogue fits its text area",
		Dialogue.body.get_content_height() <= Dialogue.body.size.y,
		[Dialogue.body.get_content_height(), Dialogue.body.size.y]
	)
	await capture("dialogue_direction")
	await tap_button(JOY_BUTTON_A)
	check("controller cross advances dialogue", Dialogue.line_index == 2)
	await tap_button(JOY_BUTTON_A)
	var attacks_before := p.attacks_started.size()
	await tap_button(JOY_BUTTON_A)
	await step(20)
	check(
		"last page closes and emits completion once", not Dialogue.active and completed_count == 1
	)
	check(
		"confirm does not become dodge or attack",
		p.state == "locomotion" and p.attacks_started.size() == attacks_before
	)
	check("gameplay resumes after conversation", not GameClock.paused)
	await tap_button(JOY_BUTTON_Y)
	check("triangle starts a repeatable conversation", Dialogue.active and Dialogue.line_index == 0)
	await tap_button(JOY_BUTTON_B)
	await step(16)
	check(
		"circle cancels without firing bow",
		not Dialogue.active and not p.bow.active() and p.state == "locomotion"
	)
	check("cancel does not emit completion", completed_count == 1)
	p.respawn(Vector3(5.5, 0, -21.2))
	arena.reset_camera()
	await step(120)
	check(
		"sign uses same interaction system",
		p.interaction.target == arena.get_node("Waymarker/Conversation")
	)
	await tap_key(KEY_E)
	await tap_key(KEY_ENTER)
	var sign_data: DialogueConversation = arena.get_node("Waymarker/Conversation").conversation
	var first_sign_line: DialogueLine
	var sign_line_count := 0
	for line in sign_data.lines:
		if line != null and not line.text.strip_edges().is_empty():
			sign_line_count += 1
			if first_sign_line == null:
				first_sign_line = line
	var sign_speaker := (
		first_sign_line.speaker if not first_sign_line.speaker.is_empty() else sign_data.speaker
	)
	check(
		"sign presents its own speaker and text",
		(
			Dialogue.active
			and Dialogue.speaker_label.text == sign_speaker
			and Dialogue.body.text == first_sign_line.text
			and Dialogue.lines.size() == sign_line_count
		)
	)
	await capture("dialogue_sign")
	await tap_key(KEY_ESCAPE)
	check(
		"escape dismisses dialogue without opening pause",
		not Dialogue.active and not GameClock.paused
	)
	# World geometry must still occlude interactions even though the target body is ignored.
	p.respawn(Vector3(7.5, 0, -22.5))
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(.2, 2, 2)
	shape.shape = box
	wall.add_child(shape)
	arena.add_child(wall)
	wall.position = Vector3(6.5, .7, -22.5)
	await step(12)
	check("wall blocks sign interaction", p.interaction.target == null)
	wall.queue_free()
	p.respawn(Vector3(-.7, 0, -20.5))
	arena.reset_camera()
	await step(20)
	await tap_key(KEY_E)
	arena.get_node("HUD")._controller_disconnected()
	await step(8)
	check(
		"controller disconnect replaces conversation with pause",
		not Dialogue.active and GameClock.paused and arena.get_node("HUD/Root/PausePanel").visible
	)
	arena.get_node("HUD")._resume()
	await step(8)
	await tap_key(KEY_E)
	arena.restart()
	await step(10)
	check(
		"restart clears dialogue and restores control",
		not Dialogue.active and not GameClock.paused and p.state == "locomotion"
	)
	var report := {
		"cap": render_cap,
		"checks": results,
		"failures": failures,
		"render_frames": Engine.get_frames_drawn() - initial_render_frame
	}
	FileAccess.open("res://captures/forest/dialogue_checks.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("DIALOGUE_REPLAY_RESULT ", JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
