@tool
extends RefCounted
## Runs inside a dedicated editor process; only creates a disposable fixture.
var results: Array[Dictionary] = []
var failures := 0
var plugin: EditorPlugin


func check(label: String, passed: bool, detail: Variant = null) -> void:
	results.append({"check": label, "passed": passed, "detail": detail})
	failures += 0 if passed else 1
	print("BUILDER_EDITOR ", label, " ", "PASS" if passed else "FAIL", " ", detail)


func wait_frames(count: int) -> void:
	for i in count:
		await plugin.get_tree().process_frame


func undo_last() -> void:
	var manager := plugin.get_undo_redo()
	var history := manager.get_object_history_id(EditorInterface.get_edited_scene_root())
	manager.get_history_undo_redo(history).undo()


func redo_last() -> void:
	var manager := plugin.get_undo_redo()
	var history := manager.get_object_history_id(EditorInterface.get_edited_scene_root())
	manager.get_history_undo_redo(history).redo()


func run(editor_plugin: EditorPlugin) -> void:
	plugin = editor_plugin
	plugin.get_window().title = "Level Builder — geïsoleerde editorcontrole"
	plugin.get_window().grab_focus()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	await wait_frames(100)
	var original := EditorInterface.get_edited_scene_root()
	var original_path := original.scene_file_path if original else ""
	var forest := load("res://settings/area_sets/forest.tres") as AreaSet
	plugin.sets.select(plugin.kit_list.find(forest))
	plugin.new_kind = "level"
	plugin.new_name.text = "Builder Editor Fixture " + str(OS.get_process_id())
	plugin.new_width.value = 36
	plugin.new_depth.value = 20
	var slug: String = plugin._slug(plugin.new_name.text)
	var path := "res://scenes/levels/" + slug.to_pascal_case() + ".tscn"
	var area_path := "res://settings/areas/" + slug + ".tres"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(area_path):
		DirAccess.remove_absolute(area_path)
	plugin._create_new()
	await wait_frames(100)
	var root := EditorInterface.get_edited_scene_root()
	check("new-level UI creates an editable scene", root != null and root.scene_file_path == path)
	if root == null or root.scene_file_path != path:
		_finish()
		return
	var terrain := root.get_node("Terrain") as LevelTerrain
	check("new-level dimensions are honored", terrain.size == Vector2(36, 20), terrain.size)
	check(
		"area and kit remain external reusable resources",
		(
			root.get("area").resource_path == area_path
			and root.get("area_set").resource_path == forest.resource_path
		)
	)
	plugin._show_builder()
	await wait_frames(20)
	check("builder bottom tab is visible", plugin.dock.is_visible_in_tree())
	check(
		"builder panel does not force a tall editor",
		plugin.dock.get_combined_minimum_size().y < 300 * EditorInterface.get_editor_scale(),
		plugin.dock.get_combined_minimum_size()
	)
	check("toolbar provides a visible builder entry", plugin.toolbar_button.text == "Level Builder")
	check(
		"asset grid shows full names and thumbnails",
		(
			plugin.palette.get_item_count() > 10
			and plugin.palette.entries[0].picture.texture != null
			and plugin.palette.entries[0].size.x >= 136
			and plugin.palette.entries[0].caption.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART
		)
	)
	plugin.active_asset = load("res://settings/level_assets/forest_pine.tres")
	plugin._set_tool(1)
	plugin.amount.value = 1
	plugin._stamp(Vector3(5, 0, 4))
	var props := root.get_node("Props")
	check(
		"palette places complete asset",
		props.get_child_count() == 1 and props.get_child(0).has_node("GeneratedCollision")
	)
	undo_last()
	check("asset placement supports undo", props.get_child_count() == 0)
	redo_last()
	check(
		"asset placement supports redo with scene owner",
		props.get_child_count() == 1 and props.get_child(0).owner == root
	)
	plugin.active_asset = load("res://settings/level_assets/acorn_guard.tres")
	plugin._stamp(Vector3(-4, 0, 2))
	var enemies := root.get_node("Enemies")
	var enemy: Node = enemies.get_child(0)
	var first_id := String(enemy.get("persistent_id"))
	check(
		"enemy gets on-rest rule and automatic identity",
		enemy.get("respawn_rule") == 1 and not first_id.is_empty()
	)
	var copied := enemy.duplicate()
	enemies.add_child(copied, true)
	copied.owner = root
	LevelChecks.ensure_enemy_ids(root, plugin.id_claims)
	check(
		"duplicating an enemy gives a fresh identity",
		copied.get("persistent_id") != enemy.get("persistent_id")
	)
	enemy.name = "RenamedEnemy"
	enemy.set("position", Vector3(-3, 0, 2))
	LevelChecks.ensure_enemy_ids(root, plugin.id_claims)
	check(
		"moving and renaming preserves enemy identity",
		String(enemy.get("persistent_id")) == first_id
	)
	plugin._set_tool(4)
	plugin._add_curve_point(Vector3(0, 0, 6))
	plugin._add_curve_point(Vector3(0, 0, -5))
	var path_node: Path3D = plugin.active_curve
	await wait_frames(40)
	check(
		"drawn path generates saved surface",
		path_node.curve.point_count == 2 and terrain.has_node("Baked/Surface")
	)
	undo_last()
	check("curve point undo", path_node.curve.point_count == 1)
	redo_last()
	check("curve point redo", path_node.curve.point_count == 2)
	plugin._set_tool(0)
	# Plateaus: the chosen height is exact, in half-metre steps up to 100 m.
	plugin.plateau_height.value = 1.0
	var low_plateau: LevelTerrace = plugin._create_plateau(Vector3(-12, 0, -8), Vector3(-4, 0, -2))
	check(
		"dragged plateau takes the chosen height",
		low_plateau != null and low_plateau.height == 1.0 and terrain.bake(),
		terrain.last_error
	)
	plugin.plateau_height.value = 2.0
	var hill: LevelTerrace = plugin._create_plateau(Vector3(-10, 1, -7), Vector3(-8, 1, -5))
	check(
		"higher plateau on a plateau bakes without overlap",
		hill != null and hill.height == 2.0 and terrain.bake(),
		terrain.last_error
	)
	undo_last()
	check("plateau creation supports undo", hill.get_parent() == null)
	redo_last()
	check("plateau creation supports redo", hill.get_parent() == terrain)
	plugin.plateau_height.value = 1.0
	var neighbour: LevelTerrace = plugin._create_plateau(Vector3(-4, 0, -8), Vector3(-1, 0, -5))
	check(
		"adjacent rectangles at one height join into one plateau",
		neighbour.height == 1.0 and terrain.bake(),
		terrain.last_error
	)
	var flat_floor: LevelTerrace = plugin._create_plateau(Vector3(8, 0, 2), Vector3(12, 0, 6), true)
	flat_floor.surface_style = load("res://settings/surface_styles/stone.tres")
	check(
		"ctrl-drag keeps ground height for a stone floor",
		flat_floor.height == 0 and terrain.bake(),
		terrain.last_error
	)
	low_plateau.height = 1.3
	check(
		"plateau height snaps to the height step",
		is_equal_approx(low_plateau.height, 1.5),
		low_plateau.height
	)
	# Editing one selected plateau leaves every other plateau untouched.
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(hill)
	plugin.selection_editor.refresh()
	plugin.selection_editor.set_height(3.5)
	check(
		"height field changes only the selected plateau",
		hill.height == 3.5 and low_plateau.height == 1.5 and neighbour.height == 1.0,
		[hill.height, low_plateau.height, neighbour.height]
	)
	undo_last()
	check("selected plateau height supports undo", hill.height == 2.0, hill.height)
	low_plateau.height = 99.6
	check("high plateaus still snap to half metres", low_plateau.height == 99.5, low_plateau.height)
	low_plateau.height = 104
	check("plateau height stops at 100 m", low_plateau.height == 100.0, low_plateau.height)
	low_plateau.height = 1.0
	# Stairs: one click near a plateau edge attaches a flight down to the ground.
	plugin.stair_width.value = 2
	var stairs: LevelRamp = plugin._create_stairs(Vector3(-8, 1, -2.3))
	var stairs_region := {}
	for region in terrain.outlines():
		if stairs and region.name == stairs.name:
			stairs_region = region
	check(
		"clicking a plateau edge attaches stairs down to the ground",
		(
			not stairs_region.is_empty()
			and stairs_region.start_height == 0
			and stairs_region.end_height == 1.0
			and stairs_region.ramp_end.is_equal_approx(Vector2(-8, -2))
			and terrain.bake()
		),
		[stairs_region, terrain.last_error]
	)
	undo_last()
	check("stairs placement supports undo", stairs.get_parent() == null)
	redo_last()
	low_plateau.height = 2.0
	for region in terrain.outlines():
		if region.name == stairs.name:
			stairs_region = region
	check("stairs follow a changed plateau height", stairs_region.end_height == 2.0, stairs_region)
	check(
		"raising a plateau with stairs attached rebakes and lengthens the stairs",
		(
			terrain.bake()
			and is_equal_approx(_flat_length(stairs), 2.0 / LevelTerrain.STAIR_SLOPE)
			and stairs.curve.get_point_position(1).is_equal_approx(Vector3(-8, 2, -2))
		),
		[terrain.last_error, stairs.curve.get_point_position(0), stairs.curve.get_point_position(1)]
	)
	low_plateau.height = 1.0
	check(
		"lowering it again shortens the stairs",
		terrain.bake() and is_equal_approx(_flat_length(stairs), 1.0 / LevelTerrain.STAIR_SLOPE),
		terrain.last_error
	)
	check(
		"clicking away from any edge places nothing",
		plugin._create_stairs(Vector3(-6, 1, -4)) == null
	)
	var inset: LevelRamp = plugin._create_stairs(Vector3(-11, 1, -2.3), true)
	var inset_region := {}
	var notched_area := 0.0
	for region in terrain.outlines():
		if inset and region.name == inset.name:
			inset_region = region
		elif region.name == low_plateau.name:
			notched_area += LevelTerrain.polygon_area(region.polygon)
	check(
		"inset stairs cut into the plateau like a Link's Awakening stairway",
		(
			not inset_region.is_empty()
			and inset_region.end_height == 1.0
			and notched_area < 48 - 4 - 2
			and terrain.bake()
		),
		[inset_region, notched_area, terrain.last_error]
	)
	var upper: LevelRamp = plugin._create_stairs(Vector3(-9, 2, -5.2))
	var upper_region := {}
	for region in terrain.outlines():
		if upper and region.name == upper.name:
			upper_region = region
	check(
		"stairs between two plateaus connect their heights",
		(
			not upper_region.is_empty()
			and upper_region.start_height == 1.0
			and upper_region.end_height == 2.0
			and terrain.bake()
		),
		[upper_region, terrain.last_error]
	)
	# Leading out is blocked by the first flight, so the same spot falls back inward.
	var fallback: LevelRamp = plugin._create_stairs(Vector3(-8, 1, -2.3))
	check(
		"blocked stairs fall back into the plateau instead of overlapping",
		(
			fallback != null
			and fallback.to_global(fallback.curve.get_point_position(1)).z < -2.5
			and terrain.bake()
		),
		terrain.last_error
	)
	undo_last()
	plugin.stair_steps.button_pressed = false
	var slope: LevelRamp = plugin._create_stairs(Vector3(-4.3, 1, -3.5))
	check(
		"treads off makes a longer grassy slope",
		(
			slope != null
			and not slope.stairs
			and (
				slope.curve.get_point_position(0).distance_to(slope.curve.get_point_position(1))
				> 2.2
			)
			and terrain.bake()
		),
		terrain.last_error
	)
	plugin.stair_steps.button_pressed = true
	# Viewport picking: hovering the plateau top beside an edge proposes inset stairs,
	# hovering just outside the edge proposes stairs leading out.
	var view_camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var on_top := view_camera.unproject_position(terrain.to_global(Vector3(-5.5, 1, -2.3)))
	var top_plan: Dictionary = plugin._stairs_plan_from_view(terrain, view_camera, on_top)
	check(
		"hovering the plateau top by an edge proposes stairs into the plateau",
		not top_plan.is_empty() and top_plan.get("inset", false) and not top_plan.has("error"),
		top_plan
	)
	var in_front := view_camera.unproject_position(terrain.to_global(Vector3(-5.5, 1, -1.7)))
	var front_plan: Dictionary = plugin._stairs_plan_from_view(terrain, view_camera, in_front)
	check(
		"hovering just outside an edge proposes stairs leading out",
		not front_plan.is_empty() and not front_plan.get("inset", true),
		front_plan
	)
	# Routes drawn on a plateau keep the plateau height instead of dropping to the ground.
	plugin._set_tool(5)
	plugin._add_curve_point(Vector3(-6, 1, -4))
	var patrol: Path3D = plugin.active_curve
	check(
		"patrol points drawn on a plateau keep its height",
		(
			patrol != null
			and is_equal_approx(patrol.to_global(patrol.curve.get_point_position(0)).y, 1.0)
		),
		patrol.to_global(patrol.curve.get_point_position(0)) if patrol else null
	)
	plugin._set_tool(0)
	# Bridges: from one plateau edge to another, here climbing from 1 m to 2 m.
	plugin.plateau_height.value = 2.0
	var far_plateau: LevelTerrace = plugin._create_plateau(Vector3(-8, 0, 4), Vector3(-2, 0, 8))
	plugin.bridge_width.value = 2
	plugin.bridge_rails.button_pressed = true
	var bridge: LevelBridge = plugin._create_bridge(Vector3(-5, 1, -2.2), Vector3(-5, 2, 4.2))
	await wait_frames(3)
	check(
		"bridge connects two plateau edges at their heights",
		(
			bridge != null
			and bridge.curve.get_point_position(0).is_equal_approx(Vector3(-5, 1, -2))
			and bridge.curve.get_point_position(1).is_equal_approx(Vector3(-5, 2, 4))
			and bridge.has_node("Generated/Body/Shape")
			and terrain.bake()
		),
		[bridge.curve.get_point_position(0), bridge.curve.get_point_position(1)] if bridge else null
	)
	far_plateau.height = 3.0
	check(
		"bridge follows a raised plateau",
		terrain.bake() and is_equal_approx(bridge.curve.get_point_position(1).y, 3.0),
		bridge.curve.get_point_position(1)
	)
	far_plateau.height = 2.0
	terrain.bake()
	undo_last()
	check("bridge placement supports undo", bridge.get_parent() == null)
	redo_last()
	check(
		"too steep a bridge is refused",
		(
			plugin
			. _bridge_plan(
				terrain,
				{"point": Vector2(0, 5), "height": 0.0},
				{"point": Vector2(1.5, 5), "height": 3.0}
			)
			. has("error")
		)
	)
	# Water: a dragged square and a clicked river both sink the ground into a bed.
	plugin._set_tool(7)
	plugin.water_shape.select(LevelWater.Shape.AREA)
	plugin.water_depth.value = .6
	var pond: LevelWater = plugin._create_water_area(Vector3(10, 0, -9), Vector3(15, 0, -5))
	await wait_frames(3)
	var pond_centre := {}
	for region in terrain.outlines():
		if region.name == pond.name:
			pond_centre = region
	check(
		"dragged water sinks the ground into a bed with soft banks",
		(
			pond != null
			and not pond_centre.is_empty()
			and absf(LevelTerrain.region_height(pond_centre, Vector2(12.5, -7)) + .6) < .01
			and LevelTerrain.region_height(pond_centre, Vector2(10.05, -7)) > -.05
			and pond.has_node("Generated/Surface")
			and terrain.bake()
		),
		terrain.last_error
	)
	undo_last()
	check("water placement supports undo", pond.get_parent() == null)
	redo_last()
	plugin.water_shape.select(LevelWater.Shape.PATH)
	plugin._add_curve_point(Vector3(10, 0, 3))
	plugin._add_curve_point(Vector3(15, 0, 3))
	var river := plugin.active_curve as LevelWater
	check(
		"clicked river is water along a path",
		(
			river != null
			and river.shape == LevelWater.Shape.PATH
			and river.outline().size() > 4
			and terrain.bake()
		),
		terrain.last_error
	)
	# Real viewport input: press, drag and release with the Water tool, twice in a row
	# (the second time with the first water still selected).
	plugin._set_tool(7)
	plugin.water_shape.select(LevelWater.Shape.AREA)
	var drag_camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	for attempt in 2:
		var corners := _visible_ground_corners(drag_camera, terrain)
		if corners.is_empty():
			check("bare ground available for water drag", false)
			continue
		var from_world := terrain.to_global(corners[0])
		var to_world := terrain.to_global(corners[1])
		var before_count := 0
		for child in terrain.get_children():
			before_count += 1 if child is LevelWater else 0
		_drag(
			drag_camera,
			drag_camera.unproject_position(from_world),
			drag_camera.unproject_position(to_world)
		)
		await wait_frames(3)
		var newest: LevelWater
		var count := 0
		for child in terrain.get_children():
			if child is LevelWater:
				count += 1
				newest = child
		var area := LevelTerrain.polygon_area(newest.outline()) if newest else 0.0
		check(
			"dragging water with real mouse events fills the whole square (%d)" % attempt,
			count == before_count + 1 and is_equal_approx(area, 4.0),
			[count - before_count, area]
		)
	# Click-click: a click without dragging sets one corner, a second click the other.
	# Corners are chosen where the editor camera sees bare ground, so hits are exact.
	for kind in [7, 2]:
		plugin._set_tool(kind)
		plugin.water_shape.select(LevelWater.Shape.AREA)
		plugin.plateau_height.value = 1.0
		var corners := _visible_ground_corners(drag_camera, terrain)
		check(
			"found bare ground for click-click (%s)" % ("water" if kind == 7 else "plateau"),
			not corners.is_empty(),
			corners
		)
		if corners.is_empty():
			continue
		var before := terrain.get_child_count()
		var screen_a := drag_camera.unproject_position(terrain.to_global(corners[0]))
		var screen_b := drag_camera.unproject_position(terrain.to_global(corners[1]))
		_drag(drag_camera, screen_a, screen_a)
		check(
			(
				"a single click waits for the opposite corner (%s)"
				% ("water" if kind == 7 else "plateau")
			),
			plugin.corner_pending and terrain.get_child_count() == before
		)
		var hover := InputEventMouseMotion.new()
		hover.position = screen_b
		plugin._forward_3d_gui_input(drag_camera, hover)
		_drag(drag_camera, screen_b, screen_b)
		await wait_frames(3)
		var created: Node = null
		for child in terrain.get_children():
			if (kind == 7 and child is LevelWater) or (kind == 2 and child is LevelTerrace):
				created = child
		var outline_area := _curve_area(created) if created else 0.0
		check(
			(
				"the second click finishes the whole rectangle (%s)"
				% ("water" if kind == 7 else "plateau")
			),
			not plugin.corner_pending and absf(outline_area - 4.0) < .01,
			[created.name if created else null, outline_area, corners]
		)
	plugin._set_tool(0)
	# Select tool: picking and moving builder pieces with what hangs off them.
	check(
		"clicking a plateau top picks that plateau",
		plugin._region_node_at(terrain, Vector2(-6, -6)) == low_plateau
	)
	check(
		"clicking water picks the water node",
		plugin._region_node_at(terrain, Vector2(12.5, -7)) == pond
	)
	var bridge_end := bridge.curve.get_point_position(1)
	plugin._begin_move(terrain, far_plateau, Vector2(-5, 6), 2.0)
	plugin._update_move(terrain, Vector2(-3.2, 7.1))
	plugin._end_move(terrain)
	check(
		"dragging a plateau moves it on the grid and its bridge end follows",
		(
			far_plateau.position.is_equal_approx(Vector3(2, 0, 1))
			and bridge.curve.get_point_position(1).is_equal_approx(bridge_end + Vector3(2, 0, 1))
			and terrain.bake()
		),
		[far_plateau.position, bridge.curve.get_point_position(1), terrain.last_error]
	)
	undo_last()
	check(
		"moving a plateau supports undo",
		(
			far_plateau.position == Vector3.ZERO
			and bridge.curve.get_point_position(1).is_equal_approx(bridge_end)
		)
	)
	var stairs_before := stairs.curve.duplicate() as Curve3D
	var inset_before := inset.position
	plugin._begin_move(terrain, low_plateau, Vector2(-6, -6), 1.0)
	plugin._update_move(terrain, Vector2(-6, -5))
	var carried: int = plugin.move_items.size()
	plugin._end_move(terrain)
	check(
		"stairs anchored to a moved plateau move with it",
		carried >= 3 and inset.position.is_equal_approx(inset_before + Vector3(0, 0, 1)),
		[carried, inset.position]
	)
	undo_last()
	plugin._begin_move(terrain, stairs, Vector2(-8, -1), 0.5)
	plugin._update_move(terrain, Vector2(-6.2, -1.3))
	plugin._end_move(terrain)
	var high_end := stairs.to_global(stairs.curve.get_point_position(1))
	check(
		"stairs dragged on their own click back onto the plateau edge",
		(
			stairs.position.is_equal_approx(Vector3(2, 0, 0))
			and is_equal_approx(high_end.z, -2.0)
			and absf(high_end.x + 6.0) < .6
			and terrain.bake()
		),
		[stairs.position, high_end, terrain.last_error]
	)
	undo_last()
	check(
		"snapping stairs supports undo",
		(
			stairs.position == Vector3.ZERO
			and stairs.curve.get_point_position(1).is_equal_approx(
				stairs_before.get_point_position(1)
			)
		)
	)
	await load("res://tests/level_builder_selection_checks.gd").new().run(
		self,
		terrain,
		{
			"plateau": low_plateau,
			"hill": hill,
			"stairs": stairs,
			"bridge": bridge,
			"water": pond,
			"path": path_node
		}
	)
	await load("res://tests/level_builder_scatter_checks.gd").new().run(self, terrain)
	# Doors and rooms: a doorway on the ground edge, a new room behind it, the link list.
	plugin._set_tool(LevelBuilderToolDoor())
	# A door set into the wall of a tall plateau.
	var previous_height: float = plugin.plateau_height.value
	plugin.plateau_height.value = 3.0
	var cliff_plateau: LevelTerrace = plugin._create_plateau(Vector3(2, 0, -10), Vector3(8, 0, -6))
	plugin.plateau_height.value = previous_height
	terrain.bake()
	var cliff_plan: Dictionary = plugin._cliff_door_plan(terrain, Vector2(5, -5.8))
	check(
		"hovering a tall plateau wall plans a door in it",
		cliff_plan.get("cliff", false) and not cliff_plan.has("error") and cliff_plan.height > 1.9,
		cliff_plan
	)
	var cliff_door: LevelDoor = plugin._create_door(terrain, cliff_plan) if cliff_plan.get("cliff", false) and not cliff_plan.has("error") else null
	check(
		"the plateau door stands against the wall, facing out, arrival in front",
		(
			cliff_door != null
			and cliff_door.cliff_door
			and absf(cliff_door.position.z + 6.0) < .1
			and cliff_door.get_node("Arrival").global_position.z > cliff_door.global_position.z + 1.0
			and terrain.bake()
		),
		[cliff_door.position if cliff_door else null, terrain.last_error]
	)
	if cliff_door:
		# Clicking the doorway in the rock selects the door, not the plateau around it.
		cliff_door._rebuild()
		var pick_camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		var door_screen := pick_camera.unproject_position(cliff_door.to_global(Vector3(0, 1.1, .2)))
		var door_pick: Dictionary = plugin._pick_authoring(terrain, pick_camera, door_screen)
		check(
			"clicking a door in a plateau wall selects the door",
			door_pick.get("node") == cliff_door,
			door_pick.get("node")
		)
		terrain.remove_child(cliff_door)
		cliff_door.free()
	if cliff_plateau:
		cliff_plateau.get_parent().remove_child(cliff_plateau)
		cliff_plateau.free()
	terrain.bake()
	var door_plan: Dictionary = plugin._door_plan(terrain, Vector2(3, -terrain.size.y / 2 + .4))
	check("hovering near a ground edge plans a doorway on it", door_plan.get("side") == 0, door_plan)
	var edge_door: LevelDoor = plugin._create_door(terrain, door_plan)
	check(
		"a door stands on the edge with its own arrival inside",
		(
			edge_door != null
			and is_equal_approx(edge_door.position.z, -terrain.size.y / 2)
			and edge_door.has_node("Arrival")
			and edge_door.get_node("Arrival").spawn_id == edge_door.door_id
			and edge_door.get_node("Arrival").global_position.z > edge_door.global_position.z
			and terrain.bake()
		),
		terrain.last_error
	)
	var gap_open := false
	for body in terrain.find_children("*", "CollisionShape3D", true, false):
		if String(body.name).begins_with("Doorway"):
			gap_open = true
	check(
		"outdoors a door on the ground edge is an open passage through the boundary",
		edge_door != null and edge_door.style == LevelDoor.Style.OPENING and String(edge_door.name).begins_with("Doorgang") and gap_open,
		[edge_door.style if edge_door else null, gap_open]
	)
	edge_door._rebuild()
	var dark_outside: bool = not edge_door.has_node("Frame/PassageGlow") and not edge_door.has_node("Frame/Sunbeam")
	edge_door.light = LevelDoor.LightMode.ON
	edge_door._rebuild()
	check(
		"doors outdoors show no light unless Licht is set to Aan",
		dark_outside and edge_door.has_node("Frame/PassageGlow"),
		dark_outside
	)
	edge_door.light = LevelDoor.LightMode.AUTO
	edge_door._rebuild()
	EditorInterface.save_scene()
	await wait_frames(10)
	var room_title := "Builder Kamer %d" % OS.get_process_id()
	var room_path: String = plugin._create_room_behind(edge_door, room_title, "interior", Vector2(8, 8))
	check(
		"a new room behind the door is created and linked",
		room_path != "" and edge_door.target_scene == room_path and FileAccess.file_exists(room_path),
		room_path
	)
	if room_path != "":
		var room: Node = load(room_path).instantiate()
		var back: LevelDoor
		for child in room.get_node("Terrain").get_children():
			if child is LevelDoor:
				back = child
		check(
			"the room's own door leads back to this door",
			(
				back != null
				and back.target_scene == path
				and back.target_spawn == edge_door.door_id
				and edge_door.target_spawn == back.door_id
				and absf(back.position.z - 4.0) < .01
				and room.get_node("Terrain").room_walls
			),
			[back.target_scene if back else null, back.position if back else null]
		)
		room.free()
	plugin._refresh_links(true)
	var listed := false
	for row in plugin.links_box.get_children():
		for button in row.get_children():
			if button is Button and edge_door.name in button.text:
				listed = true
	check("connected rooms list shows the door", listed)
	plugin._set_tool(0)
	if room_path != "":
		DirAccess.remove_absolute(room_path)
		var baked_dir := room_path.get_basename() + ".terrain"
		for file in DirAccess.get_files_at(baked_dir):
			DirAccess.remove_absolute(baked_dir.path_join(file))
		DirAccess.remove_absolute(baked_dir)
		DirAccess.remove_absolute("res://settings/areas/" + plugin._slug(room_title) + ".tres")
	var ramp := stairs
	# Replacing terrain must not free a node currently selected by editor gizmos.
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(terrain.get_node("Baked/Surface"))
	terrain.resolution = 1
	check("rebake handles a selected generated surface", terrain.bake())
	check(
		"rebake transfers selection to editable terrain",
		EditorInterface.get_selection().get_selected_nodes().has(terrain)
	)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(ramp)
	await wait_frames(5)
	var height_gizmo: EditorNode3DGizmo
	for gizmo in ramp.get_gizmos():
		if gizmo is EditorNode3DGizmo and gizmo.get_plugin() == plugin.placement_gizmos:
			height_gizmo = gizmo
	check("ramp exposes dedicated vertical drag handles", height_gizmo != null)
	if height_gizmo:
		var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		var restore: Variant = plugin.placement_gizmos._get_handle_value(height_gizmo, 1, false)
		var screen_point := camera.unproject_position(ramp.to_global(Vector3(-8, 2.6, -2)))
		plugin.placement_gizmos._set_handle(height_gizmo, 1, false, camera, screen_point)
		plugin.placement_gizmos._commit_handle(height_gizmo, 1, false, restore, false)
		check(
			"drag handle sets a manual Y height",
			absf(ramp.end_height - 2) < .02 and not ramp.follow_ground,
			ramp.end_height
		)
		undo_last()
		check("height handle drag supports undo", ramp.follow_ground)
	EditorInterface.get_selection().clear()
	EditorInterface.get_selection().add_node(terrain)
	plugin.selection_editor.refresh()
	plugin.selection_editor.apply_surface_style(
		load("res://settings/surface_styles/forest_grass.tres")
	)
	check(
		"ground material picker applies grass without changing area kit",
		terrain.surface_style.display_name == "Bosgras" and root.get("area_set") == forest
	)
	undo_last()
	check("material choice supports undo", terrain.surface_style == null)
	redo_last()
	check(
		"mixed surfaces share exclusive terrain and collision",
		terrain.bake() and terrain.get_node("Baked/Surface").mesh.get_surface_count() >= 3
	)
	var outline_count := terrain.outlines().size()
	var prop_count := props.get_child_count()
	terrain.size = Vector2(44, 28)
	check(
		"resizing preserves scene objects", terrain.bake() and props.get_child_count() == prop_count
	)
	plugin._set_tool(0)
	EditorInterface.save_scene()
	await wait_frames(30)
	var packed := (
		ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	)
	var reopened := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	check(
		"save/reopen keeps custom dimensions and ramp",
		(
			reopened.get_node("Terrain").size == Vector2(44, 28)
			and reopened.get_node("Terrain").outlines().size() == outline_count
		)
	)
	check(
		"save/reopen keeps placed enemy ids",
		reopened.get_node("Enemies/RenamedEnemy").get("persistent_id") == first_id
	)
	check(
		"save/reopen keeps scattered instances at their authored transforms",
		_scattered_instances_match(props, reopened.get_node("Props"))
	)
	check(
		"save/reopen keeps a stone floor at ground height",
		reopened.get_node("Terrain/" + String(flat_floor.name)).height == 0
	)
	check(
		"spawns discoverable without starting gameplay", "Entrance" in LevelChecks.spawn_ids(path)
	)
	reopened.free()
	# Screenshot the actual editor, including complete names, imagery and bottom bar.
	plugin._show_builder()
	EditorInterface.set_main_screen_editor("3D")
	await wait_frames(180)
	check(
		"bottom panel has room for a complete preview row",
		(
			plugin.palette.size.y
			>= (plugin.palette.preview_size + 35) * EditorInterface.get_editor_scale()
		),
		plugin.palette.size
	)
	check(
		"palette fits inside bottom tab width",
		plugin.palette.get_global_rect().end.x <= plugin.dock.get_global_rect().end.x + 1,
		plugin.palette.grid.columns
	)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		plugin.get_viewport().get_texture().get_image().save_png(
			"res://captures/level_builder/editor.png"
		)
	# Keep the fixture under captures for reproduction, remove its registered area.
	var snapshot_root := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var old_area: WorldArea = snapshot_root.get("area")
	var snapshot_area := old_area.duplicate() as WorldArea
	snapshot_area.scene_path = "res://captures/level_builder/EditorFixture.tscn"
	ResourceSaver.save(snapshot_area, "res://captures/level_builder/EditorFixtureArea.tres")
	snapshot_area.take_over_path("res://captures/level_builder/EditorFixtureArea.tres")
	for node in LevelChecks.nodes(snapshot_root):
		if LevelChecks.has_property(node, &"area") and node.get("area") == old_area:
			node.set("area", snapshot_area)
	LevelFactory.save(snapshot_root, "res://captures/level_builder/EditorFixture.tscn")
	snapshot_root.free()
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(null)
	if not original_path.is_empty():
		EditorInterface.open_scene_from_path(original_path)
	await wait_frames(5)
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(area_path)
	_finish()


func _finish() -> void:
	var file := FileAccess.open("res://captures/level_builder/editor_checks.json", FileAccess.WRITE)
	file.store_string(
		JSON.stringify(
			{
				"failures": failures,
				"checks": results,
				"frames_drawn": Engine.get_frames_drawn(),
				"display_server": DisplayServer.get_name()
			},
			"\t"
		)
	)
	plugin.get_tree().quit(1 if failures else 0)


func _scattered_instances_match(original: Node, reopened: Node) -> bool:
	if original.get_child_count() != reopened.get_child_count():
		return false
	var count := 0
	for node in original.get_children():
		if node.get_meta("level_asset_id", &"") != &"forest_flowers_blue":
			continue
		var saved := reopened.get_node_or_null(NodePath(String(node.name))) as Node3D
		if (
			saved == null
			or saved.transform != node.transform
			or saved.scene_file_path != node.scene_file_path
		):
			return false
		count += 1
	return count == 30


## Horizontal run of a two-point stair curve.
func _flat_length(ramp: LevelRamp) -> float:
	var a := ramp.curve.get_point_position(0)
	var b := ramp.curve.get_point_position(1)
	return Vector2(a.x - b.x, a.z - b.z).length()


func _drag(camera: Camera3D, from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	plugin._forward_3d_gui_input(camera, press)
	for i in range(1, 6):
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = from.lerp(to, i / 5.0)
		plugin._forward_3d_gui_input(camera, motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	plugin._forward_3d_gui_input(camera, release)


func _curve_area(path: Path3D) -> float:
	var points := PackedVector2Array()
	for i in path.curve.point_count:
		var point := path.curve.get_point_position(i)
		points.append(Vector2(point.x, point.z))
	return LevelTerrain.polygon_area(points)


## Two corners 2 m apart whose screen hits land exactly on bare ground (no other surface in front).
func _visible_ground_corners(camera: Camera3D, terrain: LevelTerrain) -> Array:
	for x in range(-16, 16, 2):
		for z in range(-8, 8, 2):
			var a := Vector3(x, 0, z)
			var b := Vector3(x + 2, 0, z + 2)
			var ok := true
			for corner in [a, b, Vector3(x + 1, 0, z + 1)]:
				if plugin._region_node_at(terrain, Vector2(corner.x, corner.z)) != null:
					ok = false
					break
				var hit: Variant = plugin._hit(
					camera, camera.unproject_position(terrain.to_global(corner))
				)
				if hit == null or terrain.to_local(hit).distance_to(corner) > .05:
					ok = false
					break
			if (
				ok
				and (
					LevelTerrain.height_under(
						Vector2(x + 1, z + 1), plugin._stair_context(terrain).plateaus
					)
					== 0.0
				)
			):
				return [a, b]
	return []


## Tool index of the Door tool (last in the plugin's Tool enum).
func LevelBuilderToolDoor() -> int:
	return plugin.Tool.DOOR
