class_name GroundFeedback
extends Node
## Reusable distance-based foot dust for any CharacterBody3D. The controller samples it.
@export var puff_scene: PackedScene = preload("res://scenes/effects/dust/DustPuff.tscn")
@export_range(0.15, 1.5, 0.05) var step_distance := 0.58
@export var minimum_speed := 0.6
@export var enabled := true
var previous_position := Vector3.ZERO
var distance_since_step := 0.0
var foot_side := 1.0
var initialized := false
var steps_emitted := 0
var landings_emitted := 0
var live_puffs: Array[Node3D] = []
@onready var body: CharacterBody3D = get_parent()


func _ready() -> void:
	if body.has_signal("landed"):
		body.connect("landed", _on_landed)


func sample_motion(delta: float, walking: bool) -> void:
	if delta <= 0.0:
		return
	live_puffs = live_puffs.filter(func(puff): return is_instance_valid(puff))
	var travel := body.global_position - previous_position
	previous_position = body.global_position
	if not initialized:
		initialized = true
		return
	var flat := Vector3(travel.x, 0.0, travel.z)
	if (
		not enabled
		or not walking
		or not body.is_on_floor()
		or travel.length() > 0.5
		or flat.length() / delta < minimum_speed
	):
		distance_since_step = 0.0
		return
	distance_since_step += flat.length()
	if distance_since_step >= step_distance:
		distance_since_step = fmod(distance_since_step, step_distance)
		var forward := flat.normalized()
		var side := forward.cross(Vector3.UP)
		_emit(body.global_position - forward * 0.16 + side * foot_side * 0.1, 1.0)
		foot_side = -foot_side
		steps_emitted += 1


func _on_landed(impact_speed: float) -> void:
	distance_since_step = 0.0
	if not enabled or impact_speed < 2.0:
		return
	_emit(body.global_position + Vector3(-0.16, 0.0, 0.0), 1.25)
	_emit(body.global_position + Vector3(0.16, 0.0, 0.0), 1.25)
	landings_emitted += 1


func _emit(at: Vector3, size_multiplier: float) -> void:
	if live_puffs.size() >= 12:
		return
	var ray := PhysicsRayQueryParameters3D.create(
		at + Vector3.UP * 0.3, at - Vector3.UP * 0.45, CombatLayers.WORLD
	)
	var hit := body.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return
	var puff := puff_scene.instantiate() as Node3D
	get_tree().current_scene.add_child(puff)
	puff.global_position = hit.position + hit.normal * 0.025
	puff.scale = Vector3.ONE * size_multiplier
	live_puffs.append(puff)


func clear() -> void:
	for puff in live_puffs:
		if is_instance_valid(puff):
			puff.queue_free()
	live_puffs.clear()
	initialized = false
	distance_since_step = 0.0
