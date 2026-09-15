extends Node
## Fireshards: the currency and the glowing shards that still have to be absorbed.
## A defeated enemy and the player's death both leave shards behind; walking close pulls them in.
## GameProgress owns the live values, SaveStore owns the disk copy, GameSession owns the player.
signal fireshards_changed(total: int)
signal shards_changed
signal shards_collected(amount: int)
signal shards_lost(amount: int)
const TOTAL_KEY := SaveSchema.FIRESHARDS_KEY
const SHARDS_KEY := SaveSchema.FIRE_SHARDS_KEY
const KIND_ENEMY := "enemy"
const KIND_LOST := "lost"
const SHARD_SCENE := preload("res://scenes/world/fireshards/FireShard.tscn")
var _shards: Dictionary = {}
var _scene: Node
var _area_codes: Dictionary = {}


func _ready() -> void:
	_remember_areas()
	SceneTransit.transition_finished.connect(_transition_finished)
	GameSession.player_registered.connect(_player_registered)
	_player_registered(GameSession.player)


## Level identity comes from the saved scene path, so shards survive every reload.
func _remember_areas() -> void:
	for area in WorldArea.discover():
		if not area.scene_path.is_empty():
			_area_codes[area.scene_path] = String(area.code)


func scene_key(scene: Node = null) -> String:
	var target := scene if scene != null else get_tree().current_scene
	if target == null:
		return ""
	var path := target.scene_file_path
	if path.is_empty():
		return ""
	return _area_codes.get(path, path)


func total() -> int:
	return int(GameProgress.data.get(TOTAL_KEY, 0))


## One place for the reward rule: a placed enemy overrides its archetype profile.
## Damageable.fireshard_reward_override is edited per enemy in the Godot Inspector.
func reward_for(enemy: Node) -> int:
	if enemy == null:
		return 0
	var override: Variant = enemy.get("fireshard_reward_override")
	if override is int and int(override) >= 0:
		return int(override)
	var brain: Variant = enemy.get("brain")
	if brain is EnemyBrain and brain.settings != null:
		return maxi(0, brain.settings.fireshard_reward)
	return 0


func pending_shards() -> Array:
	var stored: Variant = GameProgress.data.get(SHARDS_KEY, [])
	return stored if stored is Array else []


## The single shard pile left by the player's own death, if it is still waiting.
func pending_loss() -> Dictionary:
	for entry in pending_shards():
		if entry is Dictionary and String(entry.get("kind", "")) == KIND_LOST:
			return entry
	return {}


func find_shard(id: String) -> Dictionary:
	for entry in pending_shards():
		if entry is Dictionary and String(entry.get("id", "")) == id:
			return entry
	return {}


## A defeated enemy leaves its fireshards where it fell; nothing is credited until absorbed.
func drop_from_enemy(amount: int, at: Vector3) -> Dictionary:
	if amount <= 0:
		return {}
	return _add_shard(amount, at, KIND_ENEMY)


## Every death banks the carried fireshards where the player fell. Dying again before
## absorbing them destroys the older loss; shards of defeated enemies stay untouched.
func lose_to_death(at: Vector3) -> void:
	var previous := pending_loss()
	if not previous.is_empty():
		_remove_shard(String(previous.get("id", "")))
		shards_lost.emit(int(previous.get("amount", 0)))
	var carried := total()
	GameProgress.data[TOTAL_KEY] = 0
	if carried > 0:
		_add_shard(carried, at, KIND_LOST)
	fireshards_changed.emit(0)


## Called by the saved FireShard scene when the player reaches it. Returns the absorbed amount.
func absorb(id: String) -> int:
	var entry := find_shard(id)
	if entry.is_empty():
		return 0
	var amount := int(entry.get("amount", 0))
	# The shard plays its own absorption animation from here, so stop tracking it first.
	_shards.erase(id)
	_remove_shard(id)
	GameProgress.data[TOTAL_KEY] = total() + amount
	shards_collected.emit(amount)
	fireshards_changed.emit(total())
	_sync_shards()
	return amount


## Shards only exist in the level they were left in. Public for focused checks.
func sync_scene() -> void:
	_free_shards()
	_sync_shards()


func _add_shard(amount: int, at: Vector3, kind: String) -> Dictionary:
	GameProgress.ensure_preview()
	var entry := {
		"id": Crypto.new().generate_random_bytes(8).hex_encode(),
		"area": scene_key(),
		"position": [at.x, at.y, at.z],
		"amount": amount,
		"kind": kind
	}
	var shards := pending_shards()
	shards.append(entry)
	GameProgress.data[SHARDS_KEY] = shards
	shards_changed.emit()
	_sync_shards()
	return entry


func _remove_shard(id: String) -> void:
	var shards := pending_shards()
	for index in shards.size():
		var entry: Variant = shards[index]
		if entry is Dictionary and String(entry.get("id", "")) == id:
			shards.remove_at(index)
			break
	GameProgress.data[SHARDS_KEY] = shards
	shards_changed.emit()


## Spawns every saved shard that belongs to the loaded level and retires the rest.
func _sync_shards() -> void:
	var key := scene_key()
	var wanted: Dictionary = {}
	for entry in pending_shards():
		if entry is Dictionary and String(entry.get("area", "")) == key:
			wanted[String(entry.get("id", ""))] = entry
	# Untyped lookups: a shard of an unloaded level can already be freed while still stored.
	for id in _shards.keys():
		var shard = _shards[id]
		if is_instance_valid(shard) and wanted.has(id):
			continue
		if is_instance_valid(shard):
			shard.queue_free()
		_shards.erase(id)
	var scene := get_tree().current_scene
	if scene == null:
		return
	for id: String in wanted.keys():
		var node: FireShard = SHARD_SCENE.instantiate()
		scene.add_child(node)
		node.place(wanted[id])
		_shards[id] = node


func _free_shards() -> void:
	for shard in _shards.values():
		if is_instance_valid(shard):
			shard.queue_free()
	_shards.clear()


## Both the arrival signal and the polling path funnel through one scene identity, so a
## level never respawns its own shards twice in the same frame.
func _check_scene() -> void:
	var scene := get_tree().current_scene
	if scene == _scene:
		return
	_scene = scene
	sync_scene()


func _transition_finished(_scene_arrived: Node) -> void:
	_check_scene()


func _player_registered(player: PlayerCharacter) -> void:
	if player == null or player.died.is_connected(_player_died):
		return
	player.died.connect(_player_died)


func _player_died() -> void:
	var player := GameSession.player
	lose_to_death(player.global_position if is_instance_valid(player) else Vector3.ZERO)


func _process(_delta: float) -> void:
	_check_scene()
