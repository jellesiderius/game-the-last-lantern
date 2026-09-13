class_name BowSettings
extends Resource
@export var minimum_draw := 0.25
@export var recovery := 0.20
@export var release_moment := 0.03
@export var arrow_speed := 18.0
@export var maximum_distance := 16.0
@export var charged_arrow_unlocked := false
@export var charged_draw := 0.80
@export var charged_multiplier := 2.0
@export var automatic_draw_duration := 0.6
@export_range(0.1, 1.0, 0.05) var charge_move_multiplier := 0.3
@export var equip_duration := 0.18
@export var unequip_duration := 0.14
@export_range(0.15, 0.6, 0.01) var empty_duration := 0.32

@export var aim_line_length := 2.2


func full_draw_duration() -> float:
	return maxf(minimum_draw, charged_draw if charged_arrow_unlocked else automatic_draw_duration)
