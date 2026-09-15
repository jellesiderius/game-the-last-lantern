@tool
extends VBoxContainer
## Height and ground material for the selected terrain, plateau or stairs.
## Only the selected node changes; sizes stay in Godot's own Inspector.
var plugin: EditorPlugin
var target: Node3D


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	target = null
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.size() == 1:
		var node: Node = selection[0]
		while node:
			if node is LevelTerrain or node is LevelTerrace or node is LevelRamp:
				target = node
				break
			node = node.get_parent()
	visible = target != null
	if target == null:
		return
	var title := Label.new()
	title.text = String(target.name)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	if target is LevelTerrace:
		var row := HBoxContainer.new()
		var caption := Label.new()
		caption.text = "Hoogte"
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var height := SpinBox.new()
		height.min_value = 0
		height.max_value = LevelTerrain.MAX_HEIGHT
		height.step = LevelTerrain.HEIGHT_STEP
		height.suffix = "m"
		height.value = target.height
		height.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		height.value_changed.connect(set_height)
		row.add_child(height)
		add_child(row)
	var styles := SurfaceStyle.discover()
	var selector := OptionButton.new()
	selector.fit_to_longest_item = false
	selector.clip_text = true
	selector.add_item("Standaard (grond / areaset)")
	for style in styles:
		selector.add_item(style.display_name)
		if target.surface_style == style:
			selector.select(selector.item_count - 1)
	if target.surface_style and not target.surface_style in styles:
		selector.add_item(target.surface_style.display_name)
		styles.append(target.surface_style)
		selector.select(selector.item_count - 1)
	selector.item_selected.connect(
		func(index): apply_surface_style(styles[index - 1] if index > 0 else null)
	)
	add_child(selector)
	var custom := Button.new()
	custom.text = "Eigen kleuren / textures…"
	custom.pressed.connect(
		func():
			var ground: LevelTerrain = target if target is LevelTerrain else target.get_parent()
			var source: SurfaceStyle = (
				target.surface_style if target.surface_style else ground.style_for(null)
			)
			var style := source.duplicate() as SurfaceStyle
			style.display_name = "Eigen materiaal"
			apply_surface_style(style)
			EditorInterface.edit_resource(style)
	)
	add_child(custom)


func set_height(value: float) -> void:
	if not is_instance_valid(target) or not target is LevelTerrace:
		return
	if is_equal_approx(target.height, value):
		return
	var undo := plugin.get_undo_redo()
	undo.create_action("Plateauhoogte", UndoRedo.MERGE_ENDS, target)
	undo.add_do_property(target, "height", value)
	undo.add_undo_property(target, "height", target.height)
	undo.commit_action()


func apply_surface_style(style: SurfaceStyle) -> void:
	if not is_instance_valid(target):
		return
	var undo := plugin.get_undo_redo()
	undo.create_action("Kies grondmateriaal", UndoRedo.MERGE_DISABLE, target)
	undo.add_do_property(target, "surface_style", style)
	undo.add_undo_property(target, "surface_style", target.surface_style)
	undo.commit_action()
	refresh.call_deferred()
