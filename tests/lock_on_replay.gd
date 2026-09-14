extends "res://tests/room_replay.gd"
## Target lock in the saved room: acquisition, logical switching, aim, hand-over and release.


func screen_x(node: Node3D) -> float:
	return get_viewport().get_camera_3d().unproject_position(node.global_position).x


func direction_to(node: Node3D) -> Vector3:
	var offset: Vector3 = node.global_position - p.global_position
	offset.y = 0
	return offset.normalized()


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	await reset(Vector3(0, 0, .5))
	var lock: TargetLock = p.target_lock
	var dummies: Array = targets.filter(func(actor): return actor.brain == null)
	check("room has three passive lock targets", dummies.size() >= 3, dummies.size())
	var left = dummies[0]
	var center = dummies[1]
	var right = dummies[2]
	var layout := [
		[left, Vector3(-2, 0, -2)], [center, Vector3(0, 0, -2.5)], [right, Vector3(2, 0, -2)]
	]
	for pair in layout:
		pair[0].position = pair[1]
		pair[0].spawn_position = pair[1]
		pair[0].disabled = false
	await step(3)
	# Name the three by their real on-screen order instead of assuming the camera yaw.
	var ordered := [left, center, right]
	ordered.sort_custom(func(a, b): return screen_x(a) < screen_x(b))
	left = ordered[0]
	center = ordered[1]
	right = ordered[2]
	lock.toggle(direction_to(right))
	check("acquires the candidate in front of the facing direction", lock.target == right)
	lock.release()
	lock.toggle(direction_to(center))
	check("acquires the middle target when facing it", lock.target == center)
	lock.switch(1)
	check("switching right picks the next target to the right", lock.target == right)
	lock.switch(-1)
	check("switching left returns to the middle target", lock.target == center)
	lock.switch(-1)
	check("switching left again picks the left target", lock.target == left)
	lock.switch(-1)
	check("switching past the left edge keeps the lock", lock.target == left)
	lock.switch(1)
	check("switching right from the left edge picks the middle target", lock.target == center)
	lock.switch(1)
	lock.switch(1)
	check("switching past the right edge keeps the lock", lock.target == right)
	lock.switch(-1)
	lock.switch(-1)
	lock.switch(1)
	lock.switch(1)
	check("switching right twice lands on the right target", lock.target == right)
	# Face away first: turning and aiming must come from the lock, not the start pose.
	p.facing = Vector3.BACK
	p.pivot.rotation.y = PI
	await step(60)
	var marker: Control = arena.get_node("HUD/Root/LockMarker")
	check("HUD marker shows the locked target", marker.visible)
	check(
		"idle player turns to face the locked target",
		p.facing.dot(direction_to(right)) > .98,
		p.facing
	)
	check(
		"aim follows the lock instead of the cursor",
		p.aim_direction("mouse").dot(direction_to(right)) > .999
	)
	check(
		"camera framing leans toward the locked target",
		p.camera_look_offset().normalized().dot(direction_to(right)) > .99
	)
	# Strafe sideways relative to the target: the body keeps facing it while moving.
	var strafe := direction_to(right).cross(Vector3.UP)
	var before: Vector3 = p.global_position
	var worst_facing := 1.0
	p.test_input = world_input(strafe)
	for i in 60:
		await step(1)
		if i > 20:
			worst_facing = minf(worst_facing, p.facing.dot(direction_to(right)))
	p.test_input = Vector2.ZERO
	var moved: Vector3 = p.global_position - before
	moved.y = 0
	check("locked movement strafes instead of turning away", moved.length() > 1.0, moved)
	check("body keeps facing the target while strafing", worst_facing > .97, worst_facing)
	check(
		"strafing is slower than free running",
		moved.length() / .5 < p.settings.max_speed * .95,
		moved.length() / .5
	)
	await until_idle()
	await step(30)
	p.facing = Vector3.BACK
	await start("light")
	await step(2)
	check(
		"melee commits toward the locked target",
		p.locked_direction.dot(direction_to(right)) > .99,
		p.locked_direction
	)
	await until_idle()
	right.receive_hit(100, GameClock.next_attack_id(), p.global_position)
	await step(2)
	check(
		"defeated target hands the lock to the nearest remaining target",
		lock.target == center,
		lock.target
	)
	var remaining: Node3D = lock.target
	remaining.position = Vector3(0, 0, -12)
	await step(2)
	check("walking out of range releases the lock", not lock.is_active())
	await step(1)
	check("HUD marker hides without a lock", not marker.visible)
	remaining.position = Vector3(2, 0, -2)
	await step(2)
	lock.toggle(Vector3.FORWARD)
	check("toggle acquires again", lock.is_active())
	lock.toggle(Vector3.FORWARD)
	check("toggle releases", not lock.is_active())
	var report := {
		"failures": failures,
		"render_cap": render_cap,
		"physics_fps": Engine.physics_ticks_per_second,
		"results": results
	}
	var f := FileAccess.open(
		"res://captures/lock_on_checks_" + str(render_cap) + ".json", FileAccess.WRITE
	)
	f.store_string(JSON.stringify(report, "\t"))
	print("LOCK_ON_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
