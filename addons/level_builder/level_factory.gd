@tool
class_name LevelFactory
extends RefCounted


static func create(kit: AreaSet, area: WorldArea, dimensions := Vector2(24, 24)) -> Node3D:
	var root := Node3D.new()
	root.name = area.display_name.to_pascal_case()
	root.set_script(load("res://scripts/world/authoring/authored_level.gd"))
	root.set("area", area)
	root.set("area_set", kit)
	root.set("spawn_position", Vector3(0, 0, minf(6, dimensions.y / 2 - 1)))
	root.set("camera_min", -(dimensions / 2 - Vector2(5, 5)).max(Vector2.ONE))
	root.set("camera_max", (dimensions / 2 - Vector2(5, 5)).max(Vector2.ONE))
	var ground := LevelTerrain.new()
	ground.name = "Terrain"
	ground.area_set = kit
	ground.size = dimensions
	root.add_child(ground)
	ground.owner = root
	ground.bake()
	for name in ["Props", "Enemies", "Gameplay", "Routes", "Spawns"]:
		var group := Node3D.new()
		group.name = name
		root.add_child(group)
	var spawn := Marker3D.new()
	spawn.set_script(load("res://scripts/world/scene_spawn_point.gd"))
	spawn.name = "Entrance"
	spawn.position = Vector3(0, 0, minf(6, dimensions.y / 2 - 1))
	root.get_node("Spawns").add_child(spawn)
	var anchor := Marker3D.new()
	anchor.name = "StartCheckpoint"
	anchor.set_script(load("res://scripts/world/checkpoint_anchor.gd"))
	anchor.set("checkpoint_id", StringName("start." + String(area.code)))
	anchor.set("area", area)
	anchor.position = spawn.position
	root.get_node("Spawns").add_child(anchor)
	var player := load("res://scenes/actors/player/Player.tscn").instantiate() as Node3D
	player.name = "Player"
	player.position = spawn.position
	root.add_child(player)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.rotation_degrees = Vector3(-50, 45, 0)
	root.add_child(rig)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position.z = 30
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13
	camera.far = 160
	camera.current = true
	rig.add_child(camera)
	var environment := WorldEnvironment.new()
	environment.name = "WorldEnvironment"
	environment.environment = make_environment(kit)
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-55, -32, 0)
	sun.light_color = kit.sun_color
	sun.light_energy = kit.sun_energy
	sun.shadow_enabled = true
	root.add_child(sun)
	var hud: Node = load("res://scenes/ui/HUD.tscn").instantiate()
	hud.name = "HUD"
	root.add_child(hud)
	var debug := MeshInstance3D.new()
	debug.name = "DebugVolumes"
	root.add_child(debug)
	var pool := Node3D.new()
	pool.name = "ImpactPool"
	root.add_child(pool)
	for i in 4:
		var spark: Node = load("res://scenes/effects/ImpactSpark.tscn").instantiate()
		spark.name = "Spark%d" % i
		pool.add_child(spark)
	var sound := AudioStreamPlayer3D.new()
	sound.name = "ImpactSound"
	sound.stream = load("res://assets/audio/impact.wav")
	sound.volume_db = -8
	sound.max_distance = 30
	root.add_child(sound)
	own(root, root)
	return root


static func make_environment(kit: AreaSet) -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = kit.background_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = kit.ambient_color
	env.ambient_light_energy = kit.ambient_energy
	env.reflected_light_source = 2
	# ACES keeps the saturated, contrasty Tunic-like palette without washing out.
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = .4
	env.ssao_intensity = .7
	env.glow_enabled = true
	env.glow_intensity = .35
	env.fog_enabled = kit.fog_density > 0
	env.fog_light_color = kit.fog_color
	env.fog_density = kit.fog_density
	return env


static func own(node: Node, root: Node) -> void:
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path.is_empty():
			own(child, root)


static func save(root: Node, path: String) -> Error:
	var grounds: Array[LevelTerrain] = []
	for node in LevelChecks.nodes(root):
		if node is LevelTerrain:
			grounds.append(node)
	# Baking replaces generated descendants; do not iterate the old node snapshot.
	for ground in grounds:
		if not ground.bake():
			return ERR_INVALID_DATA
		var save_error: Error = ground.save_baked_resources(path)
		if save_error != OK:
			return save_error
	var packed := PackedScene.new()
	var error := packed.pack(root)
	if error != OK:
		return error
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return ResourceSaver.save(packed, path)
