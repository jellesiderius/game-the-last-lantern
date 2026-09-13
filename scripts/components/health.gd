class_name HealthComponent
extends Node
signal changed(current: float, maximum: float)
signal depleted
@export var maximum := 5.0
var current := 5.0


func _ready() -> void:
	reset()


func damage(amount: float) -> bool:
	if amount <= 0.0 or current <= 0.0:
		return false
	current = maxf(0.0, current - amount)
	changed.emit(current, maximum)
	if current <= 0.0:
		depleted.emit()
	return true


func reset() -> void:
	current = maximum
	changed.emit(current, maximum)
