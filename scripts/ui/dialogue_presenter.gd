extends CanvasLayer
## One game-wide conversation presenter, using the existing pause and input fences.
signal started(conversation: DialogueConversation)
signal finished(conversation: DialogueConversation, completed: bool)
var active := false
var conversation: DialogueConversation
var actor: Node3D
var source: Node3D
var owner_scene: Node
var lines: Array[DialogueLine] = []
var line_index := 0
var reveal := 0.0
var age := 0.0
@onready var root: Control = $Root
@onready var panel: PanelContainer = $Root/Panel
@onready var speaker_label: Label = $Root/Panel/Margin/Column/Speaker
@onready var body: RichTextLabel = $Root/Panel/Margin/Column/Text
@onready var next_label: RichTextLabel = $Root/Panel/Margin/Column/Next


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.hide()
	InputRouter.device_changed.connect(func(_kind): _refresh_prompt())


func open(data: DialogueConversation, reader: Node3D, origin: Node3D = null) -> bool:
	if active or GameClock.paused or not is_instance_valid(reader) or data == null:
		return false
	if reader is PlayerCharacter and reader.state not in ["locomotion", "bow_empty"]:
		return false
	lines.clear()
	for line in data.lines:
		if line != null and not line.text.strip_edges().is_empty():
			lines.append(line)
	if lines.is_empty():
		return false
	conversation = data
	actor = reader
	source = origin
	owner_scene = get_tree().current_scene
	active = true
	line_index = 0
	age = 0.0
	_suspend_reader()
	GameClock.paused = true
	root.show()
	panel.modulate.a = 0.0
	_show_line()
	started.emit(conversation)
	return true


func _process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(actor) or get_tree().current_scene != owner_scene:
		close(false)
		return
	age += delta
	panel.modulate.a = smoothstep(0.0, .16, age)
	if conversation.letters_per_second <= 0:
		body.visible_characters = -1
	else:
		reveal += delta * conversation.letters_per_second
		body.visible_characters = mini(int(reveal), body.get_total_character_count())
	_refresh_prompt()


func _input(event: InputEvent) -> void:
	if not active or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close(false)
	elif (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("interact")
		or (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
	):
		advance()
	else:
		return
	get_viewport().set_input_as_handled()


func advance() -> void:
	if not active:
		return
	if body.visible_characters >= 0 and body.visible_characters < body.get_total_character_count():
		reveal = body.get_total_character_count()
		body.visible_characters = int(reveal)
		_refresh_prompt()
		return
	if line_index + 1 == lines.size():
		close(true)
	else:
		line_index += 1
		_show_line()


func close(completed := false) -> void:
	if not active:
		return
	var previous := conversation
	var previous_source := source
	var previous_actor := actor
	active = false
	root.hide()
	_suspend_reader()
	GameClock.paused = false
	conversation = null
	actor = null
	source = null
	lines.clear()
	finished.emit(previous, completed)
	if completed and is_instance_valid(previous_source) and previous_source is DialogueInteractable:
		previous_source.conversation_finished.emit(previous_actor)


func _suspend_reader() -> void:
	if is_instance_valid(actor) and actor.has_method("suspend_controls"):
		actor.suspend_controls()
	InputRouter.block_gameplay_input()


func _show_line() -> void:
	var line := lines[line_index]
	speaker_label.text = line.speaker if not line.speaker.is_empty() else conversation.speaker
	speaker_label.visible = not speaker_label.text.is_empty()
	body.text = line.text
	body.get_v_scroll_bar().value = 0
	reveal = 0.0
	body.visible_characters = -1 if conversation.letters_per_second <= 0 else 0
	_refresh_prompt()


func _refresh_prompt() -> void:
	if not active:
		return
	var revealing := (
		body.visible_characters >= 0 and body.visible_characters < body.get_total_character_count()
	)
	var label := (
		"Tekst tonen"
		if revealing
		else ("Volgende" if line_index + 1 < lines.size() else "Gesprek afronden")
	)
	next_label.text = (
		"[right]"
		+ InputRouter.rich_text("%s  %s   ▾" % [InputRouter.prompt("accept"), label])
		+ "[/right]"
	)
