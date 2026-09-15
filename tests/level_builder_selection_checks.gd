@tool
extends RefCounted
## Focused selection/drag regression checks, run inside the isolated editor fixture.
var suite: RefCounted
var plugin: EditorPlugin


func run(checks: RefCounted, ground: LevelTerrain, nodes: Dictionary) -> void:
	suite = checks
	plugin = checks.plugin
	var root := EditorInterface.get_edited_scene_root()
	var plateau: LevelTerrace = nodes.plateau
	var bridge: LevelBridge = nodes.bridge
	var stairs: LevelRamp = nodes.stairs
	var water: LevelWater = nodes.water
	var path: LevelPath = nodes.path
	plugin._set_tool(0)
	ground.bake()
	await suite.wait_frames(3)
	# A real editor-world camera gives deterministic projection without changing the user's view.
	var pick_view := SubViewport.new()
	pick_view.size = Vector2i(1200, 800)
	pick_view.world_3d = ground.get_world_3d()
	plugin.add_child(pick_view)
	var camera := Camera3D.new()
	pick_view.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	camera.position = Vector3(0, 40, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	var history := plugin.get_undo_redo().get_history_undo_redo(
		plugin.get_undo_redo().get_object_history_id(root)
	)
	var version := history.get_version()
	for sample in [
		[plateau, Vector3(-6, 1, -6)],
		[nodes.hill, Vector3(-9, 2, -6)],
		[stairs, Vector3(-8, .5, -1.3)],
		[water, Vector3(12.5, -.12, -7)],
		[path, Vector3(0, 0, -3)],
		[bridge, Vector3(-5, 1.5, .93)],
		[bridge, Vector3(-5, 1.9, 3.5)],
	]:
		var screen := camera.unproject_position(ground.to_global(sample[1]))
		var hover := InputEventMouseMotion.new()
		hover.position = screen
		plugin._forward_3d_gui_input(camera, hover)
		var picked: Dictionary = plugin._selection_pick(ground, camera, screen)
		var named: Node = picked.get("node")
		suite.check(
			"viewport hover picks %s at %s" % [sample[0].name, sample[1]],
			named == sample[0],
			named.name if named else "none"
		)
		suite.check(
			"hover draws a white outline for %s" % sample[0].name,
			(
				is_instance_valid(plugin.preview)
				and plugin.preview.mesh.get_surface_count() == 1
				and plugin.preview.material_override.albedo_color == Color.WHITE
			)
		)
		var press := mouse_button(screen, true)
		var result: int = plugin._forward_3d_gui_input(camera, press)
		plugin._forward_3d_gui_input(camera, mouse_button(screen, false))
		suite.check(
			"viewport click selects the authored %s" % sample[0].name,
			(
				result == EditorPlugin.AFTER_GUI_INPUT_STOP
				and EditorInterface.get_selection().get_selected_nodes().has(sample[0])
			)
		)
	suite.check("clicks and hovering create no undo action", history.get_version() == version)
	# A front-on wall hit must resolve to the plateau, not bare ground behind it.
	camera.position = Vector3(-6, .5, 1)
	camera.rotation_degrees = Vector3.ZERO
	var wall_screen := camera.unproject_position(Vector3(-6, .5, -2))
	var wall: Dictionary = plugin._pick_authoring(ground, camera, wall_screen)
	suite.check(
		"clicking a plateau wall selects its owner", wall.get("node") == plateau, wall.get("node")
	)
	camera.position = Vector3(0, 40, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	# A manually nested prop and the Player branch both keep native selection.
	var prop := MeshInstance3D.new()
	prop.mesh = SphereMesh.new()
	prop.mesh.radius = .5
	prop.mesh.height = 1
	for parent in [root, root.get_node("Player")]:
		parent.add_child(prop)
		prop.global_position = Vector3(-6, 2, -6)
		await suite.wait_frames(2)
		var screen := camera.unproject_position(prop.global_position)
		var result: int = plugin._forward_3d_gui_input(camera, mouse_button(screen, true))
		var hover := InputEventMouseMotion.new()
		hover.position = screen
		plugin._forward_3d_gui_input(camera, hover)
		suite.check(
			"%s asset keeps native click and suppresses terrain hover" % parent.name,
			(
				result == EditorPlugin.AFTER_GUI_INPUT_PASS
				and not is_instance_valid(plugin.move_node)
				and not is_instance_valid(plugin.preview)
			)
		)
		# The corner of the sphere's bounding box is empty space, still over the plateau.
		var empty := camera.unproject_position(prop.global_position + Vector3(.47, 0, .47))
		suite.check(
			"empty mesh bounding-box space stays selectable",
			not plugin._selection_pick(ground, camera, empty).is_empty()
		)
		parent.remove_child(prop)
	prop.free()
	var screen := camera.unproject_position(Vector3(-6, 1, -6))
	var alt_click := mouse_button(screen, true)
	alt_click.alt_pressed = true
	suite.check(
		"Alt click passes through to Godot",
		plugin._forward_3d_gui_input(camera, alt_click) == EditorPlugin.AFTER_GUI_INPUT_PASS
	)
	var delete := InputEventKey.new()
	delete.keycode = KEY_DELETE
	delete.pressed = true
	suite.check(
		"Delete retains native editor handling",
		plugin._forward_3d_gui_input(camera, delete) == EditorPlugin.AFTER_GUI_INPUT_PASS
	)
	var start_curve := bridge.curve.duplicate() as Curve3D
	var stair_curve := stairs.curve.duplicate() as Curve3D
	version = history.get_version()
	suite._drag(camera, screen, camera.unproject_position(Vector3(-6, 1, -5)))
	suite.check(
		"real viewport drag carries plateau, stairs and only its bridge end",
		(
			plateau.position == Vector3(0, 0, 1)
			and stairs.position == Vector3(0, 0, 1)
			and (
				bridge.curve.get_point_position(0)
				== start_curve.get_point_position(0) + Vector3(0, 0, 1)
			)
			and bridge.curve.get_point_position(1) == start_curve.get_point_position(1)
		)
	)
	suite.check("drag commits exactly one undo action", history.get_version() == version + 1)
	suite.undo_last()
	suite.check(
		"one undo restores the complete connected assembly",
		(
			plateau.position == Vector3.ZERO
			and stairs.position == Vector3.ZERO
			and same_curve(bridge.curve, start_curve)
			and same_curve(stairs.curve, stair_curve)
		)
	)
	suite.redo_last()
	suite.check(
		"redo restores the assembly and terrain",
		(
			plateau.position == Vector3(0, 0, 1)
			and stairs.position == Vector3(0, 0, 1)
			and ground.last_error.is_empty()
		)
	)
	# Persist the moved authored state, then reload from disk rather than a cached scene.
	var saved := PackedScene.new()
	saved.pack(root)
	var save_path := "res://captures/level_builder/SelectionMoved.tscn"
	var save_error := ResourceSaver.save(saved, save_path)
	var reloaded := (
		ResourceLoader.load(save_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		as PackedScene
	)
	var reopened := reloaded.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	var saved_plateau := reopened.get_node(root.get_path_to(plateau)) as LevelTerrace
	var saved_stairs := reopened.get_node(root.get_path_to(stairs)) as LevelRamp
	var saved_bridge := reopened.get_node(root.get_path_to(bridge)) as LevelBridge
	suite.check(
		"save/reopen preserves a moved connected assembly",
		(
			save_error == OK
			and saved_plateau.position == plateau.position
			and saved_stairs.position == stairs.position
			and same_curve(saved_bridge.curve, bridge.curve)
		)
	)
	reopened.free()
	DirAccess.remove_absolute(save_path)
	suite.undo_last()
	# Cancel and tool switching restore the original curves without adding history.
	version = history.get_version()
	for cancel_kind in ["Escape", "tool", "focus", "outside"]:
		plugin._begin_move(ground, plateau, Vector2(-6, -6), 1)
		plugin._update_move(ground, Vector2(-6, -5))
		match cancel_kind:
			"Escape":
				var escape := InputEventKey.new()
				escape.keycode = KEY_ESCAPE
				escape.pressed = true
				plugin._forward_3d_gui_input(camera, escape)
			"tool":
				plugin._set_tool(1)
				plugin._set_tool(0)
			"focus":
				plugin._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
			"outside":
				plugin._input(mouse_button(Vector2(-100, -100), false))
				await suite.wait_frames(2)
				suite.check(
					"release outside viewport completes the drag",
					plateau.position == Vector3(0, 0, 1) and not is_instance_valid(plugin.move_node)
				)
				suite.undo_last()
		suite.check(
			"%s restores connected curves" % cancel_kind,
			(
				plateau.position == Vector3.ZERO
				and same_curve(bridge.curve, start_curve)
				and same_curve(stairs.curve, stair_curve)
			)
		)
	# A connector on the higher overlapping plateau must never be carried by the lower one.
	var high_bridge := LevelBridge.new()
	high_bridge.follow_ground = false
	high_bridge.curve = Curve3D.new()
	high_bridge.curve.add_point(Vector3(-9, 2, -6))
	high_bridge.curve.add_point(Vector3(-9, 2, -4))
	ground.add_child(high_bridge)
	plugin._begin_move(ground, plateau, Vector2(-6, -6), 1)
	plugin._update_move(ground, Vector2(-6, -5))
	suite.check(
		"overlapping higher plateau owns its own bridge endpoint",
		high_bridge.curve.get_point_position(0) == Vector3(-9, 2, -6)
	)
	plugin._cancel_move()
	ground.remove_child(high_bridge)
	high_bridge.queue_free()
	# Native transform changes must schedule the same geometry work without calling _changed.
	for node in [water, bridge]:
		await suite.wait_frames(3)
		ground.dirty = false
		var old_transform: Transform3D = node.transform
		var old_generated: Node = node.get_node("Generated")
		EditorInterface.get_selection().clear()
		EditorInterface.get_selection().add_node(
			node.find_children("*", "MeshInstance3D", true, false)[0]
		)
		node.position += Vector3(1, 0, 0)
		node.force_update_transform()
		suite.check("native transform schedules %s terrain update" % node.name, ground.dirty)
		await suite.wait_frames(2)
		suite.check(
			"rebuilding %s transfers generated selection to its author" % node.name,
			EditorInterface.get_selection().get_selected_nodes().has(node)
		)
		suite.check(
			"native transform refreshes %s geometry" % node.name,
			node.get_node("Generated") != old_generated
		)
		ground.bake()
		node.transform = old_transform
		node.force_update_transform()
		ground.bake()
		await suite.wait_frames(2)
	# Free movement and translated path paint use the same transaction.
	plugin.snap.value = 0
	var path_before := path.position
	plugin._begin_move(ground, path, Vector2.ZERO, 0)
	plugin._update_move(ground, Vector2(.37, .21))
	plugin._end_move(ground)
	suite.check(
		"zero grid allows precise free movement",
		path.position.is_equal_approx(path_before + Vector3(.37, 0, .21))
	)
	suite.undo_last()
	plugin.snap.value = 1
	plugin._clear_preview()
	pick_view.queue_free()
	await capture(ground, plateau, "selection_plateau")
	await capture(ground, bridge, "selection_bridge")
	await capture(ground, water, "selection_water")
	await capture(ground, path, "selection_path")
	plugin._clear_preview()


func capture(
	ground: LevelTerrain, node: Node3D, label: String, brush_point: Variant = null
) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1200, 800)
	viewport.world_3d = ground.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	plugin.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	camera.position = Vector3(20, 30, 26)
	camera.look_at(Vector3(0, 0, -1))
	camera.current = true
	if brush_point == null:
		plugin._update_pick_preview(ground, {"node": node})
	else:
		camera.size = 12
		camera.position = brush_point + Vector3(8, 12, 10)
		camera.look_at(brush_point)
		plugin._scatter_preview(brush_point, false)
	# Freeze this evidence overlay while ordinary editor hover input continues.
	var overlay: MeshInstance3D = plugin.preview.duplicate()
	ground.add_child(overlay)
	overlay.transform = Transform3D.IDENTITY
	plugin._clear_preview()
	var frames := Engine.get_frames_drawn()
	await suite.wait_frames(4)
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png("res://captures/level_builder/" + label + ".png")
	suite.check(
		label + " renders in native viewport",
		Engine.get_frames_drawn() > frames and not image.is_empty(),
		Engine.get_frames_drawn() - frames
	)
	viewport.queue_free()
	overlay.queue_free()
	await suite.wait_frames(1)


func mouse_button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	return event


func same_curve(a: Curve3D, b: Curve3D) -> bool:
	if a.point_count != b.point_count:
		return false
	for i in a.point_count:
		if not a.get_point_position(i).is_equal_approx(b.get_point_position(i)):
			return false
	return true
