class_name EnemyVariation
extends Resource
## Shared ranges only. Each Brain rolls and owns its own reproducible personality.
@export var speed_scale := Vector2(.9, 1.1)
@export var reaction_scale := Vector2(.75, 1.4)
@export var cooldown_scale := Vector2(.8, 1.6)
@export var orbit_scale := Vector2(.88, 1.15)
@export var idle_rate := Vector2(.85, 1.15)
@export var wait_scale := Vector2(.7, 1.3)
@export var patrol_scale := Vector2(.8, 1.12)
@export_range(0.0, 1.0) var look_chance := .7
@export var attack_preference := .10
@export var choice_jitter := .06


func sample(rng: RandomNumberGenerator, attack_count: int) -> Dictionary:
	var preferences: Array[float] = []
	for i in attack_count:
		preferences.append(rng.randf_range(-attack_preference, attack_preference))
	return {
		"speed": rng.randf_range(speed_scale.x, speed_scale.y),
		"reaction": rng.randf_range(reaction_scale.x, reaction_scale.y),
		"cooldown": rng.randf_range(cooldown_scale.x, cooldown_scale.y),
		"orbit": rng.randf_range(orbit_scale.x, orbit_scale.y),
		"idle_rate": rng.randf_range(idle_rate.x, idle_rate.y),
		"wait": rng.randf_range(wait_scale.x, wait_scale.y),
		"patrol_scale": rng.randf_range(patrol_scale.x, patrol_scale.y),
		"patrol_yaw": rng.randf_range(-PI, PI),
		"phase": rng.randf_range(0, 2),
		"side": -1.0 if rng.randf() < .5 else 1.0,
		"preferences": preferences
	}
