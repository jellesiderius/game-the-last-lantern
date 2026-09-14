extends PanelContainer
## A small screen-space pill follows the player beside the selected world interaction.
var fade := 0.0


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as PlayerCharacter
	var target: Interactable = player.interaction.target if player else null
	var camera := get_viewport().get_camera_3d()
	var available: bool = (
		player != null
		and is_instance_valid(target)
		and camera != null
		and not GameClock.paused
		and not Dialogue.active
		and not SceneTransit.active
		and not Checkpoints.active
		and player.state == "locomotion"
	)
	if available:
		available = (
			not camera.is_position_behind(player.global_position) and target.can_interact(player)
		)
	fade = move_toward(fade, 1.0 if available else 0.0, delta * 10.0)
	visible = fade > .01
	modulate.a = fade
	if not available:
		return
	$Margin/Row/Key/Button.text = InputRouter.prompt("interact")
	$Margin/Row/Action.text = target.prompt
	reset_size()
	var screen := camera.unproject_position(player.global_position + Vector3.UP * .15)
	var parent_control := get_parent() as Control
	var canvas_position := (
		parent_control.get_global_transform_with_canvas().affine_inverse() * screen
	)
	position = canvas_position + Vector2(48, 26)
	position.x = clampf(position.x, 12, parent_control.size.x - size.x - 12)
	position.y = clampf(position.y, 12, parent_control.size.y - size.y - 56)
