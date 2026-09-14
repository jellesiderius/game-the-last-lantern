class_name DirectorSettings
extends Resource
@export_range(1, 8, 1) var maximum_attackers := 2
@export var grant_spacing := 0.18
@export var approach_lease_timeout := 2.5
@export var distance_weight := 2.0
@export var recent_hit_weight := 1.3
@export var archetype_weight := 0.5
@export var waiting_weight := 0.35
## Extra priority for an enemy that sees the player recovering from an action.
@export var opening_weight := 1.5
## Followup strikes yield the turn once another enemy has waited this long.
@export var chain_wait_limit := 2.5
