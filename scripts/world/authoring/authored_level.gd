extends "res://scripts/world/prototype_room.gd"
## Generic saved level; its kit never determines gameplay or save identity.
@export var area: WorldArea
@export var area_set: AreaSet
@export var auto_camera_bounds := true
@export_group("Introductie")
## Optional opening action (like the panda standing up from the stump). It plays on a
## new game or when Checkpoints asks for the opening; otherwise the player respawns.
@export var entrance_sequence: EntranceSequence
@export var play_entrance := false
var hud_reveal := 1.0


func _ready() -> void:
	if auto_camera_bounds and has_node("Terrain"):
		var ground := get_node("Terrain") as LevelTerrain
		var half := (ground.size / 2 - Vector2(5, 5)).max(Vector2.ONE)
		camera_min = Vector2(ground.position.x, ground.position.z) - half
		camera_max = Vector2(ground.position.x, ground.position.z) + half
	super._ready()
	if (
		entrance_sequence
		and play_entrance
		and (not SceneTransit.active or Checkpoints.should_play_opening())
	):
		player.entrance_finished.connect(_entrance_finished)
		player.begin_entrance(entrance_sequence)
		hud_reveal = 0.0
		_status_alpha()
	elif not SceneTransit.active:
		player.respawn(spawn_position)
	reset_camera()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if hud_reveal < 1.0 and player.state != "entrance":
		hud_reveal = minf(1.0, hud_reveal + GameClock.dt / .3)
		_status_alpha()


func _entrance_finished() -> void:
	GameProgress.finish_opening()


func _status_alpha() -> void:
	var status := get_node_or_null("HUD/Root/Status") as CanvasItem
	if status:
		status.modulate.a = smoothstep(0.0, 1.0, hud_reveal)
