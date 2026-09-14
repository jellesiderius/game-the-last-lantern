class_name EnemyAttackDefinition
extends AttackDefinition
## A complete enemy attack beat: authored clips, contact geometry and body travel.
@export var start_range := 0.85
@export var hit_range := 0.98
@export var half_angle := 60.0
@export var lunge := 0.24
@export var windup_clip: StringName = &"windup"
@export var recovery_clip: StringName = &"recover"
## Extra choice score; raise it to make this beat the archetype's usual opener at its range.
@export var selection_bias := 0.0
@export_group("Pressure")
## Separate strikes delivered in one turn (min, max). Later strikes use quick_windup.
@export var strikes := Vector2i(1, 2)
## EnemySettings.attack_variants indices for the later strikes; empty repeats this beat.
@export var followups: Array[int] = []
## Tell length of a later strike or a counter. Still fully telegraphed. Keep consecutive
## contacts further apart than the player's damage i-frames (0.6 s), or later strikes cannot land.
@export_range(0.1, 2.0, 0.01) var quick_windup := 0.5
## Random extra hold at the top of the tell (min, max seconds). Punishes dodging on the first cue.
@export var delay_range := Vector2(0, .18)
