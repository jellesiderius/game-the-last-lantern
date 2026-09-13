class_name AttackDefinition
extends Resource
## One editable definition shared by animation timing, damage and effects.
@export var clip: StringName
@export_range(0, 2, 0.01) var windup := 0.08
@export_range(0.01, 2, 0.01) var active_duration := 0.10
@export_range(0, 2, 0.01) var recovery := 0.18
@export var damage := 1.0
@export var charged_damage := 1.0
@export var charged_clip: StringName
@export var knockback := 2.0
@export var charged_knockback := 2.0
@export var charged_hitstop := 0.0
## Enemy strikes may delay contact until the authored weapon reaches the target.
@export_range(0.0, 0.95, 0.05) var enemy_contact_fraction := 0.0


func duration() -> float:
	return windup + active_duration + recovery


func is_active(time: float) -> bool:
	return time >= windup and time < windup + active_duration
