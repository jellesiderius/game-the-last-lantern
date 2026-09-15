@tool
class_name LevelDoor
extends ScenePortal
## A doorway to another scene, usually set into a room wall. The terrain cuts a gap
## in its walls where a door stands on the edge. Local -Z points out through the
## door; the saved Arrival marker stands inside and faces into the room, so any
## other scene can send the player back here with Target Spawn = door_id.
enum Style { OPENING, WOODEN_DOOR, STONE_ARCH }
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
## Daylight falls in through this doorway: use it for doors that lead outside.
## The level builder sets it when linking to a scene without room walls.
@export var outside_light := false:
	set(value):
		outside_light = value
		_changed()
## Spawn id of this door's arrival marker. Doors elsewhere use it as Target Spawn.
@export var door_id: StringName = &"Door":
	set(value):
		door_id = value
		_sync_arrival()
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
	_add_entry_floor(frame, terrain)
	if outside_light:
		_add_daylight(frame, _in_cutaway_wall(terrain))
	else:
		_add_passage_hint(frame, _in_cutaway_wall(terrain))
	if style == Style.OPENING:
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


## A floor piece continuing out through the doorway, so the way on stands on
## something instead of ending at the wall: wood in a house, stone elsewhere.
func _add_entry_floor(frame: Node3D, terrain: LevelTerrain) -> void:
	if terrain == null or not terrain.room_walls:
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
