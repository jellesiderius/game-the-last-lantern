@tool
class_name ScenePortal
extends Area3D
## Saved reusable threshold: box width and destination are editable on each instance.
signal transition_started(actor: Node3D)
@export_file("*.tscn") var target_scene := ""
@export var target_spawn: StringName = &"Entrance"
@export var loading_title := "De reis gaat verder"
## Local doors/gates use a fade only. Opt in only for a substantially larger map change.
@export var allow_loading_screen := false
## Load resources as the player approaches, before the transition covers the scene.
@export_range(0, 30, .5, "suffix:m") var prefetch_distance := 8.0
@export var enabled := true
@export var settings: SceneTravelSettings
@export var trigger_size := Vector3(6, 3, 3):
	set(value):
		trigger_size = value.max(Vector3(.1, .1, .1))
		_update_shape()

var ignored_until_exit: Array[Node3D] = []
var _prefetched_path := ""
var _prefetch_cooldown := 0.0


func _ready() -> void:
	_update_shape()
	if not Engine.is_editor_hint():
		body_entered.connect(_entered)
		body_exited.connect(func(body): ignored_until_exit.erase(body))


func _update_shape() -> void:
	var collider := get_node_or_null("Shape") as CollisionShape3D
	if collider:
		collider.shape.size = trigger_size
		collider.position.y = trigger_size.y * .5


func exit_direction() -> Vector3:
	var direction := -global_basis.z
	direction.y = 0.0
	return direction.normalized()


func _entered(body: Node3D) -> void:
	# A destination marker may start inside a threshold. Require leaving before re-entry.
	if body is PlayerCharacter and body.state == "scene_travel":
		ignored_until_exit.append(body)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not enabled:
		return
	_prefetch_cooldown -= delta
	if prefetch_distance > 0 and _prefetched_path != target_scene and _prefetch_cooldown <= 0:
		_prefetch_cooldown = .2
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if (
			player
			and (
				global_position.distance_squared_to(player.global_position)
				<= prefetch_distance * prefetch_distance
			)
		):
			if SceneTransit.prefetch_scene(target_scene) == OK:
				_prefetched_path = target_scene
	if SceneTransit.active or Dialogue.active or Checkpoints.active or GameClock.paused:
		return
	for body in get_overlapping_bodies():
		if not body is PlayerCharacter or body in ignored_until_exit:
			continue
		if not can_travel(body):
			continue
		ignored_until_exit.append(body)
		if _try_travel(body):
			transition_started.emit(body)
		break


func _try_travel(player: PlayerCharacter) -> bool:
	return SceneTransit.request(self, player)


func can_travel(player: PlayerCharacter) -> bool:
	return player.state in ["locomotion", "bow_empty"]
