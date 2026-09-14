class_name DialogueInteractable
extends Interactable
## Attach below any NPC, sign or inscription. ActorInteraction supplies distance and sight checks.
@export var conversation: DialogueConversation
signal conversation_finished(actor: Node3D)
## Optional visual pivot. Leave empty for signs and inscriptions.
@export_node_path("Node3D") var facing_node: NodePath
@export_range(1, 15, .5) var turn_speed := 7.0


func _physics_process(delta: float) -> void:
	if facing_node.is_empty():
		return
	var reader := get_tree().get_first_node_in_group("player") as PlayerCharacter
	if reader == null:
		return
	var talking: bool = Dialogue.active and Dialogue.source == self
	if not talking and (GameClock.paused or reader.interaction.target != self):
		return
	var pivot := get_node_or_null(facing_node) as Node3D
	if pivot == null:
		return
	var direction := reader.global_position - pivot.global_position
	direction.y = 0.0
	if direction.length_squared() < .01:
		return
	var dt := delta if talking else GameClock.dt
	pivot.global_rotation.y = lerp_angle(
		pivot.global_rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-turn_speed * dt)
	)


func can_interact(actor: Node3D) -> bool:
	return (
		super.can_interact(actor)
		and conversation != null
		and conversation.has_content()
		and not Dialogue.active
		and not SceneTransit.active
		and not Checkpoints.active
	)


func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	# Finish the initiating physics tick before opening a modal. No second action clock.
	Dialogue.open.call_deferred(conversation, actor, self)
	interacted.emit(actor)
