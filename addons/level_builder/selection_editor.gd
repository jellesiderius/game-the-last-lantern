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
			if (
				node is LevelTerrain
				or node is LevelTerrace
				or node is LevelRamp
				or node is LevelBridge
				or node is LevelDoor
			):
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
	if target is LevelDoor:
		_door_controls()
		return
	if target is LevelBridge:
		var row := HBoxContainer.new()
		var caption := Label.new()
		caption.text = "Booghoogte"
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(caption)
		var height := SpinBox.new()
		height.max_value = LevelTerrain.MAX_HEIGHT
		height.step = LevelTerrain.HEIGHT_STEP
		height.suffix = "m"
		height.value = target.arch_height
		height.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		height.value_changed.connect(set_arch_height)
		row.add_child(height)
		add_child(row)
		return
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


## Where the selected door leads, its arrival point there, and quick ways to link it.
func _door_controls() -> void:
	var door := target as LevelDoor
	var summary := Label.new()
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = (
		"Gaat naar: " + door.target_scene.get_file().get_basename()
		if not door.target_scene.is_empty()
		else "Nog niet verbonden."
	)
	add_child(summary)
	for field in [["style", plugin.DOOR_STYLES, "Stijl"], ["light", plugin.DOOR_LIGHTS, "Licht"]]:
		var picker := OptionButton.new()
		picker.tooltip_text = field[2]
		for title in field[1]:
			picker.add_item(field[2] + ": " + title)
		picker.select(door.get(field[0]))
		picker.item_selected.connect(func(index): plugin._set_door_property(door, field[0], index))
		add_child(picker)
	if not door.target_scene.is_empty():
		var spawns: Array[StringName] = plugin._scene_spawn_ids(door.target_scene)
		if not spawns.is_empty():
			var picker := OptionButton.new()
			picker.fit_to_longest_item = false
			picker.clip_text = true
			for id in spawns:
				picker.add_item("Aankomst: " + String(id))
				if id == door.target_spawn:
					picker.select(picker.item_count - 1)
			picker.item_selected.connect(
				func(index): plugin._set_door_link(door, door.target_scene, spawns[index])
			)
			add_child(picker)
		_action("Open doelscene", func(): EditorInterface.open_scene_from_path(door.target_scene))
	_action(
		"Kies bestaande scene…",
		func():
			plugin.link_door = door
			plugin.link_dialog.popup_centered_ratio(.6)
	)
	_action(
		"Nieuwe scene erachter…",
		func():
			plugin.room_door = door
			plugin.room_name.text = ""
			plugin.room_dialog.popup_centered()
			plugin.room_name.grab_focus()
	)


func _action(title: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	add_child(button)


func set_arch_height(value: float) -> void:
	if not is_instance_valid(target) or not target is LevelBridge:
		return
	var undo := plugin.get_undo_redo()
	undo.create_action("Brugboog", UndoRedo.MERGE_ENDS, target)
	undo.add_do_property(target, "arch_height", value)
	undo.add_undo_property(target, "arch_height", target.arch_height)
	undo.commit_action()


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
