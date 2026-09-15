extends SceneTree
## Physical checks on the saved boundary, outside the editor and its generators.
var results: Array[Dictionary] = []
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(label: String, passed: bool) -> void:
	results.append({"check": label, "passed": passed})
	failures += 0 if passed else 1
	print("BOUNDARY_RUNTIME ", label, " ", "PASS" if passed else "FAIL")


func _run() -> void:
	var fixture := load("res://captures/level_builder/BoundaryFixture.tscn").instantiate() as Node3D
	var boundary := fixture.get_node("Terrain/Afkadering") as LevelBoundary
	var baked := boundary.get_node("Baked")
	root.add_child(fixture)
	await physics_frame
	await physics_frame
	check(
		"runtime uses the saved props and collider without rebuilding",
		boundary.get_node("Baked") == baked and not Engine.is_editor_hint()
	)
	var actor := CharacterBody3D.new()
	actor.collision_layer = 2
	actor.collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .2
	capsule.height = .8
	shape.shape = capsule
	actor.add_child(shape)
	fixture.add_child(actor)
	await physics_frame
	actor.position = Vector3(2, .5, -8)
	check(
		"character is blocked in the gap between two trees",
		actor.move_and_collide(Vector3(0, 0, 4)) != null and actor.position.z < -6
	)
	actor.position = Vector3(10, .5, 1)
	check(
		"bent boundary blocks the second segment",
		actor.move_and_collide(Vector3(-4, 0, 0)) != null and actor.position.x > 8
	)
	actor.position = Vector3(0, 10.5, 6)
	check(
		"raised boundary blocks a character on the plateau",
		actor.move_and_collide(Vector3(0, 0, 4)) != null and actor.position.z < 8
	)
	boundary.get_node("Baked/Barrier").queue_free()
	await physics_frame
	await physics_frame
	actor.position = Vector3(2, .5, -8)
	check(
		"without the continuous barrier the gap is passable",
		actor.move_and_collide(Vector3(0, 0, 4)) == null and actor.position.z > -6
	)
	# Walk across the saved arched bridge in both directions, on its actual collider.
	actor.floor_snap_length = .3
	actor.position = Vector3(-6.3, .41, 0)
	var crest := 0.0
	for i in 270:
		await physics_frame
		actor.velocity = Vector3(3, actor.velocity.y - 20.0 / 60, 0)
		actor.move_and_slide()
		crest = maxf(crest, actor.position.y)
	check("character climbs over the bridge arch", crest > 2.3 and actor.position.x > 6.2)
	check("character descends back onto the ground", actor.position.y < .6)
	for i in 270:
		await physics_frame
		actor.velocity = Vector3(-3, actor.velocity.y - 20.0 / 60, 0)
		actor.move_and_slide()
	check(
		"arched bridge is walkable in the reverse direction",
		actor.position.x < -6.2 and actor.position.y < .6
	)
	var file := FileAccess.open(
		"res://captures/level_builder/boundary_runtime_checks.json", FileAccess.WRITE
	)
	file.store_string(JSON.stringify({"checks": results, "failures": failures}, "\t"))
	fixture.queue_free()
	await process_frame
	quit(1 if failures else 0)
