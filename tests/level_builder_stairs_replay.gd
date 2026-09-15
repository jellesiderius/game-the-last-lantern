extends "res://tests/level_builder_replay.gd"
## The real player walks over and along builder stairs and plateau edges: it must
## never snag, stall or drop into the airborne state, on outward and inset stairs.


func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://captures/level_builder")
	initial_frames = Engine.get_frames_drawn()
	GameProgress.ensure_preview()
	GameProgress.active_slot = 0
	var path := "res://captures/level_builder/StairsReplay.tscn"
	check("stairs fixture saves", _build_fixture(path) == OK)
	await load_world(path)
	var faces: PackedVector3Array = (
		world.get_node("Terrain/Baked/GroundCollision/SurfaceShape").shape.get_faces()
	)
	var degenerate := 0
	for i in range(0, faces.size(), 3):
		if (faces[i + 1] - faces[i]).cross(faces[i + 2] - faces[i]).length_squared() < 1e-12:
			degenerate += 1
	check("stairs collision has no zero-area triangles", degenerate == 0, degenerate)
	# Plateau A (1 m, edge at z=-4) with stairs leading out at x=-5 and set in at x=5.
	await _walk("outward up centre", Vector3(-5, 0, 0), Vector3(-5, 1, -6.5), 1.0)
	await _walk("outward down centre", Vector3(-5, 1, -6.5), Vector3(-5, 0, 0), 0.0)
	await _walk("outward up along left side", Vector3(-5.65, 0, 0), Vector3(-5.65, 1, -6.5), 1.0)
	await _walk("outward down along right side", Vector3(-4.35, 1, -6.5), Vector3(-4.35, 0, 0), 0.0)
	await _walk("outward diagonal up", Vector3(-6.5, 0, 0), Vector3(-4.6, 1, -6.5), 1.0, true)
	await _walk("outward diagonal down", Vector3(-4.6, 1, -6.5), Vector3(-6.5, 0, 0), 0.0, true)
	await _walk("inset up centre", Vector3(5, 0, -1), Vector3(5, 1, -7.5), 1.0)
	await _walk("inset down centre", Vector3(5, 1, -7.5), Vector3(5, 0, -1), 0.0)
	await _walk("inset up along left side", Vector3(4.35, 0, -1), Vector3(4.35, 1, -7.5), 1.0)
	await _walk("inset down along right side", Vector3(5.65, 1, -7.5), Vector3(5.65, 0, -1), 0.0)
	# Edges: along the plateau top past the outward stairs, along the wall foot past
	# the inset opening, and along the cheek wall of the outward stairs.
	await _walk("plateau top along edge past stairs", Vector3(-9, 1, -4.4), Vector3(-1, 1, -4.4), 1.0)
	await _walk("wall foot past inset opening", Vector3(9, 0, -3.6), Vector3(1, 0, -3.6), 0.0)
	await _walk("beside outward stairs cheek", Vector3(-6.4, 0, 0), Vector3(-6.4, 0, -3.5), 0.0)
	# Plateau C (2 m) with stairs leading out west at z=7.
	await _walk("tall outward up centre", Vector3(-1, 0, 7), Vector3(7, 2, 7), 2.0)
	await _walk("tall outward down centre", Vector3(7, 2, 7), Vector3(-1, 0, 7), 0.0)
	await _walk("tall outward up along side", Vector3(-1, 0, 7.65), Vector3(7, 2, 7.65), 2.0)
	await _walk("tall plateau top along edge past stairs", Vector3(4.4, 2, 4.6), Vector3(4.4, 2, 9.4), 2.0)
	# Bridge from plateau A (1 m) to plateau C (2 m) at x=8.
	await _walk("bridge up to the higher plateau", Vector3(8, 1, -6), Vector3(8, 2, 6), 2.0)
	await _walk("bridge down to the lower plateau", Vector3(8, 2, 6), Vector3(8, 1, -6), 1.0)
	await _walk("bridge along the rail", Vector3(8.55, 1, -6), Vector3(8.55, 2, 6), 2.0)
	await _walk("ground walk under the bridge", Vector3(5, 0, 0), Vector3(11, 0, 0), 0.0)
	_finish("stairs_traversal")


func _build_fixture(path: String) -> Error:
	var kit := load("res://settings/area_sets/forest.tres") as AreaSet
	var area := WorldArea.new()
	area.code = &"area.stairs_replay"
	area.display_name = "Stairs Replay"
	area.scene_path = path
	var root := FACTORY.create(kit, area, Vector2(30, 26))
	var terrain := root.get_node("Terrain") as LevelTerrain
	_plateau(terrain, root, Rect2(-10, -12, 20, 8), 1.0)
	_plateau(terrain, root, Rect2(4, 4, 8, 6), 2.0)
	var run := 1.0 / LevelTerrain.STAIR_SLOPE
	_stairs(terrain, root, Vector2(-5, -4 + run), Vector2(-5, -4), 1)
	_stairs(terrain, root, Vector2(5, -4), Vector2(5, -4 - run), 0)
	_stairs(terrain, root, Vector2(4 - 2 * run, 7), Vector2(4, 7), 1)
	var bridge := LevelBridge.new()
	bridge.name = "Brug"
	bridge.curve = Curve3D.new()
	bridge.curve.add_point(Vector3(8, 1, -4))
	bridge.curve.add_point(Vector3(8, 2, 4))
	terrain.add_child(bridge, true)
	bridge.owner = root
	var error := FACTORY.save(root, path)
	root.free()
	return error


func _plateau(terrain: LevelTerrain, root: Node, rect: Rect2, height: float) -> void:
	var plateau := LevelTerrace.new()
	plateau.name = "Plateau"
	plateau.curve = Curve3D.new()
	for corner in [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	]:
		plateau.curve.add_point(Vector3(corner.x, 0, corner.y))
	terrain.add_child(plateau, true)
	plateau.owner = root
	plateau.height = height


func _stairs(terrain: LevelTerrain, root: Node, low: Vector2, high: Vector2, anchor: int) -> void:
	var stairs := LevelRamp.new()
	stairs.name = "Trap"
	stairs.stairs = true
	stairs.fit_length = true
	stairs.anchor_end = anchor
	stairs.width = 2
	stairs.curve = Curve3D.new()
	stairs.curve.add_point(Vector3(low.x, 0, low.y))
	stairs.curve.add_point(Vector3(high.x, 0, high.y))
	terrain.add_child(stairs, true)
	stairs.owner = root


## Holds the stick toward `to` (fixed direction, or steering when `steer`) and
## records stalls, airborne frames and the final height.
func _walk(label: String, from: Vector3, to: Vector3, expected_y: float, steer := false) -> void:
	var p: CharacterBody3D = world.player
	p.test_input = Vector2.ZERO
	p.respawn(from + Vector3.UP * .05)
	await frames(20)
	var heading := Vector3(to.x - from.x, 0, to.z - from.z)
	var total := heading.length()
	heading = heading.normalized()
	var limit := int(10.0 * Engine.physics_ticks_per_second)
	var last := p.global_position
	var stall := 0
	var longest_stall := 0
	var airborne := 0
	var drift := 0.0
	var reached := false
	for tick in limit:
		var offset := Vector3(p.global_position.x - from.x, 0, p.global_position.z - from.z)
		if offset.dot(heading) >= total - .15:
			reached = true
			break
		var remaining := Vector3(to.x - p.global_position.x, 0, to.z - p.global_position.z)
		p.test_input = _world_input(remaining.normalized() if steer else heading)
		await frames(1)
		var moved := Vector2(p.global_position.x - last.x, p.global_position.z - last.z).length()
		stall = stall + 1 if moved < .002 else 0
		longest_stall = maxi(longest_stall, stall)
		airborne += 1 if p.state == "fall" else 0
		if not steer:
			drift = maxf(drift, (offset - heading * offset.dot(heading)).length())
		last = p.global_position
	p.test_input = Vector2.ZERO
	await frames(10)
	var detail := {"position": p.global_position, "stall": longest_stall, "airborne": airborne, "drift": drift}
	check(label + " reaches the end", reached, detail)
	check(label + " never snags", longest_stall < 4, detail)
	check(label + " stays grounded", airborne == 0, detail)
	check(label + " keeps its line", drift < .25, detail)
	check(label + " ends on the right level", absf(p.global_position.y - expected_y) < .08, detail)
