@tool
extends EditorInspectorPlugin


class SpawnProperty:
	extends EditorProperty
	var options := OptionButton.new()
	var values := PackedStringArray()

	func _init() -> void:
		add_child(options)
		add_focusable(options)
		options.item_selected.connect(
			func(index): emit_changed(get_edited_property(), StringName(values[index]))
		)

	func _update_property() -> void:
		var portal := get_edited_object() as ScenePortal
		if portal == null:
			return
		values = LevelChecks.spawn_ids(portal.target_scene)
		var current := String(portal.target_spawn)
		options.clear()
		if not current in values:
			values.insert(0, current)
		for value in values:
			options.add_item(value if not value.is_empty() else "Kies een aankomstpunt")
		options.select(values.find(current))


func _can_handle(object: Object) -> bool:
	return object is ScenePortal


func _parse_property(
	object: Object,
	type: Variant.Type,
	name: String,
	_hint: PropertyHint,
	_hint_text: String,
	_usage: int,
	_wide: bool
) -> bool:
	if name == "target_spawn" and not object is ThresholdGate:
		add_property_editor(name, SpawnProperty.new())
		return true
	return false
