extends SceneTree
## Renders a small Link's Awakening-style layout to captures/level_builder/look.png.
## Run with a window (not headless): Godot --path . -s res://tools/level_builder/look_preview.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	var kit := load("res://settings/area_sets/forest.tres") as AreaSet
	var world := Node3D.new()
	root.add_child(world)
	var terrain := LevelTerrain.new()
	terrain.area_set = kit
	terrain.size = Vector2(26, 20)
	world.add_child(terrain)
	_plateau(terrain, Rect2(-13, -10, 26, 7), 1)
	_plateau(terrain, Rect2(-13, -3, 5, 8), 1)
	_plateau(terrain, Rect2(-5, -9, 7, 3), 2).surface_style = load("res://settings/surface_styles/stone.tres")
	_plateau(terrain, Rect2(2, 1, 9, 2), 1)
	_plateau(terrain, Rect2(2, 3, 2, 3), 1)
	var ramp := LevelRamp.new()
	ramp.stairs = true
	ramp.width = 2
	ramp.curve = Curve3D.new()
	ramp.curve.add_point(Vector3(0, 0, -1.6))
	ramp.curve.add_point(Vector3(0, 0, -3))
	terrain.add_child(ramp)
	# Inset stairs climbing into the higher plateau, as in the reference.
	var inset := LevelRamp.new()
	inset.stairs = true
	inset.width = 2
	inset.curve = Curve3D.new()
	inset.curve.add_point(Vector3(-2, 0, -6))
	inset.curve.add_point(Vector3(-2, 0, -7.4))
	terrain.add_child(inset)
	var path := LevelPath.new()
	path.width = 2.2
	path.curve = Curve3D.new()
	for point in [Vector3(-6, 0, 10), Vector3(-5, 0, 5), Vector3(-1, 0, 2), Vector3(0, 0, -1.4)]:
		path.curve.add_point(point)
	terrain.add_child(path)
	# A flat bridge between two 1 m plateaus and a climbing one to a 2.5 m plateau.
	_plateau(terrain, Rect2(-6, 4, 4, 4), 2.5)
	_bridge(terrain, Vector3(6, 1, -3), Vector3(6, 1, 1))
	_bridge(terrain, Vector3(2, 1, 5), Vector3(-2, 2.5, 5))
	# A pond beside the plateau and a river running under a flat bridge.
	_water(terrain, LevelWater.Shape.AREA, [Vector3(-12, 0, 6), Vector3(-7, 0, 6), Vector3(-7, 0, 9.5), Vector3(-12, 0, 9.5)])
	_water(terrain, LevelWater.Shape.PATH, [Vector3(6, 0, 9.5), Vector3(8, 0, 6), Vector3(12, 0, 4.5)])
	_bridge(terrain, Vector3(7, 0, 9), Vector3(10.5, 0, 5.5))
	var ok := terrain.bake()
	print("LOOK bake ", ok, " ", terrain.last_error)
	var environment := WorldEnvironment.new()
	environment.environment = LevelFactory.make_environment(kit)
	environment.environment.fog_enabled = false
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = kit.sun_color
	sun.light_energy = kit.sun_energy
	sun.shadow_enabled = true
	world.add_child(sun)
	var rig := Node3D.new()
	rig.rotation_degrees = Vector3(-50, 45, 0)
	world.add_child(rig)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 17
	camera.position.z = 40
	camera.far = 200
	rig.add_child(camera)
	camera.make_current()
	root.size = Vector2i(1280, 800)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/level_builder/look.png")
	# Close-up on where the stairs meet the plateaus.
	rig.position = Vector3(-1, 1, -4)
	camera.size = 7
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/level_builder/look_close.png")
	rig.position = Vector3(2, 1.5, 2)
	camera.size = 8
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/level_builder/look_bridge.png")
	rig.position = Vector3(-2, 0, 7)
	camera.size = 12
	for i in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://captures/level_builder/look_water.png")
	print("LOOK saved")
	quit()


func _plateau(terrain: LevelTerrain, rect: Rect2, height: float) -> LevelTerrace:
	var plateau := LevelTerrace.new()
	plateau.curve = Curve3D.new()
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		plateau.curve.add_point(Vector3(corner.x, 0, corner.y))
	terrain.add_child(plateau)
	plateau.height = height
	return plateau


func _bridge(terrain: LevelTerrain, from: Vector3, to: Vector3) -> void:
	var bridge := LevelBridge.new()
	bridge.curve = Curve3D.new()
	bridge.curve.add_point(from)
	bridge.curve.add_point(to)
	terrain.add_child(bridge)


func _water(terrain: LevelTerrain, shape: int, points: Array) -> void:
	var water := LevelWater.new()
	water.shape = shape
	water.width = 2.5
	water.curve = Curve3D.new()
	for point in points:
		water.curve.add_point(point)
	terrain.add_child(water)
