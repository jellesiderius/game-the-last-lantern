extends Node3D
## Authored 3D previews and native focus controls; selection supplies data to the shared player.
var starting := false
var choices: Array[CharacterChoice] = []


func _ready() -> void:
	GameClock.reset()
	AttackTokenManager.reset()
	SceneTransit.transition_failed.connect(func(_reason): starting = false)
	for child in $UI/Root/Choices.get_children():
		if child is CharacterChoice:
			choices.append(child)
	var selected_index := 0
	for i in choices.size():
		choices[i].focus_neighbor_left = choices[i].get_path_to(
			choices[posmod(i - 1, choices.size())]
		)
		choices[i].focus_neighbor_right = choices[i].get_path_to(choices[(i + 1) % choices.size()])
		choices[i].focus_entered.connect(_focus.bind(i))
		choices[i].pressed.connect(_start.bind(i))
		choices[i].mouse_entered.connect(choices[i].grab_focus)
		if choices[i].definition.id == GameSession.selected_character.id:
			selected_index = i
	choices[selected_index].grab_focus()
	InputRouter.device_changed.connect(func(_kind): _prompts())
	_prompts()


func _focus(index: int) -> void:
	for i in choices.size():
		choices[i].show_selected(i == index)


func _prompts() -> void:
	$UI/Root/Hint.text = (
		(
			"[center]"
			+ InputRouter.rich_text(
				"Left stick / D-pad  Choose      %s  Begin" % InputRouter.prompt("accept")
			)
			+ "[/center]"
		)
		if InputRouter.kind == "controller"
		else "[center]A / D or arrows  Choose      Enter / Space  Begin[/center]"
	)


func _start(index: int) -> void:
	if starting:
		return
	starting = true
	GameSession.select_character(choices[index].definition.id)
	if not SceneTransit.change_scene("res://scenes/levels/TestArena.tscn"):
		starting = false
