@tool
class_name SurfaceStyle
extends Resource
## Reusable ground appearance, independent of area identity and asset catalogs.
@export var display_name := "Eigen grondmateriaal"
@export var ground_color := Color("52664b"):
	set(value):
		ground_color = value
		emit_changed()
@export var path_color := Color("bca17a"):
	set(value):
		path_color = value
		emit_changed()
@export var cliff_color := Color("64676a"):
	set(value):
		cliff_color = value
		emit_changed()
@export var ground_texture: Texture2D:
	set(value):
		ground_texture = value
		emit_changed()
@export var path_texture: Texture2D:
	set(value):
		path_texture = value
		emit_changed()
@export_range(.1, 20, .1) var texture_scale := 3.0:
	set(value):
		texture_scale = value
		emit_changed()
@export_enum("Effen", "Gras", "Steen", "Aarde") var pattern := 1:
	set(value):
		pattern = value
		emit_changed()


func signature() -> String:
	return str(
		[
			ground_color,
			path_color,
			cliff_color,
			texture_scale,
			pattern,
			ground_texture.resource_path if ground_texture else "",
			path_texture.resource_path if path_texture else ""
		]
	)


static func discover() -> Array[SurfaceStyle]:
	var result: Array[SurfaceStyle] = []
	for name in DirAccess.get_files_at("res://settings/surface_styles"):
		name = name.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var style := load("res://settings/surface_styles/" + name) as SurfaceStyle
			if style:
				result.append(style)
	return result
