@tool
class_name AreaSet
extends Resource
## Art kit, independent of a world's identity, save data and gameplay.
@export var id: StringName
@export var display_name := "Nieuwe areaset"
@export var catalog_only := false
@export_multiline var description := ""
@export var assets: Array[LevelAsset] = []
@export_group("Ground")
@export var ground_color := Color("52664b")
@export var path_color := Color("bca17a")
@export var cliff_color := Color("64676a")
@export var ground_texture: Texture2D
@export var path_texture: Texture2D
@export_range(.1, 20, .1) var texture_scale := 3.0
@export_group("Lighting")
@export var background_color := Color("203133")
@export var ambient_color := Color("a4b8b1")
@export_range(0, 2, .05) var ambient_energy := .55
@export var sun_color := Color("ffe2b8")
@export_range(0, 3, .05) var sun_energy := 1.0
@export var fog_color := Color("384f48")
@export_range(0, .05, .001) var fog_density := .001


static func discover() -> Array[AreaSet]:
	var found: Array[AreaSet] = []
	if not DirAccess.dir_exists_absolute("res://settings/area_sets"):
		return found
	for file in DirAccess.get_files_at("res://settings/area_sets"):
		file = file.trim_suffix(".remap")
		if file.ends_with(".tres"):
			var item := load("res://settings/area_sets/" + file) as AreaSet
			if item:
				found.append(item)
	return found
