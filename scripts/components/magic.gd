class_name MagicComponent
extends Node
signal changed(current: int, maximum: int, reason: StringName)
signal denied
@export_range(1, 20, 1) var maximum := 4
var current := 4


func _ready() -> void:
	reset()


func check_available(amount := 1) -> bool:
	# Validate an attempted action without reserving or spending magic.
	if amount <= 0:
		return false
	if current < amount:
		denied.emit()
		return false
	return true


func try_spend(amount := 1) -> bool:
	if not check_available(amount):
		return false
	current -= amount
	changed.emit(current, maximum, &"spent")
	return true


func restore(amount := 1) -> void:
	if amount <= 0 or current >= maximum:
		return
	current = mini(maximum, current + amount)
	changed.emit(current, maximum, &"restored")


func reset() -> void:
	current = maximum
	changed.emit(current, maximum, &"reset")
