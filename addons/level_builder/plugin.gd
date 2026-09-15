@tool
extends EditorPlugin
## Thin editor UI over saved scenes and Resources. No runtime generator/autoload.
enum Tool { SELECT, PLACE, PLATEAU, STAIRS, PATH, PATROL, BRIDGE, WATER, SCATTER, BOUNDARY, DOOR }
const TOOL_NAMES := [
	"Selecteer",
	"Plaats",
	"Plateau",
	"Trap",
	"Pad",
	"Patrouille",
	"Brug",
	"Water",
	"Strooi",
	"Afkadering",
	"Deur"
]
const TOOL_HINTS := [
	"Klik op een plateau, trap, brug, water of pad om het te selecteren; sleep om het op het raster te verplaatsen. Trappen en bruggen aan een plateau gaan mee. Alt+klik = gewone Godot-selectie.",
	"Klik om één object te plaatsen. Kies Strooi voor groepen bloemen, bomen of andere props.",
	"Kies een Hoogte en sleep een rechthoek. Ctrl houdt de hoogte van de grond eronder. Rechthoeken tegen elkaar vormen één plateau; hogere plateaus mogen op lagere.",
	"Beweeg over de rand van een plateau en klik. Muis óp het plateau = trap erin, op de muur of ervoor = trap naar buiten. Rood = past niet.",
	"Klik punten voor een pad. Esc rondt af.",
	"Klik punten voor een patrouilleroute. Esc rondt af.",
	"Klik een plateaurand (of de grond) als begin en daarna het tweede punt. Omhoog of omlaag mag; de brug volgt de plateaus. Rood = te steil of door een plateau. Esc annuleert.",
	"Vierkant: sleep een rechthoek. Pad: klik punten voor een rivier, Esc rondt af. De grond zakt vanzelf in met zachte oevers; schuim en kringen komen vanzelf.",
	"Kies een prop en klik of sleep om te strooien. Straal bepaalt het gebied; Aantal en Afstand bepalen de dichtheid. Shift+slepen wist alleen dit type. Eén streek = één Undo.",
	"Kies een prop. Sleep een rechte lijn, of klik hoekpunten en druk Enter om af te ronden. Esc annuleert. Doorgang blokkeren sluit ook de openingen tussen de props.",
	"Beweeg naar een muur, een plateauwand (minstens 2 m hoog) of de rand van de grond en klik: er komt een deur met aankomstpunt. Buiten op de rand wordt het een open doorgang. Selecteer de deur om hem te verbinden met een bestaande scene of een nieuwe kamer erachter."
]
const DOOR_STYLES := ["Opening", "Houten deur", "Stenen boog", "Grot", "Poort"]
const DOOR_LIGHTS := ["Automatisch", "Aan", "Uit"]
const PREPARATION = preload("res://addons/level_builder/asset_preparation.gd")
const FACTORY = preload("res://addons/level_builder/level_factory.gd")
const CHECKS = preload("res://addons/level_builder/level_checks.gd")
const PORTAL_INSPECTOR = preload("res://addons/level_builder/portal_inspector.gd")
const STAIR_SLOPE := LevelTerrain.STAIR_SLOPE
const RAMP_SLOPE := LevelTerrain.RAMP_SLOPE
const STAIR_PICK_DISTANCE := 1.5
const STAIR_PICK_PIXELS := 48.0
var dock: VBoxContainer
var bottom_button: Button
var tools_dock: EditorDock
var toolbar_button: Button
var tool := Tool.SELECT
var tool_buttons := {}
var option_rows := {}
var checked_terrains := {}
var selection_editor = preload("res://addons/level_builder/selection_editor.gd").new()
var pending_reimports := PackedStringArray()
var sets := OptionButton.new()
var search := LineEdit.new()
var category := OptionButton.new()
var selected_name := Label.new()
var palette = preload("res://addons/level_builder/asset_palette.gd").new()
var radius := SpinBox.new()
var amount := SpinBox.new()
var scatter_spacing := SpinBox.new()
var scatter_paths := CheckBox.new()
var scatter_random_yaw := CheckBox.new()
var scatter_overlap := CheckBox.new()
var placement_height := SpinBox.new()
var boundary_spacing := SpinBox.new()
var boundary_random_yaw := CheckBox.new()
var boundary_collision := CheckBox.new()
var boundary_height := SpinBox.new()
var boundary_width := SpinBox.new()
var boundary_finish := Button.new()
var boundary_points := PackedVector3Array()
var boundary_hover: Variant = null
var boundary_press := Vector2.ZERO
var boundary_drag := false
var snap := SpinBox.new()
var plateau_height := SpinBox.new()
var stair_width := SpinBox.new()
var stair_steps := CheckBox.new()
var bridge_width := SpinBox.new()
var bridge_arch := SpinBox.new()
var bridge_rails := CheckBox.new()
var bridge_start := {}
var water_shape := OptionButton.new()
var water_width := SpinBox.new()
var water_depth := SpinBox.new()
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
var new_type := OptionButton.new()
var new_connect := CheckBox.new()
var door_style := OptionButton.new()
var door_width := SpinBox.new()
var door_light := OptionButton.new()
var links_box := VBoxContainer.new()
var links_signature := ""
var room_dialog := ConfirmationDialog.new()
var room_name := LineEdit.new()
var room_kind := OptionButton.new()
var room_width := SpinBox.new()
var room_depth := SpinBox.new()
var room_door: LevelDoor
var link_dialog := EditorFileDialog.new()
var link_door: LevelDoor
var import_source := ""
var id_claims := {}
var maintenance_time := 0.0
var last_paint := Vector3.INF
var stroke_nodes: Array[Node3D] = []
var erased_nodes: Array[Dictionary] = []
var painting := false
var erasing := false
var scatter_rng := RandomNumberGenerator.new()
var active_curve: Path3D
var drag_start: Variant = null
## A click without dragging sets the first corner of a rectangle; the next click finishes it.
var corner_pending := false
## Select tool: the node being dragged, with every node that moves along with it.
var move_node: Node3D
var move_items: Array[Dictionary] = []
var move_start := Vector2.ZERO
var move_height := 0.0
var move_last := Vector2.ZERO
var move_mouse_start := Vector2.ZERO
var move_dragging := false
var drag_end: Variant = null
var preview: MeshInstance3D


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
	var library := VBoxContainer.new()
	library.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(library)
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
	# One right-hand dock: tools on top, selection material, then level actions.
	tools_dock = EditorDock.new()
	tools_dock.title = "Level tools"
	tools_dock.layout_key = "LanternLevelToolsV3"
	tools_dock.default_slot = EditorDock.DOCK_SLOT_RIGHT_UL
	tools_dock.icon_name = &"Tools"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.custom_minimum_size = Vector2(200, 120) * EditorInterface.get_editor_scale()
	tools_dock.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	var buttons := HFlowContainer.new()
	body.add_child(buttons)
	var group := ButtonGroup.new()
	for i in [
		Tool.SELECT,
		Tool.PLACE,
		Tool.SCATTER,
		Tool.BOUNDARY,
		Tool.PLATEAU,
		Tool.STAIRS,
		Tool.BRIDGE,
		Tool.WATER,
		Tool.PATH,
		Tool.PATROL,
		Tool.DOOR
	]:
		var button := Button.new()
		button.text = TOOL_NAMES[i]
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = i == Tool.SELECT
		button.pressed.connect(_set_tool.bind(i))
		buttons.add_child(button)
		tool_buttons[i] = button
	_spin(snap, 0, 4, .25, 1, "m raster (0 = vrij)")
	_spin(plateau_height, .5, LevelTerrain.MAX_HEIGHT, .5, 1, "m hoog")
	_spin(stair_width, .5, 12, .5, 2, "m breed")
	_spin(bridge_width, 1, 6, .5, 2, "m breed")
	_spin(bridge_arch, 0, 100, .5, 0, "m")
	bridge_arch.tooltip_text = "Extra hoogte in het midden van de brug. 0 houdt de brug recht."
	_spin(water_width, .5, 20, .5, 3, "m breed")
	_spin(water_depth, .2, 3, .1, .6, "m diep")
	water_shape.add_item("Vierkant")
	water_shape.add_item("Pad")
	water_shape.item_selected.connect(func(_index): _set_tool(tool))
	_spin(radius, .25, 12, .25, 2, "m penseel")
	_spin(amount, 1, 120, 1, 12, "per stempel")
	_spin(scatter_spacing, .1, 10, .1, .7, "m vrijhouden")
	scatter_paths.text = "Paden vrijhouden"
	scatter_paths.button_pressed = true
	scatter_random_yaw.text = "Willekeurige hoek"
	scatter_random_yaw.button_pressed = true
	scatter_overlap.text = "Overlap toestaan"
	scatter_overlap.tooltip_text = "Strooi over bestaande assets heen. Afstand blijft gelden tussen de objecten van de nieuwe strooistreek."
	_spin(placement_height, -100, 100, .5, 0, "m")
	_spin(boundary_spacing, .25, 20, .25, 2, "m tussen props")
	_spin(boundary_height, .5, 100, .5, 4, "m")
	_spin(boundary_width, .1, 8, .1, .6, "m")
	boundary_random_yaw.text = "Willekeurige hoek"
	boundary_random_yaw.button_pressed = true
	boundary_collision.text = "Doorgang blokkeren"
	boundary_collision.button_pressed = true
	boundary_collision.tooltip_text = "Doorlopende onzichtbare botsing, ook tussen de stammen. De eigen botsing van de prop blijft behouden."
	boundary_finish.text = "Lijn afronden (Enter)"
	boundary_finish.pressed.connect(_finish_boundary)
	placement_height.tooltip_text = "Hoogte ten opzichte van het aangeklikte oppervlak. 0 plaatst op de grond; 2 plaatst 2 m erboven."
	stair_steps.text = "Treden (uit = helling)"
	stair_steps.button_pressed = true
	bridge_rails.text = "Leuningen"
	bridge_rails.button_pressed = true
	_option(
		"Raster",
		snap,
		[
			Tool.SELECT,
			Tool.PLACE,
			Tool.BOUNDARY,
			Tool.PLATEAU,
			Tool.STAIRS,
			Tool.BRIDGE,
			Tool.WATER,
			Tool.PATH,
			Tool.PATROL
		],
		body
	)
	_option("Hoogte", plateau_height, [Tool.PLATEAU], body)
	_option("Trapbreedte", stair_width, [Tool.STAIRS], body)
	_option("", stair_steps, [Tool.STAIRS], body)
	_option("Brugbreedte", bridge_width, [Tool.BRIDGE], body)
	_option("Booghoogte", bridge_arch, [Tool.BRIDGE], body)
	_option("", bridge_rails, [Tool.BRIDGE], body)
	_option("Vorm", water_shape, [Tool.WATER], body)
	_option("Breedte", water_width, [Tool.WATER], body)
	_option("Diepte", water_depth, [Tool.WATER], body)
	for title in DOOR_STYLES:
		door_style.add_item(title)
	for title in DOOR_LIGHTS:
		door_light.add_item(title)
	door_light.tooltip_text = "Automatisch: alleen licht in kamers. Buiten en in plateaus geen licht."
	door_style.select(LevelDoor.Style.WOODEN_DOOR)
	door_width.min_value = 1
	door_width.max_value = 6
	door_width.step = .5
	door_width.value = 2
	door_width.suffix = "m breed"
	door_width.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_option("Deurstijl", door_style, [Tool.DOOR], body)
	_option("Deurbreedte", door_width, [Tool.DOOR], body)
	_option("Licht", door_light, [Tool.DOOR], body)
	_option("Straal", radius, [Tool.SCATTER], body)
	_option("Aantal", amount, [Tool.SCATTER], body)
	_option("Afstand", scatter_spacing, [Tool.SCATTER], body)
	_option("Hoogte +", placement_height, [Tool.SCATTER, Tool.PLACE, Tool.BOUNDARY], body)
	_option("", scatter_random_yaw, [Tool.SCATTER], body)
	_option("", scatter_overlap, [Tool.SCATTER], body)
	_option("", scatter_paths, [Tool.SCATTER], body)
	_option("Afstand", boundary_spacing, [Tool.BOUNDARY], body)
	_option("", boundary_random_yaw, [Tool.BOUNDARY], body)
	_option("", boundary_collision, [Tool.BOUNDARY], body)
	_option("Blokhoogte", boundary_height, [Tool.BOUNDARY], body)
	_option("Blokbreedte", boundary_width, [Tool.BOUNDARY], body)
	_option("", boundary_finish, [Tool.BOUNDARY], body)
	body.add_child(HSeparator.new())
	selection_editor.plugin = self
	body.add_child(selection_editor)
	selection_editor.refresh()
	body.add_child(HSeparator.new())
	_label("Level", body)
	_button("Nieuwe ruimte", body, func(): _new_dialog("level"))
	_button("Nieuwe areaset", body, func(): _new_dialog("set"))
	_button(
		"Bewerk areaset",
		body,
		func():
			if _kit():
				EditorInterface.edit_resource(_kit())
	)
	_button("Pas areaset toe", body, _apply_kit)
	_button("Nieuwe encounter", body, _new_encounter)
	_button("Controleer level", body, _validate_level)
	_button("Speel level", body, _play_level)
	_label("Verbonden ruimtes", body)
	body.add_child(links_box)
	status.custom_minimum_size.y = 80 * EditorInterface.get_editor_scale()
	status.fit_content = true
	status.bbcode_enabled = false
	body.add_child(status)
	add_dock(tools_dock)
	bottom_button = add_control_to_bottom_panel(dock, "Level Builder")
	toolbar_button = Button.new()
	toolbar_button.text = "Level Builder"
	toolbar_button.pressed.connect(_show_builder)
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar_button)
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
	_set_tool(Tool.SELECT)
	if (
		"--level-builder-editor-checks" in OS.get_cmdline_user_args()
		or "--level-builder-elevation-checks" in OS.get_cmdline_user_args()
		or "--level-builder-boundary-checks" in OS.get_cmdline_user_args()
	):
		_run_editor_checks.call_deferred()


func _exit_tree() -> void:
	_cancel_move()
	_commit_stroke()
	_clear_preview()
	remove_inspector_plugin(inspector)
	remove_node_3d_gizmo_plugin(placement_gizmos)
	if EditorInterface.get_resource_filesystem().resources_reimported.is_connected(_reimported):
		EditorInterface.get_resource_filesystem().resources_reimported.disconnect(_reimported)
	EditorInterface.get_selection().selection_changed.disconnect(selection_editor.refresh)
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, toolbar_button)
	toolbar_button.queue_free()
	remove_dock(tools_dock)
	tools_dock.queue_free()
	remove_control_from_bottom_panel(dock)
	dock.queue_free()
	new_dialog.queue_free()
	source_dialog.queue_free()
	import_dialog.queue_free()
	room_dialog.queue_free()
	link_dialog.queue_free()


func _process(delta: float) -> void:
	maintenance_time -= delta
	if maintenance_time > 0:
		return
	maintenance_time = .5
	_refresh_links()
	var ground := _terrain()
	if ground and not checked_terrains.has(ground.get_instance_id()):
		checked_terrains[ground.get_instance_id()] = true
		ground.request_bake()
	var root := EditorInterface.get_edited_scene_root()
	if root and CHECKS.ensure_enemy_ids(root, id_claims):
		EditorInterface.mark_scene_as_unsaved()


func _spin(
	spin: SpinBox, low: float, high: float, step: float, value: float, suffix: String
) -> void:
	spin.min_value = low
	spin.max_value = high
	spin.step = step
	spin.value = value
	spin.suffix = suffix
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _option(title: String, control: Control, tools: Array, parent: Node) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = title
	label.custom_minimum_size.x = 90 * EditorInterface.get_editor_scale()
	row.add_child(label)
	row.add_child(control)
	parent.add_child(row)
	option_rows[row] = tools


func _set_tool(next: int) -> void:
	_cancel_move()
	_commit_stroke()
	_clear_preview()
	drag_start = null
	corner_pending = false
	move_node = null
	move_items.clear()
	last_paint = Vector3.INF
	tool = next
	active_curve = null
	bridge_start = {}
	boundary_points.clear()
	boundary_hover = null
	boundary_drag = false
	if tool in [Tool.PATH, Tool.PATROL, Tool.WATER]:
		var selected := EditorInterface.get_selection().get_selected_nodes()
		if selected.size() == 1 and _curve_matches_tool(selected[0]):
			active_curve = selected[0]
	for i in tool_buttons:
		tool_buttons[i].set_pressed_no_signal(i == tool)
	for row in option_rows:
		row.visible = tool in option_rows[row]
	_note(TOOL_HINTS[tool])


func _curve_matches_tool(node: Variant) -> bool:
	return (
		is_instance_valid(node)
		and (
			(tool == Tool.PATH and node is LevelPath)
			or (tool == Tool.PATROL and node is EnemyPatrol)
			or (tool == Tool.WATER and node is LevelWater and node.shape == LevelWater.Shape.PATH)
		)
	)


func _asset_selected(index: int) -> void:
	active_asset = shown_assets[index]
	selected_name.text = active_asset.display_name
	scatter_spacing.value = active_asset.spacing
	scatter_random_yaw.button_pressed = active_asset.random_yaw
	var scatter := (
		(active_asset.scatter_allowed or tool == Tool.SCATTER)
		and active_asset.category not in ["Enemies", "Gameplay"]
	)
	if tool == Tool.BOUNDARY and active_asset.category not in ["Enemies", "Gameplay"]:
		_note(TOOL_HINTS[tool])
	else:
		_set_tool(Tool.SCATTER if scatter else Tool.PLACE)
	tools_dock.make_visible()


func _scene_changed(root: Node) -> void:
	_set_tool(Tool.SELECT)
	_refresh_links.call_deferred(true)
	if root and CHECKS.has_property(root, &"area_set"):
		var kit: AreaSet = root.get("area_set")
		if kit in kit_list:
			sets.select(kit_list.find(kit))
			_refresh_palette()


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if tool == Tool.SELECT:
			if is_instance_valid(move_node):
				_cancel_move()
				_note("Verplaatsen geannuleerd.")
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if corner_pending:
			corner_pending = false
			drag_start = null
			_clear_preview()
			_note("Rechthoek geannuleerd.")
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if tool == Tool.BRIDGE and not bridge_start.is_empty():
			bridge_start = {}
			_clear_preview()
			_note("Brug geannuleerd. Kies een nieuw beginpunt.")
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		_set_tool(Tool.SELECT)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventWithModifiers and event.alt_pressed:
		_cancel_move()
		_clear_preview()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if tool == Tool.SELECT:
		return _select_input(camera, event)
	if tool == Tool.BOUNDARY:
		return _boundary_input(camera, event)
	if tool == Tool.DOOR:
		var door_ground := _terrain()
		if door_ground == null or not event is InputEventMouse:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		var door_hit: Variant = _hit(camera, event.position, false)
		# A plateau wall under the mouse wins over the edge of the ground.
		var cliff := _cliff_door_plan_from_view(door_ground, camera, event.position)
		if event is InputEventMouseMotion:
			if cliff.is_empty():
				_update_door_preview(door_ground, door_hit)
			else:
				_update_cliff_door_preview(door_ground, cliff)
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not cliff.is_empty():
				if cliff.has("error"):
					_note(cliff.error)
				else:
					_create_door(door_ground, cliff)
			elif event.pressed and door_hit != null:
				var door_local := door_ground.to_local(door_hit)
				var plan := _door_plan(door_ground, Vector2(door_local.x, door_local.z))
				if plan.is_empty():
					_note("Beweeg naar een muur of de rand van de grond.")
				else:
					_create_door(door_ground, plan)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if tool == Tool.BRIDGE:
		# Like stairs: hover shows the anchor (and the bridge once a start is set).
		var bridge_ground := _terrain()
		if bridge_ground == null:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event is InputEventMouseMotion:
			_update_bridge_preview(_bridge_anchor_from_view(bridge_ground, camera, event.position))
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_bridge_click(_bridge_anchor_from_view(bridge_ground, camera, event.position))
				_update_bridge_preview(
					_bridge_anchor_from_view(bridge_ground, camera, event.position)
				)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if tool == Tool.STAIRS:
		# Hovering previews the stairs; camera navigation keeps working.
		var ground := _terrain()
		if ground == null:
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event is InputEventMouseMotion:
			_update_stairs_preview(_stairs_plan_from_view(ground, camera, event.position))
			return EditorPlugin.AFTER_GUI_INPUT_PASS
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_build_stairs(_stairs_plan_from_view(ground, camera, event.position))
				_update_stairs_preview(_stairs_plan_from_view(ground, camera, event.position))
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Variant = _hit(camera, event.position, tool != Tool.SCATTER)
		if event.pressed:
			if at == null:
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			if corner_pending:
				# Second click of click-click rectangle drawing.
				corner_pending = false
				drag_end = at
				_finish_rectangle(event.is_command_or_control_pressed())
				return EditorPlugin.AFTER_GUI_INPUT_STOP
			match tool:
				Tool.PLACE, Tool.SCATTER:
					painting = true
					erasing = tool == Tool.SCATTER and event.shift_pressed
					if erasing:
						_erase(at)
					else:
						_stamp(at)
				Tool.PLATEAU:
					drag_start = at
					drag_end = at
					_update_plateau_preview(event.is_command_or_control_pressed())
				Tool.PATH, Tool.PATROL:
					_add_curve_point(at)
				Tool.WATER:
					if water_shape.selected == LevelWater.Shape.AREA:
						drag_start = at
						drag_end = at
						_update_water_preview()
					else:
						_add_curve_point(at)
		else:
			if drag_start != null and not corner_pending:
				if at != null:
					drag_end = at
				var moved := Vector2(drag_end.x - drag_start.x, drag_end.z - drag_start.z).length()
				if moved < .25:
					# Released where it was pressed: wait for the opposite corner.
					corner_pending = true
					_note("Klik de tegenoverliggende hoek. Esc annuleert.")
				else:
					_finish_rectangle(event.is_command_or_control_pressed())
			_commit_stroke()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion and corner_pending:
		# Hovering previews the rectangle; camera drags keep working.
		var hover: Variant = _hit(camera, event.position)
		if hover != null:
			drag_end = hover
			if tool == Tool.WATER:
				_update_water_preview()
			else:
				_update_plateau_preview(event.is_command_or_control_pressed())
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion and tool == Tool.SCATTER:
		var brush_at: Variant = _hit(camera, event.position, false)
		if brush_at != null:
			_scatter_preview(brush_at, event.shift_pressed)
		else:
			_clear_preview()
	if event is InputEventMouseMotion and (painting or drag_start != null):
		var at: Variant = _hit(camera, event.position, tool != Tool.SCATTER)
		if at == null:
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if drag_start != null:
			drag_end = at
			if tool == Tool.WATER:
				_update_water_preview()
			else:
				_update_plateau_preview(event.is_command_or_control_pressed())
		elif tool == Tool.SCATTER and at.distance_to(last_paint) >= radius.value * .5:
			var start := last_paint
			var step := maxf(.15, radius.value * .5)
			var steps := mini(32, floori(start.distance_to(at) / step))
			for i in range(1, steps + 1):
				var point := start.move_toward(at, i * step)
				if erasing:
					_erase(point)
				else:
					_stamp(point)
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _boundary_input(camera: Camera3D, event: InputEvent) -> int:
	if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_finish_boundary()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	if event is InputEventMouseMotion:
		boundary_hover = _hit(camera, event.position)
		_update_boundary_preview()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var at: Variant = _hit(camera, event.position)
		if at == null:
			boundary_drag = false
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if event.pressed:
			boundary_drag = boundary_points.is_empty()
			boundary_press = event.position
			if boundary_points.is_empty() or boundary_points[-1].distance_to(at) > .05:
				boundary_points.append(at)
			boundary_hover = at
			if event.double_click:
				_finish_boundary()
		elif (
			boundary_drag
			and event.position.distance_to(boundary_press) >= 4 * EditorInterface.get_editor_scale()
		):
			if boundary_points[-1].distance_to(at) > .05:
				boundary_points.append(at)
			_finish_boundary()
		else:
			boundary_drag = false
		_update_boundary_preview()
		return EditorPlugin.AFTER_GUI_INPUT_STOP
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _update_boundary_preview() -> void:
	var ground := _terrain()
	if ground == null or boundary_points.is_empty():
		_clear_preview()
		return
	var points := boundary_points.duplicate()
	if boundary_hover != null and points[-1].distance_to(boundary_hover) > .05:
		points.append(boundary_hover)
	var lines := PackedVector3Array()
	for i in points.size() - 1:
		var a := ground.to_local(points[i])
		var b := ground.to_local(points[i + 1])
		lines.append_array(PackedVector3Array([a, b]))
		if boundary_collision.button_pressed:
			var up := Vector3.UP * boundary_height.value
			lines.append_array(PackedVector3Array([a, a + up, a + up, b + up, b + up, b]))
	if not lines.is_empty():
		_draw_preview(lines, Color(.4, .9, .65), ground)


func _finish_boundary() -> LevelBoundary:
	var ground := _terrain()
	var root := EditorInterface.get_edited_scene_root()
	if ground == null or root == null:
		_note("Maak eerst een level met Terrain via Nieuw level.")
		return null
	if active_asset == null or active_asset.category in ["Enemies", "Gameplay"]:
		_note("Kies een prop zoals bomen, struiken, rotsen of een hek.")
		return null
	if boundary_points.size() < 2:
		_note("Klik minstens twee punten of sleep een lijn. Esc annuleert.")
		return null
	var boundary := LevelBoundary.new()
	boundary.name = "Afkadering"
	boundary.asset = active_asset
	boundary.spacing = boundary_spacing.value
	boundary.random_yaw = boundary_random_yaw.button_pressed
	boundary.random_seed = scatter_rng.randi()
	boundary.height_offset = placement_height.value
	boundary.block_movement = boundary_collision.button_pressed
	boundary.barrier_height = boundary_height.value
	boundary.barrier_width = boundary_width.value
	boundary.curve = Curve3D.new()
	boundary.curve.resource_local_to_scene = true
	boundary.curve.bake_interval = .25
	for point in boundary_points:
		boundary.curve.add_point(ground.to_local(point))
	var undo := get_undo_redo()
	undo.create_action("Plaats afkadering", UndoRedo.MERGE_DISABLE, root)
	undo.add_do_method(ground, "add_child", boundary, true)
	undo.add_do_property(boundary, "owner", root)
	undo.add_do_method(boundary, "bake")
	undo.add_undo_method(ground, "remove_child", boundary)
	undo.add_do_reference(boundary)
	undo.commit_action()
	boundary_points.clear()
	boundary_hover = null
	boundary_drag = false
	_clear_preview()
	_select(boundary)
	_note(
		"Afkadering geplaatst. Selecteer om te verplaatsen; Alt gebruikt Godots curvegrepen. Afstand en botsing blijven in de Inspector instelbaar."
	)
	return boundary


func _stamp(at: Vector3) -> void:
	if active_asset == null:
		_note("Kies eerst een asset uit de bibliotheek.")
		return
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var ground := _terrain()
	last_paint = at
	var scattering := tool == Tool.SCATTER
	if scattering and active_asset.category in ["Enemies", "Gameplay"]:
		_note(
			"Kies een prop of begroeiing om te strooien. Actors en interacties plaats je met Plaats."
		)
		return
	var count := int(amount.value) if scattering else 1
	var placed := 0
	var regions: Array[Dictionary] = []
	if ground:
		regions = ground.outlines()
	for i in count * (12 if scattering else 1):
		if placed >= count:
			break
		var point := at
		if scattering:
			var angle := scatter_rng.randf() * TAU
			var distance := sqrt(scatter_rng.randf()) * radius.value
			point += Vector3(cos(angle), 0, sin(angle)) * distance
			if ground:
				var local := ground.to_local(point)
				if absf(local.x) > ground.size.x / 2 or absf(local.z) > ground.size.y / 2:
					continue
				var in_water := false
				local.y = 0
				for region in regions:
					if Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), region.polygon):
						in_water = region.has("water")
						local.y = LevelTerrain.region_height(region, Vector2(local.x, local.z))
						break
				if in_water:
					continue
				point = ground.to_global(local)
				if scatter_paths.button_pressed and _on_path(ground, local):
					continue
			point.y += placement_height.value
			var blocked := false
			for other in _parent_for(active_asset).get_children():
				if scatter_overlap.button_pressed and not stroke_nodes.has(other):
					continue
				if (
					other is Node3D
					and other.global_position.distance_to(point) < scatter_spacing.value
				):
					blocked = true
					break
			if blocked:
				continue
		else:
			point.y += placement_height.value
		var node := active_asset.scene.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
		if node == null:
			continue
		node.name = active_asset.display_name.to_pascal_case()
		_parent_for(active_asset).add_child(node, true)
		node.owner = root
		node.global_position = point
		node.set_meta("level_asset_id", active_asset.id)
		if scatter_random_yaw.button_pressed if scattering else active_asset.random_yaw:
			node.rotation.y = scatter_rng.randf() * TAU
		node.scale *= randf_range(active_asset.scale_range.x, active_asset.scale_range.y)
		if CHECKS.has_property(node, &"persistent_id"):
			node.set("respawn_rule", 1)
		CHECKS.ensure_enemy_ids(root, id_claims)
		stroke_nodes.append(node)
		placed += 1
	if scattering:
		_note(
			(
				"%d objecten gestrooid. %s"
				% [
					placed,
					(
						"Maak Straal groter of Afstand kleiner voor meer."
						if placed < count
						else "Sleep verder; Shift wist dit type."
					)
				]
			)
		)
	if not painting:
		_commit_stroke()


## A brush outline on the terrain, kept out of saved scenes.
func _scatter_preview(at: Vector3, erase: bool) -> void:
	var ground := _terrain()
	if ground == null:
		return
	var center := ground.to_local(at)
	var polygon := PackedVector2Array()
	for i in 64:
		var angle := TAU * i / 64
		var world := at + Vector3(cos(angle), 0, sin(angle)) * radius.value
		var local := ground.to_local(world)
		polygon.append(Vector2(local.x, local.z))
	var lines := PackedVector3Array()
	_append_outline(lines, polygon, ground)
	var height_shift := ground.global_basis.inverse() * Vector3.UP * placement_height.value
	for i in lines.size():
		lines[i] += height_shift
	lines.append_array(PackedVector3Array([center, center + height_shift]))
	center += height_shift
	lines.append_array(
		PackedVector3Array(
			[
				center + Vector3(-.2, 0, 0),
				center + Vector3(.2, 0, 0),
				center + Vector3(0, 0, -.2),
				center + Vector3(0, 0, .2)
			]
		)
	)
	_draw_preview(lines, Color(1, .35, .3) if erase else Color(1, .85, .3), ground)


## Surface height at a terrain-local X/Z point, ramps included.
func _height_at(ground: LevelTerrain, point: Vector2) -> float:
	var height := 0.0
	for region in ground.outlines():
		if Geometry2D.is_point_in_polygon(point, region.polygon):
			height = maxf(height, LevelTerrain.region_height(region, point))
	return height


func _erase(at: Vector3) -> void:
	last_paint = at
	at += Vector3.UP * placement_height.value
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var doomed: Array[Node3D] = []
	for group in ["Props", "Enemies", "Gameplay"]:
		var parent := root.get_node_or_null(group)
		if parent == null:
			continue
		for node in parent.get_children():
			if (
				node is Node3D
				and node.has_meta("level_asset_id")
				and (active_asset == null or node.get_meta("level_asset_id") == active_asset.id)
				and node.global_position.distance_to(at) < radius.value
			):
				doomed.append(node)
	if doomed.is_empty():
		return
	for node in doomed:
		var selection := EditorInterface.get_selection()
		for selected in selection.get_selected_nodes():
			if selected == node or node.is_ancestor_of(selected):
				selection.remove_node(selected)
		erased_nodes.append({"node": node, "parent": node.get_parent(), "owner": node.owner})
		node.get_parent().remove_child(node)
	if not painting:
		_commit_stroke()


## Grid-snapped X/Z rectangle between two terrain-local points, clamped to the ground.
func _drag_rect(ground: LevelTerrain, a: Vector3, b: Vector3) -> Rect2:
	var grid := snap.value if snap.value > 0 else .5
	var low := Vector2(minf(a.x, b.x), minf(a.z, b.z))
	var high := Vector2(maxf(a.x, b.x), maxf(a.z, b.z))
	high = high.max(low + Vector2(grid, grid))
	low = low.max(-ground.size / 2)
	high = high.min(ground.size / 2)
	return Rect2(low, (high - low).max(Vector2.ZERO))


func _plateau_height(ground: LevelTerrain, start: Vector3, flat: bool) -> float:
	return ground.snap_height(start.y) if flat else plateau_height.value


func _create_plateau(start: Vector3, end: Vector3, flat := false) -> LevelTerrace:
	var ground := _terrain()
	var root := EditorInterface.get_edited_scene_root()
	if ground == null or root == null:
		_note("Maak eerst een level met Terrain via Nieuw level.")
		return null
	var a := ground.to_local(start)
	var rect := _drag_rect(ground, a, ground.to_local(end))
	if rect.size.x < .01 or rect.size.y < .01:
		return null
	var height := _plateau_height(ground, a, flat)
	var terrace := LevelTerrace.new()
	terrace.name = "Plateau"
	terrace.curve = Curve3D.new()
	terrace.curve.resource_local_to_scene = true
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]:
		terrace.curve.add_point(Vector3(corner.x, 0, corner.y))
	var undo := get_undo_redo()
	undo.create_action("Plateau")
	undo.add_do_method(ground, "add_child", terrace, true)
	undo.add_do_property(terrace, "owner", root)
	undo.add_do_property(terrace, "height", height)
	undo.add_undo_method(ground, "remove_child", terrace)
	undo.add_do_reference(terrace)
	undo.commit_action()
	_select(terrace)
	if not flat and height <= ground.snap_height(a.y):
		_note("Dit plateau is niet hoger dan de grond eronder. Kies een grotere Hoogte.")
	else:
		_note("Plateau op %s m." % height)
	return terrace


## Plateau edges, plateaus and existing stair footprints in terrain space.
func _stair_context(ground: LevelTerrain) -> Dictionary:
	var plateaus: Array[Dictionary] = []
	var ramps: Array[PackedVector2Array] = []
	for region in ground.outlines():
		if region.has("ramp_start"):
			ramps.append(region.polygon)
		else:
			plateaus.append(region)
	var edges: Array[Dictionary] = []
	for region in plateaus:
		var polygon: PackedVector2Array = region.polygon
		for i in polygon.size():
			var a := polygon[i]
			var b := polygon[(i + 1) % polygon.size()]
			var length := a.distance_to(b)
			if length < .5:
				continue
			var tangent := (b - a) / length
			# Outlines are counter-clockwise: the right-hand side is outside.
			edges.append(
				{
					"a": a,
					"b": b,
					"top": region.height,
					"tangent": tangent,
					"outward": Vector2(tangent.y, -tangent.x),
					"length": length
				}
			)
	return {"plateaus": plateaus, "ramps": ramps, "edges": edges}


func _edge_drops(context: Dictionary, edge: Dictionary, point: Vector2) -> bool:
	var below := LevelTerrain.height_under(point + edge.outward * .05, context.plateaus)
	return edge.top - below >= LevelTerrain.HEIGHT_STEP - LevelTerrain.EPS


## Stairs picked in the viewport: the plateau edge nearest the mouse on screen.
## The mouse over the plateau top means stairs set into it; over the wall or the
## ground in front means stairs leading out.
func _stairs_plan_from_view(ground: LevelTerrain, camera: Camera3D, mouse: Vector2) -> Dictionary:
	var context := _stair_context(ground)
	var nearest := STAIR_PICK_PIXELS * EditorInterface.get_editor_scale()
	var best := {}
	var best_along := 0.0
	for edge in context.edges:
		var a3 := ground.to_global(Vector3(edge.a.x, edge.top, edge.a.y))
		var b3 := ground.to_global(Vector3(edge.b.x, edge.top, edge.b.y))
		if camera.is_position_behind(a3) or camera.is_position_behind(b3):
			continue
		var sa := camera.unproject_position(a3)
		var sb := camera.unproject_position(b3)
		var closest := Geometry2D.get_closest_point_to_segment(mouse, sa, sb)
		var distance := mouse.distance_to(closest)
		if distance >= nearest:
			continue
		var along: float = edge.length * closest.distance_to(sa) / maxf(sa.distance_to(sb), .001)
		if not _edge_drops(context, edge, edge.a + edge.tangent * along):
			continue
		nearest = distance
		best = edge
		best_along = along
	if best.is_empty():
		return {}
	var origin := ground.to_local(camera.project_ray_origin(mouse))
	var direction := ground.global_basis.inverse() * camera.project_ray_normal(mouse)
	var on_top: Variant = Plane(Vector3.UP, best.top).intersects_ray(origin, direction)
	var inset: bool = (
		on_top != null and (Vector2(on_top.x, on_top.z) - best.a).dot(best.outward) < 0
	)
	return _plan_with_fallback(ground, context, best, best_along, inset)


## Stairs for a terrain-space point near a plateau edge (used by tests and tools).
func _stairs_plan(ground: LevelTerrain, point: Vector2, inset := false) -> Dictionary:
	var context := _stair_context(ground)
	var nearest := STAIR_PICK_DISTANCE
	var best := {}
	var best_along := 0.0
	for edge in context.edges:
		var closest := Geometry2D.get_closest_point_to_segment(point, edge.a, edge.b)
		var distance := point.distance_to(closest)
		if distance >= nearest or not _edge_drops(context, edge, closest):
			continue
		nearest = distance
		best = edge
		best_along = (closest - edge.a).dot(edge.tangent)
	if best.is_empty():
		return {}
	return _plan_with_fallback(ground, context, best, best_along, inset)


## Tries the requested direction first, then the other one before giving up.
func _plan_with_fallback(
	ground: LevelTerrain, context: Dictionary, edge: Dictionary, along: float, inset: bool
) -> Dictionary:
	var plan := _plan_on_edge(ground, context, edge, along, inset)
	if not plan.has("error"):
		return plan
	var other := _plan_on_edge(ground, context, edge, along, not inset)
	if other.has("error"):
		return plan
	other.note = (
		"Past niet in het plateau; trap naar buiten gezet."
		if inset
		else "Geen ruimte voor de rand; trap in het plateau gezet."
	)
	return other


## {low, high, width, top, bottom, inset}, plus "error" when the flight does not fit.
func _plan_on_edge(
	ground: LevelTerrain, context: Dictionary, edge: Dictionary, along: float, inset: bool
) -> Dictionary:
	var width := minf(stair_width.value, edge.length)
	var grid := snap.value if snap.value > 0 else .5
	along = clampf(
		snappedf(along - width / 2, grid) + width / 2, width / 2, edge.length - width / 2
	)
	var point: Vector2 = edge.a + edge.tangent * along
	var bottom := LevelTerrain.height_under(point + edge.outward * .05, context.plateaus)
	var slope := STAIR_SLOPE if stair_steps.button_pressed else RAMP_SLOPE
	var run: float = maxf(edge.top - bottom, LevelTerrain.HEIGHT_STEP) / slope
	var plan := {"width": width, "top": edge.top, "bottom": bottom, "inset": inset}
	if inset:
		# At a bent edge a corner of plateau can still lie in front of the flight. Slide
		# the foot out until its whole width stands clear of the plateau, so the stairs
		# run into the real cliff face instead of hiding behind a wedge of wall.
		var foot_side: Vector2 = edge.tangent * (width / 2 - .01)
		for step in 30:
			var ahead: Vector2 = point + edge.outward * .08
			var blocked := false
			for sample in [ahead - foot_side, ahead, ahead + foot_side]:
				if LevelTerrain.height_under(sample, context.plateaus) >= edge.top - LevelTerrain.EPS:
					blocked = true
			if not blocked:
				break
			point += edge.outward * .1
		plan.low = point
		plan.high = point - edge.outward * run
	else:
		plan.low = point + edge.outward * run
		plan.high = point
	if edge.top - bottom < LevelTerrain.HEIGHT_STEP - LevelTerrain.EPS:
		plan.error = "Hier is geen hoogteverschil."
		return plan
	# The flight must stay on the ground and on one level along its whole length,
	# including its four corners: a flight set into a bent or angled plateau edge may
	# not poke out through the neighbouring wall.
	var expected: float = edge.top if inset else bottom
	var side: Vector2 = edge.tangent * (width / 2 - .01)
	var tuck: Vector2 = (plan.high - plan.low).normalized() * .05
	for i in range(0, 7):
		var center: Vector2 = plan.low.lerp(plan.high, i / 6.0)
		if i == 0:
			center += tuck
		elif i == 6:
			center -= tuck
		for sample in [center - side, center, center + side]:
			if absf(sample.x) > ground.size.x / 2 or absf(sample.y) > ground.size.y / 2:
				plan.error = "De trap valt buiten de grond."
			elif not is_equal_approx(LevelTerrain.height_under(sample, context.plateaus), expected):
				plan.error = (
					"Het plateau is hier te klein voor een ingezette trap."
					if inset
					else "Er ligt iets voor deze rand; hier past geen trap."
				)
			for other in context.ramps:
				if Geometry2D.is_point_in_polygon(sample, other):
					plan.error = "Hier ligt al een trap of helling."
	var far: Vector2 = plan.high if inset else plan.low
	if absf(far.x) > ground.size.x / 2 or absf(far.y) > ground.size.y / 2:
		plan.error = "De trap valt buiten de grond."
	return plan


func _create_stairs(at: Vector3, inset := false) -> LevelRamp:
	var ground := _terrain()
	if ground == null:
		_note("Maak eerst een level met Terrain via Nieuw level.")
		return null
	var local := ground.to_local(at)
	return _build_stairs(_stairs_plan(ground, Vector2(local.x, local.z), inset))


func _build_stairs(plan: Dictionary) -> LevelRamp:
	var ground := _terrain()
	var root := EditorInterface.get_edited_scene_root()
	if ground == null or root == null:
		_note("Maak eerst een level met Terrain via Nieuw level.")
		return null
	if plan.is_empty():
		_note("Beweeg over de rand van een plateau.")
		return null
	if plan.has("error"):
		_note(plan.error)
		return null
	var stairs := LevelRamp.new()
	stairs.name = "Trap" if stair_steps.button_pressed else "Helling"
	stairs.stairs = stair_steps.button_pressed
	# The end on the plateau edge stays put; raising the plateau lengthens the flight.
	stairs.fit_length = true
	stairs.anchor_end = 0 if plan.inset else 1
	stairs.width = plan.width
	stairs.curve = Curve3D.new()
	stairs.curve.resource_local_to_scene = true
	stairs.curve.add_point(Vector3(plan.low.x, 0, plan.low.y))
	stairs.curve.add_point(Vector3(plan.high.x, 0, plan.high.y))
	var undo := get_undo_redo()
	undo.create_action("Trap")
	undo.add_do_method(ground, "add_child", stairs, true)
	undo.add_do_property(stairs, "owner", root)
	undo.add_undo_method(ground, "remove_child", stairs)
	undo.add_do_reference(stairs)
	undo.commit_action()
	_note(plan.get("note", "Trap van %s m naar %s m." % [plan.bottom, plan.top]))
	return stairs


## Bridge end under the mouse: the nearest plateau edge on screen, else the surface hit.
func _bridge_anchor_from_view(ground: LevelTerrain, camera: Camera3D, mouse: Vector2) -> Dictionary:
	var context := _stair_context(ground)
	var nearest := STAIR_PICK_PIXELS * EditorInterface.get_editor_scale()
	var best := {}
	for edge in context.edges:
		var a3 := ground.to_global(Vector3(edge.a.x, edge.top, edge.a.y))
		var b3 := ground.to_global(Vector3(edge.b.x, edge.top, edge.b.y))
		if camera.is_position_behind(a3) or camera.is_position_behind(b3):
			continue
		var sa := camera.unproject_position(a3)
		var sb := camera.unproject_position(b3)
		var closest := Geometry2D.get_closest_point_to_segment(mouse, sa, sb)
		var distance := mouse.distance_to(closest)
		if distance >= nearest:
			continue
		var along: float = edge.length * closest.distance_to(sa) / maxf(sa.distance_to(sb), .001)
		if not _edge_drops(context, edge, edge.a + edge.tangent * along):
			continue
		nearest = distance
		best = _edge_anchor(edge, along)
	if not best.is_empty():
		return best
	var at: Variant = _hit(camera, mouse)
	if at == null:
		return {}
	var local := ground.to_local(at)
	var flat := Vector2(local.x, local.z)
	return {"point": flat, "height": _height_at(ground, flat), "edge": false}


## Bridge end for a terrain-space point (used by tests and tools).
func _bridge_anchor_at(ground: LevelTerrain, point: Vector2) -> Dictionary:
	var context := _stair_context(ground)
	var nearest := STAIR_PICK_DISTANCE
	var best := {}
	for edge in context.edges:
		var closest := Geometry2D.get_closest_point_to_segment(point, edge.a, edge.b)
		var distance := point.distance_to(closest)
		if distance >= nearest or not _edge_drops(context, edge, closest):
			continue
		nearest = distance
		best = _edge_anchor(edge, (closest - edge.a).dot(edge.tangent))
	if not best.is_empty():
		return best
	return {"point": point, "height": _height_at(ground, point), "edge": false}


func _edge_anchor(edge: Dictionary, along: float) -> Dictionary:
	var grid := snap.value if snap.value > 0 else .5
	along = clampf(snappedf(along, grid), 0, edge.length)
	return {"point": edge.a + edge.tangent * along, "height": edge.top, "edge": true}


## {a, b, ha, hb, width}, plus "error" when the deck would be unwalkable or blocked.
func _bridge_plan(ground: LevelTerrain, start: Dictionary, end: Dictionary) -> Dictionary:
	var a: Vector2 = start.point
	var b: Vector2 = end.point
	var plan := {
		"a": a,
		"b": b,
		"ha": float(start.height),
		"hb": float(end.height),
		"width": bridge_width.value,
		"arch_height": bridge_arch.value
	}
	var run := a.distance_to(b)
	if run < 1.0:
		plan.error = "Kies een tweede punt verder weg."
		return plan
	if (absf(plan.hb - plan.ha) + PI * plan.arch_height) / run > LevelTerrain.BRIDGE_SLOPE:
		plan.error = "Te steil voor een brug. Verlaag Booghoogte of kies punten verder uit elkaar."
		return plan
	var plateaus: Array[Dictionary] = _stair_context(ground).plateaus
	var across := (b - a).normalized().orthogonal() * (bridge_width.value / 2 - .05)
	for i in range(1, 10):
		var t := i / 10.0
		var center := a.lerp(b, t)
		var deck := LevelBridge.span_height(plan.ha, plan.hb, t, plan.arch_height)
		for sample in [center - across, center, center + across]:
			if absf(sample.x) > ground.size.x / 2 or absf(sample.y) > ground.size.y / 2:
				plan.error = "De brug valt buiten de grond."
			elif LevelTerrain.height_under(sample, plateaus) > deck + .05:
				plan.error = "De brug gaat door een hoger plateau heen."
	return plan


func _bridge_click(anchor: Dictionary) -> void:
	var ground := _terrain()
	if ground == null or anchor.is_empty():
		_note("Klik op een plateaurand of op de grond.")
		return
	if bridge_start.is_empty():
		bridge_start = anchor
		_note("Beginpunt op %s m. Klik het tweede punt; Esc annuleert." % anchor.height)
		return
	var plan := _bridge_plan(ground, bridge_start, anchor)
	if plan.has("error"):
		_note(plan.error)
		return
	_build_bridge(plan)
	bridge_start = {}


func _create_bridge(from: Vector3, to: Vector3) -> LevelBridge:
	var ground := _terrain()
	if ground == null:
		return null
	var a := ground.to_local(from)
	var b := ground.to_local(to)
	var plan := _bridge_plan(
		ground,
		_bridge_anchor_at(ground, Vector2(a.x, a.z)),
		_bridge_anchor_at(ground, Vector2(b.x, b.z))
	)
	if plan.has("error"):
		_note(plan.error)
		return null
	return _build_bridge(plan)


func _build_bridge(plan: Dictionary) -> LevelBridge:
	var ground := _terrain()
	var root := EditorInterface.get_edited_scene_root()
	if ground == null or root == null:
		return null
	var bridge := LevelBridge.new()
	bridge.name = "Brug"
	bridge.width = plan.width
	bridge.railings = bridge_rails.button_pressed
	bridge.arch_height = plan.get("arch_height", 0.0)
	bridge.curve = Curve3D.new()
	bridge.curve.resource_local_to_scene = true
	bridge.curve.add_point(Vector3(plan.a.x, plan.ha, plan.a.y))
	bridge.curve.add_point(Vector3(plan.b.x, plan.hb, plan.b.y))
	var undo := get_undo_redo()
	undo.create_action("Brug")
	undo.add_do_method(ground, "add_child", bridge, true)
	undo.add_do_property(bridge, "owner", root)
	undo.add_undo_method(ground, "remove_child", bridge)
	undo.add_do_reference(bridge)
	undo.commit_action()
	_note("Brug van %s m naar %s m." % [plan.ha, plan.hb])
	return bridge


func _update_bridge_preview(anchor: Dictionary) -> void:
	var ground := _terrain()
	if ground == null:
		return
	var lines := PackedVector3Array()
	var color := Color(1, .85, .3)
	if not anchor.is_empty():
		_marker(lines, anchor)
	if not bridge_start.is_empty():
		_marker(lines, bridge_start)
		if not anchor.is_empty():
			var plan := _bridge_plan(ground, bridge_start, anchor)
			var a3 := Vector3(plan.a.x, plan.ha, plan.a.y)
			var b3 := Vector3(plan.b.x, plan.hb, plan.b.y)
			var side: Vector2 = (plan.b - plan.a).normalized().orthogonal() * float(plan.width) / 2
			var s := Vector3(side.x, 0, side.y)
			var deck := LevelBridge.make_deck_line(a3, b3, plan.arch_height)
			for i in deck.size() - 1:
				lines.append_array(
					PackedVector3Array([deck[i] - s, deck[i + 1] - s, deck[i] + s, deck[i + 1] + s])
				)
			lines.append_array(PackedVector3Array([a3 - s, a3 + s, b3 - s, b3 + s]))
			if plan.has("error"):
				color = Color(1, .3, .25)
				_note(plan.error)
	if lines.is_empty():
		_clear_preview()
		return
	_draw_preview(lines, color, ground)


func _marker(lines: PackedVector3Array, anchor: Dictionary) -> void:
	var point: Vector2 = anchor.point
	var y: float = anchor.height
	var r := .25
	var corners := [
		Vector3(point.x - r, y, point.y - r),
		Vector3(point.x + r, y, point.y - r),
		Vector3(point.x + r, y, point.y + r),
		Vector3(point.x - r, y, point.y + r)
	]
	for i in 4:
		lines.append(corners[i])
		lines.append(corners[(i + 1) % 4])


func _finish_rectangle(flat: bool) -> void:
	if tool == Tool.WATER:
		_create_water_area(drag_start, drag_end)
	else:
		_create_plateau(drag_start, drag_end, flat)
	drag_start = null
	_clear_preview()


func _create_water_area(start: Vector3, end: Vector3) -> LevelWater:
	var ground := _terrain()
	var root := EditorInterface.get_edited_scene_root()
	if ground == null or root == null:
		_note("Maak eerst een level met Terrain via Nieuw level.")
		return null
	var rect := _drag_rect(ground, ground.to_local(start), ground.to_local(end))
	if rect.size.x < .01 or rect.size.y < .01:
		return null
	var water := LevelWater.new()
	water.name = "Water"
	water.shape = LevelWater.Shape.AREA
	water.depth = water_depth.value
	water.position.y = ground.snap_height(ground.to_local(start).y)
	water.curve = Curve3D.new()
	water.curve.resource_local_to_scene = true
	for corner in [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]:
		water.curve.add_point(Vector3(corner.x, 0, corner.y))
	var undo := get_undo_redo()
	undo.create_action("Water")
	undo.add_do_method(ground, "add_child", water, true)
	undo.add_do_property(water, "owner", root)
	undo.add_undo_method(ground, "remove_child", water)
	undo.add_do_reference(water)
	undo.commit_action()
	_select(water)
	_note("Water geplaatst. Versleep de hoekpunten om de vorm aan te passen.")
	return water


func _update_water_preview() -> void:
	var ground := _terrain()
	if ground == null or drag_start == null:
		return
	var a := ground.to_local(drag_start)
	var rect := _drag_rect(ground, a, ground.to_local(drag_end))
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	var lines := PackedVector3Array()
	for i in 4:
		var p: Vector2 = corners[i]
		var q: Vector2 = corners[(i + 1) % 4]
		lines.append(Vector3(p.x, a.y, p.y))
		lines.append(Vector3(q.x, a.y, q.y))
	_draw_preview(lines, Color(.35, .8, 1.0), ground)


## Release outside the 3D viewport still completes the single transaction.
func _input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		if is_instance_valid(move_node):
			_finish_pending_move.call_deferred()
		if painting:
			_commit_stroke.call_deferred()
	elif (
		is_instance_valid(move_node)
		and event is InputEventKey
		and event.pressed
		and event.keycode == KEY_ESCAPE
	):
		_cancel_move()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_move()
		if painting:
			_commit_stroke()


func _finish_pending_move() -> void:
	if is_instance_valid(move_node):
		_end_move(move_node.get_parent() as LevelTerrain)


func _select_input(camera: Camera3D, event: InputEvent) -> int:
	var ground := _terrain()
	if ground == null:
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventKey and event.pressed:
		# Delete and editor shortcuts retain their normal meaning, never a half-drag.
		_cancel_move()
		_clear_preview()
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.shift_pressed or event.is_command_or_control_pressed():
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			var picked := _selection_pick(ground, camera, event.position)
			if picked.is_empty():
				_clear_preview()
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			_select(picked.node)
			_begin_move(ground, picked.node, picked.point, picked.height)
			move_mouse_start = event.position
			_update_pick_preview(ground, picked)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		if is_instance_valid(move_node):
			_end_move(ground)
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		return EditorPlugin.AFTER_GUI_INPUT_PASS
	if event is InputEventMouseMotion:
		if is_instance_valid(move_node):
			if not move_node.is_inside_tree():
				_cancel_move()
				return EditorPlugin.AFTER_GUI_INPUT_PASS
			move_dragging = (
				move_dragging
				or (
					event.position.distance_to(move_mouse_start)
					>= 4 * EditorInterface.get_editor_scale()
				)
			)
			if move_dragging:
				var origin := ground.to_local(camera.project_ray_origin(event.position))
				var direction := (
					ground.global_basis.inverse() * camera.project_ray_normal(event.position)
				)
				var grab: Variant = Plane(Vector3.UP, move_height).intersects_ray(origin, direction)
				if grab != null:
					_update_move(ground, Vector2(grab.x, grab.z))
			return EditorPlugin.AFTER_GUI_INPUT_STOP
		# Camera navigation and native marquee selection must not leave an outline behind.
		if event.button_mask != 0 or event.shift_pressed or event.is_command_or_control_pressed():
			_clear_preview()
		else:
			_update_pick_preview(ground, _selection_pick(ground, camera, event.position))
	return EditorPlugin.AFTER_GUI_INPUT_PASS


func _selection_pick(ground: LevelTerrain, camera: Camera3D, mouse: Vector2) -> Dictionary:
	var picked := _pick_authoring(ground, camera, mouse)
	if not picked.is_empty() and _asset_in_front(camera, mouse, picked.distance):
		return {}
	return picked


## Intersect the visible mesh, including walls, curved slopes and sloping bridge rails.
## Mesh caches its triangle BVH until its geometry changes.
func _mesh_hit(mesh: MeshInstance3D, origin: Vector3, direction: Vector3) -> Dictionary:
	if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
		return {}
	var inverse := mesh.global_transform.affine_inverse()
	var local_origin := inverse * origin
	var local_direction := inverse.basis * direction
	if mesh.mesh.get_aabb().intersects_ray(local_origin, local_direction) == null:
		return {}
	var triangles := mesh.mesh.generate_triangle_mesh()
	if triangles == null:
		return {}
	var hit := triangles.intersect_ray(local_origin, local_direction)
	if not hit.is_empty():
		hit.position = mesh.global_transform * hit.position
		hit.normal = (inverse.basis.transposed() * hit.normal).normalized()
	return hit


## Returns a terrain-local grab point and a WORLD-space ray distance.
func _pick_authoring(ground: LevelTerrain, camera: Camera3D, mouse: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var best := {}
	var nearest := INF
	var surface := ground.get_node_or_null("Baked/Surface") as MeshInstance3D
	var hit := _mesh_hit(surface, origin, direction)
	if not hit.is_empty():
		nearest = origin.distance_to(hit.position)
		var local := ground.to_local(hit.position)
		var normal: Vector3 = ground.global_basis.transposed() * hit.normal
		var point := Vector2(local.x, local.z)
		# Just inside a wall/cap lies the authored region that owns that face.
		if absf(normal.y) < .7:
			point -= Vector2(normal.x, normal.z).normalized() * .06
		var node := _region_node_at(ground, point, normal.y > .7)
		if node:
			best = {
				"node": node,
				"point": Vector2(local.x, local.z),
				"height": local.y,
				"distance": nearest
			}
	for child in ground.get_children():
		if (
			not (child is LevelBridge or child is LevelWater or child is LevelBoundary or child is LevelDoor)
			or not child.is_visible_in_tree()
		):
			continue
		for mesh in child.find_children("*", "MeshInstance3D", true, false):
			var child_hit := _mesh_hit(mesh, origin, direction)
			if child_hit.is_empty():
				continue
			var distance := origin.distance_to(child_hit.position)
			# A door frame stands flush with its wall: let it win a near tie with the rock.
			if child is LevelDoor:
				distance -= .15
			if distance >= nearest:
				continue
			nearest = distance
			var local := ground.to_local(child_hit.position)
			best = {
				"node": child,
				"point": Vector2(local.x, local.z),
				"height": local.y,
				"distance": nearest
			}
	return best


## Outlines are exclusive. Paint on a top surface is selectable before its plateau.
func _region_node_at(ground: LevelTerrain, point: Vector2, include_paths := true) -> Node3D:
	var top: Node3D
	for region in ground.outlines():
		if Geometry2D.is_point_in_polygon(point, region.polygon):
			top = ground.get_node_or_null(NodePath(String(region.name))) as Node3D
			break
	if top is LevelWater or not include_paths:
		return top
	for child in ground.get_children():
		if not child is LevelPath or child.curve == null:
			continue
		var points := _path_points(child)
		for i in maxi(1, points.size() - 1):
			if points.is_empty():
				break
			var closest := Geometry2D.get_closest_point_to_segment(
				point, points[i], points[mini(i + 1, points.size() - 1)]
			)
			if point.distance_to(closest) <= child.width / 2:
				return child
	return top


func _path_points(path: LevelPath) -> PackedVector2Array:
	var result := PackedVector2Array()
	if path.curve:
		for p in path.curve.get_baked_points():
			var point: Vector3 = path.transform * p
			result.append(Vector2(point.x, point.z))
	return result


## All visible scene meshes participate, including Player and manually nested assets.
## A broad-phase box only narrows candidates; empty space around a mesh is still clickable.
func _asset_in_front(camera: Camera3D, mouse: Vector2, distance: float) -> bool:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return false
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var ground := _terrain()
	var candidates: Array = []
	for id in RenderingServer.instances_cull_ray(
		origin, origin + direction * distance, camera.get_world_3d().scenario
	):
		candidates.append(instance_from_id(id))
	if candidates.is_empty():
		# The headless dummy renderer keeps no culling structure; walk the scene instead.
		candidates = root.find_children("*", "MeshInstance3D", true, false)
	for candidate in candidates:
		var mesh := candidate as MeshInstance3D
		if mesh == null or mesh == preview or not root.is_ancestor_of(mesh):
			continue
		if ground and ground.is_ancestor_of(mesh):
			continue
		var hit := _mesh_hit(mesh, origin, direction)
		if not hit.is_empty() and origin.distance_to(hit.position) < distance - .01:
			return true
	return false


func _move_state(node: Path3D) -> Dictionary:
	var state := {
		"transform": node.transform, "curve": node.curve.duplicate() if node.curve else null
	}
	if node is LevelRamp:
		state.merge(
			{
				"anchor_end": node.anchor_end,
				"follow_ground": node.follow_ground,
				"fit_length": node.fit_length,
				"width": node.width
			}
		)
	return state


func _apply_move_states(items: Array[Dictionary], ground: LevelTerrain) -> void:
	for item in items:
		if not is_instance_valid(item.node):
			continue
		for property in item.state:
			var value: Variant = item.state[property]
			item.node.set(property, value.duplicate() if value is Curve3D else value)
	if is_instance_valid(ground) and ground.is_inside_tree():
		ground.bake()
	selection_editor.refresh()


func _begin_move(ground: LevelTerrain, node: Node3D, point: Vector2, height: float) -> void:
	_cancel_move()
	if ground.dirty:
		ground.bake()
	move_node = node
	move_start = point
	move_height = height
	move_last = Vector2.ZERO
	move_dragging = false
	move_items = [{"node": node, "state": _move_state(node), "translate": true}]
	# Baking may refit any ground-following connector. Snapshot them too, so undo
	# also restores a foot that acquired a new height as the plateau passed it.
	for child in ground.get_children():
		if child == node or not (child is LevelRamp or child is LevelBridge):
			continue
		var item := {"node": child, "state": _move_state(child), "translate": false, "ends": []}
		if node is LevelTerrace and child.curve and child.curve.point_count == 2:
			if child is LevelRamp:
				item.translate = _supporting_plateau(ground, child, child.anchor_end) == node
			else:
				for i in 2:
					if _supporting_plateau(ground, child, i) == node:
						item.ends.append(i)
		move_items.append(item)


## Sample toward the supporting side of the endpoint, just as height following does.
## Inset stairs attach at their LOW end but rest inside the plateau toward the high end.
func _supporting_plateau(ground: LevelTerrain, connector: Path3D, index: int) -> LevelTerrace:
	index = clampi(index, 0, 1)
	var a: Vector3 = connector.transform * connector.curve.get_point_position(index)
	var b: Vector3 = connector.transform * connector.curve.get_point_position(1 - index)
	var direction := Vector2(a.x - b.x, a.z - b.z).normalized()
	if connector is LevelRamp and index == 0:
		direction = -direction
	var point := Vector2(a.x, a.z) + direction * .05
	var best: LevelTerrace
	var highest := -INF
	for child in ground.get_children():
		if not child is LevelTerrace or child.curve == null:
			continue
		var polygon := PackedVector2Array()
		for i in child.curve.point_count:
			var corner: Vector3 = child.transform * child.curve.get_point_position(i)
			polygon.append(Vector2(corner.x, corner.z))
		var height := ground.snap_height(child.height + child.position.y)
		if height > highest and Geometry2D.is_point_in_polygon(point, polygon):
			highest = height
			best = child
	# A manually raised connector floating over a plateau is not attached to it.
	var support_height := maxf(a.y, b.y) if connector is LevelRamp and index == 0 else a.y
	return best if absf(support_height - highest) < .1 else null


func _update_move(ground: LevelTerrain, point: Vector2) -> void:
	var delta := point - move_start
	if snap.value > 0:
		delta = (delta / snap.value).round() * snap.value
	if delta == move_last:
		return
	move_last = delta
	for item in move_items:
		var node := item.node as Path3D
		if not is_instance_valid(node):
			continue
		if item.translate:
			node.position = item.state.transform.origin + Vector3(delta.x, 0, delta.y)
		elif not item.get("ends", []).is_empty():
			var curve := (item.state.curve as Curve3D).duplicate() as Curve3D
			var shift := node.transform.basis.inverse() * Vector3(delta.x, 0, delta.y)
			for i in item.ends:
				curve.set_point_position(i, curve.get_point_position(i) + shift)
			node.curve = curve
	_update_pick_preview(ground, {"node": move_node})


func _cancel_move() -> void:
	if move_items.is_empty():
		move_node = null
		return
	var ground: LevelTerrain = (
		move_node.get_parent() as LevelTerrain if is_instance_valid(move_node) else null
	)
	var before: Array[Dictionary] = []
	for item in move_items:
		before.append({"node": item.node, "state": item.state})
	move_node = null
	move_items.clear()
	_apply_move_states(before, ground)
	_clear_preview()


func _end_move(ground: LevelTerrain) -> void:
	if not is_instance_valid(move_node) or ground == null:
		_cancel_move()
		return
	if move_last == Vector2.ZERO:
		_cancel_move()
		return
	var node := move_node
	if node is LevelRamp and node.curve and node.curve.point_count == 2:
		var plan := _snap_stairs_plan(ground, node)
		if not plan.is_empty():
			var curve := Curve3D.new()
			curve.resource_local_to_scene = true
			# Preserve the node transform; only the fitted curve changes in its local space.
			var inverse := node.transform.affine_inverse()
			curve.add_point(inverse * Vector3(plan.low.x, plan.bottom, plan.low.y))
			curve.add_point(inverse * Vector3(plan.high.x, plan.top, plan.high.y))
			node.curve = curve
			node.anchor_end = 0 if plan.inset else 1
			node.follow_ground = true
			node.fit_length = true
	if not ground.bake():
		var reason := ground.last_error
		_cancel_move()
		_note("Verplaatsen geannuleerd: " + reason)
		return
	var before: Array[Dictionary] = []
	var after: Array[Dictionary] = []
	var carried := 0
	for item in move_items:
		before.append({"node": item.node, "state": item.state})
		after.append({"node": item.node, "state": _move_state(item.node)})
		if item.node != node and (item.translate or not item.get("ends", []).is_empty()):
			carried += 1
	var undo := get_undo_redo()
	undo.create_action("Verplaats " + String(node.name), UndoRedo.MERGE_DISABLE, ground)
	undo.add_do_method(self, "_apply_move_states", after, ground)
	undo.add_undo_method(self, "_apply_move_states", before, ground)
	undo.commit_action(false)
	move_node = null
	move_items.clear()
	_update_pick_preview(ground, {"node": node})
	_note(
		(
			"%s verplaatst%s."
			% [node.name, " (met %d aangesloten onderdelen)" % carried if carried > 0 else ""]
		)
	)


## Plan without this flight, so its own notch cannot block the destination edge.
func _snap_stairs_plan(ground: LevelTerrain, stairs: LevelRamp) -> Dictionary:
	var anchor_index := clampi(stairs.anchor_end, 0, 1)
	var anchor: Vector3 = stairs.transform * stairs.curve.get_point_position(anchor_index)
	var curve := stairs.curve
	var width := stair_width.value
	var steps := stair_steps.button_pressed
	stairs.curve = null
	stair_width.set_value_no_signal(stairs.width)
	stair_steps.set_pressed_no_signal(stairs.stairs)
	var plan := _stairs_plan(ground, Vector2(anchor.x, anchor.z), anchor_index == 0)
	stairs.curve = curve
	stair_width.set_value_no_signal(width)
	stair_steps.set_pressed_no_signal(steps)
	if plan.is_empty() or plan.has("error") or not is_equal_approx(plan.width, stairs.width):
		return {}
	return plan


func _update_pick_preview(ground: LevelTerrain, picked: Dictionary) -> void:
	if picked.is_empty() or not is_instance_valid(picked.node):
		_clear_preview()
		return
	var node: Node3D = picked.node
	var lines := PackedVector3Array()
	if node is LevelBoundary:
		var points: PackedVector3Array = node.ground_line()
		for i in points.size() - 1:
			lines.append_array(PackedVector3Array([points[i], points[i + 1]]))
		if node.block_movement and points.size() >= 2:
			var up: Vector3 = Vector3.UP * node.barrier_height
			for i in points.size() - 1:
				lines.append_array(PackedVector3Array([points[i] + up, points[i + 1] + up]))
			for point in [points[0], points[-1]]:
				lines.append_array(PackedVector3Array([point, point + up]))
	elif node is LevelBridge:
		var deck: Array[Vector3] = node.deck_line()
		if deck.size() >= 4:
			var side: Vector3 = (
				Vector3(-(deck[2] - deck[1]).z, 0, (deck[2] - deck[1]).x).normalized()
				* node.width
				/ 2
			)
			for i in deck.size() - 1:
				for sign in [-1.0, 1.0]:
					lines.append(
						(
							node.transform
							* (deck[i] + side * sign + Vector3.UP * LevelBridge.DECK_LIFT)
						)
					)
					lines.append(
						(
							node.transform
							* (deck[i + 1] + side * sign + Vector3.UP * LevelBridge.DECK_LIFT)
						)
					)
			for i in [0, deck.size() - 1]:
				lines.append(node.transform * (deck[i] - side + Vector3.UP * LevelBridge.DECK_LIFT))
				lines.append(node.transform * (deck[i] + side + Vector3.UP * LevelBridge.DECK_LIFT))
	elif node is LevelPath:
		var points := _path_points(node)
		if points.size() >= 2:
			for polygon in Geometry2D.offset_polyline(
				points, node.width / 2, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND
			):
				_append_outline(lines, polygon, ground)
	else:
		for region in ground.outlines():
			if region.name == node.name:
				_append_outline(lines, region.polygon, ground, region)
	if lines.is_empty():
		_clear_preview()
		return
	_draw_preview(lines, Color.WHITE, ground)


func _append_outline(
	lines: PackedVector3Array, polygon: PackedVector2Array, ground: LevelTerrain, region := {}
) -> void:
	var surfaces: Array[Dictionary] = []
	if region.is_empty():
		surfaces = ground.outlines()
	for i in polygon.size():
		var p := polygon[i]
		var q := polygon[(i + 1) % polygon.size()]
		# Sample long edges too, so a path outline follows the terrain under it.
		var steps := maxi(1, ceili(p.distance_to(q) / .25))
		for step in steps:
			for point in [p.lerp(q, float(step) / steps), p.lerp(q, float(step + 1) / steps)]:
				var height := 0.0
				if region.is_empty():
					for surface in surfaces:
						if Geometry2D.is_point_in_polygon(point, surface.polygon):
							height = maxf(height, LevelTerrain.region_height(surface, point))
				else:
					height = LevelTerrain.region_height(region, point)
				if region.has("water"):
					var water := ground.get_node(NodePath(String(region.name))) as LevelWater
					height = water.elevation() - water.surface_drop
				lines.append(Vector3(point.x, height, point.y))


## Nearest ground edge to a terrain point: {side (0 N, 1 E, 2 S, 3 W), along}, or {}.
func _door_plan(ground: LevelTerrain, point: Vector2) -> Dictionary:
	var half := ground.size / 2
	var distances := [
		absf(point.y + half.y), absf(point.x - half.x), absf(point.y - half.y), absf(point.x + half.x)
	]
	var side := 0
	for i in 4:
		if distances[i] < distances[side]:
			side = i
	if distances[side] > 2.5:
		return {}
	var length: float = ground.size.x if side % 2 == 0 else ground.size.y
	var grid := snap.value if snap.value > 0 else .5
	var margin := door_width.value / 2 + .4
	var along := clampf(
		snappedf(point.x if side % 2 == 0 else point.y, grid), -length / 2 + margin, length / 2 - margin
	)
	return {"side": side, "along": along}


## A door in the plateau wall under the mouse: the wall face itself, the ground just in
## front of it, or else the top edge nearest on screen (like picking stairs).
## {cliff, point, outward, bottom, top, width, height}, "error" when it does not fit, or {}.
func _cliff_door_plan_from_view(ground: LevelTerrain, camera: Camera3D, mouse: Vector2) -> Dictionary:
	var context := _stair_context(ground)
	var origin := ground.to_local(camera.project_ray_origin(mouse))
	var direction := (ground.global_basis.inverse() * camera.project_ray_normal(mouse)).normalized()
	var best := {}
	var best_along := 0.0
	var best_score := INF
	for edge in context.edges:
		var normal := Vector3(edge.outward.x, 0, edge.outward.y)
		var start := Vector3(edge.a.x, 0, edge.a.y)
		# The wall face: a vertical plane through the edge, facing out.
		var facing := direction.dot(normal)
		if facing < -.001:
			var t := (start - origin).dot(normal) / facing
			var hit := origin + direction * t
			var along: float = (Vector2(hit.x, hit.z) - edge.a).dot(edge.tangent)
			if t > 0 and along >= 0 and along <= edge.length:
				var point: Vector2 = edge.a + edge.tangent * along
				var bottom := LevelTerrain.height_under(point + edge.outward * .05, context.plateaus)
				if hit.y >= bottom - .1 and hit.y <= edge.top + .1 and edge.top - bottom >= LevelTerrain.HEIGHT_STEP - LevelTerrain.EPS:
					if t < best_score:
						best_score = t
						best = edge
						best_along = along
					continue
		# The ground right in front of the wall.
		var along_edge := 0.0
		if absf(direction.y) > .001:
			var foot: Vector2 = edge.a + edge.outward * .5
			var low := LevelTerrain.height_under(foot + edge.tangent * edge.length / 2, context.plateaus)
			var t_ground := (low - origin.y) / direction.y
			if t_ground > 0:
				var spot := origin + direction * t_ground
				var flat := Vector2(spot.x, spot.z)
				along_edge = (flat - edge.a).dot(edge.tangent)
				var out: float = (flat - edge.a).dot(edge.outward)
				if along_edge >= 0 and along_edge <= edge.length and out >= 0 and out <= 1.5:
					var point: Vector2 = edge.a + edge.tangent * along_edge
					if _edge_drops(context, edge, point) and t_ground + 1000.0 < best_score:
						best_score = t_ground + 1000.0
						best = edge
						best_along = along_edge
	if best.is_empty():
		# Fallback: the top edge nearest on screen.
		var nearest := STAIR_PICK_PIXELS * EditorInterface.get_editor_scale()
		for edge in context.edges:
			var a3 := ground.to_global(Vector3(edge.a.x, edge.top, edge.a.y))
			var b3 := ground.to_global(Vector3(edge.b.x, edge.top, edge.b.y))
			if camera.is_position_behind(a3) or camera.is_position_behind(b3):
				continue
			var sa := camera.unproject_position(a3)
			var sb := camera.unproject_position(b3)
			var closest := Geometry2D.get_closest_point_to_segment(mouse, sa, sb)
			var distance := mouse.distance_to(closest)
			var along: float = edge.length * closest.distance_to(sa) / maxf(sa.distance_to(sb), .001)
			if distance >= nearest or not _edge_drops(context, edge, edge.a + edge.tangent * along):
				continue
			nearest = distance
			best = edge
			best_along = along
	return {} if best.is_empty() else _cliff_door_on_edge(context, best, best_along)


## Same as above for a terrain-space point near a plateau edge (tests and tools).
func _cliff_door_plan(ground: LevelTerrain, point: Vector2) -> Dictionary:
	var context := _stair_context(ground)
	var nearest := STAIR_PICK_DISTANCE
	var best := {}
	var best_along := 0.0
	for edge in context.edges:
		var closest := Geometry2D.get_closest_point_to_segment(point, edge.a, edge.b)
		if point.distance_to(closest) >= nearest or not _edge_drops(context, edge, closest):
			continue
		nearest = point.distance_to(closest)
		best = edge
		best_along = (closest - edge.a).dot(edge.tangent)
	return {} if best.is_empty() else _cliff_door_on_edge(context, best, best_along)


func _cliff_door_on_edge(context: Dictionary, edge: Dictionary, along: float) -> Dictionary:
	var width := minf(door_width.value, edge.length - 1.2)
	var grid := snap.value if snap.value > 0 else .5
	var margin := width / 2 + .6
	along = clampf(snappedf(along, grid), margin, edge.length - margin)
	var point: Vector2 = edge.a + edge.tangent * along
	var bottom := LevelTerrain.height_under(point + edge.outward * .05, context.plateaus)
	var plan := {
		"cliff": true,
		"point": point,
		"outward": edge.outward,
		"bottom": bottom,
		"top": edge.top,
		"width": width,
		"height": minf(2.3, edge.top - bottom - .3)
	}
	if width < 1.0:
		plan.error = "Deze plateaurand is te kort voor een deur."
	elif edge.top - bottom < 2.0 - LevelTerrain.EPS:
		plan.error = "Het plateau is te laag voor een deur (minstens 2 m)."
	return plan


func _update_cliff_door_preview(ground: LevelTerrain, plan: Dictionary) -> void:
	var base: Vector3 = Vector3(plan.point.x, plan.bottom, plan.point.y)
	var across: Vector3 = Vector3(-plan.outward.y, 0, plan.outward.x) * plan.width / 2
	var up: Vector3 = Vector3.UP * maxf(plan.height, .5)
	var lines := PackedVector3Array(
		[base - across, base - across + up, base + across, base + across + up, base - across + up, base + across + up]
	)
	_draw_preview(lines, Color(1, .3, .25) if plan.has("error") else Color(1, .85, .3), ground)


func _unique_door_id(ground: Node, base: String) -> StringName:
	# Unique both as node name and as door code: arrivals look doors up by code.
	var used: Array[StringName] = []
	var root := EditorInterface.get_edited_scene_root()
	for node in (root if root else ground).find_children("*", "Area3D", true, false):
		if node is LevelDoor:
			used.append(node.door_id)
	var candidate := base
	var index := 2
	while ground.has_node(NodePath(candidate)) or StringName(candidate) in used:
		candidate = base + str(index)
		index += 1
	return StringName(candidate)


func _create_door(ground: LevelTerrain, plan: Dictionary) -> LevelDoor:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return null
	# Outdoors on the edge of the ground a passage is an open gap or a gate, never a door.
	var outdoor_edge: bool = not ground.room_walls and not plan.get("cliff", false)
	var style: int = door_style.selected
	if outdoor_edge and not style in [LevelDoor.Style.GATE, LevelDoor.Style.CAVE]:
		style = LevelDoor.Style.OPENING
	elif plan.get("cliff", false) and style in [LevelDoor.Style.GATE]:
		style = LevelDoor.Style.STONE_ARCH
	var door := FACTORY.add_door(
		ground,
		root,
		plan.get("side", 0),
		plan.get("along", 0.0),
		_unique_door_id(ground, "Doorgang" if outdoor_edge else "Deur"),
		"",
		&"",
		style
	)
	door.light = door_light.selected
	door.width = door_width.value
	if plan.get("cliff", false):
		door.cliff_door = true
		door.width = plan.width
		door.height = plan.height
		door.position = Vector3(plan.point.x, plan.bottom, plan.point.y) + Vector3(plan.outward.x, 0, plan.outward.y) * .02
		door.rotation = Vector3(0, atan2(plan.outward.x, plan.outward.y), 0)
	var undo := get_undo_redo()
	undo.create_action("Deur")
	undo.add_do_method(ground, "add_child", door, true)
	undo.add_do_property(door, "owner", root)
	undo.add_undo_method(ground, "remove_child", door)
	undo.add_do_reference(door)
	undo.commit_action(false)
	_clear_preview()
	_select(door)
	_refresh_links(true)
	_note("Deur geplaatst. Kies rechts waar hij heen gaat: een bestaande scene of een nieuwe kamer.")
	return door


func _update_door_preview(ground: LevelTerrain, hit: Variant) -> void:
	if hit == null:
		_clear_preview()
		return
	var local := ground.to_local(hit)
	var plan := _door_plan(ground, Vector2(local.x, local.z))
	if plan.is_empty():
		_clear_preview()
		return
	var half := ground.size / 2
	var edge: Vector2 = [
		Vector2(plan.along, -half.y),
		Vector2(half.x, plan.along),
		Vector2(plan.along, half.y),
		Vector2(-half.x, plan.along)
	][plan.side]
	var across := Vector3(1, 0, 0) if plan.side % 2 == 0 else Vector3(0, 0, 1)
	var base := Vector3(edge.x, 0, edge.y)
	var w := door_width.value / 2
	var up := Vector3.UP * 2.3
	var lines := PackedVector3Array(
		[
			base - across * w,
			base - across * w + up,
			base + across * w,
			base + across * w + up,
			base - across * w + up,
			base + across * w + up
		]
	)
	_draw_preview(lines, Color(1, .85, .3), ground)


func _scene_spawn_ids(path: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not ResourceLoader.exists(path):
		return ids
	var packed := load(path) as PackedScene
	if packed == null:
		return ids
	var instance := packed.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	for node in instance.find_children("*", "Marker3D", true, false):
		# Spawn points are not tool scripts: in the editor read the property, not spawn_key().
		var id: Variant = node.get("spawn_id") if node is SceneSpawnPoint else null
		if id is StringName and not id in ids:
			ids.append(id)
	instance.free()
	return ids


func _set_door_link(door: LevelDoor, path: String, spawn: StringName) -> void:
	if not is_instance_valid(door):
		return
	var undo := get_undo_redo()
	undo.create_action("Verbind deur")
	undo.add_do_property(door, "target_scene", path)
	undo.add_do_property(door, "target_spawn", spawn)
	undo.add_do_property(door, "outside_light", _scene_is_outside(path))
	undo.add_undo_property(door, "target_scene", door.target_scene)
	undo.add_undo_property(door, "target_spawn", door.target_spawn)
	undo.add_undo_property(door, "outside_light", door.outside_light)
	undo.commit_action()
	selection_editor.refresh.call_deferred()
	_refresh_links(true)


## A scene without room walls is the outside world: doors there let daylight in.
func _scene_is_outside(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	return not "room_walls = true" in text


func _set_door_property(door: LevelDoor, property: StringName, value: Variant) -> void:
	if not is_instance_valid(door) or door.get(property) == value:
		return
	var undo := get_undo_redo()
	undo.create_action("Deur aanpassen")
	undo.add_do_property(door, property, value)
	undo.add_undo_property(door, property, door.get(property))
	undo.commit_action()


func _link_door_to_scene(door: LevelDoor, path: String) -> void:
	var ids := _scene_spawn_ids(path)
	_set_door_link(door, path, ids[0] if not ids.is_empty() else &"Entrance")
	_note("Deur verbonden met %s. Kies het aankomstpunt in de lijst rechts." % path.get_file())


func _door_side(ground: LevelTerrain, door: LevelDoor) -> int:
	var half := ground.size / 2
	var p := door.position
	var distances := [absf(p.z + half.y), absf(p.x - half.x), absf(p.z - half.y), absf(p.x + half.x)]
	var side := 0
	for i in 4:
		if distances[i] < distances[side]:
			side = i
	return side


## Creates a walled room scene behind a door, with a door back, and links both ways.
func _create_room_behind(door: LevelDoor, title: String, kind: String, size: Vector2) -> String:
	var source := EditorInterface.get_edited_scene_root()
	if not is_instance_valid(door) or source == null or source.scene_file_path.is_empty():
		_note("Sla het level eerst op en selecteer een deur.")
		return ""
	var slug := _slug(title)
	if slug.is_empty():
		_note("Vul een naam in voor de kamer.")
		return ""
	var path := "res://scenes/levels/" + slug.to_pascal_case() + ".tscn"
	var area_path := "res://settings/areas/" + slug + ".tres"
	if FileAccess.file_exists(path) or FileAccess.file_exists(area_path):
		_note("Er bestaat al een scene of gebied met die naam.")
		return ""
	var area := WorldArea.new()
	area.code = StringName("area." + Crypto.new().generate_random_bytes(16).hex_encode())
	area.display_name = title.strip_edges()
	area.scene_path = path
	var error := ResourceSaver.save(area, area_path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		_note("Opslaan mislukt: " + error_string(error))
		return ""
	area.take_over_path(area_path)
	var root: Node3D
	if kind == "outdoor":
		# A new outdoor area with the kit chosen in the builder (forest by default).
		var outdoor_kit := _kit() if _kit() and not _kit().id in [&"interior", &"cave"] else load("res://settings/area_sets/forest.tres") as AreaSet
		root = FACTORY.create(outdoor_kit, area, size)
	else:
		var kit := load("res://settings/area_sets/%s.tres" % ("cave" if kind == "dungeon" else "interior")) as AreaSet
		root = FACTORY.create_room("interior", kit, area, size)
	# The player keeps walking the same way: they enter the new room through the wall
	# that faces the way this door faces, so the doorway sits in the same corner of the
	# screen on both sides, whether it is set into a room wall, a plateau or an edge.
	var facing := Vector2(door.global_basis.z.x, door.global_basis.z.z).normalized()
	var back_side := 0
	var best := -INF
	for candidate in 4:
		var normal: Vector2 = [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][candidate]
		if normal.dot(facing) > best:
			best = normal.dot(facing)
			back_side = candidate
	var back_id := StringName("Naar" + source.scene_file_path.get_file().get_basename())
	FACTORY.add_door(
		root.get_node("Terrain"),
		root,
		back_side,
		0,
		back_id,
		source.scene_file_path,
		door.door_id,
		LevelDoor.Style.OPENING if kind == "outdoor" else (LevelDoor.Style.STONE_ARCH if kind == "dungeon" else LevelDoor.Style.WOODEN_DOOR)
	)
	FACTORY.start_at_door(root, back_id)
	error = FACTORY.save(root, path)
	root.free()
	if error != OK:
		_note("Kamer opslaan mislukt: " + error_string(error))
		return ""
	_set_door_link(door, path, back_id)
	EditorInterface.save_scene()
	EditorInterface.get_resource_filesystem().scan()
	_note("Kamer %s gemaakt en verbonden. Open hem via Verbonden ruimtes." % title.strip_edges())
	return path


func _new_room_root(kind: String, area: WorldArea, path: String, slug: String, size: Vector2) -> Node3D:
	match kind:
		"interior":
			return FACTORY.create_room("interior", load("res://settings/area_sets/interior.tres"), area, size)
		"dungeon":
			var dungeon := DungeonDefinition.new()
			dungeon.id = StringName(slug)
			dungeon.display_name = area.display_name
			dungeon.scene_path = path
			dungeon.entrance = &"DungeonEntrance"
			var dungeon_path := "res://settings/dungeons/" + slug + ".tres"
			if ResourceSaver.save(dungeon, dungeon_path, ResourceSaver.FLAG_CHANGE_PATH) == OK:
				dungeon.take_over_path(dungeon_path)
			return FACTORY.create_room("dungeon", load("res://settings/area_sets/cave.tres"), area, size, dungeon)
	return FACTORY.create(_kit(), area, size)


## Places a door (interior) or a Drempelpoort (dungeon) in the open level for a new room.
func _connect_new_room(kind: String, room: Node3D, path: String) -> void:
	var source := EditorInterface.get_edited_scene_root()
	var ground := _terrain()
	var start: Variant = source.get("spawn_position")
	var spot: Vector3 = ground.to_local(source.to_global(start if start is Vector3 else Vector3.ZERO))
	spot += Vector3(0, 0, -3)
	spot.x = clampf(spot.x, -ground.size.x / 2 + 2, ground.size.x / 2 - 2)
	spot.z = clampf(spot.z, -ground.size.y / 2 + 2, ground.size.y / 2 - 2)
	var undo := get_undo_redo()
	if kind == "dungeon":
		var gate: Node3D = load("res://scenes/world/dungeons/Drempelpoort.tscn").instantiate()
		var parent := source.get_node_or_null("Gameplay") as Node3D
		if parent == null:
			parent = source
		gate.name = "Drempelpoort"
		gate.position = parent.to_local(ground.to_global(spot))
		gate.set("dungeon", room.get("dungeon"))
		undo.create_action("Drempelpoort naar dungeon")
		undo.add_do_method(parent, "add_child", gate, true)
		undo.add_do_property(gate, "owner", source)
		undo.add_undo_method(parent, "remove_child", gate)
		undo.add_do_reference(gate)
		undo.commit_action()
		_select(gate)
		return
	var door_id := _unique_door_id(ground, "Deur")
	var door := FACTORY.add_door(ground, source, 0, 0, door_id, path, &"NaarBuiten")
	if not ground.room_walls:
		# Outdoors the door stands free where the player starts.
		door.position = spot
		door.rotation_degrees.y = 0
	undo.create_action("Deur naar nieuwe ruimte")
	undo.add_do_method(ground, "add_child", door, true)
	undo.add_do_property(door, "owner", source)
	undo.add_undo_method(ground, "remove_child", door)
	undo.add_do_reference(door)
	undo.commit_action(false)
	FACTORY.add_door(room.get_node("Terrain"), room, 2, 0, &"NaarBuiten", source.scene_file_path, door_id)
	FACTORY.start_at_door(room, &"NaarBuiten")
	_select(door)


## Lists every door, portal and gate in the open scene with a quick Open button.
func _refresh_links(force := false) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var entries: Array = []
	if root:
		for node in root.find_children("*", "Area3D", true, false):
			if not node is ScenePortal:
				continue
			var target := ""
			var dungeon_exit: bool = node.get("dungeon") != null and not node is ThresholdGate
			if node is ThresholdGate and node.dungeon:
				target = node.dungeon.scene_path
			elif not dungeon_exit:
				target = node.target_scene
			entries.append([node, target, dungeon_exit])
	var signature := str(entries.map(func(entry): return [String(entry[0].name), entry[1]]))
	if signature == links_signature and not force:
		return
	links_signature = signature
	for child in links_box.get_children():
		links_box.remove_child(child)
		child.queue_free()
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "Nog geen deuren of poorten."
		links_box.add_child(empty)
		return
	for entry in entries:
		var node: Node = entry[0]
		var target: String = entry[1]
		var row := HBoxContainer.new()
		var pick := Button.new()
		pick.flat = true
		pick.clip_text = true
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var suffix := " (niet verbonden)"
		if entry[2]:
			suffix = " → terug naar de poort"
		elif not target.is_empty():
			suffix = " → " + target.get_file().get_basename()
		pick.text = String(node.name) + suffix
		pick.pressed.connect(func(): _select(node))
		row.add_child(pick)
		if not target.is_empty() and ResourceLoader.exists(target):
			var open := Button.new()
			open.text = "Open"
			open.pressed.connect(func(): EditorInterface.open_scene_from_path(target))
			row.add_child(open)
		links_box.add_child(row)


func _select(node: Node) -> void:
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(node)
	EditorInterface.edit_node(node)


func _update_plateau_preview(flat: bool) -> void:
	var ground := _terrain()
	if ground == null or drag_start == null:
		return
	var a := ground.to_local(drag_start)
	var rect := _drag_rect(ground, a, ground.to_local(drag_end))
	var base := ground.snap_height(a.y)
	var top := _plateau_height(ground, a, flat)
	var corners := [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	var lines := PackedVector3Array()
	for i in 4:
		var p: Vector2 = corners[i]
		var q: Vector2 = corners[(i + 1) % 4]
		lines.append_array(
			PackedVector3Array(
				[
					Vector3(p.x, top, p.y),
					Vector3(q.x, top, q.y),
					Vector3(p.x, base, p.y),
					Vector3(p.x, top, p.y)
				]
			)
		)
	_draw_preview(lines, Color(1, .85, .3), ground)


func _update_stairs_preview(plan: Dictionary) -> void:
	var ground := _terrain()
	if ground == null or plan.is_empty():
		_clear_preview()
		return
	var low: Vector2 = plan.low
	var high: Vector2 = plan.high
	var side: Vector2 = (high - low).normalized().orthogonal() * float(plan.width) / 2
	var lines := PackedVector3Array()
	var steps := maxi(1, roundi((plan.top - plan.bottom) / LevelTerrain.STAIR_RISE))
	for i in steps + 1 if stair_steps.button_pressed else [0, steps]:
		var t := float(i) / steps
		var center := low.lerp(high, t)
		var y := lerpf(plan.bottom, plan.top, t)
		lines.append_array(
			PackedVector3Array(
				[
					Vector3(center.x - side.x, y, center.y - side.y),
					Vector3(center.x + side.x, y, center.y + side.y)
				]
			)
		)
	for offset in [-side, side]:
		lines.append_array(
			PackedVector3Array(
				[
					Vector3(low.x + offset.x, plan.bottom, low.y + offset.y),
					Vector3(high.x + offset.x, plan.top, high.y + offset.y)
				]
			)
		)
	_draw_preview(lines, Color(1, .3, .25) if plan.has("error") else Color(1, .85, .3), ground)
	if plan.has("error"):
		_note(plan.error)
	elif plan.has("note"):
		_note(plan.note)


func _draw_preview(lines: PackedVector3Array, color: Color, ground: LevelTerrain) -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	if not is_instance_valid(preview):
		# Unowned helper: visible in the viewport, never saved or listed in the Scene dock.
		preview = MeshInstance3D.new()
		preview.mesh = ImmediateMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.no_depth_test = true
		preview.material_override = material
		root.add_child(preview)
	(preview.material_override as StandardMaterial3D).albedo_color = color
	var mesh := preview.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point in lines:
		mesh.surface_add_vertex(point + Vector3(0, .05, 0))
	mesh.surface_end()
	preview.global_transform = ground.global_transform


func _clear_preview() -> void:
	if is_instance_valid(preview):
		preview.queue_free()
	preview = null


func _add_curve_point(at: Vector3) -> void:
	var root := EditorInterface.get_edited_scene_root()
	var ground := _terrain()
	if root == null or (tool in [Tool.PATH, Tool.WATER] and ground == null):
		_note("Maak eerst een level met Terrain via Nieuw level.")
		return
	var undo := get_undo_redo()
	if not _curve_matches_tool(active_curve) or not active_curve.is_inside_tree():
		if tool == Tool.WATER:
			var river := LevelWater.new()
			river.name = "Water"
			river.shape = LevelWater.Shape.PATH
			river.width = water_width.value
			river.depth = water_depth.value
			river.position.y = ground.snap_height(ground.to_local(at).y)
			active_curve = river
		else:
			active_curve = LevelPath.new() if tool == Tool.PATH else EnemyPatrol.new()
			active_curve.name = "Pad" if tool == Tool.PATH else "Patrouille"
		active_curve.curve = Curve3D.new()
		active_curve.curve.resource_local_to_scene = true
		active_curve.curve.bake_interval = .3
		var parent: Node = (
			ground if tool in [Tool.PATH, Tool.WATER] else root.get_node_or_null("Routes")
		)
		if parent == null:
			parent = root
		undo.create_action("Nieuwe levelcurve")
		undo.add_do_method(parent, "add_child", active_curve, true)
		undo.add_do_property(active_curve, "owner", root)
		undo.add_undo_method(parent, "remove_child", active_curve)
		undo.add_do_reference(active_curve)
		undo.commit_action()
	var before := active_curve.curve
	var after := before.duplicate() as Curve3D
	# Keep the clicked surface height, so routes drawn on plateaus stay on top of them.
	var local := active_curve.to_local(at)
	after.add_point(local)
	undo.create_action("Teken curvepunt")
	undo.add_do_property(active_curve, "curve", after)
	undo.add_undo_property(active_curve, "curve", before)
	undo.commit_action()
	_select(active_curve)


func _run_editor_checks() -> void:
	var script := (
		"res://tests/level_builder_elevation_checks.gd"
		if "--level-builder-elevation-checks" in OS.get_cmdline_user_args()
		else "res://tests/level_builder_editor_checks.gd"
	)
	if "--level-builder-boundary-checks" in OS.get_cmdline_user_args():
		script = "res://tests/level_builder_boundary_checks.gd"
	var checks = load(script).new()
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


func _save_external_data() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root:
		CHECKS.ensure_enemy_ids(root, id_claims)
		for node in CHECKS.nodes(root):
			if node is LevelTerrain:
				node.bake()


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


func _terrain() -> LevelTerrain:
	var root := EditorInterface.get_edited_scene_root()
	if root:
		for node in CHECKS.nodes(root):
			if node is LevelTerrain:
				return node
	return null


func _hit(camera: Camera3D, mouse: Vector2, grid := true) -> Variant:
	var origin := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	var ground := _terrain()
	if ground and not ground.dirty:
		# Use the actual baked surface, including stair treads and water/bridge height.
		var hit := _mesh_hit(ground.get_node_or_null("Baked/Surface"), origin, direction)
		var distance: float = origin.distance_to(hit.position) if not hit.is_empty() else INF
		for child in ground.get_children():
			if not (child is LevelBridge or child is LevelWater):
				continue
			for mesh in child.find_children("*", "MeshInstance3D", true, false):
				var candidate := _mesh_hit(mesh, origin, direction)
				if not candidate.is_empty() and origin.distance_to(candidate.position) < distance:
					hit = candidate
					distance = origin.distance_to(candidate.position)
		if not hit.is_empty():
			var point := ground.to_local(hit.position)
			if grid and snap.value > 0:
				point.x = snappedf(point.x, snap.value)
				point.z = snappedf(point.z, snap.value)
			return ground.to_global(point)
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
	if grid and snap.value > 0:
		result.x = snappedf(result.x, snap.value)
		result.z = snappedf(result.z, snap.value)
	return transform * result


func _parent_for(asset: LevelAsset) -> Node:
	var root := EditorInterface.get_edited_scene_root()
	var name := (
		"Enemies"
		if asset.category == "Enemies"
		else "Gameplay" if asset.category == "Gameplay" else "Props"
	)
	return root.get_node_or_null(name) if root.has_node(name) else root


func _on_path(ground: LevelTerrain, point: Vector3) -> bool:
	for node in ground.get_children():
		if node is LevelPath and node.curve and node.curve.point_count > 0:
			var local: Vector3 = node.transform.affine_inverse() * point
			local.y = 0
			var closest: Vector3 = node.curve.get_closest_point(local)
			if (
				Vector2(local.x, local.z).distance_to(Vector2(closest.x, closest.z))
				< node.width / 2 + scatter_spacing.value
			):
				return true
	return false


func _commit_stroke() -> void:
	painting = false
	if not erased_nodes.is_empty():
		var erase_undo := get_undo_redo()
		erase_undo.create_action(
			"Wis gestrooide assets", UndoRedo.MERGE_DISABLE, EditorInterface.get_edited_scene_root()
		)
		for item in erased_nodes:
			erase_undo.add_do_method(item.parent, "remove_child", item.node)
			erase_undo.add_undo_method(item.parent, "add_child", item.node, true)
			erase_undo.add_undo_property(item.node, "owner", item.owner)
			erase_undo.add_undo_reference(item.node)
		erase_undo.commit_action(false)
		erased_nodes.clear()
		EditorInterface.mark_scene_as_unsaved()
	if stroke_nodes.is_empty():
		return
	var undo := get_undo_redo()
	undo.create_action("Strooi levelassets" if tool == Tool.SCATTER else "Plaats levelassets")
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
	for title in ["Buiten", "Interieur", "Dungeon"]:
		new_type.add_item(title)
	new_box.add_child(new_type)
	new_connect.text = "Verbind met het geopende level"
	new_connect.button_pressed = true
	new_box.add_child(new_connect)
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
	EditorInterface.get_base_control().add_child(room_dialog)
	room_dialog.title = "Nieuwe scene achter deze deur"
	var room_box := VBoxContainer.new()
	room_dialog.add_child(room_box)
	room_name.placeholder_text = "Naam van de scene"
	room_name.custom_minimum_size = Vector2(380, 40)
	room_box.add_child(room_name)
	room_kind.add_item("Level")
	room_kind.add_item("Interieur")
	room_kind.add_item("Dungeonkamer")
	room_box.add_child(room_kind)
	var room_size := HBoxContainer.new()
	room_box.add_child(room_size)
	for spin in [room_width, room_depth]:
		spin.min_value = 4
		spin.max_value = 64
		spin.value = 10
		spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		room_size.add_child(spin)
	room_width.suffix = "m breed"
	room_depth.suffix = "m diep"
	room_dialog.confirmed.connect(
		func():
			_create_room_behind(
				room_door,
				room_name.text,
				["outdoor", "interior", "dungeon"][room_kind.selected],
				Vector2(room_width.value, room_depth.value)
			)
	)
	EditorInterface.get_base_control().add_child(link_dialog)
	link_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	link_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	link_dialog.filters = PackedStringArray(["*.tscn ; Scene"])
	link_dialog.file_selected.connect(func(path): _link_door_to_scene(link_door, path))
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
	new_type.visible = kind == "level"
	new_connect.visible = kind == "level"
	new_dialog.title = "Nieuwe ruimte" if kind == "level" else "Nieuwe areaset"
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
			var kind: String = ["outdoor", "interior", "dungeon"][new_type.selected]
			var source := EditorInterface.get_edited_scene_root()
			var link_new := (
				new_connect.button_pressed
				and kind != "outdoor"
				and source != null
				and not source.scene_file_path.is_empty()
				and _terrain() != null
			)
			var root := _new_room_root(kind, area, path, slug, Vector2(new_width.value, new_depth.value))
			if link_new:
				_connect_new_room(kind, root, path)
			error = FACTORY.save(root, path)
			root.free()
			if link_new and error == OK:
				EditorInterface.save_scene()
		if error != OK:
			_note("Level opslaan mislukt: " + error_string(error))
			return
		EditorInterface.get_resource_filesystem().scan()
		EditorInterface.open_scene_from_path(path)
		_note("Level gemaakt. Sleep een plateau of plaats assets.")


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
