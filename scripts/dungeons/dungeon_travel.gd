extends Node
## Routes and completion belong to the live save, never to a global gate instance.
signal dungeon_completed(dungeon: DungeonDefinition)
signal travel_failed(reason: String)
const ROUTES := "dungeon_return_routes"
const ABSORPTION = preload("res://scripts/dungeons/portal_absorption.gd")
var pending: Dictionary = {}
var absorption: RefCounted
var prepared_absorption: RefCounted


func _physics_process(_delta: float) -> void:
	if absorption == null:
		var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
		if player != null and player.is_node_ready():
			_prepare_actor(player)
	if absorption != null and SceneTransit.active:
		absorption.update()


func _watch_departure(portal: ScenePortal, player: PlayerCharacter) -> void:
	absorption = _prepare_actor(player)
	absorption.begin(player, portal)


func _prepare_actor(player: PlayerCharacter) -> RefCounted:
	if (
		prepared_absorption == null
		or not is_instance_valid(prepared_absorption.actor)
		or prepared_absorption.actor != player
	):
		prepared_absorption = ABSORPTION.new()
		prepared_absorption.prepare(player)
		_warm_actor.call_deferred(prepared_absorption)
	return prepared_absorption


func _warm_actor(effect: RefCounted) -> void:
	if not is_instance_valid(effect.actor) or not effect.warming:
		effect.warming = false
		return
	effect.prewarm()
	for i in 2:
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
	if effect.warming:
		effect.finish_prewarm()


## SceneTransit waits for this under the loading curtain, before returning control.
func prepare_arrival() -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
	if player == null:
		return
	var effect := _prepare_actor(player)
	while effect.warming:
		await get_tree().process_frame


func _ready() -> void:
	SceneTransit.transition_finished.connect(_arrived)
	SceneTransit.transition_failed.connect(_failed)


func completed(dungeon: DungeonDefinition) -> bool:
	return dungeon != null and bool(GameProgress.world_flag(dungeon.completion_flag()))


func _routes() -> Array:
	var routes: Variant = GameProgress.data.get("world", {}).get(ROUTES, [])
	return routes.duplicate(true) if routes is Array else []


func enter(
	gate: ScenePortal,
	dungeon: DungeonDefinition,
	gate_id: StringName,
	return_spawn: StringName,
	player: PlayerCharacter
) -> bool:
	if not pending.is_empty() or SceneTransit.active:
		return false
	var current := get_tree().current_scene
	if (
		dungeon == null
		or dungeon.id.is_empty()
		or gate_id.is_empty()
		or return_spawn.is_empty()
		or current == null
		or current.scene_file_path.is_empty()
	):
		travel_failed.emit("Deze Drempelpoort mist een dungeon of een opgeslagen terugkeerpunt.")
		return false
	var route := {
		"dungeon": String(dungeon.id),
		"destination": dungeon.scene_path,
		"source": current.scene_file_path,
		"gate": String(gate_id),
		"spawn": String(return_spawn)
	}
	if not SceneTransit.request_destination(
		player,
		dungeon.scene_path,
		dungeon.entrance,
		gate.exit_direction(),
		gate.settings,
		dungeon.display_name,
		false,
		true
	):
		return false
	pending = {"enter": true, "route": route}
	_watch_departure(gate, player)
	return true


func return_route(dungeon: DungeonDefinition) -> Dictionary:
	if dungeon == null:
		return {}
	var routes := _routes()
	if routes.is_empty() or not routes.back() is Dictionary:
		return {}
	var route: Dictionary = routes.back()
	if route.get("dungeon") != String(dungeon.id):
		return {}
	for field in ["source", "spawn", "destination", "gate"]:
		if not route.get(field) is String or route[field].is_empty():
			return {}
	return route


func leave(exit: ScenePortal, dungeon: DungeonDefinition, player: PlayerCharacter) -> bool:
	if not pending.is_empty() or SceneTransit.active:
		return false
	var route := return_route(dungeon)
	if route.is_empty():
		travel_failed.emit("Er is geen ingang onthouden. Betreed de dungeon via een Drempelpoort.")
		return false
	if not SceneTransit.request_destination(
		player,
		route.source,
		StringName(route.spawn),
		exit.exit_direction(),
		exit.settings,
		"Terug naar de buitenwereld",
		false,
		true
	):
		return false
	pending = {"enter": false, "route": route}
	_watch_departure(exit, player)
	return true


func _arrived(_scene: Node) -> void:
	if pending.is_empty():
		return
	GameProgress.ensure_preview()
	var routes := _routes()
	var route: Dictionary = pending.route
	if pending.enter:
		# A death/load outside the dungeon invalidates stale nesting, while genuine
		# dungeon-to-dungeon entrances keep their parent return route.
		while (
			not routes.is_empty()
			and (
				not routes.back() is Dictionary or routes.back().get("destination") != route.source
			)
		):
			routes.pop_back()
		routes.append(route)
	elif not routes.is_empty():
		routes.pop_back()
	GameProgress.data.world[ROUTES] = routes
	pending.clear()
	absorption = null


func _failed(reason: String) -> void:
	if pending.is_empty():
		return
	if absorption != null:
		absorption.restore()
	absorption = null
	pending.clear()
	travel_failed.emit(reason)


## Any dungeon challenge may call this: combat, puzzle, boss, or a scripted goal.
func complete(dungeon: DungeonDefinition) -> bool:
	if dungeon == null or dungeon.id.is_empty() or completed(dungeon):
		return false
	GameProgress.ensure_preview()
	for item: String in dungeon.completion_loot:
		var quantity := maxi(0, dungeon.completion_loot[item])
		GameProgress.data.inventory[item] = int(GameProgress.data.inventory.get(item, 0)) + quantity
	GameProgress.set_world_flag(dungeon.completion_flag())
	if GameProgress.active_slot >= 0:
		GameProgress.save(get_tree().get_first_node_in_group("player") as PlayerCharacter)
	dungeon_completed.emit(dungeon)
	return true
