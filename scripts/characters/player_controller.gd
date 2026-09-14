class_name PlayerCharacter
extends CharacterBody3D
signal state_changed(next: String)
signal entrance_finished
var entrance: EntranceSequence
var entrance_launched := false
var entrance_landed := false
var entrance_landing_time := 0.0
@export var settings: MovementSettings
@export var moveset: CombatMoveset
var definition: CharacterDefinition
var state := "locomotion"
var action_time := 0.0
var clip := ""
var facing := Vector3.FORWARD
var locked_direction := Vector3.FORWARD
var input_direction := Vector3.ZERO
var input_strength := 0.0
var input_device := "keyboard"
var charge_aim_device := "keyboard"
var combo_step := 0
var light_link_requested := false
var roll_attack_queued := false
var dodge_buffer := -1.0
var light_buffer := -1.0
var heavy_buffer := -1.0
var next_aim_device := "keyboard"
var roll_cooldown := 0.0
var invulnerability := 0.0
var charge_amount := 0.0
var active_window := false
var heavy_held := false
var pending_inputs: Array[String] = []
var attacks_started: Array[String] = []
var accepted_hits: Dictionary = {}
var test_input := Vector2.ZERO
var use_test_input := false
var was_paused := false
var airborne_time := 0.0
## Cosmetic landing clock; movement and action input remain immediately available.
var landing_time := -1.0
## Lock switches latch from events: a wheel click presses and releases within one frame.
var pending_lock_switch := 0
var lock_flick_held := false
signal landed(impact_speed: float)
@onready var visual: CharacterVisual = $VisualPivot/CharacterVisual
@onready var pivot: Node3D = $VisualPivot
@onready var health: HealthComponent = $Health
@onready var magic: MagicComponent = $Magic
@onready var bow: BowCombat = $BowCombat
@onready var interaction: ActorInteraction = $Interaction
@onready var ranged_loadout: RangedLoadout = $RangedLoadout
@onready var feedback: CombatFeedback = $CombatFeedback
@onready var ground_feedback: GroundFeedback = $GroundFeedback
@onready var target_lock: TargetLock = $TargetLock


func _enter_tree() -> void:
	if is_node_ready():
		GameSession.player = self
	definition = GameSession.selected_character
	if definition and definition.movement:
		settings = definition.movement.duplicate()
	if (
		definition
		and (
			get_node("VisualPivot/CharacterVisual").scene_file_path
			!= definition.visual_scene.resource_path
		)
	):
		var old := get_node("VisualPivot/CharacterVisual")
		old.get_parent().remove_child(old)
		old.free()
		var model := definition.visual_scene.instantiate()
		model.name = "CharacterVisual"
		get_node("VisualPivot").add_child(model)
	if definition:
		for path in ["CollisionShape3D", "Hurtbox/CollisionShape3D"]:
			var collision: CollisionShape3D = get_node(path)
			collision.shape = collision.shape.duplicate()
			collision.shape.radius = definition.body_radius
			collision.shape.height = definition.body_height
			collision.position.y = definition.body_height * .5
		get_node("Health").maximum = definition.maximum_health


var scene_travel_done := true
var travel_direction := Vector3.FORWARD
var travel_speed := 0.0
var travel_distance := 0.0
var travel_elapsed := 0.0
var travel_timeout := 2.0


func begin_scene_travel(direction: Vector3, speed: float, distance: float) -> void:
	suspend_controls()
	entrance = null
	travel_direction = direction.normalized()
	travel_speed = speed
	travel_distance = distance
	travel_elapsed = 0.0
	travel_timeout = distance / maxf(speed, .1) + .8
	scene_travel_done = false
	_enter("scene_travel", "")


func finish_scene_travel() -> void:
	suspend_controls()
	scene_travel_done = true
	airborne_time = 0.0
	_locomotion()


func _update_scene_travel(delta: float) -> void:
	if delta <= 0.0:
		return
	suspend_controls()
	action_time += delta
	travel_elapsed += delta
	var moving := not scene_travel_done
	var flat := Vector3(velocity.x, 0, velocity.z).move_toward(
		travel_direction * travel_speed if moving else Vector3.ZERO, settings.acceleration * delta
	)
	velocity.x = flat.x
	velocity.z = flat.z
	velocity.y = -.2 if is_on_floor() else velocity.y - settings.gravity * delta
	_face(travel_direction, delta)
	var before := global_position
	move_and_slide()
	travel_distance -= Vector2(global_position.x - before.x, global_position.z - before.z).length()
	# A blocked threshold never traps the transition in an endless walk animation.
	if travel_distance <= .01 or travel_elapsed >= travel_timeout:
		scene_travel_done = true
	ground_feedback.sample_motion(delta, moving)
	visual.sample("", 0, Vector2(velocity.x, velocity.z).length(), delta)


var rest_point: Node3D
var rest_already_lit := false
var rest_destination := Vector3.ZERO


func begin_rest_action(point: Node3D, already_lit: bool) -> void:
	suspend_controls()
	_clear_buffers()
	rest_point = point
	rest_already_lit = already_lit
	var away := global_position - point.global_position
	away.y = 0
	if away.length_squared() < .01:
		away = -facing
	rest_destination = point.global_position + away.normalized() * point.rest_distance
	_enter("rest_approach", "")


func _update_rest_action(delta: float) -> void:
	if delta <= 0:
		return
	if not is_instance_valid(rest_point):
		Checkpoints.cancel_rest.call_deferred()
		return
	suspend_controls()
	action_time += delta
	var toward := rest_point.global_position - global_position
	toward.y = 0
	_face(toward.normalized(), delta)
	if state == "rest_approach":
		var distance := rest_destination - global_position
		distance.y = 0
		var speed := minf(2.0, distance.length() / maxf(delta, .001))
		velocity = distance.normalized() * speed + Vector3.DOWN * .2
		move_and_slide()
		visual.sample("", 0, speed, delta)
		if distance.length() < .035 or action_time > 1.2:
			velocity = Vector3.ZERO
			_enter(
				"rest_settle" if rest_already_lit else "kindle",
				visual.rest_clip if rest_already_lit else visual.kindle_clip
			)
		return
	velocity = Vector3.DOWN * .2
	move_and_slide()
	visual.sample(clip, action_time, 0.0, delta)
	if state == "kindle":
		rest_point.sample_ignition(action_time, visual.carried_light_origin())
	if action_time >= (.55 if rest_already_lit else 2.25):
		_enter("resting", visual.rest_clip)
		Checkpoints.finish_sitting.call_deferred()


func hold_rest_pose() -> void:
	_enter("resting", visual.rest_clip)
	visual.sample(clip, .55, 0.0, 0.0)


func finish_rest_action() -> void:
	rest_point = null
	suspend_controls()
	velocity = Vector3.ZERO
	_locomotion()


func _exit_tree() -> void:
	if GameSession.player == self:
		GameSession.player = null


func _ready() -> void:
	add_to_group("player")
	GameSession.player = self
	GameProgress.apply_stats(self)
	input_device = InputRouter.kind
	visual.weapon.swing_connected.connect(_on_melee_connected)
	feedback.configure(visual.weapon.definition)
	if not settings:
		settings = MovementSettings.new()
	visual.configure_locomotion(settings)
	set_physics_process(true)


func _input(event: InputEvent) -> void:
	if not use_test_input:
		input_device = InputRouter.kind
		if state == "charge":
			charge_aim_device = input_device
		if event.is_action_pressed("lock_switch_left"):
			pending_lock_switch = -1
		elif event.is_action_pressed("lock_switch_right"):
			pending_lock_switch = 1


func suspend_controls() -> void:
	pending_inputs.clear()
	pending_lock_switch = 0
	light_buffer = -1
	heavy_buffer = -1
	dodge_buffer = -1
	light_link_requested = false
	roll_attack_queued = false
	heavy_held = false
	bow.aim_held = false
	if bow.active() or state == "charge":
		_locomotion()


func begin_entrance(sequence: EntranceSequence) -> void:
	suspend_controls()
	entrance = sequence
	entrance_launched = false
	entrance_landed = false
	entrance_landing_time = 0.0
	velocity = Vector3.ZERO
	facing = sequence.direction.normalized()
	pivot.rotation.y = atan2(-facing.x, -facing.z)
	var animation := sequence.animation
	if not visual.animation_player.has_animation(animation):
		animation = "idle"
	_enter("entrance", animation)
	visual.sample(clip, 0.0, 0.0, 0.0)


func _update_entrance(delta: float) -> void:
	if delta <= 0.0:
		return
	suspend_controls()
	action_time += delta
	if action_time >= entrance.takeoff_time and not entrance_launched:
		entrance_launched = true
		velocity = facing * entrance.horizontal_speed + Vector3.UP * entrance.jump_speed
	if entrance_launched and not entrance_landed:
		velocity.y -= settings.gravity * delta
		var impact_speed := maxf(0.0, -velocity.y)
		move_and_slide()
		if is_on_floor() and action_time > entrance.takeoff_time + .12:
			entrance_landed = true
			entrance_landing_time = action_time
			velocity = Vector3.ZERO
			landed.emit(impact_speed)
	else:
		velocity = Vector3.DOWN * .2
		move_and_slide()
	if entrance_landed and not visual.landing_clip.is_empty():
		visual.sample(visual.landing_clip, action_time - entrance_landing_time, 0.0, delta)
	else:
		visual.sample(clip, action_time, 0.0, delta)
	if entrance_landed and action_time - entrance_landing_time >= entrance.landing_recovery:
		entrance = null
		airborne_time = 0.0
		_locomotion()
		InputRouter.block_gameplay_input()
		entrance_finished.emit()


func request_action(action: String, device := "keyboard") -> void:
	if state in ["entrance", "scene_travel", "rest_approach", "kindle", "rest_settle", "resting"]:
		return
	next_aim_device = device
	pending_inputs.append(action)


func move_direction(stick: Vector2) -> Vector3:
	var camera = get_viewport().get_camera_3d()
	var right = camera.global_basis.x
	var back = camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	return right.normalized() * stick.x + back.normalized() * stick.y


func aim_direction(device: String) -> Vector3:
	var locked := target_lock.flat_direction()
	if locked != Vector3.ZERO:
		return locked
	if device == "mouse":
		var camera = get_viewport().get_camera_3d()
		var cursor = get_viewport().get_mouse_position()
		var point = Plane(Vector3.UP, global_position.y).intersects_ray(
			camera.project_ray_origin(cursor), camera.project_ray_normal(cursor)
		)
		if point != null:
			var direction: Vector3 = point - global_position
			direction.y = 0
			if direction.length_squared() > 0.003:
				return direction.normalized()
	if input_strength > 0.01:
		return input_direction.normalized()
	return facing


func _physics_process(_delta: float) -> void:
	if GameClock.paused:
		was_paused = true
		return
	if was_paused:
		was_paused = false
		pending_inputs.clear()
		if bow.active() or state == "charge":
			bow.aim_held = false
			heavy_held = false
			_locomotion()
	if state in ["rest_approach", "kindle", "rest_settle"]:
		_update_rest_action(GameClock.dt)
		return
	if state == "resting":
		return
	if state == "scene_travel":
		_update_scene_travel(GameClock.dt)
		return
	if state == "entrance":
		_update_entrance(GameClock.dt)
		return
	if not use_test_input and InputRouter.gameplay_input_blocked():
		suspend_controls()
		return
	if not use_test_input:
		bow.capture_input()
		for slot in 4:
			if Input.is_action_just_pressed("ability_" + str(slot + 1)):
				ranged_loadout.select_slot(slot)
		if Input.is_action_just_pressed("lock_on"):
			target_lock.toggle(facing)
		_capture_lock_switch()
		if Input.is_action_just_pressed("interact") and state in ["locomotion", "bow_empty"]:
			interaction.activate()
			if Checkpoints.active:
				return
		if Input.is_action_just_pressed("dodge"):
			request_action("dodge", input_device)
		if Input.is_action_just_pressed("light"):
			request_action("light", input_device)
		if Input.is_action_just_pressed("heavy"):
			heavy_held = true
			request_action("heavy", input_device)
		if Input.is_action_just_released("heavy"):
			heavy_held = false
			request_action("release", input_device)
	var delta := GameClock.dt
	if delta <= 0:
		return
	if landing_time >= 0.0:
		landing_time += delta
	var stick = (
		test_input
		if use_test_input
		else Input.get_vector(
			"move_left", "move_right", "move_up", "move_down", settings.stick_deadzone
		)
	)
	input_direction = move_direction(stick.limit_length(1.0))
	input_strength = input_direction.length()
	invulnerability = maxf(0, invulnerability - delta)
	roll_cooldown = maxf(0, roll_cooldown - delta)
	_capture_requests()
	if state != "dead":
		_resolve_priority()
	var previous_time := action_time
	action_time += delta
	var desired_velocity := Vector3.ZERO
	match state:
		"locomotion", "bow_empty", "fall":
			desired_velocity = input_direction * settings.max_speed
			var lock_direction := target_lock.flat_direction()
			if lock_direction != Vector3.ZERO and state != "fall":
				# Locked on: the body keeps facing the target; the stick only strafes.
				desired_velocity *= settings.lock_on_speed_multiplier
				_face(lock_direction, delta)
			elif input_strength > 0.001:
				_face(input_direction.normalized(), delta)
		"roll":
			if previous_time < settings.roll_duration:
				# Burst out of the stance and ease into the stop. Sampling the distance
				# curve keeps the authored roll distance at any physics rate.
				var before := _roll_travel(previous_time)
				var after := _roll_travel(minf(action_time, settings.roll_duration))
				desired_velocity = (
					locked_direction
					* settings.roll_speed
					* settings.roll_duration
					* (after - before)
					/ delta
				)
		"charge":
			charge_amount = minf(1, action_time / settings.charge_duration)
			_face(aim_direction(charge_aim_device), delta)
			clip = "heavy_hold" if charge_amount >= 1 else "heavy_charge"
			desired_velocity = (
				input_direction * settings.max_speed * settings.charge_move_multiplier
			)
			if charge_amount >= 1:
				_release_heavy()
				desired_velocity = Vector3.ZERO
		"light_attack", "heavy_attack", "roll_attack":
			var data := moveset.find(clip)
			var windup := data.windup
			var lunge_time := data.active_duration + .025
			var before := smoothstep(0.0, 1.0, clampf((previous_time - windup) / lunge_time, 0, 1))
			var after := smoothstep(0.0, 1.0, clampf((action_time - windup) / lunge_time, 0, 1))
			desired_velocity = locked_direction * settings.lunge_distance * (after - before) / delta
		"bow_aim", "bow_draw", "bow_shoot", "bow_recover":
			bow.update_state(delta)
			if state in ["bow_aim", "bow_draw"]:
				desired_velocity = (
					input_direction
					* settings.max_speed
					* (1.0 if magic.current == 0 else bow.settings.charge_move_multiplier)
				)
		"hurt":
			desired_velocity = locked_direction * lerpf(2.0, 0, clampf(action_time / .25, 0, 1))
	if state in ["locomotion", "bow_empty", "charge", "bow_aim", "bow_draw", "fall"]:
		var flat := Vector3(velocity.x, 0, velocity.z)
		flat = flat.move_toward(
			desired_velocity,
			(settings.acceleration if input_strength > 0 else settings.braking) * delta
		)
		velocity.x = flat.x
		velocity.z = flat.z
	else:
		velocity.x = desired_velocity.x
		velocity.z = desired_velocity.z
	velocity.y = -0.2 if is_on_floor() else velocity.y - settings.gravity * delta
	var falling_speed := maxf(0.0, -velocity.y)
	move_and_slide()
	_update_ground_contact(delta, falling_speed)
	ground_feedback.sample_motion(
		delta, state in ["locomotion", "bow_empty", "charge", "bow_aim", "bow_draw"]
	)
	interaction.refresh()
	target_lock.update(delta)
	_update_animation(delta)
	visual.show_damage_protection(
		invulnerability if state != "dead" else 0.0, settings.damage_iframes
	)
	var previous_active := active_window
	active_window = is_attack() and moveset.find(clip).is_active(action_time)
	var swing_phase := 0.0
	if is_attack():
		var attack := moveset.find(clip)
		swing_phase = (action_time - attack.windup) / attack.active_duration
	visual.weapon.drive_swing(
		self, locked_direction, action_time, moveset.find(clip) if is_attack() else null
	)
	visual.weapon.sample_hit(self, active_window, swing_phase, locked_direction)
	feedback.sample(active_window and not previous_active)
	bow.after_animation()
	_finish_action()


## Right-stick flicks switch targets while locked; they never pan the camera then.
func _capture_lock_switch() -> void:
	var look := Input.get_vector(
		"look_left", "look_right", "look_up", "look_down", settings.stick_deadzone
	)
	if look.length() < .35:
		lock_flick_held = false
	elif look.length() > .75 and not lock_flick_held and target_lock.is_active():
		lock_flick_held = true
		pending_lock_switch = 1 if look.x >= 0.0 else -1
	if pending_lock_switch != 0:
		target_lock.switch(pending_lock_switch)
		pending_lock_switch = 0


## Camera framing: a bias toward the locked target, otherwise the right-stick look offset.
func camera_look_offset() -> Vector3:
	var locked := target_lock.flat_offset()
	if locked != Vector3.ZERO:
		return (locked * .4).limit_length(settings.camera_look_distance)
	if use_test_input:
		return Vector3.ZERO
	var look := Input.get_vector(
		"look_left", "look_right", "look_up", "look_down", settings.stick_deadzone
	)
	return move_direction(look) * settings.camera_look_distance


func _capture_requests() -> void:
	light_link_requested = false
	if state == "fall":
		pending_inputs.clear()
		bow.aim_held = false
		heavy_held = false
		return
	var captured_light := false
	for request in pending_inputs:
		if bow.handle_request(request):
			continue
		match request:
			"dodge":
				dodge_buffer = GameClock.elapsed + settings.input_buffer
			"light":
				if captured_light:
					continue
				captured_light = true
				if state == "roll":
					if (
						action_time >= settings.roll_duration - settings.roll_attack_window
						and action_time < settings.roll_duration
					):
						roll_attack_queued = true
				elif state == "light_attack":
					light_link_requested = (
						action_time >= attack_duration() - settings.light_reinput_window
					)
				else:
					light_buffer = GameClock.elapsed + settings.input_buffer
			"heavy":
				if state == "roll":
					roll_attack_queued = true
				else:
					heavy_buffer = GameClock.elapsed + settings.input_buffer
			"release":
				if state == "charge":
					_release_heavy()
	pending_inputs.clear()


func _resolve_priority() -> void:
	var now := GameClock.elapsed
	var can_dodge := (
		state in ["locomotion", "charge"]
		or bow.active()
		or (is_attack() and action_time >= attack_duration() - .10)
	)
	if dodge_buffer >= now and can_dodge and roll_cooldown <= 0:
		dodge_buffer = -1
		locked_direction = input_direction.normalized() if input_strength > 0.01 else facing
		facing = locked_direction
		pivot.rotation.y = atan2(-facing.x, -facing.z)
		_enter("roll", "dodge_roll")
		light_link_requested = false
		roll_attack_queued = false
		light_buffer = -1
		heavy_buffer = -1
		return
	if light_link_requested and state == "light_attack":
		light_link_requested = false
		_start_light(combo_step % 3 + 1)
		return
	if state == "locomotion" and bow.aim_held:
		bow.begin_aim(false)
		return
	if state == "locomotion":
		if light_buffer >= now:
			light_buffer = -1
			_start_light(1)
		elif heavy_buffer >= now:
			heavy_buffer = -1
			charge_aim_device = next_aim_device
			charge_amount = 0
			_enter("charge", "heavy_charge")
			if not heavy_held:
				_release_heavy()


## Normalised roll distance covered after `time`.
func _roll_travel(time: float) -> float:
	var t := clampf(time / settings.roll_duration, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, settings.roll_ease)


func _face(direction: Vector3, delta: float) -> void:
	facing = direction
	var target := atan2(-direction.x, -direction.z)
	pivot.rotation.y = rotate_toward(
		pivot.rotation.y, target, deg_to_rad(settings.turn_speed_degrees) * delta
	)


func _lock_aim() -> void:
	locked_direction = aim_direction(next_aim_device)
	facing = locked_direction
	pivot.rotation.y = atan2(-facing.x, -facing.z)


func _enter(next: String, next_clip: String) -> void:
	landing_time = -1.0
	visual.weapon.clear_swing()
	if not next.begins_with("bow_"):
		bow.interrupt()
		visual.set_bow_mode(false)
	state = next
	clip = next_clip
	action_time = 0.0
	active_window = false
	feedback.clear()
	state_changed.emit(state)
	if state == "roll":
		$RollSound.play()
	if is_attack():
		attacks_started.append(clip)
		var attack := moveset.find(clip)
		var charged := state == "heavy_attack" and charge_amount >= .999
		visual.weapon.start_swing(
			GameClock.next_attack_id(),
			attack.charged_damage if charged else attack.damage,
			attack.charged_knockback if charged else attack.knockback,
			attack.charged_hitstop if charged else settings.hitstop_duration,
			1.8 if charged else 1.0,
			clip
		)
	visual.stowed = next not in ["charge", "light_attack", "heavy_attack", "roll_attack"]
	visual.sample(_animation_clip(), 0, Vector3(velocity.x, 0, velocity.z).length(), 0.001)
	visual.weapon.prime()


func _start_light(step: int) -> void:
	combo_step = step
	_lock_aim()
	_enter("light_attack", "attack_" + str(step))


func _release_heavy() -> void:
	# Short visual mix preserves the partial charge pose before the authored windup.
	_lock_aim()
	_enter("heavy_attack", "heavy_release")


func _animation_clip() -> String:
	if is_attack() and charge_amount >= .999 and state == "heavy_attack":
		var variant := moveset.find(clip).charged_clip
		if not variant.is_empty() and visual.animation_player.has_animation(variant):
			return variant
	if is_attack() and not visual.weapon.swing_visual_clip.is_empty():
		return visual.weapon.swing_visual_clip
	return clip


func _melee_animation_time() -> float:
	var animation_clip := _animation_clip()
	if not is_attack() or animation_clip == clip:
		return action_time
	# Alternating light direction selects an authored clip with its own phase lengths.
	# Match windup, impact and recovery to the authoritative gameplay action clock.
	var source := moveset.find(clip)
	if visual.weapon.swing_style:
		return visual.weapon.swing_style.sample_time(source, action_time)
	var target := moveset.find(animation_clip)
	if target == null:
		return action_time
	if action_time < source.windup:
		return action_time / source.windup * target.windup
	if action_time < source.windup + source.active_duration:
		return (
			target.windup
			+ (action_time - source.windup) / source.active_duration * target.active_duration
		)
	return (
		target.windup
		+ target.active_duration
		+ (action_time - source.windup - source.active_duration) / source.recovery * target.recovery
	)


func _update_animation(delta: float) -> void:
	var anim_time := bow.animation_time() if bow.active() else _melee_animation_time()
	if state == "charge" and charge_amount < 1.0:
		anim_time = charge_amount * visual.animation_player.get_animation("heavy_charge").length
	if state == "charge" and charge_amount >= 1.0:
		anim_time = fmod(action_time - settings.charge_duration, 0.5)
	if state == "roll":
		anim_time = minf(action_time, settings.roll_duration - 0.0001)
	visual.stowed = state not in ["charge", "light_attack", "heavy_attack", "roll_attack"]
	var anim_clip := _animation_clip()
	# Actual displacement stops the gait when the collider is blocked by a wall.
	var real_velocity := get_real_velocity()
	var flat_speed := Vector3(real_velocity.x, 0, real_velocity.z).length()
	if state == "locomotion" and landing_time >= 0.0:
		if (
			visual.animation_player.has_animation(visual.landing_clip)
			and landing_time < visual.animation_player.get_animation(visual.landing_clip).length
			and (flat_speed < 0.1 or landing_time < 0.08)
		):
			anim_clip = visual.landing_clip
			anim_time = landing_time
		else:
			landing_time = -1.0
	# The lead foot (matching the cut direction) steps in during windup and lands with the
	# blade, then draws back over recovery.
	var foot_step := 0.0
	var foot_lift := 0.0
	if is_attack():
		var data := moveset.find(clip)
		var land := data.windup + data.active_duration * .5
		if action_time < land:
			var t := action_time / maxf(land, .001)
			foot_step = smoothstep(0.0, 1.0, t)
			foot_lift = sin(PI * t)
		else:
			var back := (action_time - land) / maxf(data.duration() - land, .001)
			foot_step = 1.0 - smoothstep(.45, 1.0, back)
	visual.attack_step = foot_step
	visual.attack_step_lift = foot_lift
	visual.attack_step_forward = locked_direction
	visual.attack_step_side = "R" if visual.weapon.swing_direction < 0 else "L"
	visual.sample(anim_clip, anim_time, flat_speed, delta)


func _update_ground_contact(delta: float, impact_speed: float) -> void:
	if is_on_floor():
		var was_falling := airborne_time >= settings.fall_detection_delay
		airborne_time = 0.0
		if state == "fall":
			_locomotion()
		if was_falling and impact_speed >= settings.fall_minimum_speed and state != "dead":
			if state == "locomotion":
				landing_time = 0.0
			landed.emit(impact_speed)
		return
	airborne_time += delta
	if (
		airborne_time >= settings.fall_detection_delay
		and impact_speed >= settings.fall_minimum_speed
		and state not in ["fall", "hurt", "dead"]
	):
		_begin_fall()


func _begin_fall() -> void:
	_clear_buffers()
	bow.aim_held = false
	charge_amount = 0.0
	var fall_animation := visual.fall_clip
	if fall_animation.is_empty() or not visual.animation_player.has_animation(fall_animation):
		fall_animation = "idle"
	_enter("fall", fall_animation)


func _finish_action() -> void:
	if state == "roll" and (
		action_time >= settings.roll_duration
		or (
			roll_attack_queued
			and action_time >= settings.roll_duration - settings.roll_attack_cancel
		)
	):
		roll_cooldown = settings.roll_recovery
		if roll_attack_queued:
			roll_attack_queued = false
			_enter("roll_attack", "roll_attack")
		else:
			_locomotion()
	elif is_attack() and action_time >= attack_duration() - 0.00001:
		_locomotion()
	elif state == "hurt" and action_time >= .25:
		_locomotion()


func _locomotion() -> void:
	combo_step = 0
	light_link_requested = false
	if not is_on_floor() and airborne_time >= settings.fall_detection_delay:
		_begin_fall()
		return
	_enter("locomotion", "")


func is_attack() -> bool:
	return state in ["light_attack", "heavy_attack", "roll_attack"]


func attack_duration() -> float:
	var attack := moveset.find(clip)
	return attack.duration() if attack else 0.0


func is_invulnerable() -> bool:
	return (
		invulnerability > 0
		or state in ["scene_travel", "rest_approach", "kindle", "rest_settle", "resting"]
		or (
			state == "roll"
			and action_time >= settings.roll_iframe_start
			and action_time < settings.roll_iframe_end
		)
	)


func receive_hit(amount: float, id: int, origin: Vector3, _force := 1.0) -> bool:
	if state == "dead" or is_invulnerable() or accepted_hits.has(id):
		return false
	accepted_hits[id] = true
	health.damage(amount)
	InputRouter.feedback(.35, .25, .12)
	_clear_buffers()
	invulnerability = settings.damage_iframes
	locked_direction = (global_position - origin).normalized()
	locked_direction.y = 0
	if health.current <= 0:
		_enter("dead", "death")
	else:
		_enter("hurt", "hurt")
	return true


func _clear_buffers() -> void:
	pending_inputs.clear()
	dodge_buffer = -1
	light_buffer = -1
	heavy_buffer = -1
	light_link_requested = false
	roll_attack_queued = false
	heavy_held = false
	active_window = false
	feedback.clear()
	visual.weapon.clear_swing()


func respawn(at := Vector3.ZERO) -> void:
	rest_point = null
	entrance = null
	_clear_buffers()
	airborne_time = 0.0
	landing_time = -1.0
	ground_feedback.clear()
	global_position = at
	velocity = Vector3.ZERO
	invulnerability = 0
	roll_cooldown = 0
	charge_amount = 0
	accepted_hits.clear()
	health.reset()
	magic.reset()
	bow.aim_held = false
	target_lock.release()
	visual.reset_visual()
	_locomotion()


func debug_status() -> Dictionary:
	return {
		"state": state,
		"time": action_time,
		"clip": clip,
		"active": active_window,
		"invulnerable": is_invulnerable(),
		"hp": health.current,
		"speed": Vector2(velocity.x, velocity.z).length(),
		"device": input_device
	}


func _on_melee_connected(_attack_id: int) -> void:
	magic.restore(1)
	InputRouter.feedback(.12, .18 if state == "heavy_attack" else .08, .065)
