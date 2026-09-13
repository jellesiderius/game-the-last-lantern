extends CharacterBody3D
## Shared damage receiver. Optional Brain/visual components supply enemy behaviour.
@export var enemy := false
@export var label_text := "TRAINING"
var spawn_position := Vector3.ZERO
var last_ids: Dictionary = {}
var reset_time := 0.0
var flash := 0.0
var knockback := Vector3.ZERO
var disabled := false:
	set(value):
		disabled = value
		if value and is_node_ready() and brain:
			brain.suspend()
var flash_material: ShaderMaterial
var health_label: Label3D
var visual: Node3D
var brain: EnemyBrain
@onready var health: HealthComponent = $Health


func _ready() -> void:
	add_to_group("damageable")
	spawn_position = global_position
	visual = $TargetVisual
	flash_material = preload("res://settings/hit_flash.tres").duplicate()
	flash_material.render_priority = 20
	_assign_hit_flash(visual)
	OcclusionSilhouette.apply(visual)
	health_label = $HealthLabel
	brain = get_node_or_null("Brain") as EnemyBrain
	if brain:
		health.maximum = brain.settings.maximum_health
		health.reset()
		label_text = brain.settings.display_name
		brain.reset_brain()
	_update_label()


func _physics_process(_delta: float) -> void:
	var delta: float = GameClock.dt
	if delta <= 0:
		return
	flash = maxf(0, flash - delta)
	flash_material.set_shader_parameter("flash", flash)
	if disabled:
		return
	if reset_time > 0:
		if visual.has_method("present_death"):
			visual.present_death(2.5 - reset_time)
		reset_time -= delta
		if reset_time <= 0:
			reset_target()
		return
	var desired := brain.tick(delta) if brain else Vector3.ZERO
	velocity.x = knockback.x + desired.x
	velocity.z = knockback.z + desired.z
	knockback = knockback.move_toward(Vector3.ZERO, delta * 9)
	velocity.y = -.2 if is_on_floor() else velocity.y - 20 * delta
	move_and_slide()
	if brain:
		visual.present(brain, delta)
	_update_label()


func receive_hit(amount: float, id: int, origin: Vector3, force := 1.0) -> bool:
	if reset_time > 0 or last_ids.has(id) or not health.damage(amount):
		return false
	last_ids[id] = true
	flash = .1
	flash_material.set_shader_parameter("flash", flash)
	var reaction_scale := brain.on_hit(origin) if brain else 1.0
	knockback = (global_position - origin).normalized() * force * reaction_scale
	knockback.y = 0
	_update_label()
	if health.current <= 0:
		reset_time = 2.5
		if visual.has_method("present_death"):
			visual.present_death(0.0)
		else:
			visual.hide()
		health_label.text = "RESET · 2.5s"
		collision_layer = 0
		$Hurtbox.collision_layer = 0
		$ExtraHurtbox.collision_layer = 0
		if has_node("Telegraph"):
			$Telegraph.hide()
	return true


func _assign_hit_flash(node: Node) -> void:
	if node is MeshInstance3D:
		node.material_overlay = flash_material
	for child in node.get_children():
		_assign_hit_flash(child)


func _update_label() -> void:
	var tag: String = label_text
	if brain and brain.state == "windup":
		tag = "!"
	health_label.text = "%s\n%.1f / %.0f" % [tag, health.current, health.maximum]
	health_label.modulate = (
		Color("#ffbd8f") if brain and brain.state == "windup" else Color("#f7e8d2")
	)


func show_hit_color(color: Color) -> void:
	flash_material.set_shader_parameter("hit_color", color)


func reset_target() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	health.reset()
	reset_time = 0
	flash = 0
	flash_material.set_shader_parameter("flash", 0.0)
	last_ids.clear()
	visual.show()
	visual.scale = Vector3.ONE
	visual.rotation = Vector3.ZERO
	visual.position = Vector3.ZERO
	if brain:
		brain.reset_brain()
		visual.reset_pose()
	collision_layer = CombatLayers.ENEMY
	$Hurtbox.collision_layer = CombatLayers.TARGET_HURTBOX
	$ExtraHurtbox.collision_layer = CombatLayers.TARGET_HURTBOX
	_update_label()
