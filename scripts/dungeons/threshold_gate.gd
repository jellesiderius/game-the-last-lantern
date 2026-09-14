@tool
class_name ThresholdGate
extends ScenePortal
## Place the scene, select a DungeonDefinition, and move ReturnPoint onto safe ground.
@export var dungeon: DungeonDefinition:
	set(value):
		dungeon = value
		_sync_destination()
@export var gate_id: StringName
@export_storage var identity_scene := ""
@export_node_path("SceneSpawnPoint") var return_point := NodePath("ReturnPoint")
@export var preview_completed := false:
	set(value):
		preview_completed = value
		_refresh_visual()
var _editor_initialized := false
static var _identity_claims: Dictionary = {}


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_editor_initialized = false
		_assign_identity.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and Engine.is_editor_hint():
		_assign_identity(false)


func _validate_property(property: Dictionary) -> void:
	if (
		property.name
		in ["gate_id", "target_scene", "target_spawn", "loading_title", "allow_loading_screen"]
	):
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _ready() -> void:
	_sync_destination()
	_sync_return_point()
	super._ready()
	if Engine.is_editor_hint():
		_assign_identity.call_deferred()
	else:
		GameProgress.progress_changed.connect(_refresh_visual)
		if gate_id.is_empty():
			enabled = false
			push_warning("Sla de geplaatste Drempelpoort eerst op: de poort-ID ontbreekt.")
		for other in get_tree().get_nodes_in_group("threshold_gates"):
			if other.gate_id == gate_id:
				enabled = false
				other.enabled = false
				push_warning("Dubbele Drempelpoort-ID: " + String(gate_id))
		add_to_group("threshold_gates")
	_refresh_visual()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and (not _editor_initialized or gate_id.is_empty()):
		_assign_identity()


func _assign_identity(mark_unsaved := true) -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	var root := get_tree().edited_scene_root
	if root == null or root == self:
		_editor_initialized = true
		return
	if owner == null or not root.is_ancestor_of(self):
		return
	if owner != root and not root.is_editable_instance(owner):
		_editor_initialized = true
		return
	var claimed: Node = (
		_identity_claims[gate_id].get_ref() if _identity_claims.has(gate_id) else null
	)
	var copied := (
		not identity_scene.is_empty()
		and not root.scene_file_path.is_empty()
		and identity_scene != root.scene_file_path
		and FileAccess.file_exists(identity_scene)
	)
	var duplicate := is_instance_valid(claimed) and claimed != self and claimed.is_inside_tree()
	var changed := gate_id.is_empty() or duplicate or copied
	if changed:
		gate_id = StringName("gate." + Crypto.new().generate_random_bytes(16).hex_encode())
	_identity_claims[gate_id] = weakref(self)
	if not root.scene_file_path.is_empty() and identity_scene != root.scene_file_path:
		identity_scene = root.scene_file_path
		changed = true
	_sync_return_point()
	_editor_initialized = true
	update_configuration_warnings()
	if changed and mark_unsaved:
		EditorInterface.mark_scene_as_unsaved()


func _sync_destination() -> void:
	target_scene = dungeon.scene_path if dungeon else ""
	target_spawn = dungeon.entrance if dungeon else &"DungeonEntrance"
	loading_title = dungeon.display_name if dungeon else "Een nieuwe drempel"
	allow_loading_screen = false
	update_configuration_warnings()


func _sync_return_point() -> void:
	var point := get_node_or_null(return_point) as SceneSpawnPoint
	if point:
		point.spawn_id = gate_id


func _refresh_visual() -> void:
	var visual := get_node_or_null("Visual")
	if visual and visual.is_node_ready():
		visual.set_completed(
			preview_completed if Engine.is_editor_hint() else DungeonTravel.completed(dungeon)
		)


func _try_travel(player: PlayerCharacter) -> bool:
	var point := get_node_or_null(return_point) as SceneSpawnPoint
	return point != null and DungeonTravel.enter(self, dungeon, gate_id, point.spawn_key(), player)


func can_travel(player: PlayerCharacter) -> bool:
	return super.can_travel(player) or player.state == "roll"


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if dungeon == null or dungeon.id.is_empty() or dungeon.scene_path.is_empty():
		warnings.append("Kies een DungeonDefinition met een vaste dungeoncode en doelscene.")
	var point := get_node_or_null(return_point) as SceneSpawnPoint
	if point == null:
		warnings.append("Wijs een SceneSpawnPoint buiten de doorgang aan als terugkeerpunt.")
	elif is_inside_tree():
		var local := to_local(point.global_position)
		if absf(local.x) < trigger_size.x * .5 + .35 and absf(local.z) < trigger_size.z * .5 + .35:
			warnings.append(
				"Plaats ReturnPoint buiten de triggerzone, met ruimte voor de speler-collider."
			)
	return warnings
