class_name MeleeSwingStyle
extends Resource
## An authored pair of skeletal paths and the matching magical blade plane.
@export var id: StringName
@export var left_clip: StringName
@export var right_clip: StringName
## Positive rises along travel, negative descends; zero is a level waist cut.
@export_range(-40.0, 40.0, 1.0) var slope_degrees := 0.0
@export var energy_height := 0.72
@export var windup := 0.08
@export var active_duration := 0.10
@export var recovery := 0.18


func sample_time(attack: AttackDefinition, time: float) -> float:
	if time < attack.windup:
		return time / attack.windup * windup
	if time < attack.windup + attack.active_duration:
		return windup + (time - attack.windup) / attack.active_duration * active_duration
	return (
		windup
		+ active_duration
		+ (time - attack.windup - attack.active_duration) / attack.recovery * recovery
	)
