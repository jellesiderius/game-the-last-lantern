extends Node3D
## Cosmetic flight and wing beats share the game clock, including pause and hitstop.
@export var phase := 0.0
@export var flight_radius := 1.8
var home := Vector3.ZERO
var wing_left: Node3D
var wing_right: Node3D


func _ready() -> void:
	home = position
	wing_left = find_child("Wing_L", true, false)
	wing_right = find_child("Wing_R", true, false)


func _physics_process(_delta: float) -> void:
	var t := GameClock.elapsed + phase
	var flight := Vector3(sin(t * .48) * flight_radius, sin(t * 1.6) * .14, cos(t * .67) * .65)
	position = home + flight
	rotation.y = atan2(cos(t * .48) * .48 * flight_radius, -sin(t * .67) * .67 * .65)
	var flap := sin(t * 23.0) * .85 + .22
	if wing_left:
		wing_left.rotation.z = flap
	if wing_right:
		wing_right.rotation.z = -flap
