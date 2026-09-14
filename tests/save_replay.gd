extends "res://tests/intro_replay.gd"
## Real disk transactions in a disposable namespace, including interrupted/corrupt generations.


func run() -> void:
	assert(SaveStore.directory.begins_with("user://save_tests/"))
	DirAccess.make_dir_recursive_absolute(SaveStore.directory)
	for file in DirAccess.get_files_at(SaveStore.directory):
		DirAccess.remove_absolute(SaveStore.directory.path_join(file))
	for i in 3:
		var data := SaveSchema.new_game()
		data.world["identity"] = i
		data.inventory["acorns"] = 10 * i
		data.play_seconds = 3660.0 * i
		check("new independent slot %d" % i, SaveStore.write_slot(i, data, true).ok)
	check("hours/minutes display", SaveSchema.time_label(9249) == "02:34")
	check("zero display", SaveSchema.time_label(59) == "00:00")
	for i in 3:
		check("independent inventory %d" % i, SaveStore.read_slot(i).inventory.acorns == 10 * i)
		check(
			"existing slot cannot be overwritten by New Game %d" % i,
			not SaveStore.write_slot(i, SaveSchema.new_game(), true).ok
		)
	var update := SaveStore.read_slot(0)
	update.world["version_two"] = true
	check("second generation saved", SaveStore.write_slot(0, update).ok)
	check("successful save has actual timestamp", SaveStore.read_slot(0).last_saved_unix > 0)
	SaveStore._write_file(SaveStore._path(0), "interrupted")
	var recovered := SaveStore.inspect_slot(0)
	check(
		"bad primary recovers previous valid generation",
		(
			recovered.state == "filled"
			and recovered.recovered
			and not recovered.data.world.has("version_two")
		)
	)
	check(
		"repair save keeps good backup",
		(
			SaveStore.write_slot(0, update).ok
			and SaveStore._read(SaveStore._path(0, ".bak")).world.identity == 0
		)
	)
	SaveStore._write_file(SaveStore._path(1, ".tmp"), "interrupted")
	check(
		"uncommitted temporary does not replace valid slot",
		SaveStore.read_slot(1).world.identity == 1
	)
	SaveStore._write_file(SaveStore._path(2), "broken")
	SaveStore._write_file(SaveStore._path(2, ".bak"), "broken")
	check(
		"corrupt occupied slot not silently reused",
		(
			SaveStore.inspect_slot(2).state == "damaged"
			and not SaveStore.write_slot(2, update, true).ok
		)
	)
	check(
		"explicit deletion can clear damaged slot",
		SaveStore.delete_slot(2) and SaveStore.inspect_slot(2).state == "empty"
	)
	SaveStore._write_file(
		SaveStore._path(2, ".bak"), FileAccess.get_file_as_string(SaveStore._path(0))
	)
	check(
		"leftover backup cannot resurrect deleted slot", SaveStore.inspect_slot(2).state == "empty"
	)
	check(
		"new game after deletion is clean",
		(
			SaveStore.write_slot(2, SaveSchema.new_game(), true).ok
			and SaveStore.read_slot(2).world.is_empty()
		)
	)
	var invalid := update.duplicate(true)
	invalid.stats.max_health = -1
	check(
		"invalid stats rejected without changing old save",
		not SaveStore.write_slot(0, invalid).ok and SaveStore.read_slot(0).world.version_two
	)
	var previous := SaveStore.directory
	var blocker := previous.path_join("blocked")
	SaveStore._write_file(blocker, "file blocks directory")
	SaveStore.directory = blocker.path_join("saves")
	check(
		"write failure reported as failure",
		not SaveStore.write_slot(0, update).ok and not SaveStore.last_error.is_empty()
	)
	SaveStore.directory = previous
	SaveStore.mark_played(0)
	check("Continue prefers last played slot", SaveStore.preferred_slot(false) == 0)
	SaveStore.delete_slot(1)
	check("New Game prefers first empty slot", SaveStore.preferred_slot(true) == 1)
	# The scene can be moved/renamed, configured, packed and instantiated without a controller-specific path.
	var world := Node3D.new()
	world.name = "PlacementFixture"
	world.scene_file_path = "res://scenes/levels/ForestPassage.tscn"
	get_tree().root.add_child(world)
	var point := load("res://scenes/world/checkpoints/Vuurlelie.tscn").instantiate() as Vuurlelie
	point.name = "AnyName"
	point._new_checkpoint_code()
	var stable_id := point.checkpoint_id
	world.add_child(point)
	point.owner = world
	point.position = Vector3(4, 0, 8)
	point.name = "MovedAndRenamed"
	check(
		"placed prefab infers its registered area",
		point.area != null and point.area.code == "forest.passage"
	)
	check("moving and renaming preserves explicit ID", point.checkpoint_id == stable_id)
	var external_spawn := Marker3D.new()
	external_spawn.name = "SafeArrival"
	external_spawn.position = Vector3(6, 0, 9)
	external_spawn.rotation.y = 1.2
	world.add_child(external_spawn)
	external_spawn.owner = world
	point.spawn_path = NodePath("../SafeArrival")
	var packed := PackedScene.new()
	check("configured prefab packs successfully", packed.pack(world) == OK)
	var copy := packed.instantiate()
	var copied_point := copy.get_node("MovedAndRenamed") as Vuurlelie
	check(
		"saved placement retains ID area and independent spawn",
		(
			copied_point.checkpoint_id == stable_id
			and copied_point.area.code == "forest.passage"
			and copied_point.get_node(copied_point.spawn_path).position == Vector3(6, 0, 9)
		)
	)
	check(
		"spawn facing retained",
		is_equal_approx(copied_point.get_node(copied_point.spawn_path).rotation.y, 1.2)
	)
	copy.free()
	world.free()
	DirAccess.make_dir_recursive_absolute("res://captures/vuurlelie")
	var report := {"failures": failures, "checks": results, "directory": SaveStore.directory}
	FileAccess.open("res://captures/vuurlelie/storage_checks.json", FileAccess.WRITE).store_string(
		JSON.stringify(report, "\t")
	)
	print("SAVE_REPLAY_RESULT ", JSON.stringify(report))
	get_tree().quit(1 if failures else 0)
