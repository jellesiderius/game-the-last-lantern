extends "res://scripts/world/prototype_room.gd"
## Saved first area; the player owns the entrance action and its clock.
@export var entrance_sequence: EntranceSequence
@export var play_entrance := true
var hud_reveal := 0.0
@onready var water_material: ShaderMaterial = $Water/Pond.material_override
@onready var waterfall_material: ShaderMaterial = $Water/Waterfall.material_override


func _ready() -> void:
	super._ready()
	player.entrance_finished.connect(_entrance_finished)
	player.state_changed.connect(_player_state_changed)
	if play_entrance:
		player.begin_entrance(entrance_sequence)
		$HUD/Root/Status.modulate.a = 0.0
	else:
		player.respawn(spawn_position)
		hud_reveal = 1.0
	reset_camera()
	if "--forest-movie" in OS.get_cmdline_user_args():
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
	hud_reveal = 0.0


func _player_state_changed(next: String) -> void:
	if next in ["hurt", "dead"]:
		hud_reveal = 1.0


func restart() -> void:
	super.restart()
	hud_reveal = 1.0
