extends Node
## One physics clock for gameplay, animation and damage windows. Never changes Engine.time_scale.
var paused := false
var stop_remaining := 0.0
var dt := 0.0
var elapsed := 0.0
var attack_serial := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -100


func _physics_process(delta: float) -> void:
	dt = 0.0 if paused or stop_remaining > 0.00001 else delta
	if not paused:
		stop_remaining = maxf(0.0, stop_remaining - delta)
	elapsed += dt


func hitstop(duration := 0.04) -> void:
	stop_remaining = maxf(stop_remaining, duration)


func next_attack_id() -> int:
	attack_serial += 1
	return attack_serial


func reset() -> void:
	paused = false
	stop_remaining = 0.0
	dt = 0.0
