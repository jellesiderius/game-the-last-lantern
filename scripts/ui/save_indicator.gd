extends CanvasLayer
## A successful disk transaction is the only trigger. Queue behind transitions; never flash on errors.
var pending := false
var showing := false
var age := 0.0
var shown_count := 0
@onready var icon: Control = $Icon


func _ready() -> void:
	SaveStore.save_succeeded.connect(_saved)
	icon.hide()


func _saved(_slot: int, _saved_at: float) -> void:
	pending = true


func _process(delta: float) -> void:
	if SceneTransit.active or SceneTransit.fade.visible:
		icon.hide()
		return
	if pending:
		pending = false
		showing = true
		age = 0.0
		shown_count += 1
	if not showing:
		return
	icon.show()
	age += delta
	var entrance := smoothstep(0.0, .24, age)
	var leave := 1.0 - smoothstep(1.45, 1.92, age)
	icon.modulate.a = entrance * leave
	var light := smoothstep(.15, .50, age) * (1.0 - smoothstep(1.2, 1.80, age))
	$Icon/Flame.modulate.a = light
	$Icon/Glow.material.set_shader_parameter("strength", light * (1.0 + .05 * sin(age * 4.3)))
	$Icon/Lantern.modulate = Color("e9d1a1").lerp(Color("ffebbf"), light)
	if age >= 1.92:
		icon.hide()
		showing = false
