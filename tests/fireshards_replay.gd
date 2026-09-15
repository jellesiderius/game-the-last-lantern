extends "res://tests/room_replay.gd"
## Focused fireshard checks in the real first area: an enemy leaves its shards on the ground,
## the character has to walk up to absorb them, death drops the carried shards and a second
## death without absorbing destroys the older loss.
var events: Array = []
var death_spot := Vector3.ZERO
var death_ids := 0
var approach_spot := Vector3.ZERO
var start_spot := Vector3.ZERO
var checkpoint_spot := Vector3.ZERO


func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://captures/fireshards/" + label + ".png")


func reported(kind: String, amount: int) -> bool:
	for event in events:
		if event[0] == kind and int(event[1]) == amount:
			return true
	return false


func live_shards() -> Array[FireShard]:
	var found: Array[FireShard] = []
	for node in get_tree().current_scene.get_children():
		if node is FireShard and not node.is_queued_for_deletion():
			found.append(node)
	return found


func shard_report() -> Array:
	var report: Array = []
	for shard in live_shards():
		report.append([shard.entry_id, shard.amount, shard.absorbing])
	return report


func find_enemy() -> Node:
	for enemy in get_tree().get_nodes_in_group("damageable"):
		if enemy.brain == null or enemy.is_queued_for_deletion():
			continue
		if Fireshards.reward_for(enemy) > 0:
			return enemy
	return null


func silence_actors() -> void:
	# Other guards must not interrupt the walking checks; the killed guard stays down too.
	for enemy in get_tree().get_nodes_in_group("damageable"):
		enemy.disabled = true


func die() -> void:
	death_ids += 1
	death_spot = p.global_position
	p.receive_hit(99.0, 7000 + death_ids, p.global_position + Vector3.FORWARD)
	await step(6)
	check("lethal damage kills the player", p.state == "dead", p.state)


func respawn() -> void:
	check("death respawn starts", Checkpoints.respawn_player())
	var guard := 0
	while SceneTransit.active and guard < 1200:
		guard += 1
		await step(1)
	await step(8)
	arena = get_tree().current_scene
	p = arena.player
	p.use_test_input = true
	p.test_input = Vector2.ZERO
	checkpoint_spot = p.global_position
	check(
		"the level returns with a fresh player", p.state == "locomotion" and not SceneTransit.active
	)


## Walk over real ground until the player stands clear of the respawn point, so a shard pile
## can never be absorbed in the same frame the player arrives on it.
func walk_away(minimum: float) -> void:
	var start := p.global_position
	var samples: Array[Vector3] = []
	for direction in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
		p.test_input = world_input(direction)
		for _i in 200:
			await step(1)
			samples.append(p.global_position)
			if p.is_on_floor() and p.global_position.distance_to(start) >= minimum:
				p.test_input = Vector2.ZERO
				await step(8)
				approach_spot = approach_sample(samples, p.global_position)
				return
		p.test_input = Vector2.ZERO
		await step(4)
	approach_spot = approach_sample(samples, p.global_position)


## The return walk starts on ground the player already walked, not on invented ground.
func approach_sample(samples: Array[Vector3], death: Vector3) -> Vector3:
	for index in range(samples.size() - 1, -1, -1):
		if samples[index].distance_to(death) >= 2.6:
			return samples[index]
	return death


## The character only gains fireshards by closing in on the pile and pulling it in.
func approach_and_absorb(target: Vector3, capture_label := "") -> bool:
	var before: int = Fireshards.total()
	for offset in [
		Vector3(2.6, 0, 0),
		Vector3(-2.6, 0, 0),
		Vector3(0, 0, 2.6),
		Vector3(0, 0, -2.6),
		Vector3(1.9, 0, 1.9)
	]:
		var from: Vector3 = target + offset
		p.respawn(from)
		p.facing = (target - from).normalized()
		await step(24)
		if not p.is_on_floor():
			continue
		if not capture_label.is_empty():
			await capture(capture_label)
			capture_label = ""
		p.test_input = world_input(p.facing)
		for _i in 300:
			await step(1)
			if Fireshards.total() > before:
				p.test_input = Vector2.ZERO
				# The pile is still streaming into the character; wait for it to finish.
				for _k in 150:
					await step(1)
					if live_shards().is_empty():
						break
				return true
		p.test_input = Vector2.ZERO
		await step(4)
	return Fireshards.total() > before


func run() -> void:
	prepare_window()
	DirAccess.make_dir_recursive_absolute("res://captures/fireshards")
	arena = get_tree().current_scene
	p = arena.player
	render_cap = Engine.max_fps
	p.use_test_input = true
	p.test_input = Vector2.ZERO
	# A disposable slot in a test-only directory; player slots stay untouched.
	GameProgress.active_slot = 0
	GameProgress.data = SaveSchema.new_game()
	GameProgress.defeated_since_rest.clear()
	SaveStore.write_slot(0, GameProgress.data, true)
	Fireshards.shards_collected.connect(func(amount: int): events.append(["collected", amount]))
	Fireshards.shards_lost.connect(func(amount: int): events.append(["lost", amount]))
	var counter: Label = arena.get_node("HUD/Root/Fireshards/Value")
	var counter_group: HBoxContainer = arena.get_node("HUD/Root/Fireshards")

	var legacy := SaveSchema.new_game()
	legacy.erase(SaveSchema.FIRESHARDS_KEY)
	legacy.erase(SaveSchema.FIRE_SHARDS_KEY)
	var upgraded := SaveSchema.normalize(legacy)
	check(
		"older saves load without fireshards",
		upgraded.fireshards == 0 and upgraded.fire_shards.is_empty() and SaveSchema.valid(upgraded)
	)
	var souls_era := SaveSchema.new_game()
	souls_era.erase(SaveSchema.FIRESHARDS_KEY)
	souls_era.erase(SaveSchema.FIRE_SHARDS_KEY)
	souls_era[SaveSchema.LEGACY_TOTAL_KEY] = 12
	souls_era[SaveSchema.LEGACY_SHARDS_KEY] = [
		{
			"id": "abcd",
			"area": "forest.opening",
			"position": [1.0, 2.0, 3.0],
			"amount": 5,
			"kind": "enemy"
		}
	]
	var migrated := SaveSchema.normalize(souls_era)
	check(
		"saves from the souls build keep their shards",
		(
			migrated.fireshards == 12
			and migrated.fire_shards.size() == 1
			and SaveSchema.valid(migrated)
		),
		migrated
	)
	check("area identity comes from the saved level", Fireshards.scene_key() == "forest.opening")
	check(
		"a new game starts empty",
		Fireshards.total() == 0 and Fireshards.pending_shards().is_empty()
	)
	check("the shard readout starts hidden", not counter_group.visible)
	await step(6)

	# 1. A defeated enemy leaves its fireshards on the ground instead of paying them out instantly.
	var guard := find_enemy()
	var practice: EnemySettings = load("res://settings/enemies/sentinel.tres")
	check("an authored enemy carries a shard reward", guard != null)
	check(
		"practice targets stay worthless", practice.fireshard_reward == 0, practice.fireshard_reward
	)
	var reward := 0
	var enemy_spot := Vector3.ZERO
	if guard != null:
		reward = Fireshards.reward_for(guard)
		enemy_spot = guard.global_position + Vector3.UP * .35
		guard.receive_hit(999.0, 7100, guard.global_position + Vector3.FORWARD * 1.5)
		await step(6)
		check("the kill pays nothing out yet", Fireshards.total() == 0, Fireshards.total())
		var dropped := Fireshards.pending_shards()
		check(
			"the enemy leaves one pile",
			dropped.size() == 1 and String(dropped[0].get("kind", "")) == "enemy",
			dropped
		)
		var shard := live_shards()
		check(
			"the pile waits where the enemy fell",
			shard.size() == 1 and shard[0].global_position.distance_to(enemy_spot) < .01,
			shard[0].global_position if shard.size() == 1 else Vector3.ZERO
		)
		check(
			"the pile carries the enemy reward",
			shard.size() == 1 and shard[0].amount == reward,
			reward
		)
		silence_actors()
		check("the far player absorbs nothing", Fireshards.total() == 0)
		check(
			"walking up to the pile absorbs it",
			await approach_and_absorb(enemy_spot, "enemy_shards"),
			Fireshards.total()
		)
		check("the enemy reward is now carried", Fireshards.total() == reward, Fireshards.total())
		check("the absorbed pile leaves the world", live_shards().is_empty(), shard_report())
		check("the absorption is reported", reported("collected", reward))
		check(
			"the HUD counter follows the wallet",
			counter.text == str(Fireshards.total()),
			counter.text
		)
		check("the readout shows up around the change", counter_group.visible)
		var faded := false
		for _i in 500:
			await step(1)
			if not counter_group.visible:
				faded = true
				break
		check("the readout fades away again", faded, counter_group.modulate.a)

	# A per-instance override on a placed enemy must win over its archetype value.
	if guard != null:
		guard.disabled = false
		guard.fireshard_reward_override = 7
		check("a placed enemy overrides its archetype reward", Fireshards.reward_for(guard) == 7)
		guard.fireshard_reward_override = -1
		check(
			"clearing the override restores the archetype reward",
			Fireshards.reward_for(guard) == reward
		)
		guard.disabled = true

	# A kill right on top of the player must still show the shards before they are absorbed.
	if guard != null:
		guard.disabled = false
		guard.reset_target()
		var pile_spot: Vector3 = guard.global_position + Vector3.UP * .35
		p.respawn(pile_spot + Vector3(0, 0, .6))
		await step(4)
		var before_close: int = Fireshards.total()
		guard.receive_hit(999.0, 7200, guard.global_position + Vector3.FORWARD * 1.5)
		await step(12)
		check(
			"a kill on top of the player still shows the pile",
			live_shards().size() == 1 and Fireshards.total() == before_close,
			{"shards": shard_report(), "total": Fireshards.total()}
		)
		await step(44)
		check(
			"the pile then pulls itself in",
			Fireshards.total() == before_close + reward,
			Fireshards.total()
		)
		check(
			"the shards stay visible while flying",
			live_shards().size() == 1 and live_shards()[0].absorbing,
			shard_report()
		)
		await capture("point_blank_flight")
		# The counter eases up to the new total instead of snapping to it.
		var samples: Array[int] = []
		for _i in 90:
			await step(1)
			samples.append(int(counter.text))
		var climbed := false
		for shown in samples:
			climbed = climbed or (shown > before_close and shown < before_close + reward)
		check(
			"the counter climbs smoothly to the new total",
			climbed and samples.back() == before_close + reward,
			[samples.front(), samples.back(), climbed]
		)
		await step(120)
		check("the pile finishes its flight", live_shards().is_empty(), shard_report())
		silence_actors()

	# 2. Death drops the carried fireshards where the player fell.
	await step(10)
	start_spot = p.global_position
	await walk_away(4.2)
	var walked: float = p.global_position.distance_to(start_spot)
	check(
		"the player walked clear of the start",
		p.is_on_floor() and walked > 4.2,
		{"walked": walked, "position": p.global_position}
	)
	var carried: int = Fireshards.total()
	check("there are fireshards to lose", carried > 0, carried)
	# Only resting at a Vuurlelie writes the save; picking up and dying do not.
	var disk_before := JSON.stringify(SaveStore.read_slot(0))
	await die()
	var loss := Fireshards.pending_loss()
	check("the wallet is emptied on death", Fireshards.total() == 0, Fireshards.total())
	check("death banks the carried fireshards", int(loss.get("amount", 0)) == carried, loss)
	check("the loss remembers its own area", String(loss.get("area", "")) == "forest.opening", loss)
	var recorded: Array = loss.get("position", [])
	check(
		"the loss remembers the death spot",
		(
			recorded.size() == 3
			and Vector3(recorded[0], recorded[1], recorded[2]).distance_to(death_spot) < .01
		),
		[recorded, death_spot]
	)
	var dropped_shards := live_shards()
	check(
		"the loss already waits in the level",
		dropped_shards.size() == 1 and dropped_shards[0].kind == Fireshards.KIND_LOST,
		dropped_shards.size()
	)
	check("a dead player absorbs nothing", Fireshards.total() == 0 and not loss.is_empty())
	check("dying does not write the save", JSON.stringify(SaveStore.read_slot(0)) == disk_before)

	# 3. After the respawn the player walks back to it and absorbs it.
	await respawn()
	var found := live_shards()
	check(
		"the lost fireshards wait in the level",
		found.size() == 1 and found[0].amount == carried,
		found.size()
	)
	# Standing at the checkpoint must not pull the pile in from across the map.
	await step(360)
	check(
		"the loss stays put while the player stands at the checkpoint",
		live_shards().size() == 1 and Fireshards.total() == 0,
		{
			"shards": shard_report(),
			"player": p.global_position,
			"pile": death_spot,
			"distance": p.global_position.distance_to(death_spot),
			"total": Fireshards.total()
		}
	)
	await capture("lost_shards")
	check(
		"walking back into it absorbs the loss",
		await approach_and_absorb(death_spot),
		Fireshards.total()
	)
	check(
		"the carried fireshards are back",
		Fireshards.total() == carried and Fireshards.pending_loss().is_empty(),
		Fireshards.total()
	)
	check("the absorbed loss leaves the world", live_shards().is_empty(), shard_report())
	check("absorbing fireshards does not write the save", JSON.stringify(SaveStore.read_slot(0)) == disk_before)

	# 4. Dying right on top of your own respawn point must not hand the loss straight back:
	# that pile waits until the player has stepped clear and walked back into it.
	var before_anchor: int = Fireshards.total()
	p.respawn(checkpoint_spot)
	await step(6)
	await die()
	await respawn()
	await step(240)
	check(
		"a pile under the respawn is not swallowed at once",
		live_shards().size() == 1 and Fireshards.total() == 0,
		{"shards": shard_report(), "total": Fireshards.total()}
	)
	await walk_away(3.0)
	check(
		"stepping clear arms the pile",
		Fireshards.total() == 0 and live_shards().size() == 1,
		{"shards": shard_report(), "total": Fireshards.total()}
	)
	check(
		"walking back into it absorbs the loss",
		await approach_and_absorb(death_spot),
		Fireshards.total()
	)
	check(
		"the loss from the respawn point is back",
		Fireshards.total() == before_anchor,
		Fireshards.total()
	)

	# 5. A second death without absorbing destroys the older loss for good.
	events.clear()
	var lost_again: int = Fireshards.total()
	await die()
	check(
		"the second death banks the fireshards again",
		int(Fireshards.pending_loss().get("amount", 0)) == lost_again
	)
	await respawn()
	var second := live_shards()
	check(
		"the second loss waits in the level",
		second.size() == 1 and second[0].amount == lost_again,
		second.size()
	)
	await capture("second_loss")
	await die()
	check(
		"dying with unabsorbed shards clears them",
		Fireshards.pending_loss().is_empty() and Fireshards.total() == 0,
		{"total": Fireshards.total(), "loss": Fireshards.pending_loss()}
	)
	check("the loss is reported", reported("lost", lost_again))
	await respawn()
	check("those fireshards never return", live_shards().is_empty() and Fireshards.total() == 0)
	check("losing fireshards never writes the save", JSON.stringify(SaveStore.read_slot(0)) == disk_before)
	var empty_counter: Label = arena.get_node("HUD/Root/Fireshards/Value")
	check("the HUD counter shows an empty wallet", empty_counter.text == "0", empty_counter.text)

	var report := {
		"checks": results,
		"failures": failures,
		"render_frames": Engine.get_frames_drawn() - initial_render_frame,
		"seconds": (Time.get_ticks_msec() - initial_wall_ms) / 1000.0,
		"cap": render_cap
	}
	(
		FileAccess
		. open("res://captures/fireshards/checks_%d.json" % render_cap, FileAccess.WRITE)
		. store_string(JSON.stringify(report, "\t"))
	)
	print("FIRESHARDS_REPLAY_RESULT ", JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
