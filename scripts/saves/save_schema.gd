class_name SaveSchema
extends RefCounted
## Plain, versioned data only. Checkpoint IDs and area IDs never depend on node names/positions.
const VERSION := 1
const SLOT_COUNT := 3
const START_ID := "start.forest_stump"
const START_AREA := "forest.opening"


static func new_game() -> Dictionary:
	return {
		"version": VERSION,
		"play_seconds": 0.0,
		"stats": {"max_health": 5.0, "max_magic": 4},
		"display_lives": 5,
		"inventory": {},
		"skills": ["bow"],
		"world": {},
		"lit_checkpoints": [],
		"checkpoint": {"id": START_ID, "area": START_AREA, "location": "Onbekende locatie"},
		"opening_completed": false,
		"last_saved_unix": 0.0
	}


static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION:
		return false
	for key in ["stats", "inventory", "world", "checkpoint"]:
		if not data.get(key) is Dictionary:
			return false
	for key in ["skills", "lit_checkpoints"]:
		if not data.get(key) is Array:
			return false
		for entry in data[key]:
			if not entry is String or entry.is_empty():
				return false
	if not data.get("opening_completed") is bool:
		return false
	for number in [data.get("play_seconds"), data.get("last_saved_unix")]:
		if not _number(number) or number < 0:
			return false
	for number in [
		data.stats.get("max_health"), data.stats.get("max_magic"), data.get("display_lives")
	]:
		if not _number(number) or number < 1 or number > 99:
			return false
	for key in ["id", "area", "location"]:
		if not data.checkpoint.get(key) is String or data.checkpoint[key].strip_edges().is_empty():
			return false
	return true


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func time_label(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%02d:%02d" % [minutes / 60, minutes % 60]
