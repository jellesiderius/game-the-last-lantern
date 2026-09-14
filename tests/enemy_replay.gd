extends "res://tests/runtime_replay.gd"
## Real-scene AI admission, interruption, telegraph and navigation checks.


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	await reset(Vector3(0, 0, 3.1))
	var enemies: Array = targets.filter(func(actor): return actor.brain != null)
	check("at least three AI actors authored in level", enemies.size() >= 3)
	p.invulnerability = 100
	for i in enemies.size():
		var enemy = enemies[i]
		enemy.global_position = (
			p.position
			+ Vector3(sin(i * TAU / enemies.size()), 0, cos(i * TAU / enemies.size())) * 1.7
		)
		enemy.spawn_position = enemy.global_position
		enemy.disabled = false
		enemy.brain.reset_brain()
	var maximum := 0
	var turns := {}
	var wrong_admission := false
	var tells_short := false
	var windup_times := {}
	var windup_tells := {}
	var previous := {}
	# The arena now contains ten actors. Allow the authored approach/recovery cycle
	# for every queued actor; the original fixed window covered the three-actor layout.
	var admission_budget := maxi(1500, enemies.size() * 240)
	var tell_drain := 0
	for enemy in enemies:
		# Include the longest authored delay hold of any beat.
		tell_drain = maxi(tell_drain, ceili((enemy.brain.settings.attack.windup + .3) * 120) + 2)
	for i in admission_budget + tell_drain:
		if i == admission_budget:
			var outstanding := enemies.filter(func(enemy): return not turns.has(enemy.name))
			# Admission still has the original deadline. Only finish tells already
			# committed by then: cutting a full windup short is not starvation.
			if (
				outstanding.is_empty()
				or outstanding.any(func(enemy): return enemy.brain.state != "windup")
			):
				break
		await step(1)
		maximum = maxi(maximum, AttackTokenManager.leases.size())
		for enemy in enemies:
			var brain: EnemyBrain = enemy.brain
			if (
				brain.state in ["engage", "windup", "strike", "recover"]
				and not AttackTokenManager.owns(brain)
			):
				wrong_admission = true
			if brain.state == "windup" and previous.get(enemy.name) != "windup":
				windup_times[enemy.name] = GameClock.elapsed
				windup_tells[enemy.name] = brain.tell_duration
			if brain.state == "strike" and previous.get(enemy.name) != "strike":
				turns[enemy.name] = int(turns.get(enemy.name, 0)) + 1
				tells_short = (
					tells_short
					or (
						GameClock.elapsed - windup_times.get(enemy.name, 0)
						< windup_tells.get(enemy.name, brain.settings.attack.windup) - .01
					)
				)
			previous[enemy.name] = brain.state
	check("maximum two attack tokens", maximum == 2 and not wrong_admission, maximum)
	check("waiting enemies eventually get a turn", turns.size() == enemies.size(), turns)
	if turns.size() != enemies.size():
		for enemy in enemies:
			print(
				"ADMISSION_TRACE ",
				enemy.name,
				" ",
				{
					"position": enemy.position,
					"state": enemy.brain.state,
					"path": enemy.brain.locomotion.path,
					"direction": enemy.brain.direction,
					"turns": turns.get(enemy.name, 0),
					"owns": AttackTokenManager.owns(enemy.brain)
				}
			)
	check("every strike has the full authored tell", not tells_short)
	var brain: EnemyBrain = enemies[0].brain
	var stationary_score := AttackTokenManager.score(brain, 0)
	brain.recent_hit = 2
	check(
		"recent hit and wait raise priority", AttackTokenManager.score(brain, 2) > stationary_score
	)
	await reset(Vector3(0, 0, 3))
	var enemy = enemies[0]
	enemy.position = p.position + Vector3(0, 0, -.9)
	enemy.spawn_position = enemy.position
	enemy.disabled = false
	await step(10)
	check(
		"reaction delay prevents instant strike",
		p.health.current == 5 and enemy.brain.state != "strike"
	)
	var waited := 0
	while enemy.brain.state != "windup" and waited < 240:
		await step(1)
		waited += 1
	check("nearby visible target starts windup", enemy.brain.state == "windup")
	await step(45)
	var locked: Vector3 = enemy.brain.direction
	p.position = enemy.position - locked * .85
	await step(40)
	check(
		"late dodge behind committed tell avoids hit",
		p.health.current == 5 and enemy.brain.direction.dot(locked) > .999
	)
	# A multi-strike turn may chain further tells; recovery follows its last strike.
	for i in 300:
		if enemy.brain.state == "recover":
			break
		await step(1)
	check("telegraph hides after strike", not enemy.get_node("Telegraph").visible)
	# Recovery belongs to the same committed action and cannot be restarted by damage.
	var recovery_age: float = enemy.brain.state_time
	enemy.receive_hit(.5, GameClock.next_attack_id(), p.position)
	check(
		"hit preserves committed recovery and token",
		(
			enemy.brain.state == "recover"
			and is_equal_approx(enemy.brain.state_time, recovery_age)
			and AttackTokenManager.owns(enemy.brain)
		)
	)
	enemy.receive_hit(100, GameClock.next_attack_id(), p.position)
	check(
		"death releases admission and disables hurtboxes",
		(
			enemy.brain.state == "dead"
			and not AttackTokenManager.owns(enemy.brain)
			and enemy.get_node("Hurtbox").collision_layer == 0
		)
	)
	await step(305)
	check(
		"destroyed practice enemy resets",
		(
			enemy.health.current == enemy.health.maximum
			and enemy.get_node("Hurtbox").collision_layer == CombatLayers.TARGET_HURTBOX
		)
	)
	await reaction_checks(enemy)
	await reset(Vector3(1.9, 0, -.15))
	enemy.position = Vector3(1.9, 0, -2.05)
	enemy.spawn_position = enemy.position
	enemy.disabled = false
	enemy.brain.last_seen = p.position
	enemy.brain.memory = 8
	await step(80)
	check(
		"wall blocks enemy strike and admission",
		p.health.current == 5 and not AttackTokenManager.owns(enemy.brain)
	)
	var from: Vector3 = enemy.position
	for i in 650:
		# The remembered visible location is a navigation destination, never a wall bypass.
		enemy.brain.memory = 8
		await step(1)
	check(
		"enemy navigates around inner wall",
		enemy.position.distance_to(from) > 1.3 and enemy.brain.visible_target(),
		enemy.position
	)
	p.invulnerability = 100
	await step(120)
	var age: float = enemy.brain.state_time
	var position_before: Vector3 = enemy.position
	GameClock.paused = true
	await step(20)
	check(
		"pause freezes AI and movement",
		(
			is_equal_approx(age, enemy.brain.state_time)
			and enemy.position.is_equal_approx(position_before)
		)
	)
	GameClock.paused = false
	GameClock.hitstop(.04)
	await step(4)
	check("hitstop freezes AI shared clock", is_equal_approx(age, enemy.brain.state_time))
	enemy.disabled = true
	check("disable immediately releases token", not AttackTokenManager.owns(enemy.brain))
	arena.restart()
	check(
		"restart clears all outstanding requests",
		AttackTokenManager.leases.is_empty() and AttackTokenManager.requests.is_empty()
	)
	await reset(Vector3(3, 0, 3))
	enemy.disabled = false
	enemy.spawn_position = Vector3(-3, 0, 3)
	enemy.position = Vector3(0, 0, 3)
	var original_leash: float = enemy.brain.settings.leash_distance
	enemy.brain.settings.leash_distance = 1.5
	p.invulnerability = 100
	await step(5)
	check(
		"leash commits return despite visible player",
		enemy.brain.returning_after_leash and enemy.brain.state == "return_home"
	)
	await step(55)
	check(
		"leash does not oscillate back to approach",
		enemy.brain.state == "return_home" and not AttackTokenManager.owns(enemy.brain)
	)
	enemy.brain.settings.leash_distance = original_leash
	enemy.disabled = true
	var output := {
		"failures": failures,
		"results": results,
		"render_cap": render_cap,
		"physics_fps": Engine.physics_ticks_per_second,
		"observed_render_fps":
		(
			(Engine.get_frames_drawn() - initial_render_frame)
			* 1000.0
			/ maxi(1, Time.get_ticks_msec() - initial_wall_ms)
		)
	}
	var file := FileAccess.open(report_path("enemy"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	file.close()
	print("ENEMY_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)


func reaction_checks(enemy) -> void:
	await reset(Vector3(0, 0, 3))
	enemy.position = p.position + Vector3(0, 0, -.9)
	enemy.spawn_position = enemy.position
	enemy.disabled = false
	# First uncommitted hit has a real reaction; a second hit must not restart it.
	var brain: EnemyBrain = enemy.brain
	check("reset clears stagger resistance", is_zero_approx(brain.stagger_resistance_left))
	enemy.receive_hit(.25, GameClock.next_attack_id(), p.position)
	check(
		"uncommitted hit staggers and releases admission",
		brain.state == "stagger" and not AttackTokenManager.owns(brain)
	)
	await step(12)
	var age := brain.state_time
	var resistance := brain.stagger_resistance_left
	enemy.receive_hit(.25, GameClock.next_attack_id(), p.position)
	check(
		"repeated hit cannot restart stagger or resistance",
		(
			is_equal_approx(brain.state_time, age)
			and is_equal_approx(brain.stagger_resistance_left, resistance)
		)
	)
	await step(23)
	check("stagger ends despite repeated damage", brain.state != "stagger")
	enemy.receive_hit(.25, GameClock.next_attack_id(), p.position)
	check("post-stagger resistance lets enemy resume decisions", brain.state != "stagger")
	# Allow natural admission, then hit in each authored phase, including charged-force impact.
	p.invulnerability = 100
	for phase in ["windup", "strike", "recover"]:
		var waited := 0
		while brain.state != phase and waited < 300:
			await step(1)
			waited += 1
		check("natural reaction recovery reaches " + phase, brain.state == phase)
		var before_time := brain.state_time
		var before_attack := brain.attack_id
		var before_direction := brain.direction
		var hp: float = enemy.health.current
		var id := GameClock.next_attack_id()
		enemy.receive_hit(.25, id, p.position, 4.5)
		check(
			"damage preserves phase, clock, direction and token: " + phase,
			(
				brain.state == phase
				and is_equal_approx(brain.state_time, before_time)
				and brain.attack_id == before_attack
				and brain.direction == before_direction
				and AttackTokenManager.owns(brain)
			)
		)
		check(
			"resistance still accepts damage and flashes: " + phase,
			is_equal_approx(enemy.health.current, hp - .25) and enemy.flash > 0
		)
		check(
			"committed charged knockback cannot shove attack away: " + phase,
			enemy.knockback.length() <= 4.5 * brain.settings.committed_knockback_multiplier + .001
		)
		check(
			"duplicate hurtbox still ignored: " + phase,
			(
				not enemy.receive_hit(.25, id, p.position)
				and is_equal_approx(enemy.health.current, hp - .25)
			)
		)
		if phase == "windup":
			var before_resistance := brain.stagger_resistance_left
			GameClock.hitstop(.04)
			await step(4)
			check(
				"hitstop freezes reaction immunity and attack together",
				(
					is_equal_approx(brain.state_time, before_time)
					and is_equal_approx(brain.stagger_resistance_left, before_resistance)
				)
			)
	# Death overrides even an active strike; an explicitly interruptible archetype remains possible.
	var original: EnemySettings = brain.settings
	brain.settings = original.duplicate()
	brain.settings.interrupt_committed_attacks = true
	brain.stagger_resistance_left = 0
	enemy.receive_hit(.25, GameClock.next_attack_id(), p.position)
	check(
		"archetype can explicitly allow committed interruption",
		brain.state == "stagger" and not AttackTokenManager.owns(brain)
	)
	brain.settings = original
	await reset(Vector3(0, 0, 3))
	enemy.position = p.position + Vector3(0, 0, -.9)
	enemy.spawn_position = enemy.position
	enemy.disabled = false
	var waited := 0
	while brain.state != "strike" and waited < 300:
		await step(1)
		waited += 1
	check("lethal test reaches active strike", brain.state == "strike")
	enemy.receive_hit(100, GameClock.next_attack_id(), p.position)
	check(
		"lethal hit always cancels committed attack",
		(
			brain.state == "dead"
			and not AttackTokenManager.owns(brain)
			and is_zero_approx(brain.stagger_resistance_left)
		)
	)
	await reset(Vector3(0, 0, 3))
	enemy.position = p.position + Vector3(0, 0, -.9)
	enemy.spawn_position = enemy.position
	enemy.disabled = false
	# Real player actions, sword sweep, hitstop and enemy FSM: no injected damage here.
	for frame in 240:
		if frame % 18 == 0:
			p.request_action("light")
		await step(1)
	check(
		"repeated real sword attacks damage the enemy", enemy.health.current < enemy.health.maximum
	)
	check(
		"standing and mashing no longer prevents enemy retaliation",
		p.health.current < 5,
		{"player_hp": p.health.current, "enemy_hp": enemy.health.current}
	)
