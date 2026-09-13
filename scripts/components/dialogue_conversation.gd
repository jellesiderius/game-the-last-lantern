class_name DialogueConversation
extends Resource
## Edit, add and reorder Lines in the Inspector; the same resource can be reused anywhere.
@export var speaker := ""
@export var lines: Array[DialogueLine] = []
@export_range(0, 100, 1, "suffix:letters/s") var letters_per_second := 42.0


func has_content() -> bool:
	for line in lines:
		if line != null and not line.text.strip_edges().is_empty():
			return true
	return false
