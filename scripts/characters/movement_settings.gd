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
@export var roll_duration := 0.55
## Average roll speed; distance is roll_speed * roll_duration (3.36 m).
@export var roll_speed := 6.109
## Ease-out exponent: 1 is constant speed, higher bursts harder and settles softer.
@export_range(1.0, 3.0, 0.1) var roll_ease := 1.7
## Speed the roll eases down to; at walking pace the roll never stalls before walking on.
@export var roll_exit_speed := 4.5
@export var roll_iframe_start := 0.065
@export var roll_iframe_end := 0.35
@export var roll_recovery := 0.10
## A light click in this final part of the roll queues the roll attack.
@export_range(0.05, 0.5, 0.01) var roll_attack_window := 0.30
## A queued roll attack may cut this much off the end of the roll (its upright slide).
@export_range(0.0, 0.3, 0.01) var roll_attack_cancel := 0.15
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
## Locked-on locomotion strafes around the target at this fraction of max_speed.
@export_range(0.3, 1.0, 0.05) var lock_on_speed_multiplier := 0.8
