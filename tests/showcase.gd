extends Node
var p: PlayerCharacter
var arena: Node3D
var tick := 0
var captured := false


func _ready() -> void:
	process_physics_priority = -10
	call_deferred("setup")


func setup() -> void:
	get_window().position = Vector2i(80, 80)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_window().grab_focus()
	arena = get_tree().current_scene
	p = arena.player
	p.use_test_input = true
	arena.get_node("PracticeEnemy").disabled = true
	arena.get_node("PracticeEnemy").position = Vector3(4.7, 0, 3.8)
	arena.get_node("DummyA").position = Vector3(-.4, 0, .4)
	arena.get_node("DummyB").position = Vector3(.55, 0, .38)
	arena.get_node("DummyBehindWall").position = Vector3(1.9, 0, -1.7)
	arena.get_node("CameraRig/Camera3D").size = 9.5
	p.respawn(Vector3(0, 0, 2.7))


func _physics_process(_dt: float) -> void:
	if not is_instance_valid(p):
		return
	tick += 1
	match tick:
		1:
			p.test_input = Vector2.RIGHT * .45
		100:
			p.test_input = Vector2.LEFT
		200:
			p.test_input = Vector2.RIGHT
		290:
			p.test_input = Vector2.ZERO
		300:
			p.request_action("dodge")
		365:
			p.respawn(Vector3(0, 0, 1.5))
			p.facing = Vector3.FORWARD
			p.pivot.rotation.y = 0
		390:
			p.request_action("light")
		410:
			p.request_action("light")
		457:
			p.request_action("light")
		560:
			p.respawn(Vector3(1.7, 0, 2.9))
			p.facing = Vector3(-1, 0, -1).normalized()
			p.heavy_held = true
			p.request_action("heavy")
		655:
			p.request_action("release")
		765:
			p.facing = Vector3.RIGHT
			p.request_action("dodge")
		806:
			p.request_action("light")
		900:
			p.respawn(Vector3(1.5, 0, 3.0))
			p.test_input = Vector2.UP
		1040:
			p.test_input = Vector2.ZERO
		1100:
			arena.restart()
			p.use_test_input = false
			arena.get_node("PracticeEnemy").disabled = false
			if "--showcase" in OS.get_cmdline_user_args():
				get_tree().quit()
			else:
				queue_free()


func _process(_dt: float) -> void:
	if not is_instance_valid(p):
		return
	if p.active_window and not captured and p.action_time > p.moveset.find(p.clip).windup + .04:
		captured = true
		capture_after_draw("res://captures/combat_active.png")
	if tick >= 940 and tick <= 942:
		capture_after_draw("res://captures/running_game.png")


func capture_after_draw(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
