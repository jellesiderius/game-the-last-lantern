extends "res://tests/controller_replay.gd"
## Real shared gameplay/input at normal physics speed, with close camera for visual review.


func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://captures/" + p.definition.id + "_" + label + ".png"
	)


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	await clean(Vector3(0, 0, 3))
	arena.get_node("CameraRig/Camera3D").size = 9.5
	axis(JOY_AXIS_LEFT_X, .8)
	await step(38)
	await capture("run")
	axis(JOY_AXIS_LEFT_X, 0)
	button(JOY_BUTTON_A, true)
	await step(22)
	await capture("roll")
	button(JOY_BUTTON_A, false)
	await step(60)
	await clean(Vector3(0, 0, 3))
	targets[0].position = Vector3(0, 0, -1.5)
	p.facing = Vector3.FORWARD
	p.pivot.rotation.y = 0
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	await step(24)
	for shot in 4:
		button(JOY_BUTTON_B, true)
		await step(40)
		if shot == 0:
			await capture("bow_draw")
		await step(40)
		if shot == 0:
			await capture("arrow_flight")
		button(JOY_BUTTON_B, false)
		await step(44)
	print("DEMO four shots: ", p.bow.shots_fired, " magic: ", p.magic.current)
	button(JOY_BUTTON_B, true)
	axis(JOY_AXIS_LEFT_X, .7)
	await step(12)
	await capture("empty_bow_moving")
	button(JOY_BUTTON_B, false)
	axis(JOY_AXIS_LEFT_X, 0)
	axis(JOY_AXIS_TRIGGER_LEFT, 0)
	await step(60)
	p.position = Vector3(0, 0, 2.2)
	p.velocity = Vector3.ZERO
	p.facing = Vector3.FORWARD
	p.pivot.rotation.y = 0
	targets[0].position = p.position + Vector3(.55, 0, -.86)
	targets[1].position = p.position + Vector3(-.45, 0, -.82)
	await tap(JOY_BUTTON_X)
	await step(10)
	await capture("melee_refill")
	await step(80)
	print("DEMO melee restored magic: ", p.magic.current)
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	await step(24)
	button(JOY_BUTTON_B, true)
	await step(45)
	button(JOY_BUTTON_B, false)
	await step(80)
	axis(JOY_AXIS_TRIGGER_LEFT, 0)
	await step(25)
	axis(JOY_AXIS_TRIGGER_RIGHT, 1)
	await step(57)
	await capture("heavy_charge")
	while p.state != "heavy_attack" or p.action_time < .265:
		await step(1)
	await capture("charged_cleave")
	await step(75)
	axis(JOY_AXIS_TRIGGER_RIGHT, 0)
	await step(40)
	get_tree().quit()
