extends "res://scripts/world/arena.gd"
## Saved miniature room. A fixed viewing angle follows the player at a readable distance.
@export var spawn_position := Vector3(0, 0, .3)
## Seconds to remove half of the remaining horizontal framing error.
## Larger values let the player move further within the frame before the camera catches up.
@export_range(0.02, 0.4, 0.01, "suffix:s") var camera_follow_half_life := 0.12
@export_range(0.02, 0.4, 0.01, "suffix:s") var camera_height_half_life := 0.08
@export var camera_target_height := .65
@export var camera_min := Vector2(-12.0, -12.0)
@export var camera_max := Vector2(12.0, 12.0)


func _ready() -> void:
	super._ready()
	reset_camera()
	if "--acorn-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/acorn_replay.gd").new())
	if "--enemy-movement-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/enemy_movement_replay.gd").new())
	if "--enemy-surface-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/enemy_surface_replay.gd").new())
	if "--fall-dust-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/fall_dust_replay.gd").new())
	if "--lock-on-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/lock_on_replay.gd").new())
	if "--room-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/room_replay.gd").new())
	if "--energy-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/energy_replay.gd").new())
	if "--swing-style-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/swing_style_replay.gd").new())


func _physics_process(_delta: float) -> void:
	var delta := GameClock.dt
	if delta <= 0.0:
		return
	var offset := player.camera_look_offset()
	var target := Vector3(
		clampf(player.position.x + offset.x, camera_min.x, camera_max.x),
		player.position.y + camera_target_height,
		clampf(player.position.z + offset.z, camera_min.y, camera_max.y)
	)
	# Exponential damping responds immediately, preserves a small following delay and
	# settles without overshoot. Sampling GameClock keeps pause/hitstop synchronized.
	var weight := 1.0 - pow(0.5, delta / camera_follow_half_life)
	camera_home.x = lerpf(camera_home.x, target.x, weight)
	camera_home.z = lerpf(camera_home.z, target.z, weight)
	camera_home.y = lerpf(camera_home.y, target.y, 1.0 - pow(0.5, delta / camera_height_half_life))
	_apply_impact_camera(delta)
	_draw_debug()


func restart() -> void:
	super.restart()
	player.respawn(spawn_position)
	reset_camera()


## Call after a teleport or respawn so the old framing does not sweep across the level.
func reset_camera() -> void:
	camera_home = Vector3(
		clampf(player.position.x, camera_min.x, camera_max.x),
		player.position.y + camera_target_height,
		clampf(player.position.z, camera_min.y, camera_max.y)
	)
	camera_rig.position = camera_home
	camera_rig.reset_physics_interpolation()
