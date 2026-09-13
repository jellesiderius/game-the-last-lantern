extends Interactable


## A real specialization of the shared interaction contract.
func interact(actor: Node3D) -> void:
	get_parent().reset_target()
	super.interact(actor)
