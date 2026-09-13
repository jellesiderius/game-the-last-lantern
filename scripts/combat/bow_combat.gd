class_name BowCombat
extends Node
## Owns bow rules; player.state and player.action_time remain the single authority.
signal arrow_fired(projectile: MagicArrow, damage: float)
const ARROW_SCENE = preload("res://scenes/projectiles/Arrow.tscn")
@export var settings: BowSettings
var aim_held := false
var shot_pending := false
var shot_damage := 1.0
var shots_fired := 0
var charged := false
var ready_pose := false
var direct_draw := false
var appearance: WeaponDefinition
@onready var player: PlayerCharacter = get_parent()
@onready var aim_line: MeshInstance3D = $AimLine


func active() -> bool:
	return player.state.begins_with("bow_")


func capture_input() -> void:
	# PC: Q/RMB alone owns press-to-draw and release-to-fire.
	if Input.is_action_just_pressed("bow_fire"):
		player.request_action("bow_direct_press", player.input_device)
	if Input.is_action_just_released("bow_fire"):
		player.request_action("bow_direct_release", player.input_device)
	# Controller keeps the separate L2 aim / circle draw controls.
	if Input.is_action_just_pressed("bow_aim"):
		aim_held = true
		player.request_action("bow_aim", player.input_device)
	if Input.is_action_just_released("bow_aim"):
		aim_held = false
		player.request_action("bow_cancel", player.input_device)
	if aim_held or active():
		if Input.is_action_just_pressed("bow_shoot"):
			player.request_action("bow_draw", player.input_device)
		if Input.is_action_just_released("bow_shoot"):
			player.request_action("bow_release", player.input_device)


func handle_request(action: String) -> bool:
	match action:
		"bow_direct_press":
			if player.state in ["locomotion", "bow_aim"]:
				_begin_draw(player.state == "locomotion")
			return true
		"bow_direct_release":
			_release_draw(true)
			return true
		"bow_aim":
			aim_held = true
			if player.state == "locomotion":
				begin_aim(false)
			return true
		"bow_cancel":
			aim_held = false
			if active() and player.state != "bow_empty":
				unequip()
			return true
		"bow_draw":
			if player.state == "bow_aim":
				_begin_draw(false)
			return true
		"bow_release":
			_release_draw(aim_held)
			return true
	if active() and action in ["light", "heavy"]:
		if player.state == "bow_shoot":
			return true
		aim_held = false
		player._locomotion()
	return active() and action == "release"


func _begin_draw(equip: bool) -> void:
	if not player.magic.check_available():
		_reject_draw()
		return
	direct_draw = equip
	charged = false
	shot_pending = false
	player._enter("bow_draw", "bow_equip" if direct_draw else "bow_draw")


func _reject_draw() -> void:
	# The shared action clock owns this one-shot feedback, including interruptions.
	interrupt()
	player._enter("bow_empty", "bow_empty")
	player.visual.set_bow_mode(false)
	player.visual.bow.energy(0.0, -1.0, false)


func _release_draw(allowed: bool) -> void:
	if player.state != "bow_draw":
		return
	if allowed and player.action_time >= settings.minimum_draw:
		shot_damage = (
			player.moveset.find("attack_1").damage
			* (settings.charged_multiplier if charged else 1.0)
		)
		shot_pending = true
		player.locked_direction = player.facing
		player._enter("bow_shoot", "bow_release")
	elif aim_held:
		begin_aim(true)
	else:
		unequip()


func begin_aim(already_equipped: bool) -> void:
	direct_draw = false
	ready_pose = already_equipped
	shot_pending = false
	charged = false
	player.light_buffer = -1
	player.heavy_buffer = -1
	player.light_link_requested = false
	player._enter("bow_aim", "bow_aim" if already_equipped else "bow_equip")


func unequip() -> void:
	shot_pending = false
	charged = false
	player._enter("bow_recover", "bow_unequip")


func interrupt() -> void:
	direct_draw = false
	shot_pending = false
	charged = false
	aim_line.hide()


func update_state(delta: float) -> void:
	# Also handle a future drain effect removing magic during an existing draw.
	if player.state == "bow_draw" and not player.magic.check_available():
		_reject_draw()
		return
	match player.state:
		"bow_aim":
			if player.action_time >= settings.equip_duration:
				player.clip = "bow_aim"
		"bow_draw":
			charged = (
				settings.charged_arrow_unlocked and player.action_time >= settings.charged_draw
			)
			if player.action_time >= settings.full_draw_duration():
				_release_draw(true)
				return
			if direct_draw and player.action_time < direct_equip_duration():
				player.clip = "bow_equip"
			elif player.action_time < settings.minimum_draw:
				player.clip = "bow_draw"
			else:
				player.clip = "bow_hold"
	if (
		player.state == "bow_shoot"
		and not aim_held
		and player.action_time >= settings.recovery - settings.unequip_duration
	):
		player.clip = "bow_unequip"
	if player.state in ["bow_aim", "bow_draw"]:
		var device := (
			"controller"
			if player.input_device == "controller"
			else ("keyboard" if player.use_test_input else "mouse")
		)
		player._face(player.aim_direction(device), delta)


func animation_time() -> float:
	if player.state == "bow_empty":
		return clampf(player.action_time / settings.empty_duration, 0.0, 1.0) * .32
	if player.clip == "bow_unequip" and player.state == "bow_shoot":
		return maxf(0, player.action_time - (settings.recovery - settings.unequip_duration))
	if player.clip == "bow_aim":
		return fmod(
			maxf(0, player.action_time - (0.0 if ready_pose else settings.equip_duration)), .6
		)
	if player.clip == "bow_equip" and direct_draw:
		return player.action_time / direct_equip_duration() * .18
	if player.clip == "bow_draw":
		var start_time := direct_equip_duration() if direct_draw else 0.0
		return (player.action_time - start_time) / (settings.minimum_draw - start_time) * .25
	if player.clip == "bow_hold":
		return fmod(player.action_time - settings.minimum_draw, .5)
	if player.clip == "bow_release":
		return minf(.2, player.action_time)
	return player.action_time


func after_animation() -> void:
	if appearance != player.visual.weapon.definition:
		appearance = player.visual.weapon.definition
		appearance.tint_shader(aim_line)
		player.visual.bow.apply_appearance(appearance)
	var visible_bow := active() and player.state != "bow_empty"
	player.visual.set_bow_mode(visible_bow)
	if not visible_bow:
		aim_line.hide()
		if player.state == "bow_empty" and player.action_time >= settings.empty_duration:
			if aim_held:
				begin_aim(false)
			else:
				player._locomotion()
		return
	var show_arrow := player.state == "bow_draw" or (player.state == "bow_shoot" and shot_pending)
	player.visual.bow.present(
		player.visual.draw_socket.global_position, show_arrow, charged, player.action_time
	)
	var draw_amount := (
		clampf(player.action_time / settings.minimum_draw, 0, 1)
		if player.state == "bow_draw"
		else 0.0
	)
	var release_progress := (
		clampf((player.action_time - settings.release_moment) / .12, 0, 1)
		if player.state == "bow_shoot" and player.action_time >= settings.release_moment
		else -1.0
	)
	player.visual.bow.energy(draw_amount, release_progress, charged)
	aim_line.material_override.set_shader_parameter("charge", draw_amount)
	aim_line.material_override.set_shader_parameter("clock", GameClock.elapsed)
	_update_aim_line()
	if (
		player.state == "bow_shoot"
		and shot_pending
		and player.action_time >= settings.release_moment
	):
		shot_pending = false
		if player.magic.try_spend():
			var arrow: MagicArrow = ARROW_SCENE.instantiate()
			arrow.appearance = appearance
			get_tree().current_scene.add_child(arrow)
			var muzzle: Vector3 = player.visual.bow.muzzle()
			var origin := Vector3(player.global_position.x, muzzle.y, player.global_position.z)
			arrow.launch(player, origin, muzzle, player.locked_direction, shot_damage, settings)
			shots_fired += 1
			InputRouter.feedback(.10, .04, .05)
			player.visual.bow.held_arrow.hide()
			player.get_node("SwingSound").pitch_scale = 1.55
			player.get_node("SwingSound").play()
			arrow_fired.emit(arrow, shot_damage)
		else:
			_reject_draw()
		player.visual.bow.held_arrow.hide()
	if player.state == "bow_shoot" and player.action_time >= settings.recovery:
		if aim_held:
			begin_aim(true)
		else:
			player._locomotion()
	elif player.state == "bow_recover" and player.action_time >= settings.unequip_duration:
		player._locomotion()


func _update_aim_line() -> void:
	aim_line.visible = player.state in ["bow_aim", "bow_draw"]
	if not aim_line.visible:
		return
	var start: Vector3 = player.visual.bow.global_position
	var origin := Vector3(player.global_position.x, start.y, player.global_position.z)
	var end := start + player.facing * minf(settings.aim_line_length, settings.maximum_distance)
	var query := PhysicsRayQueryParameters3D.create(
		origin, start, CombatLayers.WORLD | CombatLayers.TARGET_HURTBOX
	)
	query.collide_with_areas = true
	query.hit_from_inside = true
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position
		start = origin
	else:
		query.from = start
		query.to = end
		hit = player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			end = hit.position
	var offset := end - start
	aim_line.global_position = (start + end) * .5
	aim_line.global_basis = (
		Basis(Quaternion(Vector3.UP, offset.normalized()))
		if offset.length_squared() > .000001
		else Basis.IDENTITY
	)
	aim_line.scale = Vector3(1, maxf(.001, offset.length()), 1)


func direct_equip_duration() -> float:
	return minf(.1, settings.minimum_draw * .4)
