extends "res://tests/intro_replay.gd"
## Real New Game input, native loading artwork, frozen intro, warm loads and failure recovery.


func wait_finished() -> void:
	for i in 1200:
		if not SceneTransit.active:
			break
		await frames(1)
	check("loader eventually restores control", not SceneTransit.active)


func watch_loading() -> bool:
	var seen := false
	for i in 1200:
		seen = seen or SceneTransit.loading_screen.visible
		if not SceneTransit.active:
			break
		await frames(1)
	check("map loading finishes", not SceneTransit.active)
	return seen


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/loading")
	get_window().size = Vector2i(1280, 800)
	get_window().position = Vector2i(80, 60)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_window().grab_focus()
	Input.warp_mouse(Vector2(20, 20))
	DisplayServer.window_move_to_foreground()
	await frames(10)
	var initial_frame := Engine.get_frames_drawn()
	var title := get_tree().current_scene
	var minimum: float = SceneTransit.new_game_loading_time
	# Extend only this review's display window to inspect three real viewport aspect ratios.
	SceneTransit.new_game_loading_time = 3.0
	title.get_node("Artwork/Options/NewGame").grab_focus()
	await tap(JOY_BUTTON_A)
	check(
		"New Game asks for a save slot first",
		title.get_node("SaveSlots").visible and not SceneTransit.active
	)
	await tap(JOY_BUTTON_A)
	check("New Game starts shared loading", SceneTransit.active)
	check("duplicate launch is rejected", not SceneTransit.change_scene(title.new_game_scene))
	for i in 80:
		if SceneTransit.fade.modulate.a > .99:
			break
		await frames(1)
	check("loading artwork fully covers scene setup", SceneTransit.fade.modulate.a > .99)
	check("New Game always shows lantern loading card", SceneTransit.loading_screen.visible)
	check(
		"heading is separate from internal scene path",
		SceneTransit.loading_screen.get_node("Composition/Heading").text == "Een nieuw avontuur"
	)
	await loading_capture("new_game")
	var flame_time: float = SceneTransit.loading_screen.animation_time
	var clock_time := GameClock.elapsed
	await frames(12)
	check(
		"lantern animates while game is frozen",
		SceneTransit.loading_screen.animation_time > flame_time + .1
	)
	check("loading freezes the gameplay clock", is_equal_approx(GameClock.elapsed, clock_time))
	await loading_capture("new_game_flame")
	await tap(JOY_BUTTON_B)
	await tap(JOY_BUTTON_A)
	check("confirm and cancel cannot dismiss loading", SceneTransit.active)
	for viewport_size in [Vector2i(1280, 720), Vector2i(1024, 768)]:
		get_window().size = viewport_size
		await frames(6)
		var card: Control = SceneTransit.loading_screen
		var rect: Rect2 = card.get_node("Composition/Heading").get_global_rect()
		check(
			"loading layout fits " + str(viewport_size),
			card.get_global_rect().encloses(rect),
			{"content": rect, "canvas": card.get_global_rect()}
		)
		await loading_capture("aspect_" + str(viewport_size.x) + "x" + str(viewport_size.y))
	get_window().size = Vector2i(1280, 800)
	await wait_finished()
	SceneTransit.new_game_loading_time = minimum
	var forest := get_tree().current_scene
	check("New Game reaches the forest", forest.name == "ForestOpening")
	check(
		"seated introduction waits until loader is gone",
		forest.player.state == "entrance" and forest.player.action_time < .1,
		forest.player.action_time
	)
	check(
		"loading overlay hides completely",
		not SceneTransit.fade.visible and not SceneTransit.loading_screen.visible
	)
	check(
		"loading confirm cannot become a combat action",
		forest.player.attacks_started.is_empty() and forest.player.pending_inputs.is_empty()
	)
	check("gameplay resumes after New Game", not GameClock.paused)
	await loading_capture("forest_handoff")
	forest.get_node("HUD")._return_to_title()
	await wait_finished()
	check("return to title uses the same loader", get_tree().current_scene.name == "TitleScreen")
	var house_path := "res://scenes/levels/ForestHouse.tscn"
	check(
		"other levels use public loading entry point",
		SceneTransit.change_scene(house_path, "Een warm onderkomen")
	)
	check("first visit shows loading during preparation", await watch_loading())
	check(
		"direct house launch has a valid player", get_tree().current_scene.player.definition != null
	)
	# Retain the PackedScene and supply a prior fast preparation observation: no flash on a warm load.
	var retained := load(house_path) as PackedScene
	SceneTransit.preparation_seconds[house_path] = .01
	SceneTransit.change_scene(house_path)
	check("fast cached map skips loading card", not await watch_loading())
	check(
		"cached target remains usable",
		retained != null and get_tree().current_scene.name == "ForestHouse"
	)
	get_tree().current_scene.get_node("HUD")._pause()
	SceneTransit.change_scene("res://scenes/ui/TitleScreen.tscn")
	await wait_finished()
	check("menu load releases previous pause", not GameClock.paused)
	title = get_tree().current_scene
	title._launch("res://missing_loading_destination.tscn")
	await frames(3)
	check(
		"missing target keeps source usable",
		get_tree().current_scene == title and not title.starting and not SceneTransit.active
	)
	check("missing target displays a readable error", title.get_node("Artwork/LaunchError").visible)
	var report := {
		"checks": results,
		"failures": failures,
		"render_frames": Engine.get_frames_drawn() - initial_frame,
		"renderer": RenderingServer.get_current_rendering_method(),
		"cap": Engine.max_fps
	}
	FileAccess.open("res://captures/loading/checks.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("LOADING_REPLAY_RESULT ", JSON.stringify(report))
	get_tree().quit(1 if failures else 0)


func loading_capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/loading/" + label + ".png")
