@tool
class_name LevelAssetThumbnails
extends RefCounted
## Real renderer thumbnails of saved assets; no dependency on editor scene screenshots.


static func generate(packed: PackedScene, host: Node, path: String) -> Texture2D:
	var model := packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Node3D
	if model == null:
		return null
	_strip_scripts(model)
	var meshes: Array[Dictionary] = []
	LevelAssetPreparation._collect_meshes(model, Transform3D.IDENTITY, meshes, true)
	if meshes.is_empty():
		model.free()
		return null
	var bounds := AABB()
	var first := true
	for item in meshes:
		var box: AABB = item.transform * item.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	host.add_child(viewport)
	viewport.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(.4, bounds.size.length() * 1.1)
	camera.far = maxf(100, bounds.size.length() * 6)
	viewport.add_child(camera)
	var target := bounds.get_center()
	camera.position = (
		target + Vector3(1, .85, 1.2).normalized() * maxf(10, bounds.size.length() * 2)
	)
	camera.look_at(target)
	camera.current = true
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("252c30")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(.8, .86, .92)
	env.ambient_light_energy = .7
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.4
	environment.environment = env
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	light.light_color = Color(1, .92, .82)
	light.light_energy = 1.3
	viewport.add_child(light)
	for i in 5:
		await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var texture := ImageTexture.create_from_image(image)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var error := ResourceSaver.save(texture, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error == OK:
		texture.take_over_path(path)
	viewport.queue_free()
	return texture if error == OK else null


static func _strip_scripts(node: Node) -> void:
	# Previewing a prefab must not register an actor or execute its gameplay _ready.
	node.set_script(null)
	for child in node.get_children():
		_strip_scripts(child)
