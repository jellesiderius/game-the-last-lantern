extends Node
## Native title presentation, focus, configurable scene launches, and GUI input fences.
var results: Array = []
var failures := 0


func _ready() -> void:
	run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(label: String, passed: bool, data: Variant = null) -> void:
	results.append({"check": label, "passed": passed, "data": data})
	if not passed:
		failures += 1
	print("INTRO_CHECK ", label, " ", "PASS" if passed else "FAIL", " ", data)


func capture(label: String) -> Image:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://captures/intro/" + label + ".png")
	return image


func joy(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = pressed
	Input.parse_input_event(event)
	await frames(2)


func tap(button: JoyButton) -> void:
	await joy(button, true)
	await joy(button, false)


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/intro")
	get_window().size = Vector2i(1338, 753)
	get_window().position = Vector2i(80, 80)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_window().grab_focus()
	Input.warp_mouse(Vector2(20, 20))
	DisplayServer.window_move_to_foreground()
	await frames(10)
	var title := get_tree().current_scene
	if "--intro-movie" in OS.get_cmdline_user_args():
		# Keep this dedicated capture on the title when a connected controller is in use.
		get_viewport().gui_disable_input = true
		await frames(420)
		get_tree().quit()
		return
	check("title is startup scene", title.scene_file_path == "res://scenes/ui/TitleScreen.tscn")
	check(
		"continue unavailable without a save", title.get_node("Artwork/Options/Continue").disabled
	)
	check(
		"new game receives initial focus",
		get_viewport().gui_get_focus_owner() == title.get_node("Artwork/Options/NewGame")
	)
	check(
		"test scene is configured as TestArena",
		title.test_scene == "res://scenes/levels/TestArena.tscn"
	)
	var start_frames := Engine.get_frames_drawn()
	var start_ms := Time.get_ticks_msec()
	check("title starts with a gentle fade", title.get_node("Artwork/TitleLogo").modulate.a < .5)
	await frames(90)
	var elapsed := (Time.get_ticks_msec() - start_ms) / 1000.0
	var render_fps := (Engine.get_frames_drawn() - start_frames) / elapsed
	check(
		"native render frames advance at requested cap",
		Engine.get_frames_drawn() - start_frames >= 88 and render_fps > 50.0,
		render_fps
	)
	await frames(70)
	check("title settles fully visible", title.get_node("Artwork/TitleLogo").modulate.a > .99)
	check(
		"menu clears lantern artwork",
		title.options.position.y + title.options.size.y < 500.0,
		title.options.position.y + title.options.size.y
	)
	var first := await capture("title")
	await frames(90)
	var second := await capture("flicker_later")
	var changes := 0
	var lamp_changes := 0
	var fit: float = title.artwork.scale.x
	var origin: Vector2 = title.artwork.position
	for y in range(626, 713, 3):
		for x in range(810, 860, 3):
			var point := Vector2i(origin + Vector2(x, y) * fit)
			if first.get_pixelv(point) != second.get_pixelv(point):
				lamp_changes += 1
	for y in range(540, 740, 4):
		for x in range(590, 760, 4):
			var point := Vector2i(origin + Vector2(x, y) * fit)
			if first.get_pixelv(point) != second.get_pixelv(point):
				changes += 1
	check("lantern light changes in actual rendered pixels", lamp_changes > 100, lamp_changes)
	check("sparks move in actual rendered pixels", changes > 20, changes)
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(
		"controller reaches test scene",
		get_viewport().gui_get_focus_owner() == title.get_node("Artwork/Options/TestScene")
	)
	await capture("testscene_selected")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(
		"controller reaches settings",
		get_viewport().gui_get_focus_owner() == title.get_node("Artwork/Options/Settings")
	)
	await tap(JOY_BUTTON_A)
	check("settings opens through controller", title.settings_open)
	var previous_vibration: bool = InputRouter.vibration_enabled
	await tap(JOY_BUTTON_DPAD_DOWN)
	await tap(JOY_BUTTON_A)
	check("vibration setting is functional", InputRouter.vibration_enabled != previous_vibration)
	InputRouter.vibration_enabled = previous_vibration
	await capture("settings")
	await tap(JOY_BUTTON_B)
	check(
		"circle returns from settings",
		(
			not title.settings_open
			and get_viewport().gui_get_focus_owner() == title.get_node("Artwork/Options/Settings")
		)
	)
	await tap(JOY_BUTTON_DPAD_UP)
	await tap(JOY_BUTTON_A)
	await frames(20)
	var arena := get_tree().current_scene
	check(
		"test scene opens TestArena", arena.scene_file_path == "res://scenes/levels/TestArena.tscn"
	)
	check(
		"confirm does not become a dodge or attack",
		arena.player.state == "locomotion",
		arena.player.state
	)
	check("character definition exists on direct test launch", arena.player.definition != null)
	arena.get_node("HUD")._pause()
	await frames(3)
	arena.get_node("HUD/Root/PausePanel/Layout/Tabs/Game/Title").grab_focus()
	await tap(JOY_BUTTON_A)
	await frames(10)
	title = get_tree().current_scene
	check(
		"pause menu returns to title", title.scene_file_path == "res://scenes/ui/TitleScreen.tscn"
	)
	check("return clears gameplay pause", not GameClock.paused)
	# The signal reads the exported setting at activation, rather than a hardcoded path.
	title.test_scene = "res://scenes/levels/PrototypeRoom.tscn"
	title.get_node("Artwork/Options/TestScene").grab_focus()
	await tap(JOY_BUTTON_A)
	await frames(20)
	arena = get_tree().current_scene
	check(
		"test scene honors an edited target",
		arena.scene_file_path == "res://scenes/levels/PrototypeRoom.tscn"
	)
	check("new room starts with the panda", arena.player.definition.id == "red_panda")
	arena.get_node("HUD")._return_to_title()
	await frames(10)
	title = get_tree().current_scene
	title.get_node("Artwork/Options/NewGame").grab_focus()
	await tap(JOY_BUTTON_A)
	await frames(20)
	check(
		"new game opens ForestOpening",
		get_tree().current_scene.scene_file_path == "res://scenes/levels/ForestOpening.tscn"
	)
	check(
		"new game confirm preserves forest entrance",
		(
			get_tree().current_scene.player.state == "entrance"
			and get_tree().current_scene.player.pending_inputs.is_empty()
		)
	)
	FileAccess.open("res://captures/intro/checks.json", FileAccess.WRITE).store_string(
		JSON.stringify(
			{
				"failures": failures,
				"results": results,
				"observed_render_fps": render_fps,
				"renderer": RenderingServer.get_current_rendering_method()
			},
			"\t"
		)
	)
	get_tree().quit(1 if failures else 0)
