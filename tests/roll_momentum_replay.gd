extends "res://tests/room_replay.gd"
## Walk → roll → walk keeps momentum: with the stick held the speed never drops below walking
## pace, the roll distance is unchanged and a queued roll attack still fires.


func flat_speed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	# Open lane: walk-up, the roll and the walk-out must not touch any world collider.
	var lane := p.move_direction(Vector2.RIGHT).normalized()
	var space := get_viewport().get_world_3d().direct_space_state
	var origin := Vector3.ZERO
	var found := false
	for x in range(-11, 12, 2):
		for z in range(-11, 12, 2):
			var at := Vector3(x, .3, z)
			var clear := true
			for side in [-.35, 0.0, .35]:
				var offset: Vector3 = lane.cross(Vector3.UP) * side
				var ray := PhysicsRayQueryParameters3D.create(
					at + offset, at + offset + lane * 9.0, CombatLayers.WORLD
				)
				if not space.intersect_ray(ray).is_empty():
					clear = false
			var down := PhysicsRayQueryParameters3D.create(
				at + lane * 9.0 + Vector3.UP, at + lane * 9.0 + Vector3.DOWN * 2, CombatLayers.WORLD
			)
			if clear and not space.intersect_ray(down).is_empty():
				origin = Vector3(x, 0, z)
				found = true
				break
		if found:
			break
	check("found an open lane", found, origin)
	await reset(origin)
	p.test_input = Vector2.RIGHT
	await step(60)
	check("reaches full walking speed", absf(flat_speed() - p.settings.max_speed) < .05, flat_speed())
	var start := p.global_position
	await start("dodge")
	var lowest := INF
	var speeds: Array = []
	while p.state == "roll":
		lowest = minf(lowest, flat_speed())
		speeds.append(snappedf(flat_speed(), .01))
		await step(1)
	var roll_distance := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
	var after_lowest := INF
	for i in 30:
		await step(1)
		after_lowest = minf(after_lowest, flat_speed())
	check(
		"roll never slows below walking pace",
		lowest >= p.settings.max_speed - .05,
		[lowest, speeds]
	)
	check(
		"walking after the roll keeps momentum",
		after_lowest >= p.settings.max_speed - .3,
		after_lowest
	)
	check("roll distance unchanged", roll_distance > 3.2 and roll_distance < 3.6, roll_distance)
	await reset(origin)
	await start("dodge")
	while p.action_time < .3:
		await step(1)
	await start("light")
	var guard := 0
	while p.state == "roll" and guard < 120:
		await step(1)
		guard += 1
	check("light click late in the roll starts the roll attack", p.state == "roll_attack", p.state)
	p.test_input = Vector2.ZERO
	print("ROLL_MOMENTUM_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
