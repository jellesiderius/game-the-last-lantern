@tool
extends RefCounted


func run(suite: RefCounted, ground: LevelTerrain) -> void:
	var plugin: EditorPlugin = suite.plugin
	var root := EditorInterface.get_edited_scene_root()
	var props := root.get_node("Props")
	var history := plugin.get_undo_redo().get_history_undo_redo(
		plugin.get_undo_redo().get_object_history_id(root)
	)
	var blue := load("res://settings/level_assets/forest_flowers_blue.tres") as LevelAsset
	var cream := load("res://settings/level_assets/forest_flowers_cream.tres") as LevelAsset
	var original_asset: LevelAsset = plugin.active_asset
	var original_radius: float = plugin.radius.value
	var original_amount: float = plugin.amount.value
	plugin.scatter_rng.seed = 4421
	plugin._asset_selected(plugin.shown_assets.find(blue))
	suite.check(
		"choosing flowers opens the visible scatter tool",
		plugin.tool == 8 and plugin.tool_buttons[8].text == "Strooi"
	)
	plugin.radius.value = 2
	plugin.amount.value = 30
	plugin.scatter_spacing.value = .4
	var before := props.get_child_count()
	var version := history.get_version()
	plugin._stamp(Vector3(6, 0, -3))
	var flowers: Array[Node3D] = []
	for node in props.get_children():
		if node.get_meta("level_asset_id", &"") == blue.id:
			flowers.append(node)
	suite.check(
		"one click scatters the requested flower group",
		flowers.size() == 30 and props.get_child_count() == before + 30,
		flowers.size()
	)
	var valid := true
	var varied := false
	for i in flowers.size():
		var flower := flowers[i]
		var at := flower.global_position
		valid = valid and Vector2(at.x - 6, at.z + 3).length() <= 2.001 and absf(at.y) < .001
		valid = valid and flower.owner == root and flower.scale.x >= .9 and flower.scale.x <= 1.1
		varied = varied or absf(flower.rotation.y) > .1
		for j in i:
			valid = valid and flower.global_position.distance_to(flowers[j].global_position) >= .399
	suite.check(
		"scatter respects radius, spacing, surface, owner and asset variation", valid and varied
	)
	suite.check("a scatter click creates one undo action", history.get_version() == version + 1)
	suite.undo_last()
	suite.check("undo removes the whole flower group", props.get_child_count() == before)
	suite.redo_last()
	suite.check(
		"redo restores the same saved flower transforms",
		props.get_child_count() == before + 30 and props.get_children().has(flowers[0])
	)
	# Place remains a predictable single instance, even for a scatter-enabled asset.
	plugin._set_tool(1)
	plugin._stamp(Vector3(7, 0, 1))
	suite.check(
		"Place puts down exactly one flower at the clicked point",
		(
			props.get_child_count() == before + 31
			and (
				(props.get_child(props.get_child_count() - 1) as Node3D).global_position
				== Vector3(7, 0, 1)
			)
		)
	)
	suite.undo_last()
	plugin._set_tool(8)
	# A cream flower is deliberately inside the brush: erasing blue must preserve it.
	plugin.active_asset = cream
	plugin._set_tool(1)
	plugin._stamp(Vector3(6, 0, -3))
	var kept := props.get_child(props.get_child_count() - 1)
	plugin.active_asset = blue
	plugin._set_tool(8)
	version = history.get_version()
	plugin.painting = true
	plugin.erasing = true
	plugin._erase(Vector3(5, 0, -3))
	plugin._erase(Vector3(7, 0, -3))
	plugin._commit_stroke()
	suite.check(
		"erase stroke only removes the chosen asset type",
		kept.get_parent() == props and props.get_child_count() < before + 31
	)
	suite.check("multiple erase stamps form one undo action", history.get_version() == version + 1)
	suite.undo_last()
	suite.check(
		"erase undo restores all original flowers and owners",
		props.get_child_count() == before + 31 and flowers[0].owner == root
	)
	# Paint across a path and through the pond: both exclusions apply per candidate.
	plugin.painting = true
	plugin.erasing = false
	plugin.amount.value = 20
	plugin.radius.value = 3
	var start := props.get_child_count()
	plugin._stamp(Vector3(0, 0, -3))
	plugin._stamp(Vector3(12.5, 0, -7))
	plugin._commit_stroke()
	valid = true
	for index in range(start, props.get_child_count()):
		var local: Vector3 = ground.to_local(props.get_child(index).global_position)
		valid = valid and not plugin._on_path(ground, local)
		for region in ground.outlines():
			if (
				region.has("water")
				and Geometry2D.is_point_in_polygon(Vector2(local.x, local.z), region.polygon)
			):
				valid = false
	suite.check(
		"scatter keeps paths and water free and stays inside terrain",
		valid and props.get_child_count() > start
	)
	suite.undo_last()
	# The top of a plateau is also a valid planting surface.
	plugin.radius.value = .8
	plugin.amount.value = 8
	plugin.scatter_spacing.value = .3
	start = props.get_child_count()
	plugin._stamp(Vector3(-6, 1, -6))
	valid = props.get_child_count() == start + 8
	for index in range(start, props.get_child_count()):
		valid = valid and is_equal_approx(props.get_child(index).global_position.y, 1)
	suite.check("flowers land on the plateau surface", valid)
	suite.undo_last()
	# Actual input: a dragged stroke and a release outside the viewport.
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
	plugin.radius.value = 1
	plugin.amount.value = 8
	var a := camera.unproject_position(Vector3(6, 0, 2))
	var b := camera.unproject_position(Vector3(10, 0, 2))
	var hover := InputEventMouseMotion.new()
	hover.position = a
	plugin._forward_3d_gui_input(camera, hover)
	suite.check(
		"scatter shows a brush outline before painting",
		is_instance_valid(plugin.preview) and plugin.preview.mesh.get_surface_count() == 1
	)
	version = history.get_version()
	start = props.get_child_count()
	suite._drag(camera, a, b)
	suite.check(
		"mouse dragging paints a continuous stroke with one undo",
		props.get_child_count() > start + 8 and history.get_version() == version + 1
	)
	suite.undo_last()
	suite.check("one undo removes the entire painted stroke", props.get_child_count() == start)
	plugin.painting = true
	plugin._stamp(Vector3(6, 0, 2))
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	plugin._input(release)
	await suite.wait_frames(2)
	suite.check(
		"scatter release outside viewport finishes the stroke",
		not plugin.painting and plugin.stroke_nodes.is_empty()
	)
	suite.undo_last()
	view.queue_free()
	# Keep the original 30-flower patch as the native visual sample and saved fixture.
	var reviewer = load("res://tests/level_builder_selection_checks.gd").new()
	reviewer.suite = suite
	reviewer.plugin = plugin
	plugin.radius.value = 2
	await reviewer.capture(ground, ground.get_node("Pad"), "scatter_flowers", Vector3(6, 0, -3))
	plugin._clear_preview()
	plugin.active_asset = original_asset
	plugin.radius.value = original_radius
	plugin.amount.value = original_amount
	plugin._set_tool(0)
