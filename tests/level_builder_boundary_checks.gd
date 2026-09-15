@tool
extends "res://tests/level_builder_editor_checks.gd"


func run(editor_plugin: EditorPlugin) -> void:
	plugin = editor_plugin
	plugin.get_window().grab_focus()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	await wait_frames(80)
	plugin.new_kind = "level"
	plugin.new_name.text = "Boundary Check " + str(OS.get_process_id())
	plugin.new_width.value = 32
	plugin.new_depth.value = 24
	plugin._create_new()
	await wait_frames(80)
	var root := EditorInterface.get_edited_scene_root()
	var ground := root.get_node("Terrain") as LevelTerrain
	var pine := load("res://settings/level_assets/forest_pine.tres") as LevelAsset
	plugin._set_tool(9)
	plugin._asset_selected(plugin.shown_assets.find(pine))
	check("choosing a tree keeps the boundary tool active", plugin.tool == 9)
	plugin.boundary_spacing.value = 4
	plugin.boundary_random_yaw.button_pressed = true
	plugin.snap.value = 1
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	view.world_3d = ground.get_world_3d()
	plugin.add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	camera.position = Vector3(0, 40, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	var history := plugin.get_undo_redo().get_history_undo_redo(
		plugin.get_undo_redo().get_object_history_id(root)
	)
	var version := history.get_version()
	_drag(
		camera,
		camera.unproject_position(Vector3(-8, 0, -6)),
		camera.unproject_position(Vector3(8, 0, -6))
	)
	var boundary := ground.get_node("Afkadering") as LevelBoundary
	check("dragging one line creates an editable boundary", boundary.curve.point_count == 2)
	check(
		"a 16 m line places five trees at 4 m intervals",
		boundary.get_node("Baked/Props").get_child_count() == 5
	)
	check(
		"tree line includes a continuous world collider",
		(
			boundary.has_node("Baked/Barrier")
			and boundary.get_node("Baked/Barrier").get_child_count() >= 32
		)
	)
	var varied := false
	var transforms: Array[Transform3D] = []
	for tree in boundary.get_node("Baked/Props").get_children():
		transforms.append(tree.transform)
		varied = varied or absf(tree.rotation.y) > .1
	check("random angle varies the placed tree orientations", varied)
	check("all trees and collision form one undo action", history.get_version() == version + 1)
	undo_last()
	check("undo removes the complete boundary", boundary.get_parent() == null)
	redo_last()
	check(
		"redo restores the same trees and collider",
		boundary.get_parent() == ground and _same_trees(boundary, transforms)
	)
	# Settings and curve edits rebake deterministically, without changing the asset.
	boundary.spacing = 2
	boundary.bake()
	check(
		"editing spacing rebuilds the line", boundary.get_node("Baked/Props").get_child_count() == 9
	)
	boundary.spacing = 4
	boundary.bake()
	check(
		"returning to original spacing restores random transforms",
		_same_trees(boundary, transforms)
	)
	boundary.random_yaw = false
	boundary.bake()
	var prototype := pine.scene.instantiate() as Node3D
	var valid := true
	for tree in boundary.get_node("Baked/Props").get_children():
		valid = valid and tree.rotation.is_equal_approx(prototype.rotation)
	prototype.free()
	check("random angle off preserves the asset orientation", valid)
	boundary.random_yaw = true
	boundary.bake()
	# Multi-click drawing, hovering, and cancellation leave authored content untouched.
	_click(camera, Vector3(-8, 0, 4))
	var motion := InputEventMouseMotion.new()
	motion.position = camera.unproject_position(Vector3(8, 0, 4))
	plugin._forward_3d_gui_input(camera, motion)
	check("drawing previews the line and blocking height", is_instance_valid(plugin.preview))
	_click(camera, Vector3(8, 0, 4))
	_click(camera, Vector3(8, 0, -2))
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	plugin._forward_3d_gui_input(camera, enter)
	var corner := ground.get_node("Afkadering2") as LevelBoundary
	check("clicking corners and Enter makes one bent boundary", corner.curve.point_count == 3)
	_click(camera, Vector3(-3, 0, 8))
	_click(camera, Vector3(3, 0, 8))
	version = history.get_version()
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	plugin._forward_3d_gui_input(camera, escape)
	check(
		"Escape cancels the unfinished boundary without undo noise",
		(
			plugin.boundary_points.is_empty()
			and history.get_version() == version
			and not ground.has_node("Afkadering3")
		)
	)
	# The Select tool moves the authored line, including its whole collision strip.
	await wait_frames(3)
	var picked: Dictionary = plugin._selection_pick(
		ground, camera, camera.unproject_position(Vector3(0, 1, -6))
	)
	check("tree mesh selects its authored boundary", picked.get("node") == boundary)
	plugin._begin_move(ground, boundary, Vector2.ZERO, 0)
	plugin._update_move(ground, Vector2(0, 1))
	plugin._end_move(ground)
	await wait_frames(3)
	check(
		"moving the line carries props and collision",
		boundary.position.z == 1 and boundary.get_node("Baked/Barrier").global_position.z == 1
	)
	undo_last()
	await wait_frames(3)
	check(
		"move undo restores the whole line",
		boundary.position == Vector3.ZERO and _same_trees(boundary, transforms)
	)
	# Raised surface support updates when its plateau height changes.
	plugin.plateau_height.value = 10
	var plateau: LevelTerrace = plugin._create_plateau(Vector3(-8, 0, 6), Vector3(8, 0, 10))
	ground.bake()
	plugin._set_tool(9)
	plugin.boundary_points = PackedVector3Array([Vector3(-6, 10, 8), Vector3(6, 10, 8)])
	plugin._finish_boundary()
	var raised := ground.get_node("Afkadering3") as LevelBoundary
	check(
		"boundary trees sit on the 10 m plateau",
		is_equal_approx(raised.get_node("Baked/Props").get_child(0).global_position.y, 10)
	)
	plateau.height = 11
	ground.bake()
	await wait_frames(3)
	check(
		"trees follow an edited supporting plateau",
		is_equal_approx(raised.get_node("Baked/Props").get_child(0).global_position.y, 11)
	)
	plateau.height = 10
	ground.bake()
	await wait_frames(3)
	boundary.block_movement = false
	boundary.bake()
	check(
		"blocking checkbox removes only the continuous barrier",
		(
			not boundary.has_node("Baked/Barrier")
			and boundary.get_node("Baked/Props").get_child_count() == 5
		)
	)
	boundary.block_movement = true
	boundary.bake()
	# A bridge between equal ground heights can rise in a smooth, walkable arch.
	plugin.bridge_arch.value = 2
	var bridge: LevelBridge = plugin._create_bridge(Vector3(-6, 0, 0), Vector3(6, 0, 0))
	check(
		"bridge tool can create an arch on flat ground", bridge != null and bridge.arch_height == 2
	)
	bridge.rebuild()
	var deck := bridge.deck_line()
	check("bridge arch keeps both ground endpoints", deck[1].y == 0 and deck[-2].y == 0)
	check(
		"bridge centre reaches the chosen arch height",
		is_equal_approx(LevelBridge._along(deck, 6 + LevelBridge.PAD).y, 2)
	)
	check("arch geometry has smooth intermediate segments", deck.size() > 30)
	var faces: PackedVector3Array = bridge.get_node("Generated/Body/Shape").shape.get_faces()
	var max_y := 0.0
	for point in faces:
		max_y = maxf(max_y, point.y)
	check(
		"deck and side wall collision follow the arch",
		is_equal_approx(max_y, 2 + LevelBridge.WALL_HEIGHT)
	)
	plugin._select(bridge)
	plugin.selection_editor.refresh()
	plugin.selection_editor.set_arch_height(1)
	check("selected bridge exposes an editable arch height", bridge.arch_height == 1)
	undo_last()
	check("arch height change supports undo", bridge.arch_height == 2)
	bridge.rebuild()
	plugin.bridge_arch.value = 4
	var invalid: Dictionary = plugin._bridge_plan(
		ground, {"point": Vector2(-6, 0), "height": 0}, {"point": Vector2(6, 0), "height": 0}
	)
	check("unwalkably steep arch is rejected before placing", invalid.has("error"))
	plugin.bridge_arch.value = 0
	check(
		"zero arch preserves the original straight bridge shape",
		LevelBridge.make_deck_line(Vector3.ZERO, Vector3(6, 0, 0), 0).size() == 4
	)
	plugin._set_tool(0)
	plugin._update_pick_preview(ground, {"node": bridge})
	check("selection outline follows an arched bridge", is_instance_valid(plugin.preview))
	EditorInterface.save_scene()
	var packed := (
		ResourceLoader.load(root.scene_file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		as PackedScene
	)
	var reopened := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var saved := reopened.get_node("Terrain/Afkadering") as LevelBoundary
	check(
		"saved scene contains editable curve and instanced trees",
		saved.curve.point_count == 2 and _same_trees(saved, transforms)
	)
	check(
		"saved scene contains all blocking shapes",
		(
			saved.get_node("Baked/Barrier").get_child_count()
			== boundary.get_node("Baked/Barrier").get_child_count()
		)
	)
	check(
		"saved bridge retains its arch height",
		reopened.get_node("Terrain/" + String(bridge.name)).arch_height == 2
	)
	reopened.free()
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	var fixture := Node3D.new()
	fixture.add_child(ground.duplicate())
	LevelFactory.own(fixture, fixture)
	check(
		"runtime fixture saves baked boundary geometry",
		LevelFactory.save(fixture, "res://captures/level_builder/BoundaryFixture.tscn") == OK
	)
	fixture.free()
	var reviewer = load("res://tests/level_builder_selection_checks.gd").new()
	reviewer.plugin = plugin
	reviewer.suite = self
	await reviewer.capture(ground, boundary, "boundary_trees")
	# A closer native view makes the curved deck, rails and end transitions reviewable.
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	camera.position = Vector3(5, 6, 11)
	camera.look_at(Vector3(0, 1, 0))
	camera.size = 18
	plugin._clear_preview()
	var frames := Engine.get_frames_drawn()
	await wait_frames(4)
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://captures/level_builder/bridge_arch.png")
	check("arched bridge renders in native Forward+ viewport", Engine.get_frames_drawn() > frames)
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(null)
	plugin._set_tool(0)
	view.queue_free()
	await wait_frames(3)
	var report := FileAccess.open(
		"res://captures/level_builder/boundary_checks.json", FileAccess.WRITE
	)
	report.store_string(
		JSON.stringify(
			{"checks": results, "failures": failures, "frames_drawn": Engine.get_frames_drawn()},
			"\t"
		)
	)
	plugin.get_tree().quit(1 if failures else 0)


func _click(camera: Camera3D, point: Vector3) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = camera.unproject_position(point)
		plugin._forward_3d_gui_input(camera, event)


func _same_trees(boundary: LevelBoundary, transforms: Array[Transform3D]) -> bool:
	var props := boundary.get_node("Baked/Props")
	if props.get_child_count() != transforms.size():
		return false
	for i in transforms.size():
		if not transforms[i].is_equal_approx((props.get_child(i) as Node3D).transform):
			return false
	return true
