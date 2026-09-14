extends "res://scripts/world/prototype_room.gd"
## Saved first area; the player owns the entrance action and its clock.
@export var entrance_sequence: EntranceSequence
@export var play_entrance := true
signal exit_reached(actor: Node3D)
var reached_exit := false
var hud_reveal := 0.0
@onready var water_material: ShaderMaterial = $Water/Pond.material_override
@onready var waterfall_material: ShaderMaterial = $Water/Waterfall.material_override


func _ready() -> void:
	super._ready()
	player.entrance_finished.connect(_entrance_finished)
	player.state_changed.connect(_player_state_changed)
	if play_entrance and (not SceneTransit.active or Checkpoints.should_play_opening()):
		player.begin_entrance(entrance_sequence)
		$HUD/Root/Status.modulate.a = 0.0
	else:
		player.respawn(spawn_position)
		hud_reveal = 1.0
	reset_camera()
	$ForestExit.body_entered.connect(_exit_entered)
	if SceneTransit.active:
		return
	if "--transition-replay" in OS.get_cmdline_user_args():
		get_tree().root.add_child.call_deferred(
			load("res://tests/scene_transition_replay.gd").new()
		)
	elif "--dialogue-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/dialogue_replay.gd").new())
	elif "--forest-movie" in OS.get_cmdline_user_args():
		add_child(load("res://tests/forest_preview.gd").new())
	elif "--forest-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/forest_replay.gd").new())


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	water_material.set_shader_parameter("game_time", GameClock.elapsed)
	waterfall_material.set_shader_parameter("game_time", GameClock.elapsed)
	if player.state != "entrance":
		hud_reveal = minf(1.0, hud_reveal + GameClock.dt / .3)
	$HUD/Root/Status.modulate.a = smoothstep(0.0, 1.0, hud_reveal)


func _entrance_finished() -> void:
	GameProgress.finish_opening()
	hud_reveal = 0.0


func _player_state_changed(next: String) -> void:
	if next in ["hurt", "dead"]:
		hud_reveal = 1.0


func restart() -> void:
	Dialogue.close(false)
	reached_exit = false
	super.restart()
	hud_reveal = 1.0


func _exit_entered(body: Node3D) -> void:
	if body != player or reached_exit or player.state == "dead":
		return
	reached_exit = true
	exit_reached.emit(player)
