class_name MagicArrow
extends Node3D
## Ray-swept projectile. Its clock pauses with melee, animation and hitstop.
var direction := Vector3.FORWARD
var speed := 18.0
var maximum_distance := 16.0
var travelled := 0.0
var damage := 1.0
var attack_id := -1
var shooter: Node3D
var resolved := false
var age := 0.0
@export var appearance: WeaponDefinition = preload("res://settings/weapons/rose_sword.tres")


func _ready() -> void:
	add_to_group("projectiles")
	appearance.tint_emissive_meshes(self)
	appearance.tint_shader($LightTrail)
	$CrossTrail.material_override = $LightTrail.material_override
	$WeaponLight.light_color = appearance.glow_color


func launch(
	actor: Node3D,
	origin: Vector3,
	muzzle: Vector3,
	aim: Vector3,
	amount: float,
	settings: BowSettings
) -> void:
	shooter = actor
	damage = amount
	speed = settings.arrow_speed
	maximum_distance = settings.maximum_distance
	direction = Vector3(aim.x, 0, aim.z).normalized()
	attack_id = GameClock.next_attack_id()
	global_position = muzzle
	look_at(muzzle + direction, Vector3.UP)
	# The muzzle is not allowed to teleport a shot through a wall or target.
	_resolve_segment(origin, muzzle)


func _physics_process(_delta: float) -> void:
	var delta := GameClock.dt
	if resolved or delta <= 0:
		return
	age += delta
	$LightTrail.material_override.set_shader_parameter("age", age)
	var distance := minf(speed * delta, maximum_distance - travelled)
	var next := global_position + direction * distance
	if _resolve_segment(global_position, next):
		return
	global_position = next
	travelled += distance
	if travelled >= maximum_distance:
		_finish()


func _resolve_segment(from: Vector3, to: Vector3) -> bool:
	if from.is_equal_approx(to):
		return false
	var query := PhysicsRayQueryParameters3D.create(
		from, to, CombatLayers.WORLD | CombatLayers.TARGET_HURTBOX
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.hit_from_inside = true
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	global_position = hit.position
	var collider: Node = hit.collider
	var target: Node = collider.get_parent() if collider is Area3D else collider
	if target != shooter and target.has_method("receive_hit"):
		var accepted: bool = target.receive_hit(
			damage, attack_id, shooter.global_position if is_instance_valid(shooter) else from, 0.65
		)
		if accepted and target.has_method("show_hit_color"):
			target.show_hit_color(appearance.glow_color)
	get_tree().call_group("arena", "impact", hit.position, 1.0, appearance.glow_color)
	_finish()
	return true


func _finish() -> void:
	resolved = true
	hide()
	queue_free()
