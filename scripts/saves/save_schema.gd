class_name SaveSchema
extends RefCounted
## Plain, versioned data only. Checkpoint IDs and area IDs never depend on node names/positions.
const VERSION := 1
const SLOT_COUNT := 3
const START_ID := "start.forest_stump"
const START_AREA := "forest.opening"
const FIRESHARDS_KEY := "fireshards"
const FIRE_SHARDS_KEY := "fire_shards"
## The first build of this system called the currency souls; those saves keep working.
const LEGACY_TOTAL_KEY := "souls"
const LEGACY_SHARDS_KEY := "soul_drops"
const LEGACY_SHARD_KEY := "soul_drop"
const SHARD_KINDS: Array[String] = ["enemy", "lost"]


static func new_game() -> Dictionary:
	return {
		"version": VERSION,
		"play_seconds": 0.0,
		"stats": {"max_health": 5.0, "max_magic": 4},
		"display_lives": 5,
		"inventory": {},
		"skills": ["bow"],
		"world": {},
		FIRESHARDS_KEY: 0,
		FIRE_SHARDS_KEY: [],
		"lit_checkpoints": [],
		"checkpoint": {"id": START_ID, "area": START_AREA, "location": "Onbekende locatie"},
		"opening_completed": false,
		"last_saved_unix": 0.0
	}


## Older saves (and editor fixtures) lack these optional keys; the souls-era keys are folded
## into the fireshard ones so nothing a player already collected is lost.
static func normalize(data: Dictionary) -> Dictionary:
	data[FIRESHARDS_KEY] = maxi(0, int(data.get(FIRESHARDS_KEY, data.get(LEGACY_TOTAL_KEY, 0))))
	var shards: Array = []
	var stored: Variant = data.get(FIRE_SHARDS_KEY, data.get(LEGACY_SHARDS_KEY, []))
	if stored is Array:
		for entry in stored:
			var cleaned := clean_shard(entry)
			if not cleaned.is_empty():
				shards.append(cleaned)
	var single: Variant = data.get(LEGACY_SHARD_KEY, {})
	if single is Dictionary and not single.is_empty():
		var restored := clean_shard(single)
		if not restored.is_empty():
			shards.append(restored)
	for key in [LEGACY_TOTAL_KEY, LEGACY_SHARDS_KEY, LEGACY_SHARD_KEY]:
		data.erase(key)
	data[FIRE_SHARDS_KEY] = shards
	return data


## Returns {} for anything that cannot be trusted; every other entry gets a stable identity.
static func clean_shard(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var position: Variant = entry.get("position", [])
	if (
		not entry.get("area") is String
		or not position is Array
		or position.size() != 3
		or not _number(entry.get("amount"))
		or int(entry.amount) <= 0
	):
		return {}
	var axes: Array = []
	for axis in position:
		if not _number(axis):
			return {}
		axes.append(float(axis))
	var id: Variant = entry.get("id", "")
	if not id is String or id.is_empty():
		id = Crypto.new().generate_random_bytes(8).hex_encode()
	var kind: Variant = entry.get("kind", "lost")
	if not kind is String or not kind in SHARD_KINDS:
		kind = "lost"
	return {
		"id": id, "area": entry.area, "position": axes, "amount": int(entry.amount), "kind": kind
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
	if not _valid_total(data, FIRESHARDS_KEY) or not _valid_total(data, LEGACY_TOTAL_KEY):
		return false
	if data.has(LEGACY_SHARD_KEY) and not data.get(LEGACY_SHARD_KEY) is Dictionary:
		return false
	for key in [FIRE_SHARDS_KEY, LEGACY_SHARDS_KEY]:
		if not data.has(key):
			continue
		var stored: Variant = data.get(key)
		if not stored is Array:
			return false
		for entry in stored:
			if clean_shard(entry).is_empty():
				return false
	return true


static func _valid_total(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	var stored: Variant = data.get(key)
	return _number(stored) and stored >= 0 and stored <= 99999999


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))


static func time_label(seconds: float) -> String:
	var minutes := int(seconds) / 60
	return "%02d:%02d" % [minutes / 60, minutes % 60]
