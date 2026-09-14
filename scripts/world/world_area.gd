class_name WorldArea
extends Resource
## Put area resources under settings/areas so placed checkpoints and disk loads discover them.


static func discover() -> Array[WorldArea]:
	var result: Array[WorldArea] = []
	for file in DirAccess.get_files_at("res://settings/areas"):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var resource := load("res://settings/areas/" + file) as WorldArea
			if resource != null:
				result.append(resource)
	return result


@export var code: StringName
@export var display_name := ""
@export_file("*.tscn") var scene_path := ""


func title() -> String:
	return display_name if not display_name.strip_edges().is_empty() else "Onbekende locatie"
