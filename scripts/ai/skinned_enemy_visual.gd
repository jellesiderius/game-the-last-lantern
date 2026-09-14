extends Node3D
## Samples authored bone clips using EnemyBrain's action time and the shared clock.
## Any enemy rig supplying the same clip names can use this presentation adapter.
@export var walk_cycle_speed := 1.05
@export var run_cycle_speed := 2.25
var animation_player: AnimationPlayer
var locomotion_time := 0.0
var current_clip := ""
var phase_initialized := false
@onready var telegraph: MeshInstance3D = get_parent().get_node("Telegraph")


func _ready() -> void:
	animation_player = find_children("*", "AnimationPlayer", true, false)[0]
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for clip in ["idle", "walk", "run", "turn"]:
		if animation_player.has_animation(clip):
			animation_player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	reset_pose()


func sample(clip: String, time: float) -> void:
	if current_clip != clip:
		animation_player.play(clip)
		current_clip = clip
	animation_player.seek(time, true)


func reset_pose() -> void:
	locomotion_time = 0.0
	phase_initialized = false
	current_clip = ""
	telegraph.hide()
	show()
	sample("idle", 0.0)


func present(brain: EnemyBrain, delta: float) -> void:
	if not phase_initialized:
		locomotion_time = brain.personality.get("phase", 0.0)
		phase_initialized = true
	rotation.y = atan2(-brain.direction.x, -brain.direction.z)
	var clip := "idle"
	var time := brain.state_time
	var phase := 0.0
	match brain.state:
		"windup":
			clip = brain.windup_clip
			# A delay hold keeps the raised pose after the animated tell.
			phase = clampf(time / maxf(brain.tell_duration, .001), 0.0, 1.0)
			time = phase * animation_player.get_animation(clip).length
		"strike":
			clip = brain.attack.clip
			phase = 1.0
			time = (
				clampf(time / brain.attack.active_duration, 0.0, 1.0)
				* animation_player.get_animation(clip).length
			)
		"recover":
			clip = brain.recovery_clip
			time = (
				clampf(time / brain.attack.recovery, 0.0, 1.0)
				* animation_player.get_animation(clip).length
			)
		"stagger":
			clip = "hurt"
			time = (
				clampf(time / brain.settings.stagger_duration, 0.0, 1.0)
				* animation_player.get_animation(clip).length
			)
		_:
			var actual: Vector3 = brain.actor.get_real_velocity()
			var speed: float = Vector2(actual.x, actual.z).length()
			clip = "walk" if speed > 0.08 else "idle"
			var pace := walk_cycle_speed
			if speed > 1.35 and animation_player.has_animation("run"):
				clip = "run"
				pace = run_cycle_speed
			if brain.turning_in_place and speed < .15:
				clip = "turn" if animation_player.has_animation("turn") else "idle"
			if (
				brain.state == "idle"
				and brain.idle_look
				and animation_player.has_animation("look_around")
				and brain.state_time >= brain.idle_look_delay
				and (
					(
						(brain.state_time - brain.idle_look_delay)
						* brain.personality.get("idle_rate", 1.0)
					)
					< animation_player.get_animation("look_around").length
				)
			):
				clip = "look_around"
			locomotion_time += (
				delta
				* (
					clampf(speed / pace, .1, 1.5)
					if clip in ["walk", "run"]
					else brain.personality.get("idle_rate", 1.0)
				)
			)
			time = fmod(locomotion_time, animation_player.get_animation(clip).length)
			if clip == "look_around":
				time = (
					(brain.state_time - brain.idle_look_delay)
					* brain.personality.get("idle_rate", 1.0)
				)
	sample(clip, time)
	telegraph.visible = brain.state in ["windup", "strike"]
	telegraph.rotation.y = rotation.y
	telegraph.material_override.set_shader_parameter("progress", phase)
	telegraph.material_override.set_shader_parameter("active", brain.state == "strike")
	telegraph.material_override.set_shader_parameter("reach", brain.strike_range)
	telegraph.material_override.set_shader_parameter(
		"half_angle", deg_to_rad(brain.strike_half_angle)
	)


func present_death(time: float) -> void:
	telegraph.hide()
	sample("death", minf(time, animation_player.get_animation("death").length))
	if time > 1.1:
		hide()
