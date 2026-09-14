extends Node3D
var spark_index := 0
var shake := 0.0
var camera_home := Vector3(0, 0.65, 0)
var debug_enabled := false
var debug_mesh := ImmediateMesh.new()
@onready var player: PlayerCharacter = $Player
@onready var camera_rig: Node3D = $CameraRig


func _ready() -> void:
	add_to_group("arena")
	# Each pooled impact keeps its own material; simultaneous weapons cannot recolor each other.
	for effect: GPUParticles3D in $ImpactPool.get_children():
		effect.draw_pass_1 = effect.draw_pass_1.duplicate()
		effect.draw_pass_1.material = effect.draw_pass_1.material.duplicate()
	$DebugVolumes.mesh = debug_mesh
	for arg in OS.get_cmdline_user_args():
		if arg == "--replay":
			var replay = load("res://tests/runtime_replay.gd").new()
			add_child(replay)
		if arg == "--bow-showcase":
			add_child(load("res://tests/bow_showcase.gd").new())
		if arg == "--controller-showcase":
			add_child(load("res://tests/controller_showcase.gd").new())
		if arg == "--controller-replay":
			add_child(load("res://tests/controller_replay.gd").new())
		if arg == "--enemy-replay":
			add_child(load("res://tests/enemy_replay.gd").new())
		if arg == "--crowd-replay":
			add_child(load("res://tests/crowd_replay.gd").new())
		if arg == "--bow-replay":
			add_child(load("res://tests/bow_replay.gd").new())
		if arg == "--pose-review":
			add_child(load("res://tests/pose_review.gd").new())
		if arg == "--character-showcase":
			add_child(load("res://tests/character_showcase.gd").new())
		if arg == "--showcase":
			add_child(load("res://tests/showcase.gd").new())
		if arg.begins_with("--fps="):
			Engine.max_fps = arg.trim_prefix("--fps=").to_int()


func _physics_process(_delta: float) -> void:
	var delta: float = GameClock.dt
	if delta <= 0:
		return
	var look := (
		Input.get_vector(
			"look_left", "look_right", "look_up", "look_down", player.settings.stick_deadzone
		)
		if not player.use_test_input
		else Vector2.ZERO
	)
	var look_offset := player.move_direction(look) * player.settings.camera_look_distance
	var target = Vector3(
		clampf(player.position.x * .27 + look_offset.x, -1.2, 1.2),
		.65,
		clampf(player.position.z * .27 + look_offset.z, -1.2, 1.2)
	)
	camera_home = camera_home.lerp(target, 1 - exp(-delta * 16))
	_apply_impact_camera(delta)
	_draw_debug()


## All level cameras apply the same hit response after calculating their follow position.
func _apply_impact_camera(delta: float) -> void:
	shake = maxf(0, shake - delta * .45)
	camera_rig.position = camera_home
	if player.settings.camera_shake and shake > 0:
		camera_rig.position += (
			Vector3(sin(GameClock.elapsed * 137), cos(GameClock.elapsed * 113), 0) * shake
		)


func impact(at: Vector3, power := 1.0, color := Color(1, .018, .15)) -> void:
	if not $ImpactSound.playing:
		$ImpactSound.global_position = at
		$ImpactSound.pitch_scale = .72 if power > 1.0 else 1.0
		$ImpactSound.play()
	shake = maxf(shake, .065 if power > 1.0 else .035)
	var effect: GPUParticles3D = $ImpactPool.get_child(spark_index % 4)
	var material: StandardMaterial3D = effect.draw_pass_1.material
	material.albedo_color = color.lerp(Color.WHITE, .18)
	material.emission = color
	spark_index += 1
	effect.global_position = at
	effect.restart()
	effect.emitting = true


func _process(_delta: float) -> void:
	for effect in $ImpactPool.get_children():
		effect.speed_scale = 0.0 if GameClock.paused or GameClock.stop_remaining > 0 else 1.0


func restart() -> void:
	GameClock.reset()
	AttackTokenManager.reset()
	for arrow in get_tree().get_nodes_in_group("projectiles"):
		arrow.queue_free()
	player.respawn(Vector3(0, 0, 2.2))
	for d in get_tree().get_nodes_in_group("damageable"):
		d.reset_target()
	for effect in $ImpactPool.get_children():
		effect.emitting = false
	shake = 0


func _draw_debug() -> void:
	debug_mesh.clear_surfaces()
	player.visual.weapon.debug_enabled = debug_enabled
	if not debug_enabled:
		return
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for sample in player.visual.weapon.debug_volumes:
		debug_mesh.surface_add_vertex(sample[0])
		debug_mesh.surface_add_vertex(sample[1])
		for j in 12:
			var a = Vector3(cos(j * TAU / 12), sin(j * TAU / 12), 0) * sample[2]
			var b = Vector3(cos((j + 1) * TAU / 12), sin((j + 1) * TAU / 12), 0) * sample[2]
			debug_mesh.surface_add_vertex(sample[1] + a)
			debug_mesh.surface_add_vertex(sample[1] + b)
	debug_mesh.surface_end()
