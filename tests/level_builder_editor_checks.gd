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
	plugin.mode.select(1)
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
	plugin.mode.select(3)
	plugin.active_curve = null
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
	plugin.mode.select(4)
	plugin.active_curve = null
	for point in [Vector3(-12, 0, -8), Vector3(-5, 0, -8), Vector3(-5, 0, -3), Vector3(-12, 0, -3)]:
		plugin._add_curve_point(point)
	plugin.mode.select(7)
	plugin.active_curve = null
	plugin._add_curve_point(Vector3(1, 0, -5))
	plugin._add_curve_point(Vector3(-7, 1.5, -5))
	var ramp := plugin.active_curve as LevelRamp
	check(
		"ramp snaps to terrace edge",
		ramp.curve.get_point_position(1).is_equal_approx(Vector3(-5, 1.5, -5)),
		ramp.curve.get_point_position(1)
	)
	check("ramp picks destination height", ramp.end_height == 1.5)
	check("ramp remembers its plateau connection", not ramp.terrace_attachment.is_empty())
	var terrace := ramp.get_node(ramp.terrace_attachment) as LevelTerrace
	var diagonal := ramp.curve.duplicate() as Curve3D
	diagonal.set_point_position(0, Vector3(2, 0, -2))
	diagonal.set_point_position(1, Vector3(-8, 1.5, -5))
	var fitted := RampConnection.fit(ramp, diagonal, terrace, 1)
	check("diagonal approach fits flush against plateau edge", not fitted.is_empty())
	if not fitted.is_empty():
		var overlap_area := 0.0
		for polygon in Geometry2D.intersect_polygons(
			fitted.footprint, RampConnection.polygon(terrace)
		):
			overlap_area += LevelTerrain.polygon_area(polygon)
		check("fitted ramp never overlaps plateau footprint", overlap_area < .00001)
	var reverse := Curve3D.new()
	reverse.add_point(Vector3(-8, 1.5, -5))
	reverse.add_point(Vector3(2, 0, -2))
	check(
		"top-to-bottom drawing also finds a flush connection",
		not RampConnection.fit(ramp, reverse, terrace, 0).is_empty()
	)
	var terrace_position := terrace.position
	terrace.position += Vector3(0, 0, .5)
	check(
		"plateau movement refits its connected ramp",
		terrain.bake() and is_equal_approx(ramp.end_height, terrace.height)
	)
	terrace.position = terrace_position
	terrain.bake()
	check("ramp and terrace bake without overlap", terrain.bake(), terrain.last_error)
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
	plugin.selection_editor.refresh()
	check(
		"selection editor exposes ramp fields",
		plugin.selection_editor.target == ramp and plugin.selection_editor.fields.size() == 3
	)
	plugin.selection_editor.change_value(&"end_height", 2.0)
	check("selected ramp height can be edited in builder", ramp.end_height == 2.0)
	undo_last()
	check("selection height edit supports undo", ramp.end_height == 1.5)
	var before_drag := ramp.curve.duplicate() as Curve3D
	var after_drag := before_drag.duplicate() as Curve3D
	after_drag.set_point_position(1, Vector3(-5, 2.25, -5))
	var undo := plugin.get_undo_redo()
	undo.create_action("Sleep hoogtepunt", UndoRedo.MERGE_DISABLE, ramp)
	undo.add_do_property(ramp, "curve", after_drag)
	undo.add_undo_property(ramp, "curve", before_drag)
	undo.commit_action()
	check("vertical endpoint drag controls ramp height", ramp.end_height == 2.25 and terrain.bake())
	check(
		"vertical endpoint drag updates sloped geometry", terrain.outlines()[1].end_height == 2.25
	)
	undo_last()
	check(
		"vertical endpoint drag supports undo",
		ramp.end_height == 1.5 and ramp.curve.get_point_position(1).y == 1.5
	)
	await wait_frames(5)
	var height_gizmo: EditorNode3DGizmo
	for gizmo in ramp.get_gizmos():
		if gizmo is EditorNode3DGizmo and gizmo.get_plugin() == plugin.placement_gizmos:
			height_gizmo = gizmo
	check("ramp exposes dedicated vertical drag handles", height_gizmo != null)
	if height_gizmo:
		var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
		var restore: Variant = plugin.placement_gizmos._get_handle_value(height_gizmo, 1, false)
		var screen_point := camera.unproject_position(ramp.to_global(Vector3(-5, 2.6, -5)))
		plugin.placement_gizmos._set_handle(height_gizmo, 1, false, camera, screen_point)
		plugin.placement_gizmos._commit_handle(height_gizmo, 1, false, restore, false)
		check(
			"drag handle maps the mouse to Y height",
			absf(ramp.end_height - 2) < .02,
			ramp.end_height
		)
		undo_last()
		check("height handle drag supports undo", is_equal_approx(ramp.end_height, 1.5))
	plugin.selection_editor.edit_points()
	check(
		"editing existing points exits drawing mode",
		(
			plugin.mode.selected == 0
			and EditorInterface.get_selection().get_selected_nodes()[0] == ramp
		)
	)
	plugin.mode.select(7)
	plugin.active_curve = null
	plugin._add_curve_point(Vector3(4, 0, 5))
	plugin._add_curve_point(Vector3(4, 1.5, 0))
	var linked_ramp: LevelRamp = plugin.active_curve
	var child_count := terrain.get_child_count()
	plugin._add_landing(linked_ramp, 4)
	await wait_frames(2)
	plugin.selection_editor.refresh()
	check("one click creates an adjoining plateau", terrain.get_child_count() == child_count + 1)
	var landing: LevelTerrace = plugin.selection_editor.target
	check(
		"new plateau connects to high end without overlap",
		landing != null and landing.height == 1.5 and terrain.bake()
	)
	undo_last()
	check("plateau creation supports undo", terrain.get_child_count() == child_count)
	redo_last()
	linked_ramp.end_height = 2.5
	check("plateau follows dragged ramp height", landing.height == 2.5 and terrain.bake())
	landing.height = 2
	check("editing connected plateau height also updates ramp", linked_ramp.end_height == 2)
	plugin.mode.select(8)
	plugin.active_curve = null
	for point in [Vector3(8, 0, 2), Vector3(12, 0, 2), Vector3(12, 0, 6), Vector3(8, 0, 6)]:
		plugin._add_curve_point(point)
	var stone_floor := plugin.active_curve as LevelTerrace
	check(
		"flat stone floor can be drawn alongside grass",
		stone_floor.height == 0 and stone_floor.surface_style.pattern == 2 and terrain.bake()
	)
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
	plugin.mode.select(0)
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
		"save/reopen keeps a stone floor at ground height",
		reopened.get_node("Terrain/Vloervlak").height == 0
	)
	check(
		"spawns discoverable without starting gameplay", "Entrance" in LevelChecks.spawn_ids(path)
	)
	reopened.free()
	# Screenshot the actual editor, including complete names, imagery and bottom bar.
	plugin._show_builder()
	plugin.tools_tabs.current_tab = 1
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
	file.store_string(JSON.stringify({"failures": failures, "checks": results}, "\t"))
	plugin.get_tree().quit(1 if failures else 0)
