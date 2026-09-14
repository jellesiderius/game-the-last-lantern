extends Control
## Screen-space reticle over the player's locked target. Presentation only.
@export var radius := 17.0
@export var height := .55
@export var color := Color(1.0, .8, .38, .95)
var pulse := 0.0


func _process(delta: float) -> void:
	var player := GameSession.player
	var target: Node3D = player.target_lock.target if player and player.is_node_ready() else null
	var camera := get_viewport().get_camera_3d()
	visible = (
		is_instance_valid(target)
		and camera != null
		and not camera.is_position_behind(target.global_position)
	)
	if not visible:
		return
	pulse = fposmod(pulse + GameClock.dt * 1.6, 1.0)
	var screen := camera.unproject_position(target.global_position + Vector3.UP * height)
	var parent_control := get_parent() as Control
	position = parent_control.get_global_transform_with_canvas().affine_inverse() * screen
	queue_redraw()


func _draw() -> void:
	var size_scale := 1.0 + .08 * sin(pulse * TAU)
	for i in 4:
		var start := i * TAU / 4 + TAU / 16
		draw_arc(Vector2.ZERO, radius * size_scale, start, start + TAU / 8, 8, color, 2.5, true)
	draw_circle(Vector2.ZERO, 2.5, color)
