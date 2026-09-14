@tool
class_name Vuurlelie
extends Interactable
## Place this saved scene anywhere. The editor saves a permanent identity for each placement.
## Generated automatically on placement. Moving/renaming this node preserves existing saves.
@export var checkpoint_id: StringName
@export_storage var checkpoint_editor_scene_uid := -1
@export_storage var checkpoint_editor_scene_path := ""
@export var area: WorldArea
@export var location_name := ""
@export_tool_button("Vul gebied automatisch in", "WorldEnvironment") var find_area: Callable:
	get:
		# Resolve against the current script instance after editor hot reloads.
		return Callable(self, &"_find_area_from_inspector")
@export_node_path("Marker3D") var spawn_path := NodePath("Spawn")
@export_range(.1, 3, .05) var open_duration := 1.05
@export_range(.5, 3, .05) var rest_distance := 1.12
@export_group("Vlam en vonkjes")
@export_range(.5, 3, .05) var flame_size := 1.25
@export_range(0, 24, 1) var ember_count := 9
var lit := false
var opening := 0.0
var flame_time := 0.0
var petal_bases: Array[Quaternion] = []
var petals: Array[Node3D] = []
var editor_initialized := false
static var editor_id_claims: Dictionary = {}
@onready var core: Marker3D = $Core


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		editor_initialized = false
		_editor_setup.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE and Engine.is_editor_hint():
		_editor_setup(false)


func _validate_property(property: Dictionary) -> void:
	if property.name == "checkpoint_id":
		property.usage |= PROPERTY_USAGE_READ_ONLY


func _ready() -> void:
	if Engine.is_editor_hint():
		_editor_setup.call_deferred()
		return
	if area == null:
		_find_area()
	super._ready()
	for i in 5:
		var petal := $Visual.find_child("Petal%d" % i, true, false) as Node3D
		if petal:
			petals.append(petal)
			petal_bases.append(petal.quaternion)
	$InteractionZone/Shape.shape = $InteractionZone/Shape.shape.duplicate()
	$InteractionZone/Shape.shape.radius = interaction_radius
	if checkpoint_id.is_empty() or area == null or get_node_or_null(spawn_path) == null:
		enabled = false
		push_warning("Vuurlelie needs a permanent checkpoint ID, area and spawn marker.")
	for other in get_tree().get_nodes_in_group("vuurlelies"):
		if other.checkpoint_id == checkpoint_id:
			enabled = false
			other.enabled = false
			push_warning("Duplicate Vuurlelie checkpoint ID: " + String(checkpoint_id))
	add_to_group("vuurlelies")
	$Embers.amount = maxi(1, ember_count)
	$Embers.visible = ember_count > 0
	set_lit(GameProgress.is_lit(checkpoint_id))


func _new_checkpoint_code() -> void:
	checkpoint_id = StringName("lily." + Crypto.new().generate_random_bytes(16).hex_encode())
	update_configuration_warnings()
	notify_property_list_changed()


func _find_area_from_inspector() -> void:
	var previous_area := area
	_find_area()
	if Engine.is_editor_hint() and is_inside_tree() and area != previous_area:
		var root := get_tree().edited_scene_root
		if root != null and root.is_ancestor_of(self):
			EditorInterface.mark_scene_as_unsaved()


func _find_area() -> void:
	var available := WorldArea.discover()
	var ancestor := get_parent()
	while ancestor != null:
		for candidate in available:
			if candidate.scene_path == ancestor.scene_file_path:
				area = candidate
				update_configuration_warnings()
				notify_property_list_changed()
				return
		ancestor = ancestor.get_parent()


func _editor_setup(mark_unsaved := true) -> void:
	if not is_inside_tree() or not is_node_ready():
		return
	var root := get_tree().edited_scene_root
	if root == null:
		return
	# The source prefab stays blank. Wait for Godot to assign the owner after a drop.
	if root == self:
		editor_initialized = true
		return
	if owner == null or not root.is_ancestor_of(self):
		return
	# Nested, non-editable scenes retain the identity authored in their own source.
	if owner != root and not root.is_editable_instance(owner):
		editor_initialized = true
		return
	var scene_uid := (
		ResourceLoader.get_resource_uid(root.scene_file_path)
		if not root.scene_file_path.is_empty()
		else -1
	)
	# The UUID is the save identity. Scene provenance only distinguishes a pasted copy
	# from its original, including a newly saved level that did not have a UID yet.
	var copied_to_scene := (
		not checkpoint_editor_scene_path.is_empty()
		and not root.scene_file_path.is_empty()
		and checkpoint_editor_scene_path != root.scene_file_path
		and FileAccess.file_exists(checkpoint_editor_scene_path)
		and (
			scene_uid == -1
			or checkpoint_editor_scene_uid == -1
			or checkpoint_editor_scene_uid != scene_uid
		)
	)
	var claimed: Node = null
	if editor_id_claims.has(checkpoint_id):
		claimed = editor_id_claims[checkpoint_id].get_ref()
	var duplicate_id := is_instance_valid(claimed) and claimed != self and claimed.is_inside_tree()
	var changed := false
	if checkpoint_id.is_empty() or duplicate_id or copied_to_scene:
		_new_checkpoint_code()
		changed = true
	editor_id_claims[checkpoint_id] = weakref(self)
	if scene_uid != -1 and checkpoint_editor_scene_uid != scene_uid:
		checkpoint_editor_scene_uid = scene_uid
		changed = true
	if not root.scene_file_path.is_empty() and checkpoint_editor_scene_path != root.scene_file_path:
		checkpoint_editor_scene_path = root.scene_file_path
		changed = true
	if area == null or copied_to_scene:
		var previous_area := area
		_find_area()
		changed = changed or area != previous_area
	if not editor_initialized:
		$InteractionZone/Shape.shape = $InteractionZone/Shape.shape.duplicate()
	editor_initialized = true
	update_configuration_warnings()
	if changed and mark_unsaved:
		EditorInterface.mark_scene_as_unsaved()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if checkpoint_id.is_empty():
		(
			warnings
			. append(
				"De checkpoint-ID wordt automatisch aangemaakt wanneer je deze scene in een level plaatst."
			)
		)
	if area == null:
		warnings.append(
			"Kies een WorldArea uit settings/areas, of klik 'Vul gebied automatisch in'."
		)
	if get_node_or_null(spawn_path) == null:
		(
			warnings
			. append(
				"Kies een Marker3D als spawnpunt op veilige grond naast de lelie. De pijl kijkt langs de lokale -Z richting."
			)
		)
	if is_inside_tree() and not checkpoint_id.is_empty():
		var root := (
			get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
		)
		if root:
			for other in root.find_children("*", "Node3D", true, false):
				if other != self and other is Vuurlelie and other.checkpoint_id == checkpoint_id:
					(
						warnings
						. append(
							"Dubbele checkpointcode in een geneste scene. Maak die instantie bewerkbaar zodat de editor de kopie automatisch een eigen ID kan geven."
						)
					)
	return warnings


func can_interact(actor: Node3D) -> bool:
	return (
		super.can_interact(actor)
		and area != null
		and not checkpoint_id.is_empty()
		and not Checkpoints.active
		and not SceneTransit.active
		and not Dialogue.active
		and $InteractionZone.overlaps_body(actor)
	)


func interact(actor: Node3D) -> void:
	if actor is PlayerCharacter:
		Checkpoints.begin_rest(self, actor)


func sight_exclusions() -> Array[RID]:
	return [$Body.get_rid()]


func location_title() -> String:
	return location_name if not location_name.strip_edges().is_empty() else area.title()


func set_lit(value: bool) -> void:
	lit = value
	prompt = "Rust" if lit else "Ontsteek"
	opening = 1.0 if lit else 0.0
	_apply_opening(opening)
	$Flame.visible = lit
	$Flame.scale = Vector3.ONE * flame_size
	$Light.visible = lit
	$Spark.hide()
	$Embers.emitting = lit and ember_count > 0


func _apply_opening(amount: float) -> void:
	for i in petals.size():
		petals[i].quaternion = petal_bases[i] * Quaternion(Vector3.FORWARD, deg_to_rad(62) * amount)


func sample_ignition(time: float, lantern_origin: Vector3) -> void:
	var spark_phase := clampf((time - .68) / .32, 0, 1)
	$Spark.visible = time >= .68 and time < 1.03
	$Spark.global_position = (
		lantern_origin.lerp(core.global_position, spark_phase)
		+ Vector3.UP * sin(spark_phase * PI) * .16
	)
	opening = smoothstep(.95, .95 + open_duration, time)
	_apply_opening(opening)
	$Flame.visible = time > .98
	$Light.visible = $Flame.visible
	$Embers.emitting = $Flame.visible and ember_count > 0
	$Flame.scale = Vector3.ONE * flame_size * smoothstep(.98, 1.4, time)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		# Tool-script reloads and Inspector reverts can leave an already initialized
		# placement without its stored ID. Reconcile it again before the next save.
		if not editor_initialized or checkpoint_id.is_empty():
			_editor_setup()
		if editor_initialized:
			$InteractionZone/Shape.shape.radius = interaction_radius
		return
	if not is_node_ready():
		return
	var dt := (
		delta
		if (
			(not GameClock.paused and GameClock.stop_remaining <= 0)
			or (Checkpoints.active and Checkpoints.current_point == self)
		)
		else 0.0
	)
	# Idle light only. Petal/transfer timing is sampled from the player's action clock.
	$Embers.speed_scale = 1.0 if dt > 0 else 0.0
	flame_time += dt
	for tongue: MeshInstance3D in $Flame.get_children():
		tongue.material_override.set_shader_parameter("flame_time", flame_time)
	$Light.light_energy = .7 + .035 * sin(flame_time * 2.1) + .018 * sin(flame_time * 5.7)
