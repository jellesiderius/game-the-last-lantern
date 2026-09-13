class_name EnemySettings
extends Resource
## Per-archetype combat and perception data, independent of the visible model.
@export var display_name := "Sentinel"
@export var maximum_health := 8.0
@export var move_speed := 1.5
@export var orbit_speed := 0.85
@export var orbit_radius := 1.85
@export var engagement_range := 2.5
@export var attack_range := 1.05
@export var strike_range := 1.32
@export var strike_half_angle := 65.0
@export var maximum_attack_height_difference := .45
@export var attack: AttackDefinition
## Optional moveset; the brain owns each actor's selected attack.
@export var attack_variants: Array[EnemyAttackDefinition] = []
@export var tactics: EnemyTactics
@export var variation: EnemyVariation
@export var movement: EnemyMovementSettings = EnemyMovementSettings.new()
@export var lunge_distance := 0.18
@export var reaction_time := 0.12
@export var perception_interval := 0.12
@export var aggro_range := 7.0
@export var memory_duration := 2.5
@export var leash_distance := 8.0
@export var tracking_fraction := 0.45
@export var turn_speed := 220.0
@export var face_travel_direction := false
@export var path_update_interval := 0.2
@export var alternate_orbit_after_attack := false
@export_group("Guard routine")
## Local offsets from the saved home position; an empty route keeps a sentry stationary.
@export var patrol_offsets := PackedVector3Array()
@export var patrol_speed := 0.90
@export var idle_wait_min := 2.4
@export var idle_wait_max := 3.2
@export var stagger_duration := 0.28
@export_group("Hit reactions")
## Damage/impact feedback always apply; these settings only govern interruption.
@export var stagger_on_hit := true
@export var interrupt_committed_attacks := false
## Starts after the first stagger's duration. Repeated hits never extend either timer.
@export_range(0.0, 5.0, 0.05) var stagger_resistance_duration := 1.2
@export_range(0.0, 1.0, 0.01) var committed_knockback_multiplier := 0.08
@export_range(0.0, 1.0, 0.01) var resistant_knockback_multiplier := 0.2
@export_group("Admission and appearance")
@export var post_attack_cooldown := 0.25
@export var archetype_priority := 1.0
@export var tint := Color(0.456, 0.110, 0.061)
