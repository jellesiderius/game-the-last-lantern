class_name MovementSettings
extends Resource
@export_range(0.1, 1.0, 0.05) var charge_move_multiplier := 0.35
@export var max_speed := 4.5
## Speeds represented by the authored in-place clips, in metres per second.
@export var walk_blend_speed := 1.8
@export var walk_cycle_speed := .75
@export var run_cycle_speed := 1.74545
@export var maximum_locomotion_rate := 2.6
@export var acceleration := 45.0
@export var braking := 60.0
@export var turn_speed_degrees := 1080.0
@export var stick_deadzone := 0.18
@export var gravity := 20.0
## Ignore tiny contact gaps on ramps before entering the airborne action.
@export_range(0.0, 0.15, 0.01) var fall_detection_delay := 0.06
@export var fall_minimum_speed := 1.0
@export var roll_duration := 0.42
@export var roll_speed := 8.0
@export var roll_iframe_start := 0.05
@export var roll_iframe_end := 0.27
@export var roll_recovery := 0.10
@export var input_buffer := 0.12
@export var damage_iframes := 0.60
@export var charge_duration := 0.45
## Default combat remains continuous; optional hitstop is limited to one pulse per swing.
@export var hitstop_duration := 0.0
@export var lunge_distance := 0.28
## A NEW click in this final recovery interval starts immediately; no stored follow-ups.
@export_range(0.0, 0.15, 0.01) var light_reinput_window := 0.10
@export var camera_shake := true

@export var camera_look_distance := 1.1
