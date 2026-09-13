extends "res://tests/runtime_replay.gd"
## Real six-target blade sweeps with render-frame and coordinated hitstop measurements.
var frame_intervals: Array[float] = []
var physics_times: Array[float] = []
var recording := false
var last_frame_us := 0


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if recording and last_frame_us > 0:
		frame_intervals.append((now - last_frame_us) / 1000.0)
		physics_times.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	last_frame_us = now


func percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * fraction))]


func run() -> void:
	prepare_window()
	arena = get_tree().current_scene
	p = arena.player
	targets = get_tree().get_nodes_in_group("damageable")
	render_cap = Engine.max_fps
	var enemies := targets.filter(func(actor): return actor.brain != null)
	check("six authored enemies available for crowd regression", enemies.size() >= 6)
	if enemies.size() < 6:
		get_tree().quit(1)
		return
	var baseline := "--crowd-baseline" in OS.get_cmdline_user_args()
	var trials: Array = []
	for charged in [false, true]:
		for count in [1, 6]:
			for repetition in 4:
				await reset(Vector3(0, 0, 3))
				p.magic.current = 0
				for i in count:
					var angle := deg_to_rad(lerpf(-50, 50, float(i) / 5.0)) if count > 1 else 0.0
					enemies[i].position = p.position + Vector3(sin(angle), 0, -cos(angle)) * .85
					# Keep the benchmark layout stable while exercising the real damage/AI reaction code.
					enemies[i].collision_layer = 0
				await step(3)
				frame_intervals.clear()
				physics_times.clear()
				recording = true
				var started := Time.get_ticks_usec()
				if charged:
					p.heavy_held = true
					p.request_action("heavy")
				else:
					p.request_action("light")
				await step(1)
				var stopped_ticks := 0
				var damage_ticks: Array = []
				var previous_hits := 0
				var elapsed_ticks := 0
				while p.state != "locomotion" and elapsed_ticks < 240:
					await step(1)
					elapsed_ticks += 1
					if GameClock.dt <= 0:
						stopped_ticks += 1
					var hits := 0
					for i in count:
						if enemies[i].health.current < enemies[i].health.maximum:
							hits += 1
					if hits > previous_hits:
						damage_ticks.append(
							{"tick": elapsed_ticks, "new_hits": hits - previous_hits}
						)
					previous_hits = hits
				recording = false
				var budget := ceili(
					p.visual.weapon.hitstop_duration * Engine.physics_ticks_per_second
				)
				var trial := {
					"charged": charged,
					"targets": count,
					"repetition": repetition,
					"hits": previous_hits,
					"damage_ticks": damage_ticks,
					"frozen_ticks": stopped_ticks,
					"expected_freeze_budget": budget,
					"wall_duration_ms": (Time.get_ticks_usec() - started) / 1000.0,
					"frame_p50_ms": percentile(frame_intervals, .5),
					"frame_p95_ms": percentile(frame_intervals, .95),
					"frame_max_ms": percentile(frame_intervals, 1),
					"physics_p95_ms": percentile(physics_times, .95),
				}
				trials.append(trial)
				check(
					"all targets hit once, one magic refill",
					previous_hits == count and p.magic.current == 1,
					trial
				)
				if not baseline:
					check(
						"one hitstop budget per whole swing",
						stopped_ticks <= budget + 1,
						stopped_ticks
					)
	var file := FileAccess.open(
		(
			"res://captures/crowd_"
			+ ("baseline" if baseline else "checks")
			+ "_"
			+ str(p.definition.id)
			+ "_"
			+ str(render_cap)
			+ ".json"
		),
		FileAccess.WRITE
	)
	file.store_string(
		JSON.stringify(
			{
				"failures": failures,
				"results": results,
				"trials": trials,
				"render_cap": render_cap,
				"physics_fps": Engine.physics_ticks_per_second,
				"observed_render_fps":
				(
					(Engine.get_frames_drawn() - initial_render_frame)
					* 1000.0
					/ maxi(1, Time.get_ticks_msec() - initial_wall_ms)
				)
			},
			"\t"
		)
	)
	file.close()
	print("CROWD_REPLAY_FINISHED ", failures, " failures; ", results.size(), " checks")
	get_tree().quit(1 if failures else 0)
