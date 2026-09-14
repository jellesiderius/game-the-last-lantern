extends Node


## Explicit offline render of all registered thumbnail resources.
func _ready() -> void:
	get_window().position = Vector2i(80, 80)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_window().grab_focus()
	call_deferred("run")


func run() -> void:
	var initial := Engine.get_frames_drawn()
	var seen := {}
	for kit in AreaSet.discover():
		for asset in kit.assets:
			if asset == null or seen.has(asset.id):
				continue
			seen[asset.id] = true
			var path := "res://assets/editor/level_builder/" + String(asset.id) + ".res"
			var texture := await LevelAssetThumbnails.generate(asset.scene, self, path)
			if texture:
				asset.thumbnail = texture
				ResourceSaver.save(asset, asset.resource_path)
			print("ASSET_PREVIEW ", asset.id, " ", texture != null)
	print("PREVIEW_RENDER_FRAMES ", Engine.get_frames_drawn() - initial)
	get_tree().quit()
