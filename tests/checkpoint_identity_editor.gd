@tool
extends Node3D
## Focused editor-only check. Open a disposable scene with --checkpoint-id-check.
var results: Array = []
var failures := 0


func _ready() -> void:
	if Engine.is_editor_hint() and "--checkpoint-id-check" in OS.get_cmdline_user_args():
		run.call_deferred()


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func check(label: String, passed: bool) -> void:
	results.append({"check": label, "passed": passed})
	failures += int(not passed)
	print("CHECKPOINT_ID ", label, " ", "PASS" if passed else "FAIL")


func run() -> void:
	while get_tree().edited_scene_root != self:
		await frames(1)
	assert(scene_file_path.begins_with("res://captures/vuurlelie/identity_"))
	await frames(8)
	if "--area-button-only" in OS.get_cmdline_user_args():
		await area_button_review()
		finish()
		return
	var expected_path := "res://captures/vuurlelie/identity_expected.json"
	var reload_mode := "--identity-reload" in OS.get_cmdline_user_args()
	var copied_mode := "--identity-copied" in OS.get_cmdline_user_args()
	if reload_mode or copied_mode:
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
		for child in get_children():
			if child is Vuurlelie:
				check(
					(
						"copied scene gets new identity"
						if copied_mode
						else "editor restart preserves saved identity"
					),
					(
						child.checkpoint_id != StringName(expected[child.name])
						if copied_mode
						else child.checkpoint_id == StringName(expected[child.name])
					)
				)
		finish()
		return
	var prefab := load("res://scenes/world/checkpoints/Vuurlelie.tscn") as PackedScene
	var point := prefab.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Vuurlelie
	point.name = "Original"
	add_child(point)
	await frames(4)
	check("waits for scene ownership", point.checkpoint_id.is_empty())
	point.owner = self
	await frames(6)
	check("drop creates ID without a button or setter", not point.checkpoint_id.is_empty())
	var original_id := point.checkpoint_id
	point.position = Vector3(8, 0, -4)
	point.name = "Renamed"
	await frames(4)
	check("moving and renaming preserves ID", point.checkpoint_id == original_id)
	var missing := prefab.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE) as Vuurlelie
	missing.name = "ReloadedBlank"
	add_child(missing)
	missing.owner = self
	await frames(6)
	missing.checkpoint_id = &""
	missing.editor_initialized = true
	await frames(6)
	check(
		"tool reload repairs an already initialized blank ID", not missing.checkpoint_id.is_empty()
	)
	var duplicate := point.duplicate() as Vuurlelie
	duplicate.name = "Duplicate"
	add_child(duplicate)
	duplicate.owner = self
	await frames(6)
	check(
		"duplicate gets a different ID",
		duplicate.checkpoint_id != original_id and not duplicate.checkpoint_id.is_empty()
	)
	check("duplicating preserves original ID", point.checkpoint_id == original_id)
	var duplicate_id := duplicate.checkpoint_id
	remove_child(duplicate)
	add_child(duplicate)
	duplicate.owner = self
	await frames(6)
	check("undo redo re-entry preserves assigned ID", duplicate.checkpoint_id == duplicate_id)
	for property in point.get_property_list():
		if property.name == "checkpoint_id":
			check(
				"generated ID is read-only in Inspector",
				bool(property.usage & PROPERTY_USAGE_READ_ONLY)
			)
	check("scene saves through actual editor", EditorInterface.save_scene() == OK)
	var expected := {}
	for child in get_children():
		if child is Vuurlelie:
			expected[child.name] = child.checkpoint_id
	FileAccess.open(expected_path, FileAccess.WRITE).store_string(JSON.stringify(expected))
	finish()


func area_button_review() -> void:
	var passage := (load("res://scenes/levels/ForestPassage.tscn") as PackedScene).instantiate(
		PackedScene.GEN_EDIT_STATE_INSTANCE
	)
	add_child(passage)
	passage.owner = self
	await frames(8)
	var script := load("res://scripts/world/vuurlelie.gd") as GDScript
	for stage in ["initial", "after script reload"]:
		if stage != "initial":
			check("tool script reload succeeds", script.reload(true) == OK)
			await frames(6)
		for point in passage.get_children():
			if not point is Vuurlelie:
				continue
			var original_id: StringName = point.checkpoint_id
			point.area = null
			# The Inspector fetches this property at click time, then calls it.
			var action: Variant = point.get("find_area")
			var valid: bool = action is Callable and action.is_valid()
			check("%s %s supplies a valid button Callable" % [point.name, stage], valid)
			if valid:
				action.call()
			check(
				"%s %s fills ForestPassage area" % [point.name, stage],
				point.area != null and point.area.code == &"forest.passage"
			)
			check(
				"%s %s preserves checkpoint ID" % [point.name, stage],
				point.checkpoint_id == original_id
			)


func finish() -> void:
	print("CHECKPOINT_ID_RESULT ", JSON.stringify({"checks": results, "failures": failures}))
	get_tree().quit(1 if failures else 0)
