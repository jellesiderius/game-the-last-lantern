extends Node3D
## Presentation adapter for the saved training model, independent of AI decisions.
@onready var telegraph: MeshInstance3D = get_parent().get_node("Telegraph")


func reset_pose() -> void:
	$ArmL.rotation = Vector3.ZERO
	$ArmR.rotation = Vector3.ZERO
	telegraph.hide()


func present(brain: EnemyBrain, delta: float) -> void:
	rotation.y = atan2(-brain.direction.x, -brain.direction.z)
	var decay := 1 - exp(-delta * 14)
	rotation.x = lerpf(rotation.x, 0, decay)
	rotation.z = lerpf(rotation.z, 0, decay)
	position = position.lerp(Vector3.ZERO, decay)
	scale = scale.lerp(Vector3.ONE, decay)
	$ArmL.rotation.x = lerpf($ArmL.rotation.x, 0, decay)
	$ArmR.rotation.x = lerpf($ArmR.rotation.x, 0, decay)
	var phase := 0.0
	match brain.state:
		"windup":
			phase = clampf(brain.state_time / brain.settings.attack.windup, 0, 1)
			rotation.x = .25 * smoothstep(0, 1, phase)
			rotation.z = sin(phase * 22) * .025
			$ArmL.rotation.x = -1.3 * smoothstep(0, 1, phase)
			$ArmR.rotation.x = -1.3 * smoothstep(0, 1, phase)
			scale = Vector3(1.02, 1.0 + phase * .06, 1.02)
		"strike":
			phase = 1.0
			rotation.x = -.38
			$ArmL.rotation.x = .9
			$ArmR.rotation.x = .9
			scale = Vector3(1.1, .90, 1.1)
		"stagger":
			rotation.x = (
				.26 * (1.0 - clampf(brain.state_time / brain.settings.stagger_duration, 0, 1))
			)
	# Small additive compression acknowledges damage without replacing the tell/strike.
	if brain.committed_attack():
		var impact: float = clampf(brain.actor.flash / .1, 0.0, 1.0)
		scale *= Vector3(1.0 + impact * .035, 1.0 - impact * .025, 1.0 + impact * .035)
	telegraph.visible = brain.state in ["windup", "strike"]
	telegraph.rotation.y = rotation.y
	telegraph.material_override.set_shader_parameter("progress", phase)
	telegraph.material_override.set_shader_parameter("active", brain.state == "strike")
	telegraph.material_override.set_shader_parameter("reach", brain.settings.strike_range)
	telegraph.material_override.set_shader_parameter(
		"half_angle", deg_to_rad(brain.settings.strike_half_angle)
	)
	$Body.material_override.albedo_color = brain.settings.tint
