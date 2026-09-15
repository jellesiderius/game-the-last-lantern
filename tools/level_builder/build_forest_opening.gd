extends Node
## Rebuilds the first forest area with the level builder: plateaus, the sandy path,
## the pond and all 357 placed props from assets/environment/forest_layout.json,
## plus the stump introduction, enemies, Vuurlelie, Drempelpoort and the exit.
## Heights snap to the builder's half-metre steps. Run as a scene so autoloads exist:
## Godot --headless --path . res://tools/level_builder/BuildForestOpening.tscn
const FACTORY := preload("res://addons/level_builder/level_factory.gd")
const SCENE := "res://scenes/levels/BosOpening.tscn"
const LAYOUT := "res://assets/environment/forest_layout.json"
## Ground bounds x -23..23, z -84..18: the terrain is centred at z -33.
const GROUND_SIZE := Vector2(46, 102)
const GROUND_OFFSET := Vector3(0, 0, -33)
const HEIGHTS := {1.8: 2.0, 1.05: 1.0, 1.65: 1.5, 2.4: 2.5}
const PATH := [
	Vector2(-2, 7), Vector2(-1, 6), Vector2(.2, 2), Vector2(-1.5, -.4), Vector2(-2.8, -2.8),
	Vector2(-3, -5.5), Vector2(-1.5, -7.8), Vector2(1.6, -8.5), Vector2(4, -10), Vector2(4, -12),
	Vector2(4, -17), Vector2(3, -22), Vector2(0, -28), Vector2(-3.5, -34), Vector2(-4, -39),
	Vector2(-2, -45), Vector2(1, -50), Vector2(3.5, -55), Vector2(4, -62), Vector2(4, -70),
	Vector2(4, -74)
]
const POND := Vector2(-7, -3.5)
const TERRACES := [
	["PondBank", 1.8, [[-13, -12], [-3, -12], [-2.8, -8], [-5.2, -6.8], [-9.8, -6], [-13, -6.6]]],
	["CentralMeadow", 1.05, [[-1.4, -2], [1, -1], [3.6, -2.4], [3.5, -5.3], [1.5, -7.2], [-.9, -6.7], [-2, -4.8]]],
	["EastBank", 1.65, [[8, -8], [13, -8], [13, -3], [9.5, -3.2], [8.3, -5]]],
	["WestBank00", 2.4, [[-23, 10], [-8, 10], [-14, 0], [-23, 0]]],
	["EastBank00", 2.4, [[9, 10], [23, 10], [23, 0], [14, 0]]],
	["WestBank01", 2.4, [[-23, 0], [-14, 0], [-14, -10], [-23, -10]]],
	["EastBank01", 2.4, [[14, 0], [23, 0], [23, -10], [14, -10]]],
	["WestBank02", 2.4, [[-23, -10], [-14, -10], [-14, -18], [-23, -18]]],
	["EastBank02", 2.4, [[14, -10], [23, -10], [23, -18], [12, -18]]],
	["WestBank03", 2.4, [[-23, -18], [-14, -18], [-7, -28], [-23, -28]]],
	["EastBank03", 2.4, [[12, -18], [23, -18], [23, -28], [8, -28]]],
	["WestBank04", 2.4, [[-23, -28], [-7, -28], [-9, -40], [-23, -40]]],
	["EastBank04", 2.4, [[8, -28], [23, -28], [23, -40], [2, -40]]],
	["WestBank05", 2.4, [[-23, -40], [-9, -40], [-5, -50], [-23, -50]]],
	["EastBank05", 2.4, [[2, -40], [23, -40], [23, -50], [7, -50]]],
	["WestBank06", 2.4, [[-23, -50], [-5, -50], [-2, -60], [-23, -60]]],
	["EastBank06", 2.4, [[7, -50], [23, -50], [23, -60], [10, -60]]],
	["WestBank07", 2.4, [[-23, -60], [-2, -60], [-1, -70], [-23, -70]]],
	["EastBank07", 2.4, [[10, -60], [23, -60], [23, -70], [9, -70]]],
	["WestBank08", 2.4, [[-23, -70], [-1, -70], [-1, -76], [-23, -76]]],
	["EastBank08", 2.4, [[9, -70], [23, -70], [23, -76], [9, -76]]],
	["SouthernForest", 2.4, [[-23, 10], [23, 10], [23, 18], [-23, 18]]],
	["BeyondExit", 2.4, [[-23, -84], [23, -84], [23, -76], [-23, -76]]]
]


func _ready() -> void:
	var kit := load("res://settings/area_sets/forest.tres") as AreaSet
	var area := load("res://settings/areas/forest_opening.tres") as WorldArea
	var root := FACTORY.create(kit, area, GROUND_SIZE)
	root.name = "BosOpening"
	var ground := root.get_node("Terrain") as LevelTerrain
	ground.position = GROUND_OFFSET

	for terrace in TERRACES:
		var plateau := LevelTerrace.new()
		plateau.name = terrace[0]
		plateau.curve = Curve3D.new()
		plateau.curve.resource_local_to_scene = true
		for point in _counter_clockwise(terrace[2]):
			plateau.curve.add_point(Vector3(point.x, 0, point.y) - GROUND_OFFSET)
		plateau.height = HEIGHTS[terrace[1]]
		ground.add_child(plateau)

	var path := LevelPath.new()
	path.name = "Bospad"
	path.curve = Curve3D.new()
	path.curve.resource_local_to_scene = true
	for point in PATH:
		path.curve.add_point(Vector3(point.x, 0, point.y) - GROUND_OFFSET)
	path.width = 2.4
	ground.add_child(path)

	var pond := LevelWater.new()
	pond.name = "Vijver"
	pond.curve = Curve3D.new()
	pond.curve.resource_local_to_scene = true
	var ring: Array = []
	for i in 14:
		var angle := TAU * i / 14.0
		ring.append([POND.x + cos(angle) * 2.8, POND.y + sin(angle) * 2.3])
	for point in _counter_clockwise(ring):
		pond.curve.add_point(Vector3(point.x, 0, point.y) - GROUND_OFFSET)
	pond.depth = .6
	# Calm teal like the original pond, with only a thin line of foam.
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/level_water.gdshader")
	water.set_shader_parameter("shallow_color", Color(.2, .46, .44))
	water.set_shader_parameter("deep_color", Color(.08, .27, .29))
	water.set_shader_parameter("foam_strength", .45)
	water.set_shader_parameter("foam_depth", .12)
	pond.surface_material = water
	ground.add_child(pond)

	_place_props(root)
	_place_gameplay(root, area)
	FACTORY.own(root, root)
	ground.bake()
	_check(FACTORY.save(root, SCENE), SCENE)
	root.free()
	print("FOREST_OPENING_OK ", SCENE)
	get_tree().quit()


func _place_props(root: Node3D) -> void:
	var layout: Array = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var props := root.get_node("Props")
	var scenes := {}
	var index := 0
	for placement: Dictionary in layout:
		var id: String = placement.asset
		# The builder's terrain replaces the old ground and cliff modules.
		if id in ["forest_terraces", "forest_ground"]:
			continue
		if not scenes.has(id):
			var asset: LevelAsset = null
			if ResourceLoader.exists("res://settings/level_assets/%s.tres" % id):
				asset = load("res://settings/level_assets/%s.tres" % id) as LevelAsset
			scenes[id] = asset.scene if asset and asset.scene else load("res://scenes/assets/environment/%s/Visual.tscn" % id)
		var node := (scenes[id] as PackedScene).instantiate() as Node3D
		node.name = "%s%03d" % [id.trim_prefix("forest_").to_pascal_case(), index]
		index += 1
		var y := float(placement.y)
		for old in HEIGHTS:
			if absf(y - old) < .01:
				y = HEIGHTS[old]
		if id == "forest_lily":
			y = -.1
		node.position = Vector3(placement.x, y, placement.z)
		node.rotation_degrees.y = placement.yaw
		node.scale = Vector3.ONE * float(placement.scale)
		props.add_child(node)


func _place_gameplay(root: Node3D, area: WorldArea) -> void:
	root.set("entrance_sequence", load("res://settings/forest_entrance.tres"))
	root.set("play_entrance", true)
	root.set("auto_camera_bounds", false)
	root.set("spawn_position", Vector3(-3, 0, 7.4))
	root.set("camera_min", Vector2(-10, -73))
	root.set("camera_max", Vector2(12, 7))
	(root.get_node("Player") as Node3D).position = Vector3(-3, 1.565, 4.72)
	(root.get_node("Spawns/Entrance") as Node3D).position = Vector3(-3, 0, 7.4)
	var anchor := root.get_node("Spawns/StartCheckpoint") as Node3D
	anchor.position = Vector3(-3, 0, 7.4)
	anchor.set("checkpoint_id", &"start.forest_stump")
	anchor.set("area", area)

	var guards := [
		["AcornGuard", "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4, 0, -12)", &"acorn.forest.first"],
		["AcornGuard2", "Transform3D(0.99715644, 0, 0.07535918, 0, 1, 0, -0.07535918, 0, 0.99715644, 4.9946175, 0, -4.177539)", &"acorn.forest.stump"],
		["AcornGuard3", "Transform3D(0.99715644, 0, 0.07535918, 0, 1, 0, -0.07535918, 0, 0.99715644, 4.9946175, 0, 4.3201284)", &"enemy.b07a9c13143e8e07917a3692042754d9"]
	]
	for entry in guards:
		var guard := _instance(root.get_node("Enemies"), "res://scenes/actors/npcs/enemy/AcornGuard.tscn", entry[0], entry[1])
		guard.set("respawn_rule", 1)
		guard.set("persistent_id", entry[2])
		guard.set_meta("identity_scene", SCENE)

	var gameplay := root.get_node("Gameplay")
	var lily := _instance(gameplay, "res://scenes/world/checkpoints/Vuurlelie.tscn", "Vuurlelie", "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 2.3724942, 0, 4.133)")
	lily.set("checkpoint_id", &"lily.d4ae3a89cf335ee8a264de5b66b738b2")
	lily.set("checkpoint_editor_scene_path", SCENE)
	lily.set("area", area)

	var gate := _instance(gameplay, "res://scenes/world/dungeons/Drempelpoort.tscn", "Drempelpoort", "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 3.8, 0, -29.5)")
	gate.set("dungeon", load("res://settings/dungeons/root_cellar.tres"))
	gate.set("gate_id", &"gate.965d9988e83c444ea40fc2c5838d137a")
	gate.set("identity_scene", SCENE)
	gate.set("target_scene", "res://scenes/levels/RootCellar.tscn")
	gate.set("target_spawn", &"DungeonEntrance")
	gate.set("loading_title", "Wortelkelder")

	var exit := _instance(gameplay, "res://scenes/components/ScenePortal.tscn", "ForestExit", "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 4, 0, -71.8)")
	exit.set("target_scene", "uid://vbi2yday8fds")
	exit.set("target_spawn", &"SouthGate")
	exit.set("trigger_size", Vector3(6, 3, 2.6))
	var north := Marker3D.new()
	north.name = "SpawnNorthGate"
	north.set_script(load("res://scripts/world/scene_spawn_point.gd"))
	north.transform = str_to_var("Transform3D(-1, 0, -8.742278e-08, 0, 1, 0, 8.742278e-08, 0, -1, 4, 0, -70.6)")
	north.set("spawn_id", &"NorthGate")
	root.get_node("Spawns").add_child(north)

	_instance(gameplay, "res://scenes/actors/npcs/friendly/forest_keeper/Keeper.tscn", "ForestKeeper", "Transform3D(-4.371139e-08, 0, -1, 0, 1, 0, 1, 0, -4.371139e-08, 1.0019376, -0.0024261475, -20.504957)")
	_instance(gameplay, "res://scenes/assets/environment/ForestWaymarker.tscn", "Waymarker", "Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 5.5, 0, -22.5)")
	_instance(root.get_node("Props"), "res://scenes/assets/props/hand_lantern/Visual.tscn", "GateLantern", "Transform3D(1.3, 0, 0, 0, 1.3, 0, 0, 0, 1.3, 4, 1.92, -70)")

	for group in [["Butterflies", Vector3.ZERO], ["Butterflies2", Vector3(3.1347141, 0, -11.073883)]]:
		var flock := Node3D.new()
		flock.name = group[0]
		flock.position = group[1]
		root.get_node("Props").add_child(flock)
		for flyer in [[Vector3(-1.9, 1, 5.3), 0.0], [Vector3(-.8, 1.25, 4.7), 1.63], [Vector3(-1, .85, 2.8), 3.26]]:
			var butterfly := (load("res://scenes/assets/environment/forest_butterfly/Visual.tscn") as PackedScene).instantiate() as Node3D
			butterfly.name = "Butterfly%d" % flock.get_child_count()
			butterfly.position = flyer[0]
			butterfly.set("phase", flyer[1])
			butterfly.set("flight_radius", 1.25)
			flock.add_child(butterfly)

	# Light and atmosphere of the original opening.
	var sun := root.get_node("Sun") as DirectionalLight3D
	sun.transform = str_to_var("Transform3D(0.8480481, 0.43408445, -0.3039492, 0, 0.57357645, 0.81915206, 0.52991927, -0.69468033, 0.48642042, 0, 0, 0)")
	sun.light_color = Color(1, .88, .68)
	sun.light_energy = 1.05
	sun.shadow_bias = .03
	sun.shadow_opacity = .85
	sun.shadow_blur = 3.0
	sun.directional_shadow_max_distance = 70.0
	var fill := DirectionalLight3D.new()
	fill.name = "Fill"
	fill.transform = str_to_var("Transform3D(-0.81915206, -0.38379756, 0.42625037, 0, 0.7431448, 0.6691306, -0.57357645, 0.5481197, -0.6087486, 0, 0, 0)")
	fill.light_color = Color(.65, .81, 1)
	fill.light_energy = .18
	root.add_child(fill)
	var environment := (root.get_node("WorldEnvironment") as WorldEnvironment).environment
	environment.background_color = Color(.11, .19, .18)
	environment.ambient_light_color = Color(.56, .69, .63)
	environment.ambient_light_energy = .55
	environment.tonemap_exposure = 1.3
	environment.ssil_intensity = .45
	environment.fog_enabled = true
	environment.fog_light_color = Color(.22, .32, .29)
	environment.fog_density = .0018


func _instance(parent: Node, path: String, title: String, transform_text: String) -> Node3D:
	var node := (load(path) as PackedScene).instantiate() as Node3D
	node.name = title
	node.transform = str_to_var(transform_text)
	parent.add_child(node)
	return node


## Builder outlines run counter-clockwise in (x, z): positive shoelace area.
static func _counter_clockwise(points: Array) -> Array[Vector2]:
	var result: Array[Vector2] = []
	var area := 0.0
	for i in points.size():
		var a: Array = points[i]
		var b: Array = points[(i + 1) % points.size()]
		area += a[0] * b[1] - b[0] * a[1]
		result.append(Vector2(a[0], a[1]))
	if area < 0:
		result.reverse()
	return result


func _check(error: Error, what: String) -> void:
	if error != OK:
		push_error("FOREST_OPENING_FAILED %s: %s" % [what, error_string(error)])
		get_tree().quit(1)
