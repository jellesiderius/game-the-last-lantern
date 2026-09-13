class_name EntranceSequence
extends Resource
## A level-authored entrance, sampled by PlayerCharacter's action clock.
@export var animation := "entrance"
@export_range(0.0, 10.0) var takeoff_time := 2.55
@export_range(0.0, 2.0) var landing_recovery := 0.32
@export var direction := Vector3.BACK
@export var horizontal_speed := 3.2
@export var jump_speed := 3.5
