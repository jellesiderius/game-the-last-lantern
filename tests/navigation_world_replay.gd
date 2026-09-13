extends Node3D
## A separate 256 m level, no Arena inheritance, no bounds/paths/navigation region.
var failures := 0
var results: Array = []


func _ready() -> void:
	call_deferred("run")


func check(label: String, passed: bool, data = null) -> void:
	results.append({"check": label, "passed": passed, "data": data})
	if not passed:
		failures += 1
	print("CHECK ", label, " ", "PASS" if passed else "FAIL", " ", JSON.stringify(data))


func ready_surface(radius: float) -> EnemySurfaceNavigation:
	var navigation := NavigationWorld.surface_for($Probe, radius)
	var deadline := Time.get_ticks_msec() + 60000
	while not navigation.ready and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return navigation


func run() -> void:
	var started := Time.get_ticks_msec()
	var navigation := await ready_surface(.25)
	check(
		"256 m world automatically bakes without a level adapter",
		navigation.ready,
		Time.get_ticks_msec() - started
	)
	var from := to_global(Vector3(-100, 0, 0))
	var goal := to_global(Vector3(100, 0, 0))
	var path := navigation.route(from, goal, .25)
	check(
		"translated level has a connected 200 m world-space route",
		not path.is_empty() and path[-1].distance_to(goal) < .25,
		path
	)
	check(
		"large world wall blocks direct steering",
		not navigation.segment_clear(to_global(Vector3(-2, 0, 0)), to_global(Vector3(2, 0, 0)), .25)
	)
	check(
		"nearby actors share the same navigation map",
		navigation == NavigationWorld.surface_for($Probe, .25)
	)
	var island := to_global(Vector3(-150, 0, 0))
	var disconnected := navigation.route(from, island, .25)
	check(
		"disconnected island cannot acquire an unsafe direct route",
		disconnected.is_empty() or disconnected[-1].distance_to(island) > 1.0,
		disconnected
	)
	var before := NavigationWorld.signature
	$Wall.position.z = 40
	NavigationWorld.invalidate()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var updated := await ready_surface(.25)
	check(
		"changed collision invalidates geometry and rebuilds automatically",
		updated.ready and NavigationWorld.signature != before
	)
	check(
		"updated wall position frees the old corridor",
		updated.segment_clear(to_global(Vector3(-2, 0, 0)), to_global(Vector3(2, 0, 0)), .25)
	)
	var output := {
		"failures": failures,
		"results": results,
		"elapsed_ms": Time.get_ticks_msec() - started,
		"floor_size_m": 256,
		"root_position": global_position
	}
	(
		FileAccess
		. open("res://captures/acorn_guard/large_world_checks.json", FileAccess.WRITE)
		. store_string(JSON.stringify(output, "\t"))
	)
	print("WORLD_NAVIGATION_REPLAY_FINISHED ", failures, " failures")
	get_tree().quit(1 if failures else 0)
