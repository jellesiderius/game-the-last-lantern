extends "res://scripts/world/arena.gd"
## Saved miniature room. A fixed viewing angle follows the player at a readable distance.
@export var spawn_position := Vector3(0, 0, .3)
## Ghost-target framing: an invisible target eases toward the player and the camera
## eases toward that target. The two stages give a soft start and a soft stop without
## overshoot; at rest both land exactly on the player. Half-lives in seconds.
@export_range(0.02, 0.6, 0.01, "suffix:s") var ghost_follow_half_life := 0.15
@export_range(0.02, 0.6, 0.01, "suffix:s") var camera_follow_half_life := 0.11
var ghost_target := Vector3.ZERO
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
	if "--roll-momentum-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/roll_momentum_replay.gd").new())
	if "--lock-switch-replay" in OS.get_cmdline_user_args():
		add_child(load("res://tests/lock_switch_replay.gd").new())
	if "--roll-review" in OS.get_cmdline_user_args():
		add_child(load("res://tests/roll_review_replay.gd").new())
	if "--slash-closeup" in OS.get_cmdline_user_args():
		add_child(load("res://tests/slash_closeup_replay.gd").new())
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
	# Frame-rate independent exponential stages. GameClock keeps pause/hitstop in sync.
	var ghost_weight := 1.0 - pow(0.5, delta / ghost_follow_half_life)
	var camera_weight := 1.0 - pow(0.5, delta / camera_follow_half_life)
	ghost_target.x = lerpf(ghost_target.x, target.x, ghost_weight)
	ghost_target.z = lerpf(ghost_target.z, target.z, ghost_weight)
	camera_home.x = lerpf(camera_home.x, ghost_target.x, camera_weight)
	camera_home.z = lerpf(camera_home.z, ghost_target.z, camera_weight)
	# Lock exactly once both stages have settled, instead of creeping forever.
	var flat_target := Vector2(target.x, target.z)
	if (
		Vector2(ghost_target.x, ghost_target.z).distance_to(flat_target) < .001
		and Vector2(camera_home.x, camera_home.z).distance_to(flat_target) < .001
	):
		ghost_target.x = target.x
		ghost_target.z = target.z
		camera_home.x = target.x
		camera_home.z = target.z
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
	ghost_target = camera_home
	camera_rig.position = camera_home
	camera_rig.reset_physics_interpolation()
