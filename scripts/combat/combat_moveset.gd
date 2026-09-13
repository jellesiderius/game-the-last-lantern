class_name CombatMoveset
extends Resource
@export var attacks: Array[AttackDefinition] = []


func find(clip: StringName) -> AttackDefinition:
	for attack in attacks:
		if attack.clip == clip:
			return attack
	return null
