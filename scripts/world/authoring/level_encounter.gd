@tool
class_name LevelEncounter
extends Node
## Inspector-configured objective. EnemyBrain still owns combat and action time.
signal completed
@export var enemies: Array[NodePath] = []
@export var unlock_portals: Array[NodePath] = []
@export var dungeon: DungeonDefinition
@export var completion_flag: StringName
var finished := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if not completion_flag.is_empty() and GameProgress.world_flag(String(completion_flag)):
		_finish(false)
		return
	for path in unlock_portals:
		var portal := get_node_or_null(path) as ScenePortal
		if portal:
			portal.enabled = false
	for path in enemies:
		var actor := get_node_or_null(path)
		var health := actor.get_node_or_null("Health") as HealthComponent if actor else null
		if health:
			health.depleted.connect(_check.call_deferred)
	_check.call_deferred()


func _check() -> void:
	if finished or enemies.is_empty():
		return
	for path in enemies:
		var actor := get_node_or_null(path)
		var health := actor.get_node_or_null("Health") as HealthComponent if actor else null
		if health == null or health.current > 0:
			return
	_finish(true)


func _finish(record: bool) -> void:
	finished = true
	for path in unlock_portals:
		var portal := get_node_or_null(path) as ScenePortal
		if portal:
			portal.enabled = true
	if record:
		if not completion_flag.is_empty():
			GameProgress.set_world_flag(String(completion_flag))
		if dungeon:
			DungeonTravel.complete(dungeon)
		completed.emit()
