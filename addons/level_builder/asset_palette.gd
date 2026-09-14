@tool
extends ScrollContainer
## GridMap-like asset palette with actual renders and complete wrapping names.
signal item_selected(index: int)
var scene_paths := PackedStringArray()
var grid := GridContainer.new()
var entries: Array[Control] = []
var preview_size := 72.0:
	set(value):
		preview_size = value
		_layout()


class AssetTile:
	extends PanelContainer
	var palette: Control
	var index := 0
	var caption := Label.new()
	var picture := TextureRect.new()

	func _gui_input(event: InputEvent) -> void:
		if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		):
			palette.select(index)
			palette.item_selected.emit(index)
			accept_event()

	func _get_drag_data(_at: Vector2) -> Variant:
		if index >= palette.scene_paths.size():
			return null
		var preview := Label.new()
		preview.text = caption.text
		set_drag_preview(preview)
		return {"type": "files", "files": PackedStringArray([palette.scene_paths[index]])}


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)
	resized.connect(_layout)


func _layout() -> void:
	var editor_scale := EditorInterface.get_editor_scale()
	var cell_width := maxf(136, preview_size + 16) * editor_scale
	grid.columns = maxi(1, int((size.x - 18 * editor_scale) / (cell_width + 8 * editor_scale)))
	for tile in entries:
		tile.custom_minimum_size.x = cell_width
		tile.picture.custom_minimum_size = Vector2(preview_size, preview_size) * editor_scale


func clear() -> void:
	for tile in entries:
		grid.remove_child(tile)
		tile.queue_free()
	entries.clear()


func add_item(title: String, icon: Texture2D = null) -> int:
	var tile := AssetTile.new()
	tile.palette = self
	tile.index = entries.size()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(box)
	tile.picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tile.picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tile.picture.texture = icon
	tile.picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tile.picture)
	tile.caption.text = title
	tile.caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.caption.custom_minimum_size.x = 130 * EditorInterface.get_editor_scale()
	tile.caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tile.caption)
	grid.add_child(tile)
	entries.append(tile)
	_layout()
	return tile.index


func set_item_tooltip(index: int, text: String) -> void:
	entries[index].tooltip_text = text


func set_item_icon(index: int, icon: Texture2D) -> void:
	entries[index].picture.texture = icon


func select(index: int) -> void:
	for i in entries.size():
		var style := StyleBoxFlat.new()
		style.bg_color = Color(.15, .35, .32, .8) if i == index else Color(.15, .15, .16, .6)
		style.content_margin_left = 3
		style.content_margin_right = 3
		style.content_margin_top = 3
		style.content_margin_bottom = 3
		entries[i].add_theme_stylebox_override("panel", style)


func get_item_count() -> int:
	return entries.size()
