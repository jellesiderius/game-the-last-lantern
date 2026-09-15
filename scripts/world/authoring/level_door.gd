@tool
class_name LevelDoor
extends ScenePortal
## A doorway to another scene, usually set into a room wall. The terrain cuts a gap
## in its walls where a door stands on the edge. Local -Z points out through the
## door; the saved Arrival marker stands inside and faces into the room, so any
## other scene can send the player back here with Target Spawn = door_id.
enum Style { OPENING, WOODEN_DOOR, STONE_ARCH, CAVE, GATE }
## Automatisch: a light only in walled rooms; Aan and Uit force it either way.
enum LightMode { AUTO, ON, OFF }
const GATE_SCENE := "res://scenes/assets/environment/forest_gate/Visual.tscn"
const ARRIVAL_DEPTH := 1.4
@export var style: Style = Style.WOODEN_DOOR:
	set(value):
		style = value
		_changed()
@export_range(1, 6, .5, "suffix:m") var width := 2.0:
	set(value):
		width = value
		trigger_size = Vector3(width + .6, 3, 1.2)
		_changed()
@export_range(1.8, 4, .1, "suffix:m") var height := 2.3:
	set(value):
		height = value
		_changed()
@export var light: LightMode = LightMode.AUTO:
	set(value):
		light = value
		_changed()
## Daylight falls in through this doorway: use it for doors that lead outside.
## The level builder sets it when linking to a scene without room walls.
@export var outside_light := false:
	set(value):
		outside_light = value
		_changed()
## Set into the wall of a plateau instead of a room wall or the ground edge:
## a stone frame around a dark opening in the cliff.
@export var cliff_door := false:
	set(value):
		cliff_door = value
		_changed()
## Spawn id of this door's arrival marker. Doors elsewhere use it as Target Spawn.
@export var door_id: StringName = &"Door":
	set(value):
		door_id = value
		_sync_arrival()
		update_configuration_warnings()
var _queued := false


func _ready() -> void:
	_sync_arrival()
	super._ready()
	_rebuild()
	if Engine.is_editor_hint():
		set_notify_transform(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_changed()


func _changed() -> void:
	if not is_inside_tree():
		return
	if not _queued:
		_queued = true
		_rebuild.call_deferred()
	if Engine.is_editor_hint() and get_parent() is LevelTerrain:
		get_parent().request_bake()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var root := owner if owner else get_tree().edited_scene_root if Engine.is_editor_hint() and is_inside_tree() else null
	if root == null:
		return warnings
	for node in root.find_children("*", "Area3D", true, false):
		if node != self and node is LevelDoor and node.door_id == door_id:
			warnings.append(
				"Deurcode %s wordt ook gebruikt door %s: aankomsten komen dan bij de verkeerde deur uit. Geef deze deur een eigen Door Id." % [door_id, node.name]
			)
	return warnings


func arrival() -> SceneSpawnPoint:
	return get_node_or_null("Arrival") as SceneSpawnPoint


func _sync_arrival() -> void:
	var marker := arrival()
	if marker:
		marker.spawn_id = door_id


## Frame, entry floor and lights; rebuilt on load and never saved into the scene.
func _rebuild() -> void:
	_queued = false
	var previous := get_node_or_null("Frame")
	if previous:
		remove_child(previous)
		previous.queue_free()
	var frame := Node3D.new()
	frame.name = "Frame"
	add_child(frame)
	var terrain := get_parent() as LevelTerrain
	if cliff_door:
		_build_cliff_opening(frame, terrain)
		if light == LightMode.ON:
			_add_passage_hint(frame, false)
		return
	_add_entry_floor(frame, terrain)
	if _wants_light(terrain):
		if outside_light:
			_add_daylight(frame, _in_cutaway_wall(terrain))
		else:
			_add_passage_hint(frame, _in_cutaway_wall(terrain))
	if style == Style.OPENING:
		return
	if style == Style.GATE:
		_add_gate(frame)
		return
	if style == Style.CAVE:
		_add_cave_rocks(frame, terrain, height)
		return
	var stone := style == Style.STONE_ARCH
	var colour := Color("5c5a63") if stone else Color("24170d")
	if stone and terrain:
		colour = terrain.style_for(null).cliff_color
	# In a low wall facing the camera the doorway stays low too: short posts only,
	# so the frame never hides the player.
	if _in_cutaway_wall(terrain):
		if stone:
			var low := Vector3(.4, terrain.cutaway_height + .1, .5)
			for side in [-1.0, 1.0]:
				_box(frame, Vector3(side * (width / 2 + low.x / 2), low.y / 2, 0), low, colour)
			return
		# Like the Forest house: two slim dark posts, no lintel or leaf.
		var slim := Vector3(.18, height + .1, .22)
		for side in [-1.0, 1.0]:
			_box(frame, Vector3(side * (width / 2 + slim.x / 2), slim.y / 2, .1), slim, colour)
		return
	var post := Vector3(.4 if stone else .18, height, .55 if stone else .3)
	for side in [-1.0, 1.0]:
		_box(frame, Vector3(side * (width / 2 + post.x / 2), height / 2, 0), post, colour)
	var lintel_height := .45 if stone else .22
	_box(frame, Vector3(0, height + lintel_height / 2, 0), Vector3(width + post.x * 2, lintel_height, post.z), colour)


## Doorway in a plateau wall: a dark opening flush with the cliff, framed by stone
## posts and a lintel standing out from the face, with a threshold stone in front.
func _build_cliff_opening(frame: Node3D, terrain: LevelTerrain) -> void:
	var stone := terrain.style_for(null).cliff_color if terrain else Color("5c5a63")
	var dark := MeshInstance3D.new()
	dark.name = "Opening"
	var plane := QuadMesh.new()
	plane.size = Vector2(width, height)
	dark.mesh = plane
	var shade := StandardMaterial3D.new()
	shade.albedo_color = Color(.035, .03, .04)
	shade.roughness = 1.0
	dark.material_override = shade
	dark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dark.position = Vector3(0, height / 2, .03)
	frame.add_child(dark)
	if style == Style.OPENING:
		return
	if style == Style.CAVE:
		_add_cave_rocks(frame, terrain, height)
		return
	var colour := stone if style in [Style.STONE_ARCH, Style.GATE] else Color("24170d")
	var post := Vector3(.2 if style == Style.WOODEN_DOOR else .4, height, .45)
	for side in [-1.0, 1.0]:
		_box(frame, Vector3(side * (width / 2 + post.x / 2), height / 2, .12), post, colour)
	var lintel := .22 if style == Style.WOODEN_DOOR else .4
	_box(frame, Vector3(0, height + lintel / 2, .12), Vector3(width + post.x * 2, lintel, post.z), colour)
	_box(frame, Vector3(0, .04, .45), Vector3(width + post.x * 2, .08, .7), stone.darkened(.15))


## A floor piece continuing out through the doorway, so the way on stands on
## something instead of ending at the wall: wood in a house, stone elsewhere.
func _add_entry_floor(frame: Node3D, terrain: LevelTerrain) -> void:
	if terrain == null:
		return
	if not terrain.room_walls:
		# Outdoors on the edge of the ground: the path runs on through the gap and
		# fades into the background, so the passage reads as a way out.
		if _on_ground_edge(terrain):
			var settings := terrain.style_for(null)
			_box(frame, Vector3(0, -.03, -1.5 + .05), Vector3(width + .6, .06, 3.1), settings.path_color)
			_box(frame, Vector3(0, -.36, -1.5 + .05), Vector3(width + 1.0, .6, 3.1), settings.cliff_color.darkened(.3))
		return
	var settings := terrain.style_for(null)
	var colour := settings.cliff_rim_color if terrain.room_look == 1 else settings.cliff_color
	# Tucked a few centimetres under the room floor so no seam shows at the threshold.
	_box(frame, Vector3(0, -.252, -1.0 + .05), Vector3(width + .4, .5, 2.1), colour)


## Daylight from outside: a warm spot light shines in through the doorway, its
## shadow shaped by the wall, so a patch of light falls on the tiles in front of it.
func _add_daylight(frame: Node3D, cutaway: bool) -> void:
	var spot := SpotLight3D.new()
	spot.name = "Sunbeam"
	spot.light_color = Color(1, .9, .7)
	spot.light_energy = 1.8
	spot.light_specular = .2
	spot.spot_range = 7
	spot.spot_angle = 24 + width * 3
	spot.spot_attenuation = 1.2
	spot.shadow_enabled = true
	# Outside, above the doorway, aimed down and into the room (+Z).
	spot.position = Vector3(0, height + (1.2 if cutaway else .6), -1.4)
	spot.rotation_degrees = Vector3(-48, 180, 0)
	frame.add_child(spot)


## Doors to other rooms stay dim; a faint light low in the opening shows that the
## way continues without lighting the room.
func _add_passage_hint(frame: Node3D, _cutaway: bool) -> void:
	var glow := OmniLight3D.new()
	glow.name = "PassageGlow"
	glow.light_color = Color(1, .78, .55)
	glow.light_energy = 1.6
	glow.light_specular = 0
	glow.omni_range = width * .5 + 2.2
	glow.omni_attenuation = 1.6
	glow.position = Vector3(0, .6, -.35)
	frame.add_child(glow)


func _wants_light(terrain: LevelTerrain) -> bool:
	if light != LightMode.AUTO:
		return light == LightMode.ON
	return terrain != null and terrain.room_walls


## Rough rock blocks around the opening: a cave mouth in a cliff or at the edge.
func _add_cave_rocks(frame: Node3D, terrain: LevelTerrain, tall: float) -> void:
	var rock := terrain.style_for(null).cliff_color.darkened(.1) if terrain else Color("5c5a63")
	var pieces := [
		[Vector3(-width / 2 - .35, tall * .3, .15), Vector3(.8, tall * .6, .7), 8.0],
		[Vector3(-width / 2 - .25, tall * .78, .1), Vector3(.6, tall * .5, .6), -12.0],
		[Vector3(width / 2 + .35, tall * .35, .15), Vector3(.85, tall * .7, .7), -6.0],
		[Vector3(width / 2 + .2, tall * .85, .1), Vector3(.55, tall * .4, .6), 15.0],
		[Vector3(-width * .2, tall + .15, .12), Vector3(width * .7, .45, .65), 5.0],
		[Vector3(width * .25, tall + .05, .15), Vector3(width * .6, .4, .6), -7.0]
	]
	for piece in pieces:
		_box(frame, piece[0], piece[1], rock)
		(frame.get_child(frame.get_child_count() - 1) as Node3D).rotation_degrees.z = piece[2]


## A wooden forest gate standing open in an outdoor passage.
func _add_gate(frame: Node3D) -> void:
	if not ResourceLoader.exists(GATE_SCENE):
		return
	var gate := (load(GATE_SCENE) as PackedScene).instantiate() as Node3D
	gate.name = "Gate"
	gate.scale = Vector3.ONE * clampf(width / 2.4, .5, 2.5)
	frame.add_child(gate)


## True when the door stands on one of the four edges of the ground.
func _on_ground_edge(terrain: LevelTerrain) -> bool:
	var half := terrain.size / 2
	return (
		absf(absf(position.z) - half.y) <= .75 or absf(absf(position.x) - half.x) <= .75
	)


## True on the south or east edge of a walled room, where the walls are cut away.
func _in_cutaway_wall(terrain: LevelTerrain) -> bool:
	if terrain == null or not terrain.room_walls:
		return false
	var half := terrain.size / 2
	return absf(position.z - half.y) <= .75 or absf(position.x - half.x) <= .75


static func _box(parent: Node3D, centre: Vector3, size: Vector3, colour: Color) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = .9
	mesh.material_override = material
	mesh.position = centre
	parent.add_child(mesh)
