class_name TargetLock
extends Node
## Souls-like target lock for the parent actor. Selection only: the controller decides how
## facing, aim and camera framing use `target`. Eligible nodes join GROUP and expose is_lockable().
signal target_changed(target: Node3D)
const GROUP := &"lock_targets"
@export_range(2, 20, .5, "suffix:m") var acquire_range := 9.0
@export_range(2, 25, .5, "suffix:m") var break_range := 12.0
## Seconds without line of sight before the lock releases.
@export_range(0, 3, .05, "suffix:s") var sight_grace := .8
## Metres of extra distance one radian away from the facing direction is worth when acquiring.
## Small, so the nearest enemy wins unless another is almost as close and clearly in front.
@export var facing_weight := 0.8
## Switching only considers targets within this angle of the current lock line (no targets
## behind the player), and never wraps around to the opposite side.
@export_range(30, 180, 5, "suffix:°") var switch_max_angle := 150.0
## Metres of extra distance one radian of turn is worth when switching.
@export var switch_turn_weight := 2.0
var target: Node3D
var hidden_time := 0.0
var last_target_position := Vector3.ZERO
@onready var actor: Node3D = get_parent()


func is_active() -> bool:
	return is_instance_valid(target)


func toggle(facing: Vector3) -> void:
	if is_active():
		release()
	else:
		_set_target(best_target(facing))


func release() -> void:
	_set_target(null)


## Validates the lock once per physics tick. A defeated target hands over to the nearest
## candidate; distance or lasting loss of sight releases.
func update(delta: float) -> void:
	if target == null:
		return
	if not is_instance_valid(target) or not is_lockable(target):
		_set_target(_nearest_to(last_target_position))
		return
	last_target_position = target.global_position
	if flat_offset().length() > break_range:
		release()
		return
	hidden_time = 0.0 if has_line_of_sight(target) else hidden_time + delta
	if hidden_time > sight_grace:
		release()


## Nearest logical candidate to the right (direction 1) or left (-1) of the current lock on
## screen. Targets behind the player are ignored; keeps the lock when nothing lies that way.
func switch(direction: int) -> void:
	var best := switch_candidate(direction)
	if best:
		_set_target(best)


func switch_candidate(direction: int) -> Node3D:
	if not is_active():
		return null
	var line := flat_offset()
	var camera := get_viewport().get_camera_3d()
	if line.length_squared() < .0001 or camera == null:
		return null
	# Left/right is what the player sees: the camera's horizontal axis on the ground plane.
	var screen_right := _flat(camera.global_basis.x).normalized()
	var best: Node3D
	var best_score := INF
	for candidate in candidates():
		if candidate == target:
			continue
		var offset := _flat(candidate.global_position - actor.global_position)
		if offset.length_squared() < .0001:
			continue
		var lateral := (offset - line).dot(screen_right)
		if lateral * direction < .15:
			continue
		var turn := absf(line.signed_angle_to(offset, Vector3.UP))
		if turn > deg_to_rad(switch_max_angle):
			continue
		var score := offset.length() + turn * switch_turn_weight
		if score < best_score:
			best = candidate
			best_score = score
	return best


func candidates() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node3D in get_tree().get_nodes_in_group(GROUP):
		if (
			node != actor
			and is_lockable(node)
			and _flat(node.global_position - actor.global_position).length() <= acquire_range
			and has_line_of_sight(node)
		):
			result.append(node)
	return result


## Closest candidate, preferring those in front of `facing`.
func best_target(facing: Vector3) -> Node3D:
	var best: Node3D
	var best_score := INF
	facing = _flat(facing)
	for candidate in candidates():
		var offset := _flat(candidate.global_position - actor.global_position)
		var angle := 0.0
		if facing.length_squared() > .001 and offset.length_squared() > .001:
			angle = absf(facing.signed_angle_to(offset, Vector3.UP))
		var score := offset.length() + angle * facing_weight
		if score < best_score:
			best = candidate
			best_score = score
	return best


## Group members opt in with is_lockable(); anything else is never a target.
static func is_lockable(node: Node) -> bool:
	return node.has_method(&"is_lockable") and node.call(&"is_lockable")


func has_line_of_sight(node: Node3D) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(
		actor.global_position + Vector3.UP * .4,
		node.global_position + Vector3.UP * .4,
		CombatLayers.WORLD
	)
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


## Horizontal actor-to-target offset, or zero without a lock.
func flat_offset() -> Vector3:
	return _flat(target.global_position - actor.global_position) if is_active() else Vector3.ZERO


func flat_direction() -> Vector3:
	var offset := flat_offset()
	return offset.normalized() if offset.length_squared() > .0001 else Vector3.ZERO


func _nearest_to(point: Vector3) -> Node3D:
	var best: Node3D
	for candidate in candidates():
		if (
			best == null
			or candidate.global_position.distance_to(point) < best.global_position.distance_to(point)
		):
			best = candidate
	return best


func _set_target(next: Node3D) -> void:
	hidden_time = 0.0
	if next:
		last_target_position = next.global_position
	if next == target:
		return
	target = next
	target_changed.emit(target)


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
