class_name SceneTravelSettings
extends Resource
@export_range(.1, 3, .05, "suffix:m") var exit_walk_distance := 1.5
@export_range(.1, 3, .05, "suffix:m") var entry_walk_distance := 1.5
@export_range(.5, 5, .1, "suffix:m/s") var walk_speed := 2.6
@export_range(.1, 1.5, .05, "suffix:s") var fade_duration := .45
@export_range(0, 1, .05, "suffix:s") var black_hold := .12

## Time for a threshold presentation before the shared curtain begins.
@export_range(0, 1, .05, "suffix:s") var departure_fade_delay := .12
