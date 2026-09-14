extends Node
## Selection persists across level restart; no character-specific combat logic lives here.
var characters: Array[CharacterDefinition] = [preload("res://settings/characters/red_panda.tres")]
var selected_character: CharacterDefinition
## The live player while it is inside the tree. Cheaper and clearer than a group lookup per tick.
var player: PlayerCharacter


func _init() -> void:
	selected_character = characters[0]
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--character="):
			var id := arg.trim_prefix("--character=")
			if not select_character(id) and id in ["crow", "capybara"]:
				# Historical profiles remain available only to explicit regression launches.
				selected_character = load("res://settings/characters/%s.tres" % id)


func select_character(id: String) -> bool:
	for character in characters:
		if character.id == id:
			selected_character = character
			return true
	return false


func _ready() -> void:
	if "--selection-replay" in OS.get_cmdline_user_args():
		get_tree().root.call_deferred("add_child", load("res://tests/selection_replay.gd").new())
