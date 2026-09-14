extends "res://tests/room_replay.gd"
## Close frames through light swings on open ground: blade, crescent and footwork.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	var camera := get_viewport().get_camera_3d()
	var original_size := camera.size
	camera.size = 4.5
	for swing in 3:
		await reset(Vector3(0, 0, 4))
		p.visual.weapon.last_light_direction = 1.0 if swing % 2 == 0 else -1.0
		await step(20)
		if swing == 0:
			var stowed_weapon: MeleeWeapon = p.visual.weapon
			var stowed_blade: Vector3 = (
				stowed_weapon.get_node("BladeTip").global_position
				- stowed_weapon.get_node("BladeBase").global_position
			)
			var stowed_aim := Basis(Vector3.UP, atan2(-p.facing.x, -p.facing.z))
			print(
				"STOW socket %s blade %s base %s" % [
					p.visual.socket.bone_name,
					stowed_aim.inverse() * stowed_blade.normalized(),
					stowed_aim.inverse() * (stowed_weapon.get_node("BladeBase").global_position - p.global_position)
				]
			)
			await capture("slash_stow")
		await start("light")
		var weapon: MeleeWeapon = p.visual.weapon
		var aim := Basis(Vector3.UP, atan2(-p.locked_direction.x, -p.locked_direction.z))
		for moment in [.04, .09, .11, .13, .16, .2, .26, .34]:
			while p.action_time < moment and p.state == "light_attack":
				await step(1)
			var blade: Vector3 = (
				weapon.get_node("BladeTip").global_position - weapon.get_node("BladeBase").global_position
			)
			# Character space: +x right, +y up, -z forward.
			print(
				"SWING %d dir %+.0f t=%.2f blade %s" % [
					swing, weapon.swing_direction, p.action_time, aim.inverse() * blade.normalized()
				]
			)
			await capture("slash_%d_%03d" % [swing, int(moment * 1000)])
		await until_idle()
	# Roll frames, seen from the side of the travel direction.
	await reset(Vector3(0, 0, 4))
	p.facing = Vector3.RIGHT
	p.pivot.rotation.y = -PI * .5
	await step(20)
	await start("dodge")
	for moment in [.03, .08, .14, .2, .27, .34, .41]:
		while p.action_time < moment and p.state == "roll":
			await step(1)
		await capture("roll_%03d" % int(moment * 1000))
	camera.size = original_size
	print("SLASH_CLOSEUP_FINISHED")
	get_tree().quit(0)
