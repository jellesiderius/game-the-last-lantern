extends Node
## Focused saved-level, terrain, collider, portal and persistence checks.
const FACTORY = preload("res://addons/level_builder/level_factory.gd")
const PREP = preload("res://addons/level_builder/asset_preparation.gd")
const CHECKS = preload("res://addons/level_builder/level_checks.gd")
var results: Array[Dictionary] = []
var failures := 0
var initial_frames := 0
var world: Node3D
var traversal_only := "--builder-traversal-only" in OS.get_cmdline_user_args()


func _ready() -> void:
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	call_deferred("run")


func check(label: String, passed: bool, detail: Variant = null) -> void:
	results.append({"check": label, "passed": passed, "detail": detail})
	failures += 0 if passed else 1
	print("BUILDER_CHECK ", label, " ", "PASS" if passed else "FAIL", " ", detail)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://captures/level_builder/" + label + ".png"
	)


func load_world(name: String) -> void:
	GameClock.reset()
	if is_instance_valid(world):
		get_tree().root.remove_child(world)
		world.queue_free()
		await frames(2)
	var scene_path := (
		name if name.begins_with("res://") else "res://scenes/levels/" + name + ".tscn"
	)
	world = load(scene_path).instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	world.player.use_test_input = true
	# This isolated replay drives the actors itself; live editor shortcuts must
	# not open its pause menu while the user continues authoring another window.
	world.get_node("HUD").set_process_input(false)
	await frames(50)


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	if DisplayServer.get_name() != "headless":
		get_window().title = "Level Builder — geïsoleerde spelcontrole"
		get_window().position = Vector2i(80, 80)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
		get_window().grab_focus()
	initial_frames = Engine.get_frames_drawn()
	GameProgress.ensure_preview()
	GameProgress.active_slot = 0
	if not traversal_only:
		await _asset_checks()
		_terrain_checks()
	await load_world("BuilderForest")
	var terrain := world.get_node("Terrain") as LevelTerrain
	var saved_mesh: Mesh = terrain.get_node("Baked/Surface").mesh
	await frames(20)
	check(
		"runtime loads the saved ground without generation",
		saved_mesh == terrain.get_node("Baked/Surface").mesh and not terrain.is_processing()
	)
	check(
		"panda stands on generated ground",
		world.player.is_on_floor() and absf(world.player.position.y) < .03,
		world.player.position
	)
	check(
		"generic camera retains size13 and fixed angles",
		(
			world.get_node("CameraRig/Camera3D").size == 13
			and world.camera_rig.rotation_degrees.is_equal_approx(Vector3(-50, 45, 0))
		)
	)
	var guard: Node3D = world.get_node("Enemies").get_child(0)
	var patrol_guard: Node3D = world.get_node("Enemies").get_child(1)
	check("authored patrol uses individual route", patrol_guard.brain.authored_patrol.size() == 2)
	check(
		"shared enemy profile stays untouched",
		(
			guard.brain.authored_patrol.is_empty()
			and guard.brain.settings == patrol_guard.brain.settings
		)
	)
	var surface = NavigationWorld.surface_for(guard, .3, .9)
	await frames(100)
	check("navigation discovers saved asset and terrain collisions", surface.ready)
	var navigation_route: PackedVector3Array = surface.route(
		Vector3(1, 0, -8), Vector3(-4.8, 1.5, -8), .3
	)
	check(
		"enemy navigation connects ramp and terrace",
		navigation_route.size() > 1 and navigation_route[-1].y > 1.4
	)
	await capture("forest_gameplay")
	for enemy in world.get_node("Enemies").get_children():
		enemy.disabled = true
	world.player.respawn(Vector3(1.4, 0, -8))
	world.player.use_test_input = true
	world.player.test_input = _world_input(Vector3.LEFT)
	await frames(210)
	world.player.test_input = Vector2.ZERO
	check(
		"panda climbs ramp and crosses terrace seam",
		world.player.position.x < -4.4 and world.player.position.y > 1.45,
		world.player.position
	)
	await capture("ramp_top")
	world.player.test_input = _world_input(Vector3.RIGHT)
	await frames(210)
	world.player.test_input = Vector2.ZERO
	check(
		"panda descends ramp onto ground",
		world.player.position.x > 1 and world.player.position.y < .1,
		world.player.position
	)
	await frames(80)
	check(
		"camera settles after ramp traversal",
		absf(world.camera_home.y - (world.player.position.y + world.camera_target_height)) < .03
	)
	if traversal_only:
		await capture("ramp_return_%d" % Engine.max_fps)
		_finish("traversal_%d" % Engine.max_fps)
		return
	world.player.respawn(Vector3(0, 0, 6))
	for enemy in world.get_node("Enemies").get_children():
		enemy.disabled = false
	world.set_physics_process(false)
	world.camera_rig.position = Vector3(0, 0, 0)
	world.get_node("CameraRig/Camera3D").size = 32
	await frames(4)
	await capture("forest_overview")
	world.get_node("CameraRig/Camera3D").size = 13
	world.set_physics_process(true)
	# Raycasts verify generated colliders follow moved/rotated instances.
	var tree: Node3D = world.get_node("Props").get_child(0)
	var original := tree.position
	tree.position = Vector3(-6, 0, 5)
	await frames(3)
	var hit := world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(-8, .7, 5), Vector3(-4, .7, 5), 1)
	)
	check(
		"moving tree moves its own collision",
		not hit.is_empty() and tree.is_ancestor_of(hit.collider)
	)
	tree.position = original
	var code: StringName = guard.persistent_id
	guard.receive_hit(999, 98765, world.player.position, 0)
	await frames(4)
	check(
		"placed enemy records defeat under stable id",
		GameProgress.defeated_since_rest.has(String(code))
	)
	# Real portal entry to cave and back. Test objects persist outside replaced scenes.
	var portal := world.get_node("Gameplay/NaarVolgendGebied") as ScenePortal
	world.player.respawn(portal.position + Vector3(0, 0, .4))
	world.player.use_test_input = true
	await frames(240)
	world = get_tree().current_scene
	check("saved portal reaches cave", world.name == "BuilderCave", world.name)
	if world.name == "BuilderCave":
		world.player.use_test_input = true
		check(
			"area set changes while player is shared",
			world.get("area_set").id == &"cave" and world.player.definition.id == &"red_panda"
		)
		await capture("cave_gameplay")
		var back := world.get_node("Gameplay/NaarVolgendGebied") as ScenePortal
		world.player.respawn(back.position + Vector3(0, 0, .4))
		await frames(240)
		world = get_tree().current_scene
		check("return portal reaches forest", world.name == "BuilderForest", world.name)
		var returned := world.get_node("Enemies").get_child(0)
		check("defeated enemy stays defeated after area change", returned.health.current == 0)
		var lily := world.get_node("Gameplay").get_child(0) as Vuurlelie
		check(
			"checkpoint discovers separate area identity",
			lily.area.code == &"builder_forest" and not lily.checkpoint_id.is_empty()
		)
		# Existing rest service, including real save, uses this newly authored level.
		world.player.respawn(lily.position + Vector3(0, 0, 1.7))
		world.player.use_test_input = true
		await frames(6)  # Area3D overlap updates on a physics tick after teleporting.
		check("placed checkpoint accepts interaction", Checkpoints.begin_rest(lily, world.player))
		for i in 600:
			if Checkpoints.rest_menu != null and world.player.state == "resting":
				break
			await frames(1)
		check(
			"rest interaction reaches its menu", Checkpoints.rest_menu != null, world.player.state
		)
		Checkpoints.menu_action(&"rest")
		await frames(240)
		check(
			"rest restores placed ordinary enemy",
			returned.health.current > 0 and not GameProgress.defeated_since_rest.has(String(code))
		)
		check("new level checkpoint can be saved", SaveStore.inspect_slot(0).state == "filled")
		Checkpoints.menu_action(&"continue")
		await frames(60)
		check(
			"continue closes the rest menu",
			not Checkpoints.active and not Checkpoints.rest_menu.visible
		)
	await load_world("BuilderCity")
	check(
		"city uses same playable foundation",
		world.get("area_set").id == &"city" and world.player.is_on_floor()
	)
	await capture("city_gameplay")
	if ResourceLoader.exists("res://captures/level_builder/EditorFixture.tscn"):
		await load_world("res://captures/level_builder/EditorFixture.tscn")
		for enemy in world.get_node("Enemies").get_children():
			enemy.disabled = true
		world.player.respawn(Vector3(10, 0, 4))
		await frames(80)
		check("saved mixed-material floor is walkable", world.player.is_on_floor())
		await capture("stone_floor")
		world.set_physics_process(false)
		world.camera_rig.position = Vector3.ZERO
		world.get_node("CameraRig/Camera3D").size = 48
		await frames(4)
		await capture("materials_overview")
	_finish("runtime_checks")


func _finish(name: String) -> void:
	var drawn := Engine.get_frames_drawn() - initial_frames
	if DisplayServer.get_name() != "headless":
		check("native review rendered actual frames", drawn > 100, drawn)
	var file := FileAccess.open("res://captures/level_builder/" + name + ".json", FileAccess.WRITE)
	file.store_string(
		JSON.stringify({"failures": failures, "render_frames": drawn, "checks": results}, "\t")
	)
	get_tree().quit(1 if failures else 0)


func _terrain_checks() -> void:
	var root := load("res://scenes/levels/BuilderForest.tscn").instantiate() as Node3D
	var terrain := root.get_node("Terrain") as LevelTerrain
	var props := root.get_node("Props").get_child_count()
	var path := terrain.get_node("Hoofdpad") as LevelPath
	var before: Mesh = terrain.get_node("Baked/Surface").mesh
	path.curve = path.curve.duplicate()
	path.width += 1
	path.curve.set_point_position(1, Vector3(-2, 0, 3))
	check("curve edits rebuild exclusive ground", terrain.bake(), terrain.last_error)
	check(
		"ground rebuild preserves placed props", root.get_node("Props").get_child_count() == props
	)
	check(
		"ground geometry updates after path edit", terrain.get_node("Baked/Surface").mesh != before
	)
	var stable: Mesh = terrain.get_node("Baked/Surface").mesh
	check(
		"unchanged bake is idempotent",
		terrain.bake() and stable == terrain.get_node("Baked/Surface").mesh
	)
	var mask: Texture2D = stable.surface_get_material(0).get_shader_parameter("path_mask")
	check("paths use a high-resolution filtered mask", mask != null and mask.get_width() >= 512)
	var mask_data := mask.get_image().get_data()
	terrain.resolution = 2
	check("coarse terrain remains valid", terrain.bake())
	stable = terrain.get_node("Baked/Surface").mesh
	var coarse_mask: Texture2D = stable.surface_get_material(0).get_shader_parameter("path_mask")
	check(
		"smooth path edges are independent of ground cell size",
		coarse_mask.get_image().get_data() == mask_data
	)
	var duplicate := terrain.get_node("Terrashelling").duplicate() as LevelRamp
	terrain.add_child(duplicate)
	check(
		"overlapping ramps rejected without replacing ground",
		not terrain.bake() and stable == terrain.get_node("Baked/Surface").mesh
	)
	terrain.remove_child(duplicate)
	duplicate.free()
	check("valid terrain can be rebuilt after rejection", terrain.bake())
	# Plateaus may overlap: the higher (or earlier) one owns the shared area.
	var stacked := terrain.get_node("Rotsbank").duplicate() as LevelTerrace
	terrain.add_child(stacked)
	check("overlapping plateaus merge instead of breaking ground", terrain.bake(), terrain.last_error)
	terrain.remove_child(stacked)
	stacked.free()
	check("terrain rebuilds after removing the stacked plateau", terrain.bake())
	check(
		"saved scene packs edited curves and meshes",
		FACTORY.save(root, "res://captures/level_builder/roundtrip.tscn") == OK
	)
	var restored: Node = load("res://captures/level_builder/roundtrip.tscn").instantiate()
	check(
		"reopen preserves manual path width",
		is_equal_approx(restored.get_node("Terrain/Hoofdpad").width, path.width)
	)
	check("reopen preserves saved collision", restored.has_node("Terrain/Baked/GroundCollision"))
	restored.free()
	root.free()


func _world_input(direction: Vector3) -> Vector2:
	var camera := get_viewport().get_camera_3d()
	var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var back := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
	return Vector2(direction.dot(right), direction.dot(back))


func _asset_checks() -> void:
	var visited := {}
	for kit in AreaSet.discover():
		for asset in kit.assets:
			if asset == null or asset.scene == null or visited.has(asset.id):
				continue
			visited[asset.id] = true
			var node := asset.scene.instantiate()
			if node.has_meta("level_asset_source"):
				var expected: bool = (
					node.get_meta("level_asset_collision_mode") != PREP.CollisionMode.NONE
				)
				check(
					"asset collider policy " + String(asset.id),
					PREP._has_collision(node) == expected
				)
			node.free()
	# Transform-sensitive preparation, preserve authored collision and manual child edits.
	var root := Node3D.new()
	var model := MeshInstance3D.new()
	model.name = "OffsetBox"
	model.mesh = BoxMesh.new()
	model.position = Vector3(2, 1, 0)
	model.rotation.y = .7
	root.add_child(model)
	model.owner = root
	var source := PackedScene.new()
	source.pack(root)
	root.free()
	ResourceSaver.save(
		source, "res://captures/level_builder/source.tscn", ResourceSaver.FLAG_CHANGE_PATH
	)
	source = ResourceLoader.load(
		"res://captures/level_builder/source.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REPLACE
	)
	var destination := "res://captures/level_builder/prepared.tscn"
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(destination)
	check("automatic asset preparation succeeds", PREP.prepare(source, destination) == OK)
	var prepared := (load(destination) as PackedScene).instantiate()
	var shape: ConcavePolygonShape3D = prepared.get_node("GeneratedCollision").get_child(0).shape
	var centroid := Vector3.ZERO
	for point in shape.get_faces():
		centroid += point
	centroid /= shape.get_faces().size()
	check(
		"generated collision includes imported transforms",
		centroid.is_equal_approx(Vector3(2, 1, 0)),
		centroid
	)
	var marker := Marker3D.new()
	marker.name = "ManualSocket"
	prepared.add_child(marker)
	marker.owner = prepared
	FACTORY.save(prepared, destination)
	prepared.free()
	var regeneration := PREP.prepare(source, destination)
	check("collision regeneration succeeds", regeneration == OK, error_string(regeneration))
	var revised := (
		(
			ResourceLoader.load(destination, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE)
			as PackedScene
		)
		. instantiate()
	)
	check("collision regeneration preserves manual nodes", revised.has_node("ManualSocket"))
	revised.free()
