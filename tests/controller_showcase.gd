extends "res://tests/controller_replay.gd"


## Short visual demonstration; all controller operations use the actual saved bindings.
func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/" + label + ".png")


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	await clean()
	axis(JOY_AXIS_LEFT_X, 1)
	await step(52)
	axis(JOY_AXIS_LEFT_X, 0)
	await tap(JOY_BUTTON_A)
	await step(65)
	await clean(Vector3(0, 0, 3))
	p.facing = Vector3.FORWARD
	targets[0].position = Vector3(0, 0, 0)
	await step(20)
	axis(JOY_AXIS_TRIGGER_LEFT, 1)
	await step(22)
	button(JOY_BUTTON_B, true)
	await step(32)
	await capture("controller_bow_draw")
	button(JOY_BUTTON_B, false)
	await step(9)
	await capture("controller_arrow_flight")
	await step(55)
	axis(JOY_AXIS_TRIGGER_LEFT, 0)
	await step(30)
	await tap(JOY_BUTTON_START)
	await tap(JOY_BUTTON_RIGHT_SHOULDER)
	await step(30)
	await capture("controller_controls")
	await step(85)
	await tap(JOY_BUTTON_B)
	await step(25)
	# Sample the actual presenter/shader at four authored windup fractions.
	var brains = get_tree().get_nodes_in_group("enemy_ai")
	for actor in targets:
		actor.disabled = true
	p.position = Vector3(0, 0, 3.8)
	GameClock.paused = true
	var hud = arena.get_node("HUD")
	hud.set_process(false)
	hud.pause_panel.hide()
	for phase in [.0, .25, .5, .92, 1.0]:
		for i in brains.size():
			var brain: EnemyBrain = brains[i]
			brain.actor.position = Vector3((i - 1) * 2.7, 0, 1.0)
			brain.direction = Vector3(0, 0, 1)
			brain.state = "strike" if phase == 1.0 else "windup"
			brain.state_time = phase * brain.settings.attack.windup
			brain.actor.visual.present(brain, .008333)
		await step(35)
		await capture("enemy_warning_%03d" % roundi(phase * 100))
	await step(20)
	get_tree().quit()
