class_name EnemyBrain
extends Node
## Decision component. Actor owns collisions/health; a separate presenter owns animation.
signal state_changed(state: String)
@export var settings: EnemySettings
## Zero derives a stable seed from the instance path; set explicitly for replays/spawns.
@export var variation_seed := 0
## Optional editor-placed route; individual state never mutates the shared Resource.
var authored_patrol := PackedVector3Array()
var ordered_patrol := true
var spawn_floor_settled := false
var state := "approach"
var state_time := 0.0
var direction := Vector3.FORWARD
var recent_hit := 0.0
var stagger_resistance_left := 0.0
var cooldown := 0.0
var admission_wait_since := -1.0
var memory := 0.0
var noticed_time := 0.0
var perception_left := 0.0
var path_left := 0.0
var waypoint := Vector3.ZERO
var last_seen := Vector3.ZERO
var attack_id := -1
var hit_attempted := false
var returning_after_leash := false
var orbit_sign := 1.0
var attack_index := 0
var turning_in_place := false
var previous_attack_index := -1
var observation: Dictionary = {}
var observed_state_since := 0.0
var spacing_left := 0.0
var spacing_cooldown := 0.0
var spacing_destination := Vector3.ZERO
var decision_reason := "idle"
var decision_history: Array[Dictionary] = []
var patrol_index := 0
var idle_duration := 2.4
var idle_look := false
var routine_rng := RandomNumberGenerator.new()
var personality: Dictionary = {}
var idle_look_delay := 0.0
var locomotion := EnemyLocomotion.new()
## Animated tell of the committed attack; windup_duration adds its random delay hold.
var tell_duration := 0.0
var windup_duration := 0.0
## Strikes delivered after the first in this turn, and strikes still to come.
var chain_count := 0
var strikes_left := 0
## True while pressing a visible player recovery instead of circling.
var pressing_opening := false
var hits_in_window := 0
var hit_window_left := 0.0
var _sight_frame := -1
var _sight := false
var face_travel_direction: bool:
	get:
		return settings.movement != null or settings.face_travel_direction
var attack: AttackDefinition:
	get:
		return (
			settings.attack
			if settings.attack_variants.is_empty()
			else settings.attack_variants[attack_index % settings.attack_variants.size()]
		)
var attack_range: float:
	get:
		return attack.start_range if attack is EnemyAttackDefinition else settings.attack_range
var strike_range: float:
	get:
		return attack.hit_range if attack is EnemyAttackDefinition else settings.strike_range
var strike_half_angle: float:
	get:
		return attack.half_angle if attack is EnemyAttackDefinition else settings.strike_half_angle
var lunge_distance: float:
	get:
		return attack.lunge if attack is EnemyAttackDefinition else settings.lunge_distance
var windup_clip: StringName:
	get:
		return attack.windup_clip if attack is EnemyAttackDefinition else &"windup"
var recovery_clip: StringName:
	get:
		return attack.recovery_clip if attack is EnemyAttackDefinition else &"recover"
var target: PlayerCharacter
@onready var actor = get_parent()


func _ready() -> void:
	add_to_group("enemy_ai")
	_initialize_personality()
	call_deferred("_prepare_navigation")


func _prepare_navigation() -> void:
	NavigationWorld.surface_for(actor, settings.movement.radius, settings.movement.height)
	NavigationWorld.surface_for(
		actor,
		settings.movement.radius + settings.movement.preferred_path_clearance,
		settings.movement.height
	)


func _initialize_personality() -> void:
	routine_rng.seed = variation_seed if variation_seed != 0 else hash(str(get_path()))
	personality = (
		settings.variation.sample(routine_rng, settings.attack_variants.size())
		if settings.variation
		else {}
	)
	orbit_sign = personality.get("side", -1.0 if get_instance_id() % 2 else 1.0)


func operational() -> bool:
	return (
		not actor.disabled
		and actor.reset_time <= 0
		and actor.health.current > 0
		and is_instance_valid(target)
		and target.state != "dead"
	)


func target_distance() -> float:
	return (
		actor.global_position.distance_to(target.global_position)
		if is_instance_valid(target)
		else INF
	)


## One sight ray per physics tick, however many decisions ask for it.
func visible_target() -> bool:
	if not is_instance_valid(target):
		return false
	if _sight_frame != Engine.get_physics_frames():
		_sight_frame = Engine.get_physics_frames()
		var ray := PhysicsRayQueryParameters3D.create(
			actor.global_position + Vector3.UP * .4,
			target.global_position + Vector3.UP * .4,
			CombatLayers.WORLD
		)
		_sight = actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	return _sight


## True while a visible player action leaves a punishable recovery.
func sees_opening() -> bool:
	return (
		settings.tactics != null
		and observation.get("visible", false)
		and observation.get("state", "") in settings.tactics.punish_states
		and (
			GameClock.elapsed - float(observation.get("observed_at", -INF))
			<= settings.tactics.opening_memory
		)
	)


func can_request_attack() -> bool:
	return (
		operational()
		and state in ["approach", "orbit"]
		and cooldown <= 0
		and spacing_left <= 0
		and noticed_time >= settings.reaction_time * personality.get("reaction", 1.0)
		and target_distance() <= settings.engagement_range
		and visible_target()
	)


func grant_attack() -> void:
	if can_request_attack():
		if settings.tactics and not settings.attack_variants.is_empty():
			var noise: Array = []
			if settings.variation:
				for beat in settings.attack_variants:
					noise.append(
						routine_rng.randf_range(
							-settings.variation.choice_jitter, settings.variation.choice_jitter
						)
					)
			var choice := settings.tactics.choose_attack(
				settings.attack_variants,
				observation,
				previous_attack_index,
				personality.get("preferences", []),
				noise
			)
			attack_index = choice.index
			_record_decision(choice.reason, {"attack": attack.clip, "scores": choice.scores})
		chain_count = 0
		_enter("engage")
	else:
		AttackTokenManager.release(self)


func cancel_attack() -> void:
	var completed := state == "recover"
	chain_count = 0
	if state == "recover":
		previous_attack_index = attack_index
		if not settings.tactics:
			attack_index += 1
		if settings.alternate_orbit_after_attack:
			if not settings.variation or routine_rng.randf() < .55:
				orbit_sign *= -1.0
	# A blocked approach must not lose its accumulated place in the queue.
	AttackTokenManager.release(self, not completed)
	cooldown = settings.post_attack_cooldown * personality.get("cooldown", 1.0)
	if settings.variation:
		cooldown *= routine_rng.randf_range(.8, 1.4)
	_enter("approach")


func suspend() -> void:
	AttackTokenManager.release(self)
	_enter("idle")


func reset_brain() -> void:
	AttackTokenManager.release(self)
	_initialize_personality()
	locomotion.reset()
	spawn_floor_settled = false
	state_time = 0
	attack_index = 0
	previous_attack_index = -1
	observation.clear()
	observed_state_since = 0.0
	spacing_left = 0.0
	spacing_cooldown = 0.0
	decision_reason = "idle"
	decision_history.clear()
	patrol_index = 0
	idle_look = false
	turning_in_place = false
	tell_duration = 0.0
	windup_duration = 0.0
	chain_count = 0
	strikes_left = 0
	hits_in_window = 0
	hit_window_left = 0.0
	_sight_frame = -1
	cooldown = 0
	recent_hit = 0
	stagger_resistance_left = 0
	memory = 0
	noticed_time = 0
	perception_left = 0
	path_left = 0
	hit_attempted = false
	returning_after_leash = false
	_enter("approach")


func committed_attack() -> bool:
	return state in ["windup", "strike", "recover"]


## Returns the physical knockback multiplier, independently of accepting damage.
func on_hit(origin: Vector3) -> float:
	recent_hit = 2.0
	last_seen = origin
	memory = settings.memory_duration
	if actor.health.current <= 0:
		AttackTokenManager.release(self)
		stagger_resistance_left = 0
		_enter("dead")
		return 0.0
	if committed_attack() and not settings.interrupt_committed_attacks:
		return settings.committed_knockback_multiplier
	if _should_retaliate():
		_retaliate()
		return settings.committed_knockback_multiplier
	if not settings.stagger_on_hit or state == "stagger" or stagger_resistance_left > 0:
		return settings.resistant_knockback_multiplier
	AttackTokenManager.release(self)
	stagger_resistance_left = settings.stagger_duration + settings.stagger_resistance_duration
	_enter("stagger")
	return 1.0


func _enter(next: String) -> void:
	state = next
	pressing_opening = false
	state_time = 0
	path_left = 0
	if next == "windup":
		admission_wait_since = -1.0
	if next in ["idle", "windup", "strike", "recover", "stagger", "dead"]:
		locomotion.speed = 0
	state_changed.emit(state)


func tick(delta: float) -> Vector3:
	turning_in_place = false
	target = GameSession.player
	if not spawn_floor_settled and actor.is_on_floor():
		spawn_floor_settled = true
		var offset: Vector3 = actor.global_position - actor.spawn_position
		offset.y = 0
		if offset.length() < settings.movement.radius * 2:
			# A level edit can lower the ground beneath a placed enemy. Once it
			# lands, its home must be on that floor rather than suspended in air.
			actor.spawn_position.y = actor.global_position.y
	if not operational():
		if state not in ["idle", "dead"]:
			suspend()
		return Vector3.ZERO
	state_time += delta
	recent_hit = maxf(0, recent_hit - delta)
	stagger_resistance_left = maxf(0, stagger_resistance_left - delta)
	cooldown = maxf(0, cooldown - delta)
	spacing_left = maxf(0, spacing_left - delta)
	spacing_cooldown = maxf(0, spacing_cooldown - delta)
	memory = maxf(0, memory - delta)
	hit_window_left = maxf(0, hit_window_left - delta)
	perception_left -= delta
	if perception_left <= 0:
		perception_left = settings.perception_interval
		if (
			not returning_after_leash
			and target_distance() <= settings.aggro_range
			and visible_target()
		):
			last_seen = target.global_position
			memory = settings.memory_duration
			if settings.tactics:
				_observe_target()
		elif settings.tactics:
			# Remember a location, never a hidden opponent's current action.
			observation["visible"] = false
	if memory > 0:
		noticed_time += delta
	else:
		noticed_time = 0
	var difference: Vector3 = last_seen - actor.global_position
	difference.y = 0
	if state not in ["windup", "strike", "recover", "stagger"]:
		if actor.global_position.distance_to(actor.spawn_position) > settings.leash_distance:
			returning_after_leash = true
			memory = 0
		if memory <= 0 or returning_after_leash:
			spacing_left = 0.0
			AttackTokenManager.release(self)
			if (
				state not in ["return_home", "idle", "patrol"]
				or (returning_after_leash and state != "return_home")
			):
				_record_decision("return_home")
				_enter("return_home")
		elif state in ["idle", "patrol", "return_home"]:
			_record_decision("investigate_visible_target")
			_enter("approach")
	if settings.tactics and state in ["approach", "orbit", "engage"]:
		_consider_spacing()
		if spacing_left > 0:
			return _move_to(spacing_destination, settings.move_speed, delta)
	match state:
		"return_home":
			if actor.global_position.distance_to(actor.spawn_position) < .18:
				returning_after_leash = false
				noticed_time = 0
				_enter_idle()
				return Vector3.ZERO
			return _move_to(actor.spawn_position, settings.move_speed, delta)
		"idle":
			if not _patrol_points().is_empty() and state_time >= idle_duration:
				_enter("patrol")
				_record_decision("patrol_home_area")
			return Vector3.ZERO
		"patrol":
			var route := _patrol_points()
			var offset := route[patrol_index % route.size()]
			if authored_patrol.is_empty():
				offset = (
					offset.rotated(Vector3.UP, personality.get("patrol_yaw", 0.0))
					* personality.get("patrol_scale", 1.0)
				)
			var destination: Vector3 = actor.spawn_position + offset
			if (
				actor.global_position.distance_to(destination) < .15
				or (authored_patrol.is_empty() and state_time > 6.0)
			):
				patrol_index += (
					routine_rng.randi_range(1, maxi(1, route.size() - 1))
					if settings.variation and (authored_patrol.is_empty() or not ordered_patrol)
					else 1
				)
				_enter_idle()
				return Vector3.ZERO
			return _move_to(destination, settings.patrol_speed, delta)
		"approach", "orbit":
			# A visible recovery is pressed immediately instead of politely circled.
			pressing_opening = sees_opening()
			if pressing_opening:
				cooldown = 0.0
			if can_request_attack():
				AttackTokenManager.request_attack(self)
			if (
				not pressing_opening
				and target_distance() <= settings.engagement_range
				and visible_target()
			):
				if state != "orbit":
					_enter("orbit")
				var radial := -difference.normalized()
				var destination: Vector3 = (
					last_seen
					+ (
						radial.rotated(Vector3.UP, orbit_sign * .30)
						* settings.orbit_radius
						* personality.get("orbit", 1.0)
					)
				)
				if not face_travel_direction:
					_face(difference, delta)
				return _move_to(destination, settings.orbit_speed, delta)
			if not face_travel_direction:
				_face(difference, delta)
			return _move_to(_approach_destination(), settings.move_speed, delta)
		"engage":
			if not face_travel_direction:
				_face(difference, delta)
			if (
				target_distance() <= attack_range
				and (
					absf(target.global_position.y - actor.global_position.y)
					<= settings.maximum_attack_height_difference
				)
				and visible_target()
			):
				if face_travel_direction:
					_face(difference, delta)
					if direction.dot(difference.normalized()) < .98:
						turning_in_place = true
						return Vector3.ZERO
				direction = difference.normalized()
				_begin_windup()
				return Vector3.ZERO
			return _move_to(_approach_destination(), settings.move_speed, delta)
		"windup":
			if state_time < tell_duration * settings.tracking_fraction:
				_face(difference, delta)
			if state_time >= windup_duration:
				_enter("strike")
		"strike":
			var actual: Vector3 = target.global_position - actor.global_position
			var height_difference := absf(actual.y)
			actual.y = 0
			if (
				not hit_attempted
				and height_difference <= settings.maximum_attack_height_difference
				and (state_time >= attack.active_duration * attack.enemy_contact_fraction)
				and actual.length() < strike_range
				and actual.normalized().dot(direction) > cos(deg_to_rad(strike_half_angle))
				and visible_target()
			):
				hit_attempted = true
				target.receive_hit(attack.damage, attack_id, actor.global_position)
			if state_time >= attack.active_duration:
				if not _chain_followup():
					_enter("recover")
				return Vector3.ZERO
			return direction * lunge_distance / attack.active_duration
		"recover":
			if state_time >= attack.recovery:
				cancel_attack()
		"stagger":
			if state_time >= settings.stagger_duration:
				_enter("approach")
	return Vector3.ZERO


func _begin_windup(quick := false) -> void:
	var beat := attack as EnemyAttackDefinition
	tell_duration = minf(beat.quick_windup, attack.windup) if quick and beat else attack.windup
	if beat and not quick:
		strikes_left = (
			routine_rng.randi_range(beat.strikes.x, maxi(beat.strikes.x, beat.strikes.y)) - 1
		)
	windup_duration = tell_duration
	if beat and beat.delay_range.y > 0.0:
		windup_duration += routine_rng.randf_range(beat.delay_range.x, beat.delay_range.y)
	attack_id = GameClock.next_attack_id()
	hit_attempted = false
	_enter("windup")


## A multi-strike turn continues with a quick, telegraphed tell; the admission token is kept.
func _chain_followup() -> bool:
	var beat := attack as EnemyAttackDefinition
	if beat == null or strikes_left <= 0:
		return false
	# Alone, a guard strings attacks together; in a crowd, others get their turn.
	if AttackTokenManager.longest_wait() > AttackTokenManager.settings.chain_wait_limit:
		return false
	if (
		not visible_target()
		or (
			absf(target.global_position.y - actor.global_position.y)
			> settings.maximum_attack_height_difference
		)
	):
		return false
	var options: Array[int] = []
	for index in beat.followups if not beat.followups.is_empty() else [attack_index]:
		var next := _beat(index)
		if next and target_distance() <= next.start_range + .35:
			options.append(index)
	if options.is_empty():
		return false
	previous_attack_index = attack_index
	attack_index = options[routine_rng.randi_range(0, options.size() - 1)]
	strikes_left -= 1
	chain_count += 1
	_record_decision("chain_followup", {"attack": attack.clip, "chain": chain_count})
	_begin_windup(true)
	return true


## Mashing an uncommitted enemy builds toward an armored counter instead of a stun lock.
func _should_retaliate() -> bool:
	if settings.retaliation_hits <= 0 or committed_attack() or not operational():
		return false
	hits_in_window = hits_in_window + 1 if hit_window_left > 0 else 1
	hit_window_left = settings.retaliation_window
	if hits_in_window < settings.retaliation_hits:
		return false
	if target_distance() > settings.engagement_range:
		return false
	hits_in_window = 0
	return true


func _retaliate() -> void:
	AttackTokenManager.claim(self)
	if not settings.attack_variants.is_empty():
		attack_index = _quickest_attack()
	chain_count = 0
	strikes_left = 0
	stagger_resistance_left = 0
	_record_decision("retaliate_against_pressure", {"attack": attack.clip})
	_begin_windup(true)


## The beat an attack index names; archetypes without variants repeat their single attack.
func _beat(index: int) -> EnemyAttackDefinition:
	if settings.attack_variants.is_empty():
		return settings.attack as EnemyAttackDefinition
	if index < 0 or index >= settings.attack_variants.size():
		return null
	return settings.attack_variants[index]


func _quickest_attack() -> int:
	var quickest := 0
	for i in settings.attack_variants.size():
		if settings.attack_variants[i].windup < settings.attack_variants[quickest].windup:
			quickest = i
	return quickest


func _face(toward: Vector3, delta: float) -> void:
	if toward.length_squared() < .001:
		return
	var yaw := atan2(-direction.x, -direction.z)
	yaw = rotate_toward(yaw, atan2(-toward.x, -toward.z), deg_to_rad(settings.turn_speed) * delta)
	direction = Vector3(-sin(yaw), 0, -cos(yaw))


func _observe_target() -> void:
	if observation.get("state", "") != target.state or not observation.get("visible", false):
		observed_state_since = GameClock.elapsed
	var away: Vector3 = (target.global_position - actor.global_position).normalized()
	observation = {
		"visible": true,
		"state": target.state,
		"distance": target_distance(),
		"retreat_speed": target.get_real_velocity().dot(away),
		"facing_us": target.facing.dot(-away) > .35,
		"observed_at": GameClock.elapsed
	}


func _enter_idle() -> void:
	idle_duration = (
		routine_rng.randf_range(settings.idle_wait_min, settings.idle_wait_max)
		* personality.get("wait", 1.0)
	)
	idle_look = not _patrol_points().is_empty()
	idle_look_delay = 0.0
	if settings.variation:
		idle_look = routine_rng.randf() < settings.variation.look_chance
		idle_look_delay = routine_rng.randf_range(.1, .65)
	_enter("idle")
	_record_decision("watch_home_area")


func _consider_spacing() -> void:
	var policy := settings.tactics
	if spacing_left > 0 or spacing_cooldown > 0 or not observation.get("visible", false):
		return
	if observation.get("state", "") != "charge" or not observation.get("facing_us", false):
		return
	if (
		GameClock.elapsed - observed_state_since
		< policy.reaction_delay * personality.get("reaction", 1.0)
	):
		return
	if float(observation.get("distance", INF)) > policy.spacing_trigger_range:
		return
	var away: Vector3 = actor.global_position - last_seen
	away.y = 0
	away = away.normalized()
	var offset := (away + away.cross(Vector3.UP) * orbit_sign * .45).normalized()
	spacing_destination = actor.global_position + offset * policy.spacing_distance
	spacing_left = policy.spacing_duration
	spacing_cooldown = policy.spacing_cooldown
	AttackTokenManager.release(self)
	_enter("orbit")
	_record_decision("respect_heavy_tell")


func _approach_destination() -> Vector3:
	if (
		settings.tactics
		and observation.get("visible", false)
		and target_distance() > attack_range + .35
	):
		if observation.get("state", "") in ["bow_aim", "bow_draw"]:
			var toward: Vector3 = last_seen - actor.global_position
			toward.y = 0
			return (
				last_seen
				+ toward.normalized().cross(Vector3.UP) * orbit_sign * settings.tactics.flank_offset
			)
	return last_seen


func _record_decision(reason: String, detail: Dictionary = {}) -> void:
	decision_reason = reason
	if not settings.tactics:
		return
	decision_history.append({"time": GameClock.elapsed, "reason": reason, "detail": detail})
	if decision_history.size() > 32:
		decision_history.pop_front()


func _move_to(destination: Vector3, speed: float, delta: float) -> Vector3:
	return locomotion.move(self, destination, speed * personality.get("speed", 1.0), delta)


func _exit_tree() -> void:
	AttackTokenManager.release(self)


func _patrol_points() -> PackedVector3Array:
	return authored_patrol if not authored_patrol.is_empty() else settings.patrol_offsets
