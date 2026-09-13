extends Node
## Deterministic demonstration using real movement, melee, bow and damage code.
var tick := 0
var p: PlayerCharacter
var arena: Node3D
var flight_captured := false
var aiming_captured := false


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
	for d in get_tree().get_nodes_in_group("damageable"):
		d.disabled = true
	arena.get_node("PracticeEnemy").position = Vector3(4.8, 0, 3)
	arena.get_node("RangeNear").position = Vector3(-4, 0, -1.2)
	arena.get_node("CameraRig/Camera3D").size = 10.5
	p.respawn(Vector3(-3.8, 0, 3.5))
	p.facing = Vector3.FORWARD
	p.pivot.rotation.y = 0


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(p):
		return
	tick += 1
	match tick:
		1:
			pass
		30, 150, 270, 390, 510, 900:
			p.request_action("bow_direct_press")
		85, 205, 325, 445, 565, 955:
			p.request_action("bow_direct_release")
		620:
			p.request_action("bow_cancel")
		650:
			p.test_input = Vector2(.7071068, -.7071068)
		740:
			p.test_input = Vector2.ZERO
		775:
			p.request_action("light")
		855:
			pass
		1030:
			p.request_action("bow_cancel")
			p.facing = Vector3.RIGHT
			p.request_action("dodge")
		1140:
			arena.restart()
			p.use_test_input = false
			for d in get_tree().get_nodes_in_group("damageable"):
				d.disabled = false
			if "--bow-showcase" in OS.get_cmdline_user_args():
				get_tree().quit()
			else:
				queue_free()


func _process(_delta: float) -> void:
	if not is_instance_valid(p):
		return
	if not aiming_captured and p.state == "bow_draw" and p.action_time > .32:
		aiming_captured = true
		capture("res://captures/bow_aim.png")
	if not flight_captured:
		for arrow in get_tree().get_nodes_in_group("projectiles"):
			if arrow.travelled > 1.1:
				flight_captured = true
				capture("res://captures/arrow_flight.png")
	if tick == 844:
		print("SHOWCASE melee refill: magic=", p.magic.current, " shots=", p.bow.shots_fired)


func capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
