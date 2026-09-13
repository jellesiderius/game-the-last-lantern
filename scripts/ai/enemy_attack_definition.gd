class_name EnemyAttackDefinition
extends AttackDefinition
## A complete enemy attack beat: authored clips, contact geometry and body travel.
@export var start_range := 0.85
@export var hit_range := 0.98
@export var half_angle := 60.0
@export var lunge := 0.24
@export var windup_clip: StringName = &"windup"
@export var recovery_clip: StringName = &"recover"
