class_name RangedLoadout
extends Node
## Empty slots stay locked. Adding an ability supplies its id here; never fake an unlocked weapon.
signal selection_changed(slot: int, ability: StringName)
signal selection_denied(slot: int)
@export var abilities: Array[StringName] = [&"bow", &"", &"", &""]
var selected_slot := 0


func select_slot(slot: int) -> bool:
	if slot < 0 or slot >= abilities.size() or abilities[slot].is_empty():
		selection_denied.emit(slot)
		return false
	selected_slot = slot
	selection_changed.emit(slot, abilities[slot])
	return true
