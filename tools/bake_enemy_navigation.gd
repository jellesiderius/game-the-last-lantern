extends SceneTree
## Optional offline cache for any saved 3D level; no scene coordinates or names.
## Godot --headless --path . --script tools/bake_enemy_navigation.gd -- res://scenes/levels/PrototypeRoom.tscn


func _initialize() -> void:
	call_deferred("bake")


func bake() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Supply a res:// level scene path.")
		quit(1)
		return
	var path := args[0]
	var packed: PackedScene = load(path)
	var level := packed.instantiate()
	# Strip scripts from the detached offline copy to avoid gameplay/autoload calls.
	strip_scripts(level)
	root.add_child(level)
	var service = load("res://scripts/ai/navigation_world.gd")
	var mesh: NavigationMesh = service.bake_settings(.3)
	var data := NavigationMeshSourceGeometryData3D.new()
	service.parse_world_geometry(mesh, data, level)
	NavigationServer3D.bake_from_source_geometry_data(mesh, data)
	mesh.set_meta("source_signature", service.geometry_signature(data))
	var output := path.get_basename() + "_navigation.tres"
	assert(mesh.get_polygon_count() > 0)
	assert(ResourceSaver.save(mesh, output) == OK)
	# Insert the cache as a normal saved region, without resaving/repacking actors.
	var text := FileAccess.get_file_as_string(path)
	if not text.contains('id="EnemyNavigationCache"'):
		var at := text.find("\n[sub_resource")
		if at < 0:
			at = text.find("\n[node")
		text = text.insert(
			at,
			'\n[ext_resource type="NavigationMesh" path="%s" id="EnemyNavigationCache"]\n' % output
		)
		text += '\n[node name="EnemyNavigationCache" type="NavigationRegion3D" parent="."]\nenabled = false\nnavigation_mesh = ExtResource("EnemyNavigationCache")\n'
		FileAccess.open(path, FileAccess.WRITE).store_string(text)
	print("NAVIGATION_CACHE_SAVED ", output, " polygons=", mesh.get_polygon_count())
	quit()


func strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		strip_scripts(child)
