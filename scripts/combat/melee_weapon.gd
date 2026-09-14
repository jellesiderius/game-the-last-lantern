class_name MeleeWeapon
extends Node3D
@export var definition: WeaponDefinition = preload("res://settings/weapons/rose_sword.tres")
@export var blade_sample_paths: Array[NodePath] = [^"BladeBase", ^"BladeTip"]
signal swing_connected(attack_id: int)
var blade_samples: Array[Marker3D] = []
var previous_samples: Array[Vector3] = []
var reported_connection := false
var attack_id := -1
var damage := 1.0
var knockback := 2.0
var hitstop_duration := 0.04
var impact_power := 1.0
var hit_targets: Dictionary = {}
var last_base := Vector3.ZERO
var last_tip := Vector3.ZERO
var primed := false
var trail: MeshInstance3D
var trail_mesh: ImmediateMesh
var trail_points: Array = []
var debug_volumes: Array = []
var emissions: Array[StandardMaterial3D] = []
var debug_enabled := false
var sweep_shape := CapsuleShape3D.new()
var sweep_query := PhysicsShapeQueryParameters3D.new()
var energy_primed := false
var energy_tip := Vector3.ZERO
var previous_energy_tip := Vector3.ZERO
var previous_energy_angle := 0.0
@onready var energy_trail: BladeSweep = $EnergyBladeTrail
var swing_basis := Basis.IDENTITY
var swing_direction := -1.0
var swing_half_angle := deg_to_rad(75.0)
var swing_width := 1.0
var swing_visual_clip := ""
var swing_random := RandomNumberGenerator.new()
var last_light_direction := 1.0
var swing_style: MeleeSwingStyle
var last_style_index := -1
## Death's Door style cut: during the swing the blade turns around its grip along the
## same clean arc as the energy crescent, driven by one eased progress value.
@export_range(0.0, 1.0, 0.05) var blade_follow := 1.0
@export_range(1.0, 5.0, 0.1) var swing_ease := 2.6
@export_range(0.0, 0.3, 0.01) var anticipation := 0.06
var rest_transform := Transform3D.IDENTITY
var swing_progress := 0.0
var swing_driven := false


func _ready() -> void:
	rest_transform = transform
	for path in blade_sample_paths:
		blade_samples.append(get_node(path) as Marker3D)
	previous_samples.resize(blade_samples.size())
	sweep_shape.radius = 0.075
	sweep_query.shape = sweep_shape
	sweep_query.collision_mask = CombatLayers.TARGET_HURTBOX
	sweep_query.collide_with_areas = true
	sweep_query.collide_with_bodies = false
	for obj in $WeaponModel.find_children("*", "MeshInstance3D", true, false):
		for idx in obj.mesh.get_surface_count():
			var source = obj.get_active_material(idx)
			if source and source.resource_name.begins_with(definition.blade_material_prefix):
				var m: StandardMaterial3D = source.duplicate()
				m.emission_enabled = true
				m.emission = definition.glow_color
				m.emission_energy_multiplier = definition.glow_energy
				obj.set_surface_override_material(idx, m)
				emissions.append(m)
	trail = $ActiveBladeTrail
	trail_mesh = ImmediateMesh.new()
	trail.mesh = trail_mesh
	trail.material_override = trail.material_override.duplicate()
	trail.material_override.emission = definition.glow_color
	$WeaponLight.light_color = definition.glow_color
	energy_trail.configure(definition)


func set_charge(charge: float) -> void:
	for m in emissions:
		m.emission_energy_multiplier = lerpf(
			definition.glow_energy, definition.charged_glow_energy, charge
		)
	$WeaponLight.light_energy = lerpf(0.35, 0.65, charge)


func start_swing(
	id: int, amount: float, force := 2.0, stop_time := .04, power := 1.0, clip := ""
) -> void:
	clear_swing()
	attack_id = id
	damage = amount
	knockback = force
	hitstop_duration = stop_time
	impact_power = power
	_choose_swing(clip)


func _choose_swing(clip: String) -> void:
	# Randomness is sampled once at swing start, never during rendering or collision.
	# Both light directions have authored bone clips; timing is remapped by the player.
	swing_visual_clip = clip
	swing_style = null
	swing_direction = 1.0 if clip == "attack_2" else -1.0
	swing_basis = Basis.IDENTITY
	swing_width = 1.0
	swing_half_angle = deg_to_rad(definition.energy_half_angle_degrees)
	if definition.alternate_light_swings and clip.begins_with("attack_"):
		swing_direction = -last_light_direction
		last_light_direction = swing_direction
		if clip in ["attack_1", "attack_2"]:
			swing_visual_clip = "attack_1" if swing_direction < 0 else "attack_2"
		elif (
			clip == "attack_3"
			and swing_direction > 0
			and not definition.reverse_finisher_clip.is_empty()
		):
			swing_visual_clip = definition.reverse_finisher_clip
	if clip.begins_with("attack_") and not definition.light_swing_styles.is_empty():
		var choices: Array[int] = []
		for index in definition.light_swing_styles.size():
			if index != last_style_index or definition.light_swing_styles.size() == 1:
				choices.append(index)
		last_style_index = choices[swing_random.randi_range(0, choices.size() - 1)]
		swing_style = definition.light_swing_styles[last_style_index]
		swing_visual_clip = swing_style.left_clip if swing_direction < 0 else swing_style.right_clip
	if energy_radius() <= 0 or (not definition.randomize_energy_swing and not swing_style):
		return
	var tilt := swing_random.randf_range(
		-definition.swing_tilt_degrees, definition.swing_tilt_degrees
	)
	var pitch := swing_random.randf_range(
		-definition.swing_pitch_degrees, definition.swing_pitch_degrees
	)
	if swing_style:
		tilt = -swing_direction * swing_style.slope_degrees
		pitch = 0.0
	if impact_power > 1.5:
		# The charged shoulder chop descends from the high right edge to the low left.
		tilt = swing_random.randf_range(
			-definition.charged_swing_tilt_degrees,
			-minf(definition.charged_swing_tilt_degrees, 18.0)
		)
		pitch = 0.0
	swing_basis = Basis(Vector3.FORWARD, deg_to_rad(tilt)) * Basis(Vector3.RIGHT, deg_to_rad(pitch))
	if swing_style:
		# Preserve horizontal radius: a diagonal cut must not shorten its ground reach.
		swing_basis = swing_basis.scaled_local(Vector3(1.0 / cos(deg_to_rad(tilt)), 1, 1))
	if not definition.randomize_energy_swing:
		return
	swing_half_angle = deg_to_rad(
		clampf(
			(
				definition.energy_half_angle_degrees
				+ swing_random.randf_range(
					-definition.swing_arc_variation_degrees, definition.swing_arc_variation_degrees
				)
			),
			20,
			85
		)
	)
	swing_width = swing_random.randf_range(.8, 1.08)


func clear_swing() -> void:
	if is_node_ready():
		transform = rest_transform
	swing_driven = false
	swing_progress = 0.0
	reported_connection = false
	hit_targets.clear()
	primed = false
	energy_primed = false
	trail_points.clear()
	debug_volumes.clear()
	if trail_mesh:
		trail_mesh.clear_surfaces()
	if energy_trail:
		energy_trail.clear()


func prime() -> void:
	last_base = $BladeBase.global_position
	last_tip = $BladeTip.global_position
	for i in blade_samples.size():
		previous_samples[i] = blade_samples[i].global_position
	primed = true


func sample_hit(actor: Node3D, active: bool, phase := 0.0, facing := Vector3.FORWARD) -> void:
	var base: Vector3 = $BladeBase.global_position
	var tip: Vector3 = $BladeTip.global_position
	debug_volumes.clear()
	if not active:
		energy_primed = false
		prime()
		trail_points.clear()
		trail_mesh.clear_surfaces()
		energy_trail.refresh()
		return
	if not primed:
		prime()
	var largest_step := 0.0
	for i in blade_samples.size():
		largest_step = maxf(
			largest_step, previous_samples[i].distance_to(blade_samples[i].global_position)
		)
	var steps := maxi(1, ceili(largest_step / .055))
	var space := get_world_3d().direct_space_state
	for i in range(steps + 1):
		var u := float(i) / steps
		for segment in range(blade_samples.size() - 1):
			var a := previous_samples[segment].lerp(blade_samples[segment].global_position, u)
			var b := previous_samples[segment + 1].lerp(
				blade_samples[segment + 1].global_position, u
			)
			_sweep_segment(actor, space, a, b)
	if energy_radius() > 0.0:
		_sample_energy(actor, space, facing)
		energy_trail.sample_blade(base, tip, energy_tip, impact_power > 1.5)
	for i in blade_samples.size():
		previous_samples[i] = blade_samples[i].global_position
	if energy_radius() <= 0.0:
		trail_points.append([base, tip])
		if trail_points.size() > 7:
			trail_points.pop_front()
		_draw_trail()
	last_base = base
	last_tip = tip


func energy_radius() -> float:
	return definition.charged_energy_reach if impact_power > 1.5 else definition.energy_reach


func energy_height() -> float:
	if swing_style:
		return swing_style.energy_height
	return definition.charged_energy_height if impact_power > 1.5 else definition.energy_height


func energy_angle(phase: float) -> float:
	return lerpf(-swing_half_angle, swing_half_angle, clampf(phase, 0, 1)) * swing_direction


func energy_local_point(angle: float, radius: float) -> Vector3:
	return swing_basis * Vector3(sin(angle) * radius, 0, -cos(angle) * radius)


func _sample_energy(actor: Node3D, space: PhysicsDirectSpaceState3D, facing: Vector3) -> void:
	var base: Vector3 = $BladeBase.global_position
	var tip: Vector3 = $BladeTip.global_position
	var aim_basis := Basis(Vector3.UP, atan2(-facing.x, -facing.z))
	var local_tip := aim_basis.inverse() * (tip - actor.global_position)
	# Follow the evaluated bone pose, including its real speed and slope. Keep the
	# extension in the forward sector, at the existing horizontal damage radius.
	var angle := clampf(atan2(local_tip.x, -local_tip.z), -swing_half_angle, swing_half_angle)
	var blade_axis := tip - base
	var slope := clampf(
		blade_axis.y / maxf(Vector2(blade_axis.x, blade_axis.z).length(), .05), -.364, .364
	)
	var extension := maxf(0.0, energy_radius() - Vector2(local_tip.x, local_tip.z).length())
	var height := maxf(.10, local_tip.y + slope * extension)
	# Some interpolated arm poses briefly recoil within an otherwise one-way light
	# cut. Do not amplify that single sample into a backwards fold in the energy.
	# The physical blade still follows its pose; both energy damage and rendering
	# use this same continuous leading edge.
	if energy_primed and swing_style and (angle - previous_energy_angle) * swing_direction < 0.0:
		angle = previous_energy_angle
		height = previous_energy_tip.y - actor.global_position.y
	if swing_driven:
		# The damage edge is the visible crescent head, not a re-measured bone.
		angle = arc_angle(clampf(swing_progress, 0.0, 1.0))
		height = arc_point(actor, aim_basis, angle, energy_radius()).y - actor.global_position.y
	energy_tip = (
		actor.global_position
		+ aim_basis * Vector3(sin(angle) * energy_radius(), height, -cos(angle) * energy_radius())
	)
	if not energy_primed:
		previous_energy_tip = energy_tip
		energy_primed = true
	# The actual blade is already swept above. This visible continuation shares its
	# attack ID and target deduplication; the fading history never deals damage.
	var travel := maxf(energy_tip.distance_to(previous_energy_tip), tip.distance_to(last_tip))
	var steps := maxi(1, ceili(travel / .07))
	for i in range(steps + 1):
		var t := float(i) / steps
		_sweep_segment(actor, space, last_tip.lerp(tip, t), previous_energy_tip.lerp(energy_tip, t))
	previous_energy_tip = energy_tip
	previous_energy_angle = angle


func ease_value() -> float:
	return swing_style.active_ease if swing_style else swing_ease


## One eased value drives the blade, the crescent head and the energy damage edge.
## Slightly negative during windup (pull-back), 0..1 across the active window.
func progress_at(time: float, attack: AttackDefinition) -> float:
	if time < attack.windup:
		return -anticipation * smoothstep(0.0, 1.0, time / maxf(attack.windup, .001))
	var t := clampf((time - attack.windup) / attack.active_duration, 0.0, 1.0)
	return lerpf(-anticipation, 1.0, 1.0 - pow(1.0 - t, ease_value()))


func arc_angle(progress: float) -> float:
	return lerpf(-swing_half_angle, swing_half_angle, progress) * swing_direction


func arc_point(actor: Node3D, aim_basis: Basis, angle: float, radius: float) -> Vector3:
	var point := actor.global_position + aim_basis * energy_local_point(angle, radius)
	point.y = maxf(actor.global_position.y + .10, point.y + energy_height())
	return point


## Call after the skeleton pose is sampled and before sample_hit. Null attack resets.
func drive_swing(
	actor: Node3D, facing: Vector3, time: float, attack: AttackDefinition
) -> void:
	transform = rest_transform
	swing_driven = false
	if attack == null or energy_radius() <= 0.0:
		return
	var aim_basis := Basis(Vector3.UP, atan2(-facing.x, -facing.z))
	var end := attack.windup + attack.active_duration
	swing_progress = progress_at(time, attack)
	var radius := energy_radius()
	# The crescent grows with the blade while cutting and dissolves once it is complete.
	if time <= end + .0001:
		var steps := maxi(12, ceili(2.0 * swing_half_angle * radius / .08))
		var rows: Array = []
		for i in range(steps + 1):
			var angle := arc_angle(float(i) / steps)
			rows.append(
				[
					arc_point(actor, aim_basis, angle, radius * .2),
					arc_point(actor, aim_basis, angle, radius * .6),
					arc_point(actor, aim_basis, angle, radius)
				]
			)
		energy_trail.show_arc(rows, swing_progress, impact_power > 1.5)
	else:
		energy_trail.release_arc()
	# Blend onto the arc during windup, cut, then hand back to the authored recovery
	# over the whole recovery so the blade returns to idle the normal way.
	var weight := smoothstep(0.0, 1.0, time / maxf(attack.windup, .001))
	if time > end:
		weight *= 1.0 - smoothstep(0.0, 1.0, (time - end) / maxf(attack.recovery, .001))
	weight *= blade_follow
	if weight <= 0.001:
		return
	swing_driven = true
	var target := arc_point(actor, aim_basis, arc_angle(clampf(swing_progress, -1.0, 1.0)), radius)
	var direction := target - global_position
	if direction.length() < .01:
		return
	var plane_normal := (aim_basis * swing_basis.orthonormalized() * Vector3.UP).normalized()
	if absf(direction.normalized().dot(plane_normal)) > .95:
		plane_normal = Vector3.UP
	var scale_now := global_basis.get_scale()
	var desired := Basis.looking_at(direction.normalized(), plane_normal).get_rotation_quaternion()
	var current := global_basis.orthonormalized().get_rotation_quaternion()
	global_basis = Basis(current.slerp(desired, weight)).scaled(scale_now)


func _sweep_segment(
	actor: Node3D, space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3
) -> void:
	var axis := b - a
	sweep_shape.height = axis.length() + .15
	sweep_query.transform = Transform3D(
		Basis(Quaternion(Vector3.UP, axis.normalized())), (a + b) * .5
	)
	if debug_enabled:
		debug_volumes.append([a, b, .075])
	for hit in space.intersect_shape(sweep_query, 32):
		var area = hit.collider
		var target = area.get_parent()
		if not target.has_method("receive_hit") or hit_targets.has(target.get_instance_id()):
			continue
		# Torso-height visibility prevents hitting through even low blocking walls.
		var destination: Vector3 = target.global_position + Vector3.UP * 0.4
		var ray = PhysicsRayQueryParameters3D.create(
			actor.global_position + Vector3.UP * 0.4, destination, 1
		)
		if not space.intersect_ray(ray).is_empty():
			continue
		hit_targets[target.get_instance_id()] = true
		if target.receive_hit(damage, attack_id, actor.global_position, knockback):
			if target.has_method("show_hit_color"):
				target.show_hit_color(definition.glow_color)
			if not reported_connection:
				reported_connection = true
				# Later targets in this same sweep cannot freeze the whole game again.
				GameClock.hitstop(hitstop_duration)
				swing_connected.emit(attack_id)
			get_tree().call_group(
				"arena", "impact", destination, impact_power, definition.glow_color
			)


func _draw_trail() -> void:
	trail_mesh.clear_surfaces()
	if trail_points.size() < 2:
		return
	trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, trail_points.size()):
		var a = trail_points[i - 1]
		var b = trail_points[i]
		var color := definition.trail_color
		color.a *= float(i) / trail_points.size()
		trail_mesh.surface_set_color(color)
		for v in [a[0], a[1], b[1], a[0], b[1], b[0]]:
			trail_mesh.surface_add_vertex(v)
	trail_mesh.surface_end()
