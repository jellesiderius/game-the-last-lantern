@tool
extends "res://tests/level_builder_editor_checks.gd"
## Run only in an isolated editor copy with --level-builder-elevation-checks.


func run(editor_plugin: EditorPlugin) -> void:
	plugin = editor_plugin
	plugin.get_window().title = "Level Builder — hoogtecontrole"
	plugin.get_window().grab_focus()
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	await wait_frames(80)
	plugin.new_kind = "level"
	plugin.new_name.text = "Builder Elevation " + str(OS.get_process_id())
	plugin.new_width.value = 32
	plugin.new_depth.value = 24
	plugin._create_new()
	await wait_frames(80)
	var root := EditorInterface.get_edited_scene_root()
	var ground := root.get_node("Terrain") as LevelTerrain
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	check(
		"construction height allows 100 m with half-metre steps",
		plugin.plateau_height.max_value == 100 and plugin.plateau_height.step == .5
	)
	plugin.plateau_height.value = 100
	var plateau: LevelTerrace = plugin._create_plateau(Vector3(-8, 0, -7), Vector3(8, 0, 7))
	check("plateau can be authored at 100 m", plateau.height == 100)
	plateau.height = 99.6
	check("height still snaps to 0.5 m", plateau.height == 99.5)
	plateau.height = 104
	check("height is capped at 100 m", plateau.height == 100)
	check("100 m plateau bakes", ground.bake(), ground.last_error)
	var view := SubViewport.new()
	view.size = Vector2i(1200, 800)
	view.world_3d = ground.get_world_3d()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	plugin.add_child(view)
	var camera := Camera3D.new()
	view.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 40
	camera.position = Vector3(0, 140, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	check(
		"pointer reaches the baked 100 m top",
		_hit_at(camera, Vector3(0, 100, 0)).is_equal_approx(Vector3(0, 100, 0))
	)
	plugin._select(plateau)
	plugin.selection_editor.refresh()
	var fields: Array = plugin.selection_editor.find_children("*", "SpinBox", true, false)
	check(
		"selected plateau height field allows 100 m in 0.5 m steps",
		fields.size() == 1 and fields[0].max_value == 100 and fields[0].step == .5
	)
	var ramp := LevelRamp.new()
	ramp.curve = Curve3D.new()
	ramp.curve.add_point(Vector3.ZERO)
	ramp.curve.add_point(Vector3(2, 0, 0))
	ramp.start_height = 99.6
	ramp.end_height = 104
	check(
		"stair endpoints support the same range and snapping",
		ramp.start_height == 99.5 and ramp.end_height == 100
	)
	ramp.free()
	plugin.selection_editor.set_height(10)
	undo_last()
	check("height edit undo restores 100 m", plateau.height == 100)
	redo_last()
	check("height edit redo restores 10 m", plateau.height == 10)
	check("10 m fixture bakes", ground.bake(), ground.last_error)
	camera.position.y = 40
	plugin._set_tool(7)
	plugin.water_shape.select(LevelWater.Shape.AREA)
	_drag(
		camera,
		camera.unproject_position(Vector3(-6, 10, -5)),
		camera.unproject_position(Vector3(-2, 10, -1))
	)
	var pond: LevelWater
	for child in ground.get_children():
		if child is LevelWater:
			pond = child
	check(
		"dragging water on a plateau stores its 10 m elevation",
		pond != null and pond.elevation() == 10
	)
	if pond == null:
		_finish()
		return
	check("elevated pond bakes", ground.bake(), ground.last_error)
	pond.rebuild()
	check("pond surface is just below its plateau", _surface_height(pond, Vector2(-4, -3), 9.88))
	check(
		"water bed is carved below the plateau top",
		is_equal_approx(_bed_height(ground, Vector2(-4, -3)), 9.4),
		_bed_height(ground, Vector2(-4, -3))
	)
	var collision := ground.get_node("Baked/GroundCollision/SurfaceShape") as CollisionShape3D
	var collision_arrays: Array = []
	collision_arrays.resize(Mesh.ARRAY_MAX)
	collision_arrays[Mesh.ARRAY_VERTEX] = (collision.shape as ConcavePolygonShape3D).get_faces()
	var collision_mesh := ArrayMesh.new()
	collision_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, collision_arrays)
	var bed_hit := collision_mesh.generate_triangle_mesh().intersect_ray(
		Vector3(-4, 20, -3), Vector3.DOWN
	)
	check(
		"elevated water collision follows its 9.4 m bed",
		not bed_hit.is_empty() and is_equal_approx(bed_hit.position.y, 9.4)
	)
	check(
		"placing pointer sees elevated water surface",
		is_equal_approx(_hit_at(camera, Vector3(-4, 10, -3)).y, 9.88)
	)
	undo_last()
	check("water creation undo removes the entire pond", pond.get_parent() == null)
	redo_last()
	ground.bake()
	check(
		"water creation redo preserves elevation",
		pond.get_parent() == ground and pond.elevation() == 10
	)
	# Ground water remains at the original height, even beside a tall plateau.
	var low_water: LevelWater = plugin._create_water_area(Vector3(10, 0, -5), Vector3(14, 0, -1))
	ground.bake()
	low_water.rebuild()
	check(
		"ground water keeps the original surface and bed heights",
		(
			_surface_height(low_water, Vector2(12, -3), -.12)
			and is_equal_approx(_bed_height(ground, Vector2(12, -3)), -.6)
		)
	)
	# Overshooting the supporting plateau must not leave floating water outside it.
	var edge_water: LevelWater = plugin._create_water_area(Vector3(6, 10, 3), Vector3(11, 10, 6))
	ground.bake()
	edge_water.rebuild()
	check(
		"elevated water stops at the supporting plateau edge",
		(
			edge_water.contains_surface(Vector2(7, 4))
			and not edge_water.contains_surface(Vector2(10, 4))
		)
	)
	check("water and dry terrain regions stay exclusive", _exclusive(ground))
	# Higher islands cut the shared water surface and bed footprints.
	plugin.plateau_height.value = 10.5
	var island: LevelTerrace = plugin._create_plateau(Vector3(-5, 10, -4), Vector3(-3, 10, -2))
	ground.bake()
	check(
		"higher island excludes pond surface and retains land",
		(
			island.height == 10.5
			and not pond.contains_surface(Vector2(-4, -3))
			and is_equal_approx(_hit_at(camera, Vector3(-4, 10.5, -3)).y, 10.5)
		)
	)
	undo_last()
	ground.bake()
	check(
		"island undo restores the pond surface",
		pond.contains_surface(Vector2(-4, -3)) and _surface_height(pond, Vector2(-4, -3), 9.88)
	)
	# Allow Godot's deferred path editor selection to follow the undone island.
	await wait_frames(3)
	plugin.water_shape.select(LevelWater.Shape.PATH)
	plugin._set_tool(7)
	plugin.water_width.value = 1
	plugin._add_curve_point(_hit_at(camera, Vector3(-6, 10, 3)))
	plugin._add_curve_point(_hit_at(camera, Vector3(-2, 10, 3)))
	var river: LevelWater = plugin.active_curve
	plugin._set_tool(0)
	ground.bake()
	river.rebuild()
	check(
		"river on plateau keeps its clicked elevation",
		river.elevation() == 10 and _surface_height(river, Vector2(-4, 3), 9.88)
	)
	plugin._set_tool(4)
	plugin._add_curve_point(_hit_at(camera, Vector3(1, 10, -5)))
	plugin._add_curve_point(_hit_at(camera, Vector3(5, 10, -5)))
	var path: LevelPath = plugin.active_curve
	plugin._set_tool(5)
	plugin._add_curve_point(_hit_at(camera, Vector3(1, 10, -4)))
	plugin._add_curve_point(_hit_at(camera, Vector3(5, 10, -4)))
	var route: EnemyPatrol = plugin.active_curve
	plugin._set_tool(0)
	check(
		"paths and patrol routes preserve clicked plateau heights",
		_curve_at_height(path, 10) and _curve_at_height(route, 10)
	)
	ground.bake()
	var blue := load("res://settings/level_assets/forest_flowers_blue.tres") as LevelAsset
	plugin.active_asset = blue
	plugin._set_tool(8)
	plugin.radius.value = 1
	plugin.amount.value = 8
	plugin.scatter_spacing.value = .3
	plugin.scatter_paths.button_pressed = true
	plugin.scatter_rng.seed = 821
	plugin.scatter_random_yaw.button_pressed = true
	plugin.placement_height.value = 2
	var props := root.get_node("Props")
	var count := props.get_child_count()
	var history := plugin.get_undo_redo().get_history_undo_redo(
		plugin.get_undo_redo().get_object_history_id(root)
	)
	var version := history.get_version()
	plugin._stamp(_hit_at(camera, Vector3(2, 10, 1)))
	var varied := false
	var correct := props.get_child_count() == count + 8
	var transforms: Array[Transform3D] = []
	for i in range(count, props.get_child_count()):
		var flower := props.get_child(i) as Node3D
		correct = correct and is_equal_approx(flower.global_position.y, 12)
		varied = varied or absf(flower.rotation.y) > .1
		transforms.append(flower.transform)
	check("scatter height is offset above the clicked 10 m surface", correct)
	check("enabled random angle varies flower rotation", varied)
	check("height offset control keeps 0.5 m steps", plugin.placement_height.step == .5)
	check("raised scatter group has one undo action", history.get_version() == version + 1)
	undo_last()
	check("undo removes the raised group", props.get_child_count() == count)
	redo_last()
	correct = props.get_child_count() == count + transforms.size()
	for i in transforms.size():
		correct = correct and (props.get_child(count + i) as Node3D).transform == transforms[i]
	check("redo preserves exact height and random angles", correct)
	plugin.painting = true
	plugin.erasing = true
	plugin._erase(Vector3(2, 10, 1))
	plugin._commit_stroke()
	check("erase uses the selected height offset", props.get_child_count() == count)
	undo_last()
	check("erase undo restores the raised flowers", props.get_child_count() == count + 8)
	plugin.radius.value = .25
	plugin.amount.value = 6
	plugin.scatter_spacing.value = 10
	plugin.scatter_paths.button_pressed = false
	var overlap_start := props.get_child_count()
	var overlap_point := (props.get_child(count) as Node3D).global_position - Vector3.UP * 2
	plugin._stamp(overlap_point)
	check("overlap is blocked by default", props.get_child_count() == overlap_start)
	plugin.scatter_overlap.button_pressed = true
	check(
		"allowing overlap keeps distance editable at its chosen value",
		plugin.scatter_spacing.editable and plugin.scatter_spacing.value == 10
	)
	plugin._stamp(overlap_point)
	check(
		"overlap ignores existing flowers but spaces the new group",
		props.get_child_count() == overlap_start + 1
	)
	undo_last()
	check("one undo removes only the overlapping group", props.get_child_count() == overlap_start)
	plugin.scatter_spacing.value = .1
	plugin.painting = true
	version = history.get_version()
	plugin._stamp(overlap_point)
	plugin._stamp(overlap_point)
	plugin._commit_stroke()
	check(
		"smaller distance permits a denser overlapping stroke",
		props.get_child_count() > overlap_start + 6
	)
	correct = true
	for i in range(overlap_start, props.get_child_count()):
		for j in range(overlap_start, i):
			correct = (
				correct
				and (
					(props.get_child(i) as Node3D).global_position.distance_to(
						(props.get_child(j) as Node3D).global_position
					)
					>= .099
				)
			)
	check("overlap preserves distance across all stamps in the same stroke", correct)
	check("overlapping stroke has one undo action", history.get_version() == version + 1)
	undo_last()
	check(
		"undo overlapping stroke preserves earlier flowers",
		props.get_child_count() == overlap_start
	)
	plugin.scatter_overlap.button_pressed = false
	plugin.scatter_spacing.value = 10
	plugin._stamp(overlap_point)
	check(
		"turning overlap off restores minimum spacing",
		props.get_child_count() == overlap_start and plugin.scatter_spacing.editable
	)
	plugin.radius.value = 1
	plugin.amount.value = 8
	plugin.scatter_spacing.value = .3
	plugin.scatter_paths.button_pressed = true
	plugin.scatter_random_yaw.button_pressed = false
	plugin.placement_height.value = .5
	count = props.get_child_count()
	plugin._stamp(Vector3(5, 10, 1))
	var prototype := blue.scene.instantiate() as Node3D
	correct = props.get_child_count() == count + 8
	for i in range(count, props.get_child_count()):
		var flower := props.get_child(i) as Node3D
		correct = (
			correct
			and is_equal_approx(flower.global_position.y, 10.5)
			and flower.rotation.is_equal_approx(prototype.rotation)
		)
	prototype.free()
	check("disabled random angle retains prefab rotation at the chosen height", correct)
	plugin._set_tool(1)
	plugin.placement_height.value = -.5
	plugin._stamp(_hit_at(camera, Vector3(2, 10, 4)))
	check(
		"single placement supports negative surface offsets",
		is_equal_approx((props.get_child(-1) as Node3D).global_position.y, 9.5)
	)
	plugin.placement_height.value = 0
	plugin._stamp(_hit_at(camera, Vector3(4, 10, 4)))
	check(
		"zero placement offset sits directly on the plateau",
		is_equal_approx((props.get_child(-1) as Node3D).global_position.y, 10)
	)
	EditorInterface.save_scene()
	var packed := (
		ResourceLoader.load(root.scene_file_path, "", ResourceLoader.CACHE_MODE_IGNORE)
		as PackedScene
	)
	var reopened := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	check(
		"saved water preserves its 10 m elevation",
		(reopened.get_node("Terrain/" + String(pond.name)) as LevelWater).elevation() == 10
	)
	check(
		"saved routes preserve plateau heights",
		_curve_at_height(reopened.get_node("Routes/" + String(route.name)), 10, false)
	)
	var saved_props := reopened.get_node("Props")
	correct = saved_props.get_child_count() == props.get_child_count()
	for i in props.get_child_count():
		correct = (
			correct
			and (props.get_child(i) as Node3D).transform.is_equal_approx(
				(saved_props.get_child(i) as Node3D).transform
			)
		)
	check("save/reopen preserves placement heights and angles", correct)
	reopened.free()
	plugin._show_builder()
	plugin._set_tool(8)
	plugin.placement_height.value = 2
	var reviewer = load("res://tests/level_builder_selection_checks.gd").new()
	reviewer.plugin = plugin
	reviewer.suite = self
	await reviewer.capture(ground, pond, "elevation_water_scatter", Vector3(0, 10, 0))
	await RenderingServer.frame_post_draw
	plugin.get_viewport().get_texture().get_image().save_png(
		"res://captures/level_builder/elevation_controls.png"
	)
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(null)
	plugin._set_tool(0)
	view.queue_free()
	await wait_frames(3)
	var report := FileAccess.open(
		"res://captures/level_builder/elevation_checks.json", FileAccess.WRITE
	)
	report.store_string(
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


func _hit_at(camera: Camera3D, at: Vector3) -> Vector3:
	var hit: Variant = plugin._hit(camera, camera.unproject_position(at))
	return hit if hit != null else Vector3.INF


func _surface_height(water: LevelWater, point: Vector2, height: float) -> bool:
	var mesh := water.get_node_or_null("Generated/Surface") as MeshInstance3D
	if mesh == null:
		return false
	var hit: Dictionary = plugin._mesh_hit(mesh, Vector3(point.x, 120, point.y), Vector3.DOWN)
	return not hit.is_empty() and is_equal_approx(hit.position.y, height)


func _bed_height(ground: LevelTerrain, point: Vector2) -> float:
	var mesh := ground.get_node("Baked/Surface") as MeshInstance3D
	var hit: Dictionary = plugin._mesh_hit(mesh, Vector3(point.x, 120, point.y), Vector3.DOWN)
	return hit.position.y if not hit.is_empty() else INF


func _curve_at_height(path: Path3D, height: float, global := true) -> bool:
	for i in path.curve.point_count:
		var at := path.curve.get_point_position(i)
		at = path.to_global(at) if global else path.transform * at
		if not is_equal_approx(at.y, height):
			return false
	return path.curve.point_count == 2


func _exclusive(ground: LevelTerrain) -> bool:
	var regions := ground.outlines()
	for i in regions.size():
		for j in i:
			for overlap in Geometry2D.intersect_polygons(regions[i].polygon, regions[j].polygon):
				if LevelTerrain.polygon_area(overlap) > .0001:
					return false
	return true
