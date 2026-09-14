@tool
extends VBoxContainer
## Contextual editing of saved authoring nodes through the editor undo history.
var plugin: EditorPlugin
var target: Node3D
var fields := {}
var values := {}


func refresh() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	fields.clear()
	values.clear()
	target = null
	var selection := EditorInterface.get_selection().get_selected_nodes()
	if selection.size() == 1:
		var node: Node = selection[0]
		while node:
			if (
				node is LevelTerrain
				or node is LevelPath
				or node is LevelTerrace
				or node is LevelRamp
				or node is EnemyPatrol
			):
				target = node
				break
			node = node.get_parent()
	var title := Label.new()
	title.text = "Bewerk: " + String(target.name) if target else "Selecteer grond, plateau of route"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(title)
	if target == null:
		return
	if target is LevelTerrain or target is LevelTerrace or target is LevelRamp:
		_material_controls()
	if target is LevelTerrain:
		_field("Breedte", &"size", 2, 1024, .5, 0)
		_field("Diepte", &"size", 2, 1024, .5, 1)
	elif target is LevelTerrace:
		_field("Hoogte", &"height", 0, 12, .25)
	elif target is LevelRamp:
		_field("Breedte", &"width", .5, 12, .25)
		_field("Beginhoogte", &"start_height", 0, 12, .25)
		_field("Eindhoogte", &"end_height", 0, 12, .25)
		var depth := SpinBox.new()
		depth.min_value = 1
		depth.max_value = 100
		depth.step = .5
		depth.value = 4
		depth.suffix = "m plateau diep"
		add_child(depth)
		var landing := Button.new()
		landing.text = "Plateau aan hoge kant"
		landing.pressed.connect(func(): plugin._add_landing(target, depth.value))
		add_child(landing)
	elif target is LevelPath:
		_field("Padbreedte", &"width", .2, 20, .1)
		_field("Zachte rand", &"edge_softness", .01, 2, .05)
	if target is LevelTerrace and target.connected_ramp():
		var connection := Label.new()
		connection.text = "Hoogte gekoppeld aan " + String(target.connected_ramp().name)
		connection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(connection)
	if target is Path3D:
		if target is LevelRamp:
			var hint := Label.new()
			hint.text = "Sleep de grepen boven de groene lijntjes voor hoogte. Curvepunten verplaatsen de uiteinden in 3D."
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			add_child(hint)
		var edit := Button.new()
		edit.text = "Bewerk curvepunten"
		edit.pressed.connect(edit_points)
		add_child(edit)
	add_child(HSeparator.new())


func _material_controls() -> void:
	var label := Label.new()
	label.text = "Grondmateriaal"
	add_child(label)
	var styles := SurfaceStyle.discover()
	var selector := OptionButton.new()
	selector.fit_to_longest_item = false
	selector.add_item("Van areaset / grond")
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
	custom.text = "Eigen kleuren / texture…"
	custom.pressed.connect(
		func():
			var style: SurfaceStyle
			if target.surface_style:
				style = target.surface_style.duplicate()
			else:
				style = SurfaceStyle.new()
				var source: Resource = plugin._terrain().surface_style
				if source == null:
					source = plugin._terrain().area_set
				for key in [
					"ground_color",
					"path_color",
					"cliff_color",
					"ground_texture",
					"path_texture",
					"texture_scale"
				]:
					style.set(key, source.get(key))
			style.display_name = "Eigen materiaal"
			apply_surface_style(style)
			EditorInterface.edit_resource(style)
	)
	add_child(custom)


func apply_surface_style(style: SurfaceStyle) -> void:
	if not is_instance_valid(target):
		return
	var undo := plugin.get_undo_redo()
	undo.create_action("Kies grondmateriaal", UndoRedo.MERGE_DISABLE, target)
	undo.add_do_property(target, "surface_style", style)
	undo.add_undo_property(target, "surface_style", target.surface_style)
	undo.commit_action()
	refresh.call_deferred()


func _field(
	label: String, property: StringName, low: float, high: float, step: float, axis := -1
) -> void:
	var row := HBoxContainer.new()
	add_child(row)
	var caption := Label.new()
	caption.text = label
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	var spin := SpinBox.new()
	spin.min_value = low
	spin.max_value = high
	spin.allow_greater = true
	spin.step = step
	spin.suffix = "m"
	spin.custom_minimum_size.x = 110 * EditorInterface.get_editor_scale()
	spin.value = target.get(property)[axis] if axis >= 0 else target.get(property)
	row.add_child(spin)
	var key := String(property) + str(axis)
	fields[key] = spin
	values[key] = [property, axis]
	spin.value_changed.connect(func(value): change_value(property, value, axis))


func change_value(property: StringName, value: float, axis := -1) -> void:
	if not is_instance_valid(target):
		return
	var before: Variant = target.get(property)
	var after: Variant = value
	if axis >= 0:
		after = Vector2(before)
		after[axis] = value
	if before == after:
		return
	var undo := plugin.get_undo_redo()
	undo.create_action(
		"Bewerk " + String(target.name) + " " + property, UndoRedo.MERGE_ENDS, target
	)
	undo.add_do_property(target, property, after)
	undo.add_undo_property(target, property, before)
	undo.commit_action()


func edit_points() -> void:
	if not is_instance_valid(target):
		return
	var node := target
	plugin._commit_stroke()
	plugin.mode.select(0)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	EditorInterface.edit_node(node)
	plugin.tools_dock.make_visible()
	(
		plugin
		. _note(
			"Versleep de curvegrepen in 3D. Godots curvebalk voegt punten toe of verwijdert ze. Alle wijzigingen ondersteunen Undo/Redo."
		)
	)


func _process(_delta: float) -> void:
	if not is_instance_valid(target):
		return
	for key in fields:
		var spin: SpinBox = fields[key]
		if spin.get_line_edit().has_focus():
			continue
		var property: StringName = values[key][0]
		var axis: int = values[key][1]
		spin.set_value_no_signal(target.get(property)[axis] if axis >= 0 else target.get(property))
