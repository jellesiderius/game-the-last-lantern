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
@export var facing_weight := 2.5
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


## Next candidate clockwise on screen (direction 1) or counter-clockwise (-1) from the
## current target, as seen from the actor. Cycles around when nothing lies further that way.
func switch(direction: int) -> void:
	if not is_active():
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := _screen_bearing(target, camera)
	var best: Node3D
	var best_turn := INF
	var best_distance := INF
	for candidate in candidates():
		if candidate == target:
			continue
		var turn := fposmod((_screen_bearing(candidate, camera) - from) * direction, TAU)
		var distance := _flat(candidate.global_position - actor.global_position).length()
		if turn < best_turn - .05 or (absf(turn - best_turn) <= .05 and distance < best_distance):
			best = candidate
			best_turn = turn
			best_distance = distance
	if best:
		_set_target(best)


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


func _screen_bearing(node: Node3D, camera: Camera3D) -> float:
	var offset := _flat(node.global_position - actor.global_position)
	var right := _flat(camera.global_basis.x).normalized()
	var up := _flat(-camera.global_basis.z).normalized()
	return atan2(offset.dot(right), offset.dot(up))


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
