extends Control
## Lightweight saved UI; uses wall time so the lantern stays alive while gameplay is paused.
@export var default_heading := "De reis gaat verder"
@export var caption := "Ook het kleinste licht wijst de weg."
var animation_time := 0.0
var shown_at_msec := 0
@onready var composition: Control = $Composition


func _ready() -> void:
	resized.connect(_fit)
	_fit()


func present(heading: String) -> void:
	animation_time = 0.0
	shown_at_msec = Time.get_ticks_msec()
	$Composition/Heading.text = heading if not heading.is_empty() else default_heading
	$Composition/Caption.text = caption
	show()


func _fit() -> void:
	var factor := minf(size.x / 1280.0, size.y / 800.0)
	composition.scale = Vector2.ONE * factor
	composition.position = (size - Vector2(1280, 800) * factor) * .5


func _process(delta: float) -> void:
	if not visible:
		return
	animation_time += delta
	for node in [$Composition/Glow, $Composition/Flame, $Composition/Trail]:
		node.material.set_shader_parameter("animation_time", animation_time)
	for i in $Composition/Embers.get_child_count():
		var ember: TextureRect = $Composition/Embers.get_child(i)
		var phase := fmod(animation_time / (4.8 + i * .31) + i * .173, 1.0)
		ember.position = Vector2(
			640 + sin(i * 3.7) * 68 + sin(phase * 4 + i) * 16, 395 - phase * 210
		)
		ember.modulate.a = sin(phase * PI) * .46
