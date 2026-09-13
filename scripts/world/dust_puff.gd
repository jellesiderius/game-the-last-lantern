extends Node3D
## Transient instance of an authored mesh scene; shares pause/hitstop with gameplay.
@export var lifetime := 0.50
var age := 0.0
@onready var cloud: Node3D = $Cloud


func _physics_process(_delta: float) -> void:
	var delta := GameClock.dt
	if delta <= 0.0:
		return
	age += delta
	var phase := clampf(age / lifetime, 0.0, 1.0)
	cloud.scale = Vector3.ONE * lerpf(0.55, 1.4, phase)
	cloud.position.y = phase * 0.12
	var opacity := (1.0 - smoothstep(0.15, 1.0, phase)) * 0.7
	for mesh: MeshInstance3D in cloud.get_children():
		mesh.set_instance_shader_parameter("opacity", opacity)
	if age >= lifetime:
		queue_free()
