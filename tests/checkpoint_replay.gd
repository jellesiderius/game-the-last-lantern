extends "res://tests/intro_replay.gd"
## Full native lifecycle. A second process with --checkpoint-reload verifies disk persistence.
var p: PlayerCharacter
var render_start := 0
var phase := "lifecycle"
var refresh_alpha := -1.0


func key_tap(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await frames(2)


func click_button(button: Control) -> void:
	var screen_point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = screen_point
		event.global_position = screen_point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await frames(2)


func step(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func photo(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/vuurlelie/" + label + ".png")


func settle_scene() -> void:
	await finish_transition()
	p = get_tree().current_scene.get_node("Player")
	p.use_test_input = true
	p.test_input = Vector2.ZERO
	await step(8)


func find_lily() -> Vuurlelie:
	return get_tree().get_first_node_in_group("vuurlelies") as Vuurlelie


func near_lily(point: Vuurlelie) -> void:
	p.respawn(point.get_node("Spawn").global_position)
	p.facing = (point.global_position - p.global_position).normalized()
	p.pivot.rotation.y = atan2(-p.facing.x, -p.facing.z)
	p.reset_physics_interpolation()
	get_tree().current_scene.reset_camera()
	await step(20)
	p.interaction.refresh()
	check("safe spawn is grounded", p.is_on_floor() and absf(p.position.y) < .05, p.position)
	check("nearby lily is interactable", p.interaction.target == point, p.interaction.target)


func ignite(point: Vuurlelie, label: String) -> void:
	await near_lily(point)
	var previous_checkpoint: String = GameProgress.data.checkpoint.id
	var previous_save: float = SaveStore.read_slot(GameProgress.active_slot).last_saved_unix
	p.health.damage(2)
	p.magic.try_spend(2)
	p.use_test_input = false
	InputRouter.blocked_through_frame = -1
	await step(4)
	await tap(JOY_BUTTON_Y)
	check("triangle starts rest interaction", Checkpoints.active)
	p.use_test_input = true
	for i in 400:
		if p.state == "kindle":
			break
		await step(1)
	check("first interaction uses kindle action", p.state == "kindle", p.state)
	for i in 400:
		if p.state != "kindle" or p.action_time >= .85:
			break
		await step(1)
	check(
		"transfer spark visible before opening",
		point.get_node("Spark").visible and point.opening < .01
	)
	await photo(label + "_spark")
	p.request_action("light")
	check("kindle blocks attacks", p.pending_inputs.is_empty() and not p.is_attack())
	for i in 200:
		if p.state != "kindle" or p.action_time >= 1.45:
			break
		await step(1)
	check(
		"five petals opening with actual flame",
		(
			point.petals.size() == 5
			and point.opening > .1
			and point.opening < .95
			and point.get_node("Flame").visible
		),
		point.opening
	)
	await photo(label + "_opening")
	for i in 300:
		if (
			GameClock.paused
			and is_instance_valid(Checkpoints.rest_menu)
			and Checkpoints.rest_menu.visible
			and not SceneTransit.active
		):
			break
		await step(1)
	await frames(18)
	check(
		"rest menu pauses gameplay",
		(
			Checkpoints.active
			and GameClock.paused
			and Checkpoints.rest_menu.visible
			and p.state == "resting"
		)
	)
	check(
		"sitting neither heals nor refills magic",
		p.health.current == p.health.maximum - 2 and p.magic.current == p.magic.maximum - 2
	)
	check(
		"sitting does not save or change checkpoint",
		(
			SaveStore.read_slot(GameProgress.active_slot).last_saved_unix == previous_save
			and GameProgress.data.checkpoint.id == previous_checkpoint
		)
	)
	check("sitting shows no save success message", Checkpoints.rest_menu.status.text.is_empty())
	check(
		"only Rusten and Verdergaan are offered",
		(
			Checkpoints.rest_menu.buttons.get_child_count() == 2
			and not Checkpoints.rest_menu.buttons.has_node("save")
		)
	)
	await photo(label + "_sitting")
	Checkpoints.rest_menu.buttons.get_node("rest").grab_focus()
	await key_tap(KEY_ENTER)
	check(
		"Rusten starts shared scene transition fade",
		SceneTransit.active and not SceneTransit.loading_screen.visible
	)
	await frames(12)
	await photo(label + "_refresh_fade")
	await finish_transition()
	check(
		"NPC refresh happens behind a fully opaque scene curtain",
		refresh_alpha > .999,
		refresh_alpha
	)
	check(
		"rest fully restores independent meters",
		p.health.current == p.health.maximum and p.magic.current == p.magic.maximum
	)
	check(
		"rest auto-save really committed",
		SaveStore.read_slot(GameProgress.active_slot).checkpoint.id == String(point.checkpoint_id)
	)
	check(
		"lit flower has persistent flame and embers",
		(
			point.lit
			and point.opening == 1
			and point.get_node("Flame").visible
			and point.get_node("Embers").emitting
		)
	)
	await photo(label + "_rest")


func close_rest() -> void:
	p.use_test_input = false
	Checkpoints.rest_menu.buttons.get_node("continue").grab_focus()
	await joy(JOY_BUTTON_A, true)
	await frames(24)
	check(
		"holding confirm keeps rest menu until release",
		Checkpoints.active and p.state == "resting",
		p.state
	)
	await joy(JOY_BUTTON_A, false)
	await frames(24)
	check(
		"confirm release closes rest without dodge or attack",
		not Checkpoints.active and p.state == "locomotion" and p.pending_inputs.is_empty(),
		p.state
	)
	p.use_test_input = true


func run() -> void:
	assert(SaveStore.directory.begins_with("user://save_tests/"))
	DirAccess.make_dir_recursive_absolute("res://captures/vuurlelie")
	get_window().size = Vector2i(1280, 800)
	get_window().position = Vector2i(80, 60)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	get_window().grab_focus()
	DisplayServer.window_move_to_foreground()
	Input.warp_mouse(Vector2(12, 12))
	await frames(10)
	render_start = Engine.get_frames_drawn()
	Checkpoints.world_refreshed.connect(func(): refresh_alpha = SceneTransit.fade.modulate.a)
	if "--checkpoint-passage-review" in OS.get_cmdline_user_args():
		phase = "passage_rest"
		await passage_rest_review()
		finish()
		return
	if "--checkpoint-fire-review" in OS.get_cmdline_user_args():
		phase = "fire_review"
		Checkpoints.start_slot(0)
		await settle_scene()
		var lily := find_lily()
		await near_lily(lily)
		get_viewport().get_camera_3d().size = 4.5
		for i in 5:
			await frames(45)
			await photo("fire_detail_%d" % i)
		get_viewport().get_camera_3d().size = 13
		await frames(45)
		await photo("fire_gameplay")
		var camera := get_viewport().get_camera_3d()
		var game_transform := camera.global_transform
		camera.top_level = true
		camera.size = 3.8
		var target := lily.global_position + Vector3.UP * .8
		var views := {
			"front": Vector3(0, 3, 5),
			"left": Vector3(-5, 3, 0),
			"back": Vector3(0, 3, -5),
			"right": Vector3(5, 3, 0),
		}
		for label in views:
			camera.global_position = target + views[label]
			camera.look_at(target)
			await frames(12)
			await photo("fire_" + label)
		camera.top_level = false
		camera.global_transform = game_transform
		camera.size = 13
		Checkpoints.begin_rest(lily, p)
		await frames(100)
		await Checkpoints.menu_action("rest")
		await frames(30)
		await photo("save_lantern_small")
		finish()
		return
	if "--checkpoint-reload" in OS.get_cmdline_user_args():
		phase = "fresh_process"
		await reload_phase()
		finish()
		return
	DirAccess.make_dir_recursive_absolute(SaveStore.directory)
	for file in DirAccess.get_files_at(SaveStore.directory):
		DirAccess.remove_absolute(SaveStore.directory.path_join(file))
	var title := get_tree().current_scene
	title._refresh_continue()
	check("Continue hidden with no saves", not title.get_node("Artwork/Options/Continue").visible)
	await frames(155)
	await photo("title_no_save")
	title.get_node("Artwork/Options/NewGame").grab_focus()
	await tap(JOY_BUTTON_A)
	var picker := title.get_node("SaveSlots")
	check("New Game opens shared slots", picker.visible and not SceneTransit.active)
	check(
		"first empty slot focused",
		get_viewport().gui_get_focus_owner() == picker.slots[0].get_node("Select")
	)
	await frames(18)
	await photo("empty_slots")
	await tap(JOY_BUTTON_A)
	check(
		"initial save exists before loading",
		(
			SaveStore.read_slot(0).checkpoint.id == SaveSchema.START_ID
			and not SaveStore.read_slot(0).opening_completed
		)
	)
	var paused_time: float = GameProgress.data.play_seconds
	await settle_scene()
	check("new game has seated introduction", p.state == "entrance", p.state)
	check(
		"loading and intro do not count playtime",
		is_equal_approx(GameProgress.data.play_seconds, paused_time)
	)
	for i in 1000:
		if p.state != "entrance":
			break
		await step(1)
	check("opening completion persisted", SaveStore.read_slot(0).opening_completed)
	check("stump stays initial checkpoint", GameProgress.data.checkpoint.id == SaveSchema.START_ID)
	if "--checkpoint-start-only" in OS.get_cmdline_user_args():
		phase = "new_game_start"
		await start_reload_checks()
		finish()
		return
	# A death before resting uses the safe ground next to the stump, without replaying the intro.
	GameProgress.set_world_flag("picked_before_first_rest", true)
	p.receive_hit(99, 19001, p.position + Vector3.RIGHT)
	get_tree().current_scene.get_node("HUD")._restart()
	await settle_scene()
	check(
		"pre-lily death uses safe stump ground",
		p.state == "locomotion" and p.position.distance_to(Vector3(-3, 0, 7.4)) < .1
	)
	check(
		"death retains progress since last save",
		GameProgress.world_flag("picked_before_first_rest")
	)
	var point := find_lily()
	await near_lily(point)
	check(
		"unactivated flower closed and dark",
		(
			not point.lit
			and point.opening == 0
			and not point.get_node("Flame").visible
			and not point.get_node("Embers").emitting
		)
	)
	check("inactive prompt is Ontsteek", point.prompt == "Ontsteek")
	await photo("closed_game")
	await frames(40)
	check(
		"walking past does not change checkpoint",
		GameProgress.data.checkpoint.id == SaveSchema.START_ID
	)
	await ignite(point, "first")
	var at_rest_time: float = GameProgress.data.play_seconds
	var fire_time: float = point.flame_time
	await frames(40)
	check(
		"rest pause not counted as playtime",
		is_equal_approx(at_rest_time, GameProgress.data.play_seconds)
	)
	check("fire stays alive behind paused rest menu", point.flame_time > fire_time + .2)
	await photo("first_embers_later")
	await frames(120)
	check("save icon disappears after its short display", not SaveIndicator.icon.visible)
	# A real write failure cannot trigger success feedback.
	var original_directory := SaveStore.directory
	var blocked := original_directory.path_join("blocked")
	SaveStore._write_file(blocked, "file")
	SaveStore.directory = blocked.path_join("saves")
	var indicator_count: int = SaveIndicator.shown_count
	Checkpoints.menu_action(&"rest")
	await finish_transition()
	check("save error stays visible", not Checkpoints.rest_menu.status.text.is_empty())
	check(
		"failed save does not light success icon",
		SaveIndicator.shown_count == indicator_count and not SaveIndicator.icon.visible
	)
	SaveStore.directory = original_directory
	Checkpoints.rest_menu.show_message("", false)
	await frames(3)
	var panel_before: Rect2 = Checkpoints.rest_menu.panel.get_global_rect()
	var button_before: Rect2 = Checkpoints.rest_menu.buttons.get_node("rest").get_global_rect()
	await click_button(Checkpoints.rest_menu.buttons.get_node("rest"))
	check(
		"mouse Rusten starts shared fade without loading screen",
		SceneTransit.active and not SceneTransit.loading_screen.visible
	)
	await finish_transition()
	check(
		"rest saves without a text success message",
		(
			Checkpoints.rest_menu.status.text.is_empty()
			and SaveStore.read_slot(0).checkpoint.id == String(point.checkpoint_id)
		)
	)
	check(
		"rest layout does not shift after activation",
		(
			Checkpoints.rest_menu.panel.get_global_rect().is_equal_approx(panel_before)
			and Checkpoints.rest_menu.buttons.get_node("rest").get_global_rect().is_equal_approx(
				button_before
			)
		)
	)
	await frames(30)
	check(
		"successful save lights the bottom-left lantern",
		SaveIndicator.icon.visible and SaveIndicator.get_node("Icon/Flame").modulate.a > .9
	)
	check(
		"save icon is at bottom-left and fits viewport",
		(
			SaveIndicator.icon.get_global_rect().position.x < 100
			and (
				SaveIndicator.icon.get_global_rect().end.y
				<= get_viewport().get_visible_rect().size.y
			)
		)
	)
	await photo("save_lantern")
	await close_rest()
	check("activated prompt is Rust", point.prompt == "Rust")
	# New live progress after resting survives death, while an explicit disk load uses saved data.
	GameProgress.data.inventory["unsaved_acorns"] = 7
	GameProgress.data.skills.append("test_skill")
	GameProgress.set_world_flag("opened_after_rest", true)
	p.health.maximum = 6
	p.magic.maximum = 5
	p.receive_hit(99, 19002, p.position + Vector3.RIGHT)
	get_tree().current_scene.get_node("HUD")._restart()
	await settle_scene()
	point = find_lily()
	check(
		"death keeps live inventory skills and permanent world",
		(
			GameProgress.data.inventory.unsaved_acorns == 7
			and "test_skill" in GameProgress.data.skills
			and GameProgress.world_flag("opened_after_rest")
		)
	)
	check("death restores upgraded full meters", p.health.current == 6 and p.magic.current == 5)
	check(
		"death returns to active lily",
		p.position.distance_to(point.get_node("Spawn").global_position) < .1
	)
	check("death uses smooth fade without loading card", not SceneTransit.loading_screen.visible)
	check(
		"disk save was not replaced by death",
		not SaveStore.read_slot(0).inventory.has("unsaved_acorns")
	)
	Checkpoints.start_slot(0)
	await settle_scene()
	check(
		"disk load is distinct from death",
		(
			not GameProgress.data.inventory.has("unsaved_acorns")
			and p.health.current == 5
			and p.magic.current == 4
		)
	)
	point = find_lily()
	check(
		"loaded lily is immediately open and burning",
		point.lit and point.opening == 1 and point.get_node("Flame").visible
	)
	# Ordinary rest-policy enemy returns; permanent-rule fixture remains defeated.
	var enemies := get_tree().get_nodes_in_group("damageable")
	var ordinary: Node = enemies[0]
	var permanent: Node = enemies[1]
	ordinary.respawn_rule = 1
	permanent.respawn_rule = 2
	permanent.persistent_id = &"test.permanent_guard"
	ordinary.receive_hit(999, 991, p.position, 0)
	permanent.receive_hit(999, 992, p.position, 0)
	await near_lily(point)
	check("repeat rest starts", Checkpoints.begin_rest(point, p))
	for i in 350:
		if (
			GameClock.paused
			and is_instance_valid(Checkpoints.rest_menu)
			and Checkpoints.rest_menu.visible
			and not SceneTransit.active
		):
			break
		check_no_kindle()
		await step(1)
	check(
		"sitting leaves defeated enemies untouched",
		ordinary.health.current == 0 and permanent.health.current == 0
	)
	Checkpoints.rest_menu.buttons.get_node("rest").grab_focus()
	await tap(JOY_BUTTON_A)
	await finish_transition()
	check("normal enemies return on rest", ordinary.health.current == ordinary.health.maximum)
	check("rest preserves configured hidden health labels", not ordinary.health_label.visible)
	check(
		"defeated permanent enemies stay gone",
		permanent.health.current == 0 and GameProgress.world_flag("enemy:test.permanent_guard")
	)
	# A later save also refreshes ordinary NPCs, without changing the checkpoint or permanent flags.
	ordinary.receive_hit(999, 993, p.position, 0)
	Checkpoints.menu_action(&"rest")
	check(
		"save refresh holds gameplay paused",
		SceneTransit.active and GameClock.paused and Checkpoints.rest_menu.busy
	)
	await finish_transition()
	check("repeat rest respawns ordinary enemy", ordinary.health.current == ordinary.health.maximum)
	check("repeat rest preserves permanent defeat", permanent.health.current == 0)
	await close_rest()
	# Move into a different real area and replace the checkpoint there.
	SceneTransit.change_scene("res://scenes/levels/ForestPassage.tscn")
	await settle_scene()
	point = find_lily()
	await ignite(point, "second")
	check(
		"second checkpoint replaces first across areas",
		(
			GameProgress.data.checkpoint.id == "lily.forest.cottage"
			and GameProgress.data.checkpoint.area == "forest.passage"
		)
	)
	check("both activations retained", GameProgress.data.lit_checkpoints.size() == 2)
	await close_rest()
	SceneTransit.change_scene("res://scenes/levels/ForestOpening.tscn")
	await settle_scene()
	GameProgress.set_world_flag("cross_area_live", true)
	p.receive_hit(99, 19003, p.position + Vector3.RIGHT)
	get_tree().current_scene.get_node("HUD")._restart()
	await settle_scene()
	point = find_lily()
	check(
		"cross-area death returns to latest lily",
		(
			get_tree().current_scene.name == "ForestPassage"
			and p.position.distance_to(point.get_node("Spawn").global_position) < .1
		)
	)
	check("cross-area death preserves live progress", GameProgress.world_flag("cross_area_live"))
	# Commit a distinctive game for the fresh-process continuation.
	GameProgress.data.inventory["proof"] = 31
	GameProgress.set_world_flag("restart_proof", true)
	GameProgress.save(p)
	get_tree().current_scene.get_node("HUD")._return_to_title()
	await finish_transition()
	title = get_tree().current_scene
	check("Continue now visible", title.get_node("Artwork/Options/Continue").visible)
	var two := SaveSchema.new_game()
	two.world["other_world"] = true
	SaveStore.write_slot(1, two, true)
	var three := SaveSchema.new_game()
	three.inventory["proof"] = 99
	SaveStore.write_slot(2, three, true)
	SaveStore.mark_played(0)
	title.get_node("Artwork/Options/Continue").grab_focus()
	await tap(JOY_BUTTON_A)
	picker = title.get_node("SaveSlots")
	check(
		"Continue focuses last played existing save",
		get_viewport().gui_get_focus_owner() == picker.slots[0].get_node("Select")
	)
	await frames(20)
	await photo("filled_slots")
	picker._ask_delete(2)
	check(
		"deletion defaults to keep game",
		get_viewport().gui_get_focus_owner() == picker.get_node("Confirm/Panel/Column/Cancel")
	)
	await tap(JOY_BUTTON_DPAD_UP)
	check(
		"delete confirmation traps controller focus",
		picker.get_node("Confirm").is_ancestor_of(get_viewport().gui_get_focus_owner())
	)
	await photo("delete_confirmation")
	await tap(JOY_BUTTON_B)
	check("cancel deletion preserves file", SaveStore.read_slot(2).inventory.proof == 99)
	picker.close()
	await frames(18)
	title.get_node("Artwork/Options/NewGame").grab_focus()
	await tap(JOY_BUTTON_A)
	check(
		"all-full New Game shows explicit deletion instruction",
		picker.status.text.contains("Verwijder eerst")
	)
	var before_save_time: float = SaveStore.read_slot(1).last_saved_unix
	picker.slots[1].get_node("Select").grab_focus()
	await tap(JOY_BUTTON_A)
	await settle_scene()
	check(
		"filled slot selected from New Game loads instead of overwrites",
		(
			GameProgress.active_slot == 1
			and GameProgress.world_flag("other_world")
			and SaveStore.read_slot(1).last_saved_unix == before_save_time
		)
	)
	check(
		"new slot has independent closed lily",
		not find_lily().lit and GameProgress.data.lit_checkpoints.is_empty()
	)
	check(
		"first slot still independent",
		(
			SaveStore.read_slot(0).inventory.proof == 31
			and SaveStore.read_slot(2).inventory.proof == 99
		)
	)
	finish()


func check_no_kindle() -> void:
	if p.state == "kindle":
		check("active lily must not repeat ignition", false)


func reload_phase() -> void:
	var title := get_tree().current_scene
	check("fresh process sees saved Continue", title.get_node("Artwork/Options/Continue").visible)
	Checkpoints.start_slot(0)
	await settle_scene()
	var point := find_lily()
	check(
		"fresh process restores latest cross-area checkpoint",
		(
			get_tree().current_scene.name == "ForestPassage"
			and p.position.distance_to(point.get_node("Spawn").global_position) < .1
		)
	)
	check(
		"fresh process restores inventory and world",
		GameProgress.data.inventory.get("proof") == 31 and GameProgress.world_flag("restart_proof")
	)
	check(
		"fresh process keeps both lilies lit",
		(
			GameProgress.data.lit_checkpoints.size() == 2
			and point.lit
			and point.opening == 1
			and point.get_node("Embers").emitting
		)
	)
	check(
		"fresh process arrives with full meters",
		p.health.current == p.health.maximum and p.magic.current == p.magic.maximum
	)
	await frames(70)
	await photo("fresh_process_flame")
	var time_before: float = GameProgress.data.play_seconds
	await step(120)
	check("active seconds counted", GameProgress.data.play_seconds > time_before + .8)
	get_tree().current_scene.get_node("HUD")._pause()
	time_before = GameProgress.data.play_seconds
	await frames(35)
	check("pause time excluded", is_equal_approx(time_before, GameProgress.data.play_seconds))
	get_tree().current_scene.get_node("HUD")._return_to_title()
	await finish_transition()
	title = get_tree().current_scene
	title._open_slots(false)
	var picker := title.get_node("SaveSlots")
	for i in 3:
		picker._ask_delete(i)
		picker.get_node("Confirm/Panel/Column/Delete").grab_focus()
		await tap(JOY_BUTTON_A)
		check(
			"explicit confirmation deletes only selected slot %d" % i,
			SaveStore.inspect_slot(i).state == "empty"
		)
	check(
		"Continue disappears after deleting last save",
		not title.get_node("Artwork/Options/Continue").visible
	)
	picker.close()
	await frames(20)
	await photo("title_after_last_delete")


func passage_rest_review() -> void:
	var initial := SaveSchema.new_game()
	initial.opening_completed = true
	initial.checkpoint.id = "lily.forest.cottage"
	initial.checkpoint.area = "forest.passage"
	var created := SaveStore.write_slot(0, initial, true)
	check("disposable Passage slot created", created.ok)
	if not created.ok:
		return
	Checkpoints.start_slot(0)
	await settle_scene()
	var lilies := get_tree().get_nodes_in_group("vuurlelies")
	check("actual ForestPassage has three lilies", lilies.size() == 3)
	var ids: Array[StringName] = []
	for point: Vuurlelie in lilies:
		var label := String(point.name)
		check(
			label + " has a unique saved identity",
			not point.checkpoint_id.is_empty() and point.checkpoint_id not in ids
		)
		ids.append(point.checkpoint_id)
		check(
			label + " has its area and interaction enabled",
			point.enabled and point.area != null and point.area.code == &"forest.passage"
		)
		await near_lily(point)
		check(
			label + " offers Ontsteek", p.interaction.target == point and point.prompt == "Ontsteek"
		)
		await photo("passage_" + label + "_prompt")
		if p.interaction.target != point:
			continue
		p.health.damage(2)
		p.magic.try_spend(2)
		p.use_test_input = false
		InputRouter.blocked_through_frame = -1
		await tap(JOY_BUTTON_Y)
		p.use_test_input = true
		for i in 500:
			if p.state == "resting":
				break
			await step(1)
		check(label + " opens its rest menu", Checkpoints.active and p.state == "resting")
		if not Checkpoints.active or p.state != "resting":
			Checkpoints.cancel_rest()
			continue
		await frames(20)
		await click_button(Checkpoints.rest_menu.buttons.get_node("rest"))
		for i in 300:
			if not Checkpoints.rest_menu.busy:
				break
			await frames(1)
		check(
			label + " restores health and magic",
			p.health.current == p.health.maximum and p.magic.current == p.magic.maximum
		)
		var saved := SaveStore.read_slot(0)
		check(
			label + " really saves its checkpoint",
			(
				saved.checkpoint.id == String(point.checkpoint_id)
				and String(point.checkpoint_id) in saved.lit_checkpoints
			)
		)
		await frames(20)
		await photo("passage_" + label + "_rest")
		await click_button(Checkpoints.rest_menu.buttons.get_node("continue"))
		await frames(25)
		check(
			label + " returns control and offers Rust",
			not Checkpoints.active and p.state == "locomotion" and point.prompt == "Rust"
		)


func start_reload_checks() -> void:
	# A failed New Game already wrote its slot. It must work without deleting that save.
	var initial := SaveSchema.new_game()
	initial.inventory["recovery_fixture"] = 1
	check("existing unfinished slot fixture saved", SaveStore.write_slot(1, initial, true).ok)
	check("existing unfinished slot starts", Checkpoints.start_slot(1))
	await settle_scene()
	check("unfinished slot plays opening", p.state == "entrance", p.state)
	check("existing slot data retained", GameProgress.data.inventory.get("recovery_fixture") == 1)
	for i in 1000:
		if p.state != "entrance":
			break
		await step(1)
	check("recovered opening completes", SaveStore.read_slot(1).opening_completed)
	check("completed first slot loads", Checkpoints.start_slot(0))
	await settle_scene()
	check(
		"completed opening loads on safe ground without replaying intro",
		p.state == "locomotion" and p.position.distance_to(Vector3(-3, 0, 7.4)) < .1,
		p.position
	)
	check("start anchor is on walkable ground", p.is_on_floor())
	check(
		"recovered slot remains independent",
		not GameProgress.data.inventory.has("recovery_fixture")
	)
	await photo("new_game_safe_start")


func finish() -> void:
	var report := {
		"failures": failures,
		"checks": results,
		"phase": phase,
		"render_frames": Engine.get_frames_drawn() - render_start,
		"renderer": RenderingServer.get_current_rendering_method()
	}
	(
		FileAccess
		. open("res://captures/vuurlelie/" + phase + "_checks.json", FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	print("CHECKPOINT_REPLAY_RESULT ", JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
