@tool
extends SceneSpawnPoint


## Resolve before _ready too: SceneTransit validates packed destinations off-tree.
func spawn_key() -> StringName:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is ThresholdGate:
			return ancestor.gate_id
		ancestor = ancestor.get_parent()
	return spawn_id
