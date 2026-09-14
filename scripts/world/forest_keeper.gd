extends StaticBody3D
## Peaceful presentation uses the existing character wrapper and shared animation clock.
@onready var visual: CharacterVisual = $CharacterVisual


func _physics_process(_delta: float) -> void:
	visual.sample("", 0.0, 0.0, GameClock.dt)
