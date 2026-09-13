extends Node
## Global admission control; committed tells/strikes are never silently stolen.
var settings: DirectorSettings = preload("res://settings/enemies/director.tres")
var requests: Dictionary = {}
var leases: Dictionary = {}
var next_grant_at := 0.0
var grants := 0


func _ready() -> void:
	process_physics_priority = -30


func request_attack(brain: EnemyBrain) -> void:
	var id := brain.get_instance_id()
	if leases.has(id) or requests.has(id):
		return
	if brain.admission_wait_since < 0:
		brain.admission_wait_since = GameClock.elapsed
	requests[id] = {"brain": weakref(brain), "since": brain.admission_wait_since}


func release(brain: EnemyBrain, preserve_wait := false) -> void:
	var id := brain.get_instance_id()
	requests.erase(id)
	leases.erase(id)
	if not preserve_wait:
		brain.admission_wait_since = -1.0


func owns(brain: EnemyBrain) -> bool:
	return leases.has(brain.get_instance_id())


func reset() -> void:
	requests.clear()
	leases.clear()
	next_grant_at = 0.0
	grants = 0


func score(brain: EnemyBrain, waiting: float) -> float:
	return (
		(
			settings.distance_weight
			* (1.0 - clampf(brain.target_distance() / brain.settings.engagement_range, 0, 1))
		)
		+ settings.recent_hit_weight * clampf(brain.recent_hit / 2.0, 0, 1)
		+ settings.archetype_weight * brain.settings.archetype_priority
		# Keep age increasing: a capped bonus could starve an actor repeatedly
		# delayed by other bodies, even after preserving its original request time.
		+ settings.waiting_weight * maxf(waiting, 0.0)
	)


func _physics_process(_delta: float) -> void:
	if GameClock.dt <= 0:
		return
	for id in leases.keys():
		var brain: EnemyBrain = leases[id].brain.get_ref()
		if not is_instance_valid(brain) or not brain.operational():
			leases.erase(id)
		elif (
			brain.state == "engage"
			and GameClock.elapsed - leases[id].since > settings.approach_lease_timeout
		):
			leases.erase(id)
			brain.cancel_attack()
	var candidates: Array = []
	for id in requests.keys():
		var brain: EnemyBrain = requests[id].brain.get_ref()
		if not is_instance_valid(brain) or not brain.can_request_attack():
			requests.erase(id)
			continue
		candidates.append(
			{
				"id": id,
				"brain": brain,
				"score": score(brain, GameClock.elapsed - requests[id].since)
			}
		)
	candidates.sort_custom(
		func(a, b):
			return a.score > b.score if not is_equal_approx(a.score, b.score) else a.id < b.id
	)
	if (
		leases.size() >= settings.maximum_attackers
		or GameClock.elapsed < next_grant_at
		or candidates.is_empty()
	):
		return
	var winner: Dictionary = candidates[0]
	requests.erase(winner.id)
	leases[winner.id] = {"brain": weakref(winner.brain), "since": GameClock.elapsed}
	next_grant_at = GameClock.elapsed + settings.grant_spacing
	grants += 1
	winner.brain.grant_attack()


func debug_status() -> String:
	var names: PackedStringArray = []
	for lease in leases.values():
		var brain: EnemyBrain = lease.brain.get_ref()
		if is_instance_valid(brain):
			names.append("%s:%s" % [brain.get_parent().name, brain.state])
	return (
		"TOKENS %d/%d  WAIT %d\n%s"
		% [leases.size(), settings.maximum_attackers, requests.size(), ", ".join(names)]
	)
