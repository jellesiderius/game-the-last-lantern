extends Node
## Stays above changing levels; uses actual controller events and native menu buttons.
var results: Array = []
var failures := 0


func _ready() -> void:
	call_deferred("run")


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func tap(index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	Input.parse_input_event(event)
	await frames(3)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(5)


func check(label: String, passed: bool) -> void:
	results.append({"check": label, "passed": passed})
	failures += 0 if passed else 1
	print("SELECTION_CHECK ", label, " ", passed)


func run() -> void:
	await frames(12)
	get_window().position = Vector2i(80, 80)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_window().grab_focus()
	check("startup is character select", get_tree().current_scene.name == "CharacterSelect")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/character_select.png")
	for definition in GameSession.characters:
		var id := String(definition.id)
		for navigation_step in GameSession.characters.size():
			var choice := get_viewport().gui_get_focus_owner() as CharacterChoice
			if choice and choice.definition.id == id:
				break
			await tap(JOY_BUTTON_DPAD_RIGHT)
		var focused := get_viewport().gui_get_focus_owner() as CharacterChoice
		check("controller focuses " + id, focused != null and focused.definition.id == id)
		await tap(JOY_BUTTON_A)
		await frames(10)
		var arena = get_tree().current_scene
		var player: PlayerCharacter = arena.player
		for target in get_tree().get_nodes_in_group("damageable"):
			target.disabled = true
		check(id + " uses selected definition", player.definition.id == id)
		check(
			id + " loads authored visual",
			player.visual.scene_file_path == player.definition.visual_scene.resource_path
		)
		check(id + " confirm does not dodge", player.state == "locomotion")
		check(
			id + " has one sword instance",
			player.visual.find_children("WeaponModel", "Node3D", true, false).size() == 1
		)
		check(
			id + " has independent charged animation",
			player.visual.animation_player.has_animation("heavy_release_charged")
		)
		check(
			id + " applies profile capsule",
			is_equal_approx(
				player.get_node("CollisionShape3D").shape.radius, player.definition.body_radius
			)
		)
		check(
			id + " uses matching bow palette",
			player.visual.bow.appearance == player.visual.weapon.definition
		)
		check(
			id + " uses its movement profile",
			(
				definition.movement != null
				and is_equal_approx(player.settings.max_speed, definition.movement.max_speed)
			)
		)
		var rotation: Vector3 = player.get_node("CollisionShape3D").rotation
		await tap(JOY_BUTTON_A)
		await frames(15)
		check(
			id + " rolling collider stays upright",
			(
				player.state == "roll"
				and player.get_node("CollisionShape3D").rotation.is_equal_approx(rotation)
			)
		)
		await frames(65)
		player.respawn(Vector3(0, 0, 2.2))
		check(
			id + " respawn preserves character and magic",
			(
				player.definition.id == id
				and player.magic.current == 4
				and player.visual.weapon.visible
			)
		)
		await tap(JOY_BUTTON_START)
		var menu = arena.get_node("HUD").pause_panel
		menu.get_node("Layout/Tabs/Game/ChooseCharacter").grab_focus()
		await tap(JOY_BUTTON_A)
		await frames(10)
		check(
			id + " returns to selector",
			get_tree().current_scene.name == "CharacterSelect" and not GameClock.paused
		)
	var file := FileAccess.open("res://captures/selection_checks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "results": results}, "\t"))
	get_tree().quit(1 if failures else 0)
