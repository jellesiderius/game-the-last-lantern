extends "res://tests/room_replay.gd"
## Focused lock-on selection with its own dummies: nearest acquisition, screen left/right
## switching, no targets behind the player and no wrap-around past the edge.


func screen_x(node: Node3D) -> float:
	return get_viewport().get_camera_3d().unproject_position(node.global_position).x


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	var camera := get_viewport().get_camera_3d()
	var right := Vector3(camera.global_basis.x.x, 0, camera.global_basis.x.z).normalized()
	var ahead := Vector3(-camera.global_basis.z.x, 0, -camera.global_basis.z.z).normalized()
	# Screen layout seen from the player: far-left, left, centre (nearest), right, behind.
	var layout := [
		-right * 3.2 + ahead * 2.4, -right * 1.4 + ahead * 2.6, ahead * 1.8,
		right * 1.6 + ahead * 2.8, right * .6 - ahead * 2.5
	]
	# Find open ground: every dummy needs a clear sight line, or lock-on ignores it.
	var origin := Vector3(0, 0, 4)
	var space := get_viewport().get_world_3d().direct_space_state
	var found := false
	for x in range(-10, 11, 2):
		for z in range(-10, 11, 2):
			var at := Vector3(x, .4, z)
			var clear := true
			for offset in layout:
				var ray := PhysicsRayQueryParameters3D.create(at, at + offset, CombatLayers.WORLD)
				var down := PhysicsRayQueryParameters3D.create(
					at + offset + Vector3.UP, at + offset + Vector3.DOWN, CombatLayers.WORLD
				)
				if not space.intersect_ray(ray).is_empty() or space.intersect_ray(down).is_empty():
					clear = false
					break
			if clear:
				origin = Vector3(x, 0, z)
				found = true
				break
		if found:
			break
	check("found open ground for the lock layout", found, origin)
	await reset(origin)
	for target in targets:
		target.disabled = true
	var scene: PackedScene = load("res://scenes/actors/npcs/friendly/TrainingDummy.tscn")
	var dummies: Array[Node3D] = []
	for offset in layout:
		var dummy: Node3D = scene.instantiate()
		arena.add_child(dummy)
		dummy.global_position = p.global_position + offset
		dummies.append(dummy)
	await step(6)
	for dummy in dummies:
		print(
			"DUMMY ", dummy.global_position, " lockable=", TargetLock.is_lockable(dummy),
			" sight=", p.target_lock.has_line_of_sight(dummy)
		)
	var far_left := dummies[0]
	var left := dummies[1]
	var center := dummies[2]
	var right_dummy := dummies[3]
	var behind := dummies[4]
	var lock: TargetLock = p.target_lock
	check("dummies are lockable", lock.candidates().size() == 5, lock.candidates().size())
	lock.toggle(ahead)
	check("acquires the nearest target in front", lock.target == center, lock.target)
	lock.switch(1)
	check("right picks the next target to the right", lock.target == right_dummy)
	lock.switch(1)
	check("right past the edge keeps the lock (no wrap, no target behind)", lock.target == right_dummy)
	lock.switch(-1)
	check("left returns to the centre", lock.target == center)
	lock.switch(-1)
	check("left picks the nearest left target first", lock.target == left)
	lock.switch(-1)
	check("left again picks the far-left target", lock.target == far_left)
	lock.switch(-1)
	check("left past the edge keeps the lock", lock.target == far_left)
	check("the target behind the player is never chosen by switching", lock.target != behind)
	for i in [0, 1, 2]:
		check(
			"screen order sanity %d" % i,
			screen_x(dummies[i]) < screen_x(dummies[i + 1]),
			[screen_x(dummies[i]), screen_x(dummies[i + 1])]
		)
	lock.release()
	for dummy in dummies:
		dummy.queue_free()
	print("LOCK_SWITCH_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
