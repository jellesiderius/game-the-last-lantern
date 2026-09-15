extends Node
## Explicit offline starter-kit authoring. Existing levels/resources are never overwritten.
const PREP = preload("res://addons/level_builder/asset_preparation.gd")
const FACTORY = preload("res://addons/level_builder/level_factory.gd")
var library: Dictionary = {}


func _ready() -> void:
	call_deferred("run")


func run() -> void:
	if "--refresh-demo-terrain" in OS.get_cmdline_user_args():
		for name: String in ["BuilderForest", "BuilderCave", "BuilderCity"]:
			var path := "res://scenes/levels/" + name + ".tscn"
			var level: Node = load(path).instantiate()
			var kit_id := name.trim_prefix("Builder").to_lower()
			var kit := load("res://settings/area_sets/" + kit_id + ".tres") as AreaSet
			var area := load("res://settings/areas/" + name.to_snake_case() + ".tres") as WorldArea
			level.set("area_set", kit)
			level.set("area", area)
			level.get_node("Terrain").area_set = kit
			level.get_node("Gameplay").get_child(0).area = area
			level.get_node("Spawns/StartCheckpoint").set("area", area)
			_add_demo_ramp(level)
			assert(FACTORY.save(level, path) == OK)
			level.free()
		get_tree().quit()
		return
	DirAccess.make_dir_recursive_absolute("res://settings/area_sets")
	DirAccess.make_dir_recursive_absolute("res://settings/level_assets")
	var forest := _kit("forest", "Bos", Color("52664b"), Color("bca17a"), Color("686b69"))
	var cave := _kit("cave", "Grot · startset", Color("4b5156"), Color("757671"), Color("42474c"))
	cave.sun_energy = .4
	cave.sun_color = Color("adc9df")
	cave.ambient_color = Color("9ba9b8")
	cave.background_color = Color("161d26")
	cave.description = "Technische startset met hergebruikte rotsassets; voeg later de eigen grotmodellen toe."
	var city := _kit("city", "Stad · startset", Color("79766c"), Color("b1a797"), Color("68655d"))
	city.description = "Technische startset met de bestaande dorpsassets; uitbreidbaar met eigen stadsmodellen."
	var shared := _kit(
		"shared", "Gedeelde gameplay", Color("52664b"), Color("bca17a"), Color("686b69")
	)
	shared.catalog_only = true
	for id in ["forest_pine", "forest_pine_b", "forest_pine_c", "forest_oak"]:
		forest.assets.append(
			_asset(
				id,
				id.replace("forest_", "").capitalize(),
				"Bomen",
				PREP.CollisionMode.TRUNK,
				true,
				2.3
			)
		)
	for id in [
		"forest_fern",
		"forest_shrub",
		"forest_flowers_blue",
		"forest_flowers_cream",
		"forest_mushrooms",
		"forest_reeds"
	]:
		forest.assets.append(
			_asset(
				id,
				id.replace("forest_", "").capitalize(),
				"Begroeiing",
				PREP.CollisionMode.NONE,
				true,
				.7
			)
		)
	for id in ["forest_rocks", "forest_stump", "forest_hollow_log", "forest_fence", "forest_gate"]:
		forest.assets.append(
			_asset(
				id, id.replace("forest_", "").capitalize(), "Props", PREP.CollisionMode.AUTO, false
			)
		)
	for id in ["rock_cluster", "forest_rocks", "forest_cliff"]:
		cave.assets.append(
			_asset(
				id, id.replace("forest_", "").capitalize(), "Rotsen", PREP.CollisionMode.AUTO, false
			)
		)
	for id in ["cottage", "smithy", "barrel", "timber_fence", "timber_bridge", "stone_stairs"]:
		city.assets.append(
			_asset(id, id.capitalize(), "Gebouwen en props", PREP.CollisionMode.AUTO, false)
		)
	for entry in [
		[
			"acorn_guard",
			"Eikelwacht",
			"Enemies",
			"res://scenes/actors/npcs/enemy/PlacedAcornGuard.tscn"
		],
		["vuurlelie", "Vuurlelie", "Gameplay", "res://scenes/world/checkpoints/Vuurlelie.tscn"],
		["portal", "Doorgang", "Gameplay", "res://scenes/components/ScenePortal.tscn"],
		["threshold", "Drempelpoort", "Gameplay", "res://scenes/world/dungeons/Drempelpoort.tscn"],
		[
			"dungeon_exit",
			"Dungeonuitgang",
			"Gameplay",
			"res://scenes/world/dungeons/DungeonExit.tscn"
		],
		[
			"keeper",
			"Bosbewoner",
			"Gameplay",
			"res://scenes/actors/npcs/friendly/forest_keeper/Keeper.tscn"
		],
		[
			"waymarker",
			"Wegwijzer",
			"Gameplay",
			"res://scenes/assets/environment/ForestWaymarker.tscn"
		]
	]:
		var asset := LevelAsset.new()
		asset.id = entry[0]
		asset.display_name = entry[1]
		asset.category = entry[2]
		asset.scene = load(entry[3])
		asset = _save_new(asset, "res://settings/level_assets/" + entry[0] + ".tres") as LevelAsset
		shared.assets.append(asset)
	for kit in [forest, cave, city, shared]:
		_save_new(kit, "res://settings/area_sets/" + String(kit.id) + ".tres")
	forest = load("res://settings/area_sets/forest.tres")
	cave = load("res://settings/area_sets/cave.tres")
	city = load("res://settings/area_sets/city.tres")
	_demo(forest, "BuilderForest", "Bouwvoorbeeld bos", "BuilderCave")
	_demo(cave, "BuilderCave", "Bouwvoorbeeld grot", "BuilderForest")
	_demo(city, "BuilderCity", "Bouwvoorbeeld stad", "BuilderForest")
	print("LEVEL_BUILDER_BOOTSTRAP_OK")
	get_tree().quit()


func _kit(id: String, label: String, ground: Color, path: Color, cliff: Color) -> AreaSet:
	var kit := AreaSet.new()
	kit.id = StringName(id)
	kit.display_name = label
	var style_path := "res://settings/surface_styles/" + id + ".tres"
	var style := load(style_path) as SurfaceStyle if FileAccess.file_exists(style_path) else null
	if style == null:
		style = SurfaceStyle.new()
		style.display_name = label
		style.ground_color = ground
		style.path_color = path
		style.cliff_color = cliff
		style.cliff_rim_color = cliff.lightened(.25)
		_save_new(style, style_path)
		style = load(style_path)
	kit.default_surface = style
	return kit


func _asset(
	id: String, label: String, category: String, policy: int, scatter: bool, spacing := 1.0
) -> LevelAsset:
	if library.has(id):
		return library[id]
	var resource_path := "res://settings/level_assets/" + id + ".tres"
	if FileAccess.file_exists(resource_path):
		library[id] = load(resource_path)
		return library[id]
	var scene_path := "res://scenes/assets/environment/" + id + "/Asset.tscn"
	if not FileAccess.file_exists(scene_path):
		var source := load("res://scenes/assets/environment/" + id + "/Visual.tscn") as PackedScene
		assert(PREP.prepare(source, scene_path, policy) == OK, id)
	var asset := LevelAsset.new()
	asset.id = StringName(id)
	asset.display_name = label
	asset.category = category
	asset.scene = load(scene_path)
	asset.scatter_allowed = scatter
	asset.spacing = spacing
	asset.scale_range = Vector2(.9, 1.1) if scatter else Vector2.ONE
	asset.random_yaw = scatter
	_save_new(asset, "res://settings/level_assets/" + id + ".tres")
	library[id] = asset
	return asset


func _save_new(resource: Resource, path: String) -> Resource:
	if not FileAccess.file_exists(path):
		assert(ResourceSaver.save(resource, path, ResourceSaver.FLAG_CHANGE_PATH) == OK, path)
		resource.take_over_path(path)
	else:
		return load(path)
	return resource


func _demo(kit: AreaSet, name: String, label: String, target: String) -> void:
	var path := "res://scenes/levels/" + name + ".tscn"
	if FileAccess.file_exists(path):
		return
	var area := WorldArea.new()
	area.code = StringName(name.to_snake_case())
	area.display_name = label
	area.scene_path = path
	_save_new(area, "res://settings/areas/" + name.to_snake_case() + ".tres")
	var root := FACTORY.create(kit, area)
	root.name = name
	root.scene_file_path = path
	var terrain := root.get_node("Terrain") as LevelTerrain
	var route := LevelPath.new()
	route.name = "Hoofdpad"
	route.curve = Curve3D.new()
	route.curve.resource_local_to_scene = true
	route.curve.bake_interval = .3
	for point in [
		Vector3(0, 0, 9),
		Vector3(-1, 0, 3),
		Vector3(1, 0, -2),
		Vector3(4, 0, -6),
		Vector3(4, 0, -10)
	]:
		route.curve.add_point(point, Vector3(0, 0, 1), Vector3(0, 0, -1))
	terrain.add_child(route)
	var branch := LevelPath.new()
	branch.name = "Zijpad"
	branch.width = 1.8
	branch.curve = Curve3D.new()
	branch.curve.add_point(Vector3(-1, 0, 3))
	branch.curve.add_point(Vector3(-5, 0, 0))
	terrain.add_child(branch)
	var terrace := LevelTerrace.new()
	terrace.name = "Rotsbank"
	terrace.height = 1.5
	terrace.curve = Curve3D.new()
	for point in [
		Vector3(-11, 0, -11),
		Vector3(-4, 0, -11),
		Vector3(-4, 0, -5),
		Vector3(-8, 0, -4),
		Vector3(-11, 0, -6)
	]:
		terrace.curve.add_point(point)
	terrain.add_child(terrace)
	assert(terrain.bake(), terrain.last_error)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71831
	if kit.id == &"forest":
		for at in [
			Vector3(-8, 0, 7),
			Vector3(-8, 0, 3),
			Vector3(7, 0, 6),
			Vector3(9, 0, 1),
			Vector3(9, 0, -6),
			Vector3(-8, 1.5, -8),
			Vector3(-5, 1.5, -9)
		]:
			_place(root, library["forest_pine"].scene, "Props", at, rng.randf() * TAU)
		for at in [
			Vector3(-5, 0, 4),
			Vector3(-4, 0, 6),
			Vector3(4, 0, 3),
			Vector3(6, 0, -2),
			Vector3(-3, 0, -1),
			Vector3(7, 0, 7)
		]:
			_place(root, library["forest_fern"].scene, "Props", at)
	elif kit.id == &"cave":
		for at in [Vector3(-7, 0, 6), Vector3(7, 0, 5), Vector3(8, 0, -5), Vector3(-8, 1.5, -8)]:
			_place(root, library["rock_cluster"].scene, "Props", at)
	else:
		_place(root, library["cottage"].scene, "Props", Vector3(7, 0, 1))
		_place(root, library["barrel"].scene, "Props", Vector3(5, 0, 4))
		_place(root, library["timber_fence"].scene, "Props", Vector3(-6, 0, 5))
	var enemy_scene := load("res://scenes/actors/npcs/enemy/PlacedAcornGuard.tscn") as PackedScene
	for at in [Vector3(1, 0, -3), Vector3(6, 0, -4)]:
		var enemy := _place(root, enemy_scene, "Enemies", at)
		enemy.set("respawn_rule", 1)
		enemy.set(
			"persistent_id",
			StringName(
				name.to_snake_case() + ".guard." + str(root.get_node("Enemies").get_child_count())
			)
		)
		enemy.set_meta("identity_scene", path)
	var lily := _place(
		root, load("res://scenes/world/checkpoints/Vuurlelie.tscn"), "Gameplay", Vector3(-5, 0, 0)
	)
	lily.set("checkpoint_id", StringName("lily." + name.to_snake_case()))
	lily.set("area", area)
	lily.set("checkpoint_editor_scene_path", path)
	var portal := _place(
		root, load("res://scenes/components/ScenePortal.tscn"), "Gameplay", Vector3(4, 0, -9)
	)
	portal.name = "NaarVolgendGebied"
	portal.set("target_scene", "res://scenes/levels/" + target + ".tscn")
	portal.set("target_spawn", &"Entrance")
	portal.set("settings", load("res://settings/transitions/door.tres"))
	portal.set("trigger_size", Vector3(3, 3, 1.5))
	_place(root, library["forest_gate"].scene, "Props", Vector3(4, 0, -9))
	var patrol := EnemyPatrol.new()
	patrol.name = "Wachtroute"
	patrol.curve = Curve3D.new()
	patrol.curve.add_point(Vector3(6, 0, -4))
	patrol.curve.add_point(Vector3(7, 0, -1))
	root.get_node("Routes").add_child(patrol)
	patrol.enemy = patrol.get_path_to(root.get_node("Enemies").get_child(1))
	_add_demo_ramp(root)
	FACTORY.own(root, root)
	assert(FACTORY.save(root, path) == OK)
	root.free()


func _place(root: Node, packed: PackedScene, parent: String, at: Vector3, yaw := 0.0) -> Node3D:
	var node := packed.instantiate() as Node3D
	root.get_node(parent).add_child(node, true)
	node.position = at
	node.rotation.y = yaw
	node.owner = root
	return node


func _add_demo_ramp(root: Node) -> void:
	var ground := root.get_node("Terrain") as LevelTerrain
	if not ground.has_node("Terrashelling"):
		var ramp := LevelRamp.new()
		ramp.name = "Terrashelling"
		ramp.curve = Curve3D.new()
		ramp.curve.resource_local_to_scene = true
		ramp.curve.add_point(Vector3(1, 0, -8))
		ramp.curve.add_point(Vector3(-4, 0, -8))
		ground.add_child(ramp)
		ramp.owner = root
		var path := LevelPath.new()
		path.name = "Terraspad"
		path.width = 1.8
		path.curve = Curve3D.new()
		path.curve.resource_local_to_scene = true
		for point in [Vector3(1, 0, -5), Vector3(1, 0, -8), Vector3(-7, 0, -8)]:
			path.curve.add_point(point)
		ground.add_child(path)
		path.owner = root
	assert(ground.bake(), ground.last_error)
