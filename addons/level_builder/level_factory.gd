@tool
class_name LevelFactory
extends RefCounted


const LEVEL_SCRIPT := "res://scripts/world/authoring/authored_level.gd"
const DUNGEON_SCRIPT := "res://scripts/world/authoring/authored_dungeon.gd"


static func create(
	kit: AreaSet, area: WorldArea, dimensions := Vector2(24, 24), root_script := LEVEL_SCRIPT
) -> Node3D:
	var root := Node3D.new()
	root.name = area.display_name.to_pascal_case()
	root.set_script(load(root_script))
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


## An enclosed room: an interior (kind "interior") or a dungeon room (kind "dungeon").
## Dungeons need their DungeonDefinition; they get its entrance marker and an exit.
static func create_room(
	kind: String, kit: AreaSet, area: WorldArea, dimensions: Vector2, dungeon: DungeonDefinition = null
) -> Node3D:
	var root := create(kit, area, dimensions, DUNGEON_SCRIPT if kind == "dungeon" else LEVEL_SCRIPT)
	var terrain := root.get_node("Terrain") as LevelTerrain
	terrain.room_walls = true
	root.get_node("CameraRig/Camera3D").size = 11
	# Rooms float in the dark, like a diorama; the area set gives the colour.
	for node in root.find_children("*", "WorldEnvironment", true, false):
		var dark := (node as WorldEnvironment).environment.duplicate() as Environment
		dark.fog_enabled = false
		if kind == "interior":
			dark.tonemap_exposure = 1.3
		(node as WorldEnvironment).environment = dark
	if kind == "interior":
		terrain.room_look = 1
		terrain.wall_height = 2.6
		terrain.cutaway_height = .5
	var lamp := OmniLight3D.new()
	lamp.name = "RoomLight"
	lamp.position = Vector3(dimensions.x * .15, 2.6, -dimensions.y * .15)
	lamp.light_color = Color(1, .72, .4) if kind == "interior" else Color("ffa64d")
	lamp.light_energy = 1.0 if kind == "interior" else .9
	lamp.omni_range = maxf(7.0, maxf(dimensions.x, dimensions.y) * .75)
	lamp.shadow_enabled = true
	root.add_child(lamp)
	if kind == "dungeon" and dungeon:
		root.set("dungeon", dungeon)
		var entrance := root.get_node("Spawns/Entrance") as Node3D
		entrance.name = String(dungeon.entrance)
		entrance.set("spawn_id", dungeon.entrance)
		# Like the Wortelkelder: arrival a few metres in, the exit just behind it,
		# both kept on the floor of the room.
		var arrival := Vector3(0, 0, dimensions.y / 2 - 3.2)
		entrance.position = arrival
		root.set("spawn_position", arrival)
		root.get_node("Player").position = arrival
		root.get_node("Spawns/StartCheckpoint").position = arrival
		var exit: Node3D = load("res://scenes/world/dungeons/DungeonExit.tscn").instantiate()
		exit.name = "Uitgang"
		exit.set("dungeon", dungeon)
		exit.position = Vector3(0, 0, dimensions.y / 2 - 1.4)
		exit.rotation_degrees.y = 180
		root.get_node("Gameplay").add_child(exit)
	own(root, root)
	terrain.bake()
	return root


## A doorway on one ground edge (0 north, 1 east, 2 south, 3 west) of the terrain,
## leading to target_scene; its arrival marker answers to door_id.
static func add_door(
	terrain: LevelTerrain,
	root: Node,
	side: int,
	along: float,
	door_id: StringName,
	target_scene := "",
	target_spawn: StringName = &"",
	style := LevelDoor.Style.WOODEN_DOOR
) -> LevelDoor:
	var door := LevelDoor.new()
	door.name = String(door_id)
	door.collision_layer = 0
	door.collision_mask = 2
	door.settings = load("res://settings/transitions/door.tres")
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.resource_local_to_scene = true
	shape.shape = box
	door.add_child(shape)
	var arrival := Marker3D.new()
	arrival.name = "Arrival"
	arrival.set_script(load("res://scripts/world/scene_spawn_point.gd"))
	# Stands inside the room and faces into it; -Z of the door points out.
	arrival.position = Vector3(0, 0, LevelDoor.ARRIVAL_DEPTH)
	arrival.rotation_degrees.y = 180
	door.add_child(arrival)
	door.style = style
	door.width = 2.0
	door.door_id = door_id
	door.target_scene = target_scene
	door.target_spawn = target_spawn
	var half := terrain.size / 2
	door.position = [
		Vector3(along, 0, -half.y), Vector3(half.x, 0, along), Vector3(along, 0, half.y), Vector3(-half.x, 0, along)
	][side]
	door.rotation_degrees.y = [0.0, -90.0, 180.0, 90.0][side]
	terrain.add_child(door, true)
	door.owner = root
	shape.owner = root
	arrival.owner = root
	arrival.set("spawn_id", door_id)
	return door


## Starts a room (in the editor, on F6 and after a checkpoint) at a door's arrival.
static func start_at_door(root: Node3D, door_id: StringName) -> void:
	var door := root.get_node_or_null("Terrain/" + String(door_id)) as LevelDoor
	if door == null or not door.has_node("Arrival"):
		return
	var at: Vector3 = door.transform * (door.get_node("Arrival") as Node3D).position
	root.set("spawn_position", at)
	for path in ["Player", "Spawns/Entrance", "Spawns/StartCheckpoint"]:
		var node := root.get_node_or_null(path) as Node3D
		if node:
			node.position = at


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
