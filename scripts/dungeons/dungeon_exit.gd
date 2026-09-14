@tool
extends ScenePortal
@export var dungeon: DungeonDefinition


func _ready() -> void:
	super._ready()
	if not Engine.is_editor_hint():
		GameProgress.progress_changed.connect(_refresh_visual)
		_refresh_visual()


func _refresh_visual() -> void:
	$Visual.set_completed(DungeonTravel.completed(dungeon))


func can_travel(player: PlayerCharacter) -> bool:
	return super.can_travel(player) or player.state == "roll"


func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		var route := DungeonTravel.return_route(dungeon)
		target_scene = route.get("source", "")
		target_spawn = StringName(route.get("spawn", ""))
	super._physics_process(delta)


func _try_travel(player: PlayerCharacter) -> bool:
	return DungeonTravel.leave(self, dungeon, player)
