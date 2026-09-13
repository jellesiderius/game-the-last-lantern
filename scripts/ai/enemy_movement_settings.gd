class_name EnemyMovementSettings
extends Resource
## Ground steering profile. Radius must include the actor's physical capsule.
@export var radius := .25
@export var height := 1.0
@export var acceleration := 9.0
@export var braking := 14.0
@export var arrival_radius := .40
@export var path_interval := .32
@export var retarget_distance := .5
@export var path_look_ahead_time := .55
@export var preferred_path_clearance := .20
@export var obstacle_clearance := .10
@export var prediction_time := .55
@export var neighbor_distance := 2.4
@export var maximum_neighbors := 8
@export var personal_space := .12
@export var stuck_repath_time := .7
