@tool
extends EditorPlugin
## Thin editor UI over saved scenes and Resources. No runtime generator/autoload.
const PREPARATION = preload("res://addons/level_builder/asset_preparation.gd")
const FACTORY = preload("res://addons/level_builder/level_factory.gd")
const CHECKS = preload("res://addons/level_builder/level_checks.gd")
const PORTAL_INSPECTOR = preload("res://addons/level_builder/portal_inspector.gd")
var dock: VBoxContainer
var bottom_button: Button
var tools_dock: EditorDock
var tools_tabs := TabContainer.new()
var editable_objects := OptionButton.new()
var editable_nodes: Array[Node3D] = []
var checked_terrains := {}
var selection_editor = preload("res://addons/level_builder/selection_editor.gd").new()
var pending_reimports := PackedStringArray()
var toolbar_button: Button
var sets := OptionButton.new()
var search := LineEdit.new()
var category := OptionButton.new()
var selected_name := Label.new()
var palette = preload("res://addons/level_builder/asset_palette.gd").new()
var mode := OptionButton.new()
var radius := SpinBox.new()
var amount := SpinBox.new()
var snap := SpinBox.new()
var status := RichTextLabel.new()
var new_dialog := ConfirmationDialog.new()
var new_name := LineEdit.new()
var new_width := SpinBox.new()
var new_depth := SpinBox.new()
var dimensions_row := HBoxContainer.new()
var source_dialog := EditorFileDialog.new()
var import_dialog := ConfirmationDialog.new()
var import_name := LineEdit.new()
var import_category := LineEdit.new()
var collision_mode := OptionButton.new()
var kit_list: Array[AreaSet] = []
var shown_assets: Array[LevelAsset] = []
var active_asset: LevelAsset
var inspector: EditorInspectorPlugin
var placement_gizmos: EditorNode3DGizmoPlugin
var new_kind := "level"
var import_source := ""
var id_claims := {}
var maintenance_time := 0.0
var last_paint := Vector3.INF
var stroke_nodes: Array[Node3D] = []
var painting := false
var active_curve: Path3D


func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "Level Builder"
	dock.custom_minimum_size = Vector2(0, 220 * EditorInterface.get_editor_scale())
	dock.visibility_changed.connect(
		func():
			if dock.is_visible_in_tree():
				_ensure_panel_height.call_deferred()
	)
	dock.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	dock.add_child(body)
	var library := VBoxContainer.new()
	library.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(library)
	var filters := HBoxContainer.new()
	library.add_child(filters)
	sets.custom_minimum_size.x = 160 * EditorInterface.get_editor_scale()
	sets.fit_to_longest_item = false
	sets.clip_text = true
	filters.add_child(sets)
	sets.item_selected.connect(func(_i): _refresh_palette())
	search.placeholder_text = "Zoek assets of tags…"
	search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filters.add_child(search)
	search.text_changed.connect(func(_text): _refresh_palette(false))
	category.add_item("Alles")
	category.custom_minimum_size.x = 110 * EditorInterface.get_editor_scale()
	category.fit_to_longest_item = false
	category.clip_text = true
	filters.add_child(category)
	category.item_selected.connect(func(_i): _refresh_palette(false))
	palette.preview_size = 72
	palette.custom_minimum_size.y = 110
	palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	library.add_child(palette)
	palette.item_selected.connect(_asset_selected)
	var library_footer := HBoxContainer.new()
	library.add_child(library_footer)
	selected_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_name.text = "Kies een model"
	selected_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	library_footer.add_child(selected_name)
	_button("Asset toevoegen", library_footer, func(): source_dialog.popup_centered_ratio(.65))
	_button("Vernieuwen", library_footer, _refresh_sets)
	# Tools have their own right-hand dock; asset minimum widths cannot displace them.
	tools_dock = EditorDock.new()
	tools_dock.title = "Level tools"
	tools_dock.layout_key = "LanternLevelToolsV2"
	tools_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	tools_dock.icon_name = &"Tools"
	var tools_scroll := ScrollContainer.new()
	tools_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tools_scroll.custom_minimum_size = Vector2(200, 120) * EditorInterface.get_editor_scale()
	tools_dock.add_child(tools_scroll)
	var tools_body := VBoxContainer.new()
	tools_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tools_scroll.add_child(tools_body)
	# Wrapping tab buttons remain visible even in a narrow right sidebar.
	var navigation := HFlowContainer.new()
	tools_body.add_child(navigation)
	var group := ButtonGroup.new()
	for i in 3:
		var tab := Button.new()
		tab.text = ["Bouwen", "Bewerken", "Level"][i]
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = i == 0
		tab.pressed.connect(func(): tools_tabs.current_tab = i)
		tools_tabs.tab_changed.connect(func(current): tab.set_pressed_no_signal(current == i))
		navigation.add_child(tab)
	tools_body.add_child(tools_tabs)
	tools_tabs.tabs_visible = false
	tools_tabs.custom_minimum_size.y = 240 * EditorInterface.get_editor_scale()
	tools_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var tool_box := _tools_page("Bouwen")
	var edit_box := _tools_page("Bewerken")
	var level_box := _tools_page("Level")
	_label("Onderdeel", edit_box)
	editable_objects.fit_to_longest_item = false
	editable_objects.clip_text = true
	edit_box.add_child(editable_objects)
	editable_objects.item_selected.connect(
		func(index):
			if (
				index >= 0
				and index < editable_nodes.size()
				and is_instance_valid(editable_nodes[index])
			):
				EditorInterface.get_selection().clear()
				EditorInterface.get_selection().add_node(editable_nodes[index])
				EditorInterface.edit_node(editable_nodes[index])
				tools_dock.make_visible()
	)
	selection_editor.plugin = self
	edit_box.add_child(selection_editor)
	selection_editor.refresh()
	_label("Gereedschap", tool_box)
	for title in [
		"Selecteren",
		"Asset plaatsen",
		"Begroeiing schilderen",
		"Pad tekenen",
		"Terras tekenen",
		"Patrouille tekenen",
		"Begroeiing wissen",
		"Ramp tekenen",
		"Vloervlak tekenen"
	]:
		mode.add_item(title)
	mode.fit_to_longest_item = false
	mode.clip_text = true
	tool_box.add_child(mode)
	mode.item_selected.connect(_mode_changed)
	radius.min_value = .25
	radius.max_value = 12
	radius.step = .25
	radius.value = 2
	radius.suffix = "m"
	amount.min_value = 1
	amount.max_value = 40
	amount.value = 6
	amount.suffix = "per stempel"
	snap.min_value = 0
	snap.max_value = 4
	snap.step = .25
	snap.suffix = "m (0 = vrij)"
	_label("Penseelgrootte", tool_box)
	tool_box.add_child(radius)
	_label("Aantal", tool_box)
	tool_box.add_child(amount)
	_label("Rasterstap", tool_box)
	tool_box.add_child(snap)
	_button("Nieuwe curve", tool_box, _new_curve)
	_button("Nieuwe encounter", tool_box, _new_encounter)
	_button(
		"Selecteren (Esc)",
		tool_box,
		func():
			_commit_stroke()
			mode.select(0)
			active_curve = null
	)
	_button("Nieuw level", level_box, func(): _new_dialog("level"))
	_button("Nieuwe areaset", level_box, func(): _new_dialog("set"))
	_button(
		"Bewerk areaset",
		level_box,
		func():
			if _kit():
				EditorInterface.edit_resource(_kit())
	)
	_button("Pas areaset toe", level_box, _apply_kit)
	_button(
		"Bewerk grondafmetingen",
		level_box,
		func():
			var terrain := _terrain()
			if terrain:
				EditorInterface.get_selection().clear()
				EditorInterface.get_selection().add_node(terrain)
				tools_tabs.current_tab = 1
	)
	_button("Controleer level", level_box, _validate_level)
	_button("Speel level", level_box, _play_level)
	status.custom_minimum_size.y = 80 * EditorInterface.get_editor_scale()
	status.fit_content = false
	status.bbcode_enabled = false
	tools_body.add_child(status)
	add_dock(tools_dock)
	bottom_button = add_control_to_bottom_panel(dock, "Level Builder")
	toolbar_button = Button.new()
	toolbar_button.text = "Level Builder"
	toolbar_button.pressed.connect(_show_builder)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar_button)
	add_tool_menu_item("Level Builder openen", _show_builder)
	_setup_dialogs()
	inspector = PORTAL_INSPECTOR.new()
	add_inspector_plugin(inspector)
	placement_gizmos = preload("res://addons/level_builder/placement_gizmos.gd").new()
	placement_gizmos.undo_redo = get_undo_redo()
	add_node_3d_gizmo_plugin(placement_gizmos)
	scene_changed.connect(_scene_changed)
	EditorInterface.get_selection().selection_changed.connect(selection_editor.refresh)
	EditorInterface.get_resource_filesystem().resources_reimported.connect(_reimported)
	set_input_event_forwarding_always_enabled()
	_refresh_sets()
	if "--level-builder-editor-checks" in OS.get_cmdline_user_args():
		_run_editor_checks.call_deferred()
	_note(
		"Kies een asset en klik in het level. Paden en terrassen: klik punten; Esc om af te ronden. Versleep punten met Godots curvegrepen."
	)


func _exit_tree() -> void:
	_commit_stroke()
	remove_inspector_plugin(inspector)
	remove_node_3d_gizmo_plugin(placement_gizmos)
	if EditorInterface.get_resource_filesystem().resources_reimported.is_connected(_reimported):
		EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_reimported)
	EditorInterface.get_selection().selection_changed.disconnect(selection_editor.refresh)
	remove_tool_menu_item("Level Builder openen")
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar_button)
	toolbar_button.queue_free()
	remove_dock(tools_dock)
	tools_dock.queue_free()
	remove_control_from_bottom_panel(dock)
	dock.queue_free()
	new_dialog.queue_free()
	source_dialog.queue_free()
	import_dialog.queue_free()


func _run_editor_checks() -> void:
	var checks = load("res://tests/level_builder_editor_checks.gd").new()
	await checks.run(self)


func _handles(object: Object) -> bool:
	return object is Node3D


func _show_builder() -> void:
	EditorInterface.set_distraction_free_mode(false)
	make_bottom_panel_item_visible(dock)
	tools_dock.make_visible()
	_ensure_panel_height.call_deferred()


func _ensure_panel_height() -> void:
	# Godot restores the previous tab height, sometimes smaller than its contents.
	# Only grow a too-small builder; retain any larger height chosen by the user.
	if not is_instance_valid(dock) or not dock.is_visible_in_tree():
		return
	var desired := minf(
		260 * EditorInterface.get_editor_scale(), get_viewport().get_visible_rect().size.y * .45
	)
	if dock.size.y >= desired - 8:
		return
	var ancestor := dock.get_parent()
	while ancestor:
		if ancestor is SplitContainer and ancestor.vertical:
			ancestor.split_offset = -int(desired)
			break
		ancestor = ancestor.get_parent()


func _process(delta: float) -> void:
	maintenance_time -= delta
	if maintenance_time > 0:
		return
	maintenance_time = .5
	_refresh_editable_objects()
	var ground := _terrain()
	if ground and not checked_terrains.has(ground.get_instance_id()):
		checked_terrains[ground.get_instance_id()] = true
		ground.request_bake()
	var root := EditorInterface.get_edited_scene_root()
	if root and CHECKS.ensure_enemy_ids(root, id_claims):
		EditorInterface.mark_scene_as_unsaved()


func _refresh_editable_objects() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var current: Array[Node3D] = []
	if root:
		for node in CHECKS.nodes(root):
			if (
				node is LevelTerrain
				or node is LevelPath
				or node is LevelTerrace
				or node is LevelRamp
				or node is EnemyPatrol
			):
				current.append(node)
	if current != editable_nodes:
		editable_nodes = current
		editable_objects.clear()
		for node in editable_nodes:
			editable_objects.add_item(String(node.name))
	if is_instance_valid(selection_editor.target) and selection_editor.target in editable_nodes:
		editable_objects.select(editable_nodes.find(selection_editor.target))


func _save_external_data() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root:
		CHECKS.ensure_enemy_ids(root, id_claims)
		for node in CHECKS.nodes(root):
			if node is LevelTerrain:
				node.bake()


func _tools_page(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	tools_tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	scroll.add_child(box)
	return box


func _label(text: String, parent: Node) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _button(title: String, parent: Node, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)


func _note(message: String) -> void:
	status.text = message


func _kit() -> AreaSet:
	return (
		kit_list[sets.selected] if sets.selected >= 0 and sets.selected < kit_list.size() else null
	)


func _refresh_sets() -> void:
	var selected := _kit()
	kit_list.clear()
	for kit in AreaSet.discover():
		if not kit.catalog_only:
			kit_list.append(kit)
	sets.clear()
	for kit in kit_list:
		sets.add_item(kit.display_name)
	if selected in kit_list:
		sets.select(kit_list.find(selected))
	_refresh_palette()
	if not pending_reimports.is_empty():
		_reimported.call_deferred(pending_reimports.duplicate())


func _all_assets() -> Array[LevelAsset]:
	var result: Array[LevelAsset] = []
	if _kit():
		result.append_array(_kit().assets)
	for shared in AreaSet.discover():
		if shared.catalog_only:
			for asset in shared.assets:
				if not asset in result:
					result.append(asset)
	return result


func _refresh_palette(reset_categories := true) -> void:
	var assets := _all_assets()
	if reset_categories:
		category.clear()
		category.add_item("Alles")
		var categories := PackedStringArray()
		for asset in assets:
			if asset and not asset.category in categories:
				categories.append(asset.category)
		categories.sort()
		for name in categories:
			category.add_item(name)
	palette.clear()
	palette.scene_paths.clear()
	shown_assets.clear()
	for asset in assets:
		if asset == null or asset.scene == null:
			continue
		if category.selected > 0 and category.get_item_text(category.selected) != asset.category:
			continue
		if (
			not search.text.is_empty()
			and not (
				search.text.to_lower()
				in (asset.display_name + " " + " ".join(asset.tags)).to_lower()
			)
		):
			continue
		shown_assets.append(asset)
		palette.scene_paths.append(asset.scene.resource_path)
		var icon := asset.thumbnail
		if icon == null:
			icon = EditorInterface.get_base_control().get_theme_icon(
				"Area3D" if asset.id == &"portal" else "MeshInstance3D", "EditorIcons"
			)
		var index: int = palette.add_item(asset.display_name, icon)
		palette.set_item_tooltip(
			index, asset.display_name + "\n" + asset.category + "\n" + asset.scene.resource_path
		)
		if asset.thumbnail == null:
			EditorInterface.get_resource_previewer().queue_resource_preview(
				asset.scene.resource_path, self, "_thumbnail_ready", asset.id
			)
		if active_asset == asset:
			palette.select(index)


func _thumbnail_ready(_path: String, preview: Texture2D, _small: Texture2D, id: Variant) -> void:
	if not is_instance_valid(palette) or preview == null:
		return
	for i in shown_assets.size():
		if shown_assets[i].id == id:
			palette.set_item_icon(i, preview)


func _asset_selected(index: int) -> void:
	active_asset = shown_assets[index]
	selected_name.text = active_asset.display_name
	mode.select(1)
	tools_tabs.current_tab = 0
	tools_dock.make_visible()
	_mode_changed(1)
	_note(
		(
			active_asset.display_name
			+ ": klik om te plaatsen. Botsing en gedrag reizen met het object mee."
		)
	)


func _scene_changed(root: Node) -> void:
	_commit_stroke()
	active_curve = null
	mode.select(0)
	if root and CHECKS.has_property(root, &"area_set"):
		var kit: AreaSet = root.get("area_set")
		if kit in kit_list:
			sets.select(kit_list.find(kit))
			_refresh_palette()


func _mode_changed(_index: int) -> void:
	_commit_stroke()
	last_paint = Vector3.INF
	if mode.selected in [3, 4, 5, 7, 8]:
		var selected := EditorInterface.get_selection().get_selected_nodes()
		active_curve = selected[0] as Path3D if selected.size() == 1 else null
		if not _curve_matches_mode():
			active_curve = null
		_note(
			"Klik punten in de wereld. 'Nieuwe curve' begint een apart pad/terras. Esc stopt tekenen; selecteer de curve om punten en breedte te bewerken."
		)


func _curve_matches_mode() -> bool:
	if not is_instance_valid(active_curve):
		return false
	return (
		(mode.selected == 3 and active_curve is LevelPath)
		or (mode.selected == 4 and active_curve is LevelTerrace)
		or (mode.selected == 5 and active_curve is EnemyPatrol)
		or (mode.selected == 7 and active_curve is LevelRamp)
		or (
			mode.selected == 8
			and active_curve is LevelTerrace
			and is_zero_approx(active_curve.height)
		)
	)


func _terrain() -> LevelTerrain:
	var root := EditorInterface.get_edited_scene_root()
	if root:
		for node in CHECKS.nodes(root):
			if node is LevelTerrain:
				return node
	return null


func _hit(camera: Camera3D, mouse: Vector2) -> Variant:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var ground := _terrain()
	var transform := ground.global_transform if ground else Transform3D.IDENTITY
	var local_origin: Vector3 = transform.affine_inverse() * origin
	var local_direction: Vector3 = transform.basis.inverse() * direction
	var hit: Variant = Plane(Vector3.UP, 0).intersects_ray(local_origin, local_direction)
	var nearest := INF
	var result: Variant = null
	if (
		hit != null
		and (
			ground == null
			or (absf(hit.x) <= ground.size.x / 2 and absf(hit.z) <= ground.size.y / 2)
		)
	):
		result = hit
		nearest = local_origin.distance_squared_to(hit)
	if ground:
		for region in ground.outlines():
			var polygon: PackedVector2Array = region.polygon
			if polygon.size() < 3:
				continue
			var p0 := Vector3(
				polygon[0].x, LevelTerrain.region_height(region, polygon[0]), polygon[0].y
			)
			var p1 := Vector3(
				polygon[1].x, LevelTerrain.region_height(region, polygon[1]), polygon[1].y
			)
			var p2 := Vector3(
				polygon[2].x, LevelTerrain.region_height(region, polygon[2]), polygon[2].y
			)
			var raised: Variant = Plane(p0, p1, p2).intersects_ray(local_origin, local_direction)
			if (
				raised != null
				and Geometry2D.is_point_in_polygon(Vector2(raised.x, raised.z), region.polygon)
			):
				if local_origin.distance_squared_to(raised) < nearest:
					result = raised
					nearest = local_origin.distance_squared_to(raised)
	if result == null:
		return null
	if snap.value > 0:
		result.x = snappedf(result.x, snap.value)
		result.z = snappedf(result.z, snap.value)
	return transform * result


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_commit_stroke()
		mode.select(0)
		active_curve = null
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if mode.selected == 0 or (event is InputEventWithModifiers and event.alt_pressed):
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_commit_stroke()
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		var at: Variant = _hit(camera, event.position)
		if at == null:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if mode.selected in [3, 4, 5, 7, 8]:
			_add_curve_point(at)
		elif mode.selected == 6:
			_erase(at)
		else:
			painting = true
			_stamp(at)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and painting and mode.selected == 2:
		var at: Variant = _hit(camera, event.position)
		if at != null and at.distance_to(last_paint) >= radius.value * .5:
			_stamp(at)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _parent_for(asset: LevelAsset) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	var name := (
		"Enemies"
		if asset.category == "Enemies"
		else "Gameplay" if asset.category == "Gameplay" else "Props"
	)
	return root.get_node_or_null(name) if root.has_node(name) else root


func _stamp(at: Vector3) -> void:
	if active_asset == null:
		_note("Kies eerst een asset uit de bibliotheek.")
		return
	if mode.selected == 2 and not active_asset.scatter_allowed:
		_note(
			"Dit object wordt afzonderlijk geplaatst. Het penseel is voor begroeiing en props met Scatter Allowed."
		)
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var ground := _terrain()
	last_paint = at
	var count := int(amount.value) if mode.selected == 2 else 1
	for i in count:
		var point := at
		if mode.selected == 2:
			var angle := randf() * TAU
			var distance := sqrt(randf()) * radius.value
			point += Vector3(cos(angle), 0, sin(angle)) * distance
			if ground:
				var local := ground.to_local(point)
				if absf(local.x) > ground.size.x / 2 or absf(local.z) > ground.size.y / 2:
					continue
				local.y = 0
				for region in ground.outlines():
					if Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), region.polygon):
						local.y = LevelTerrain.region_height(region, Vector2(local.x, local.z))
				point = ground.to_global(local)
				if _on_path(ground, local):
					continue
			var blocked := false
			for other in _parent_for(active_asset).get_children():
				if (
					other is Node3D
					and other.global_position.distance_to(point) < active_asset.spacing
				):
					blocked = true
					break
			if blocked:
				continue
		var node := active_asset.scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		if node == null:
			continue
		node.name = active_asset.display_name.to_pascal_case()
		_parent_for(active_asset).add_child(node, true)
		node.owner = root
		node.global_position = point
		node.set_meta("level_asset_id", active_asset.id)
		if active_asset.random_yaw:
			node.rotation.y = randf() * TAU
		node.scale *= randf_range(active_asset.scale_range.x, active_asset.scale_range.y)
		if CHECKS.has_property(node, &"persistent_id"):
			node.set("respawn_rule", 1)
		CHECKS.ensure_enemy_ids(root, id_claims)
		stroke_nodes.append(node)
	if mode.selected == 1:
		_commit_stroke()


func _on_path(ground: LevelTerrain, point: Vector3) -> bool:
	for node in ground.get_children():
		if node is LevelPath and node.curve and node.curve.point_count > 0:
			var local: Vector3 = node.transform.affine_inverse() * point
			local.y = 0
			var closest: Vector3 = node.curve.get_closest_point(local)
			if (
				Vector2(local.x, local.z).distance_to(Vector2(closest.x, closest.z))
				< node.width / 2 + active_asset.spacing
			):
				return true
	return false


func _commit_stroke() -> void:
	painting = false
	if stroke_nodes.is_empty():
		return
	var undo := get_undo_redo()
	undo.create_action("Plaats levelassets")
	for node in stroke_nodes:
		if not is_instance_valid(node) or node.get_parent() == null:
			continue
		undo.add_do_method(node.get_parent(), "add_child", node, true)
		undo.add_do_property(node, "owner", node.owner)
		undo.add_undo_method(node.get_parent(), "remove_child", node)
		undo.add_do_reference(node)
	undo.commit_action(false)
	EditorInterface.mark_scene_as_unsaved()
	stroke_nodes.clear()


func _erase(at: Vector3) -> void:
	if active_asset == null or not active_asset.scatter_allowed:
		return
	var undo := get_undo_redo()
	undo.create_action("Wis geschilderde assets")
	for node in _parent_for(active_asset).get_children():
		if (
			node is Node3D
			and node.get_meta("level_asset_id", &"") == active_asset.id
			and node.global_position.distance_to(at) < radius.value
		):
			undo.add_do_method(node.get_parent(), "remove_child", node)
			undo.add_undo_method(node.get_parent(), "add_child", node, true)
			undo.add_undo_property(node, "owner", node.owner)
			undo.add_undo_reference(node)
	undo.commit_action()


func _new_curve() -> void:
	active_curve = null
	if not mode.selected in [3, 4, 5, 7, 8]:
		mode.select(3)
	_note("Klik het eerste punt in het level.")


func _add_curve_point(at: Vector3) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var ground := _terrain()
	if root == null or (mode.selected != 5 and ground == null):
		_note("Maak eerst een level met Terrain via Nieuw level.")
		return
	var undo := get_undo_redo()
	if not _curve_matches_mode() or not active_curve.is_inside_tree():
		active_curve = (
			LevelPath.new()
			if mode.selected == 3
			else (
				LevelTerrace.new()
				if mode.selected in [4, 8]
				else LevelRamp.new() if mode.selected == 7 else EnemyPatrol.new()
			)
		)
		active_curve.name = (
			"Pad"
			if mode.selected == 3
			else (
				"Terras"
				if mode.selected == 4
				else (
					"Vloervlak"
					if mode.selected == 8
					else "Ramp" if mode.selected == 7 else "Patrouille"
				)
			)
		)
		if mode.selected == 8:
			active_curve.height = 0
			active_curve.surface_style = load("res://settings/surface_styles/stone.tres")
		active_curve.curve = Curve3D.new()
		active_curve.curve.resource_local_to_scene = true
		active_curve.curve.bake_interval = .3
		if active_curve is LevelRamp:
			active_curve.points_define_height = true
		var parent: Node = ground if mode.selected != 5 else root.get_node("Routes")
		undo.create_action("Nieuwe levelcurve")
		undo.add_do_method(parent, "add_child", active_curve, true)
		undo.add_do_property(active_curve, "owner", root)
		undo.add_undo_method(parent, "remove_child", active_curve)
		undo.add_do_reference(active_curve)
		undo.commit_action()
	if active_curve is LevelRamp and active_curve.curve.point_count == 2:
		_note(
			"De ramp heeft twee punten. Versleep de uiteinden of kies Nieuwe curve voor een tweede ramp."
		)
		return
	var before := active_curve.curve
	var after := before.duplicate() as Curve3D
	var local := active_curve.to_local(at)
	if active_curve is LevelRamp:
		if before.point_count == 0:
			local.y = maxf(0, local.y)
		else:
			var height := local.y
			local.y = (maxf(0, height) if height > 0 or active_curve.start_height > 0 else 1.5)
	else:
		local.y = 0
	after.add_point(local)
	var attachment := {}
	if active_curve is LevelRamp and after.point_count == 2:
		attachment = RampConnection.find_attachment(active_curve, after, ground)
		if not attachment.is_empty():
			after = attachment.curve
	undo.create_action("Teken curvepunt")
	undo.add_do_property(active_curve, "curve", after)
	undo.add_undo_property(active_curve, "curve", before)
	if not attachment.is_empty():
		undo.add_do_property(active_curve, "width", attachment.width)
		undo.add_undo_property(active_curve, "width", active_curve.width)
		undo.add_do_property(active_curve, "attached_end", attachment.endpoint)
		undo.add_undo_property(active_curve, "attached_end", active_curve.attached_end)
		undo.add_do_property(
			active_curve, "terrace_attachment", active_curve.get_path_to(attachment.terrace)
		)
		undo.add_undo_property(active_curve, "terrace_attachment", active_curve.terrace_attachment)
	undo.commit_action()
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(active_curve)
	EditorInterface.edit_node(active_curve)


func _new_encounter() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var node := LevelEncounter.new()
	node.name = "Encounter"
	var parent := root.get_node_or_null("Gameplay")
	if parent == null:
		parent = root
	var undo := get_undo_redo()
	undo.create_action("Nieuwe encounter")
	undo.add_do_method(parent, "add_child", node, true)
	undo.add_do_property(node, "owner", root)
	undo.add_undo_method(parent, "remove_child", node)
	undo.add_do_reference(node)
	undo.commit_action()
	EditorInterface.edit_node(node)
	_note("Sleep enemies naar Enemies en portals naar Unlock Portals in de Inspector.")


func _add_landing(ramp: LevelRamp, depth: float) -> void:
	if not is_instance_valid(ramp) or ramp.curve == null or ramp.curve.point_count != 2:
		_note("Teken eerst een ramp met twee uiteinden.")
		return
	var ground := ramp.get_parent() as LevelTerrain
	var root := EditorInterface.get_edited_scene_root()
	if ground == null or root == null:
		return
	ramp.ensure_point_heights()
	var endpoint := 1 if ramp.end_height >= ramp.start_height else 0
	var high := ramp.transform * ramp.curve.get_point_position(endpoint)
	var low := ramp.transform * ramp.curve.get_point_position(1 - endpoint)
	var direction := Vector2(high.x - low.x, high.z - low.z).normalized()
	if direction.length_squared() < .1:
		_note("Geef de ramp eerst een lengte in het grondvlak.")
		return
	var center := Vector2(high.x, high.z)
	var side := direction.orthogonal() * ramp.width / 2
	var outline := PackedVector2Array(
		[
			center - side,
			center + side,
			center + side + direction * depth,
			center - side + direction * depth
		]
	)
	for point in outline:
		if absf(point.x) > ground.size.x / 2 or absf(point.y) > ground.size.y / 2:
			_note("Het plateau valt buiten de grond. Kies minder diepte of vergroot eerst Terrain.")
			return
	for region in ground.outlines():
		if region.name == ramp.name:
			continue
		for overlap in Geometry2D.intersect_polygons(outline, region.polygon):
			if LevelTerrain.polygon_area(overlap) > LevelTerrain.EPS:
				_note(
					(
						"Hier ligt al "
						+ String(region.name)
						+ ". Pas dat plateau aan of kies minder diepte."
					)
				)
				return
	var landing := LevelTerrace.new()
	landing.name = String(ramp.name) + "Plateau"
	landing.height = high.y
	landing.curve = Curve3D.new()
	landing.curve.resource_local_to_scene = true
	for point in outline:
		landing.curve.add_point(Vector3(point.x, 0, point.y))
	landing.height_source = NodePath("../" + String(ramp.name))
	landing.height_source_end = endpoint
	var undo := get_undo_redo()
	undo.create_action("Plateau aansluiten op ramp")
	undo.add_do_method(ground, "add_child", landing, true)
	undo.add_do_property(landing, "owner", root)
	undo.add_undo_method(ground, "remove_child", landing)
	undo.add_do_reference(landing)
	undo.commit_action()
	mode.select(0)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(landing)
	EditorInterface.edit_node(landing)
	tools_tabs.current_tab = 1
	tools_dock.make_visible()
	_note(
		"Plateau aangesloten. Hoogte volgt het rampeinde; versleep de plateaupunten om de grond uit te breiden."
	)


func _validate_level() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	_save_external_data()
	var messages := CHECKS.validate(root)
	_note("Levelcontrole geslaagd." if messages.is_empty() else "\n".join(messages))


func _play_level() -> void:
	_commit_stroke()
	_validate_level()
	EditorInterface.save_scene()
	EditorInterface.play_current_scene()


func _apply_kit() -> void:
	var root := EditorInterface.get_edited_scene_root()
	var kit := _kit()
	if root == null or kit == null:
		return
	var undo := get_undo_redo()
	undo.create_action("Pas areaset toe")
	for node in CHECKS.nodes(root):
		if CHECKS.has_property(node, &"area_set"):
			undo.add_do_property(node, "area_set", kit)
			undo.add_undo_property(node, "area_set", node.get("area_set"))
	var env := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env:
		undo.add_do_property(env, "environment", FACTORY.make_environment(kit))
		undo.add_undo_property(env, "environment", env.environment)
	var sun := root.get_node_or_null("Sun") as DirectionalLight3D
	if sun:
		undo.add_do_property(sun, "light_color", kit.sun_color)
		undo.add_do_property(sun, "light_energy", kit.sun_energy)
		undo.add_undo_property(sun, "light_color", sun.light_color)
		undo.add_undo_property(sun, "light_energy", sun.light_energy)
	undo.commit_action()


func _setup_dialogs() -> void:
	EditorInterface.get_base_control().add_child(new_dialog)
	var new_box := VBoxContainer.new()
	new_dialog.add_child(new_box)
	new_box.add_child(new_name)
	new_box.add_child(dimensions_row)
	for spin in [new_width, new_depth]:
		spin.min_value = 2
		spin.max_value = 1024
		spin.allow_greater = true
		spin.value = 24
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dimensions_row.add_child(spin)
	new_width.suffix = "m breed"
	new_depth.suffix = "m diep"
	new_name.placeholder_text = "Naam"
	new_name.custom_minimum_size = Vector2(380, 50)
	new_dialog.confirmed.connect(_create_new)
	EditorInterface.get_base_control().add_child(source_dialog)
	source_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	source_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	source_dialog.filters = PackedStringArray(["*.glb,*.gltf,*.tscn ; 3D-model of scene"])
	source_dialog.file_selected.connect(_source_selected)
	EditorInterface.get_base_control().add_child(import_dialog)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 430
	import_dialog.add_child(box)
	_label("Naam in de bibliotheek", box)
	box.add_child(import_name)
	_label("Categorie", box)
	box.add_child(import_category)
	_label("Botsingsvorm · bestaande collision heeft voorrang", box)
	for title in [
		"Automatisch (bestaand of modeloppervlak)",
		"Geen (decoratie)",
		"Doos",
		"Convex per mesh",
		"Modeloppervlak (ook openingen)",
		"Boomstam (onderste deel)"
	]:
		collision_mode.add_item(title)
	box.add_child(collision_mode)
	import_dialog.confirmed.connect(_import_asset)


func _new_dialog(kind: String) -> void:
	new_kind = kind
	dimensions_row.visible = kind == "level"
	new_dialog.title = "Nieuw level" if kind == "level" else "Nieuwe areaset"
	new_name.text = ""
	new_dialog.popup_centered()
	new_name.grab_focus()


func _slug(text: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]+")
	return (
		regex
		. sub(text.to_snake_case().to_lower(), "_", true)
		. strip_edges()
		. trim_prefix("_")
		. trim_suffix("_")
	)


func _create_new() -> void:
	var slug := _slug(new_name.text)
	if slug.is_empty() or _kit() == null:
		_note("Vul een naam in en kies een areaset.")
		return
	if new_kind == "set":
		var path := "res://settings/area_sets/" + slug + ".tres"
		if FileAccess.file_exists(path):
			_note("Er bestaat al een areaset met die bestandsnaam.")
			return
		var kit := _kit().duplicate() as AreaSet
		kit.id = StringName(slug)
		kit.display_name = new_name.text.strip_edges()
		kit.assets = []
		var error := ResourceSaver.save(kit, path, ResourceSaver.FLAG_CHANGE_PATH)
		if error != OK:
			_note("Opslaan mislukt: " + error_string(error))
			return
		kit.take_over_path(path)
		EditorInterface.get_resource_filesystem().scan()
		_refresh_sets()
		for index in kit_list.size():
			if kit_list[index].resource_path == path:
				sets.select(index)
		_refresh_palette()
		EditorInterface.edit_resource(kit)
	else:
		var path := "res://scenes/levels/" + slug.to_pascal_case() + ".tscn"
		var area_path := "res://settings/areas/" + slug + ".tres"
		if FileAccess.file_exists(path) or FileAccess.file_exists(area_path):
			_note("Er bestaat al een level of gebied met die bestandsnaam.")
			return
		var area := WorldArea.new()
		area.code = StringName("area." + Crypto.new().generate_random_bytes(16).hex_encode())
		area.display_name = new_name.text.strip_edges()
		area.scene_path = path
		var error := ResourceSaver.save(area, area_path, ResourceSaver.FLAG_CHANGE_PATH)
		if error == OK:
			area.take_over_path(area_path)
			var root := FACTORY.create(_kit(), area, Vector2(new_width.value, new_depth.value))
			error = FACTORY.save(root, path)
			root.free()
		if error != OK:
			_note("Level opslaan mislukt: " + error_string(error))
			return
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(path)
		_note("Level gemaakt. Plaats assets of kies Pad tekenen.")


func _source_selected(path: String) -> void:
	import_source = path
	import_name.text = (
		path.get_base_dir().get_file().capitalize()
		if path.get_file() in ["model.glb", "Visual.tscn"]
		else path.get_file().get_basename().capitalize()
	)
	import_category.text = "Props"
	import_dialog.title = "Plaatsbare asset voorbereiden"
	import_dialog.popup_centered()


func _import_asset() -> void:
	var target_kit := _kit()
	if target_kit == null:
		return
	var slug := _slug(import_name.text)
	if slug.is_empty():
		_note("Vul een assetnaam in.")
		return
	var path := "res://scenes/assets/environment/" + slug + "/Asset.tscn"
	var resource_path := "res://settings/level_assets/" + slug + ".tres"
	if FileAccess.file_exists(path) or FileAccess.file_exists(resource_path):
		_note("Die assetnaam bestaat al. Kies een nieuwe naam; bestaande prefabs blijven behouden.")
		return
	var source := load(import_source) as PackedScene
	var error := PREPARATION.prepare(source, path, collision_mode.selected)
	if error != OK:
		_note("Asset voorbereiden mislukt: " + error_string(error))
		return
	var asset := LevelAsset.new()
	asset.id = StringName(slug)
	asset.display_name = import_name.text
	asset.category = import_category.text
	asset.scene = load(path)
	asset.thumbnail = await LevelAssetThumbnails.generate(
		asset.scene, self, "res://assets/editor/level_builder/" + slug + ".res"
	)
	DirAccess.make_dir_recursive_absolute(resource_path.get_base_dir())
	error = ResourceSaver.save(asset, resource_path, ResourceSaver.FLAG_CHANGE_PATH)
	if error == OK:
		asset.take_over_path(resource_path)
		target_kit.assets.append(asset)
		error = ResourceSaver.save(target_kit, target_kit.resource_path)
	EditorInterface.get_resource_filesystem().scan()
	_refresh_palette()
	_note(
		(
			"Asset toegevoegd met opgeslagen botsingsvorm. Open de prefab om de collision te bekijken."
			if error == OK
			else error_string(error)
		)
	)


func _reimported(paths: PackedStringArray) -> void:
	# Only refresh generated collision in registered assets; preserve every placed instance.
	var visited := {}
	for kit in AreaSet.discover():
		for asset in kit.assets:
			if asset == null or asset.scene == null or visited.has(asset.scene.resource_path):
				continue
			visited[asset.scene.resource_path] = true
			var instance := asset.scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
			var source := String(instance.get_meta("level_asset_source", ""))
			var policy := int(instance.get_meta("level_asset_collision_mode", 0))
			instance.free()
			if source.is_empty():
				continue
			var changed := source in paths
			for dependency in ResourceLoader.get_dependencies(source):
				if dependency.get_slice("::", dependency.get_slice_count("::") - 1) in paths:
					changed = true
			if changed:
				if asset.scene.resource_path in EditorInterface.get_open_scenes():
					if not source in pending_reimports:
						pending_reimports.append(source)
					_note(
						(
							"Sluit de prefab en klik Vernieuwen om botsing bij te werken: "
							+ asset.scene.resource_path
						)
					)
					continue
				var error := PREPARATION.prepare(load(source), asset.scene.resource_path, policy)
				if error == OK:
					asset.scene = ResourceLoader.load(
						asset.scene.resource_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE
					)
					asset.thumbnail = await LevelAssetThumbnails.generate(
						asset.scene,
						self,
						"res://assets/editor/level_builder/" + String(asset.id) + ".res"
					)
					ResourceSaver.save(asset, asset.resource_path)
					pending_reimports.erase(source)
					_refresh_palette(false)
				else:
					_note(
						(
							"Botsing bijwerken mislukt: "
							+ asset.display_name
							+ " · "
							+ error_string(error)
						)
					)
