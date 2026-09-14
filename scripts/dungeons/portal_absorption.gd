class_name PortalAbsorption
extends RefCounted
## Fade the complete actor with its original materials. Preparation happens before contact.
var actor: PlayerCharacter
var origin := Vector3.ZERO
var direction := Vector3.FORWARD
var visibility := true
var surfaces: Array[Dictionary] = []
var meshes: Array[Dictionary] = []
var lights: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var ground_enabled := true
var warming := true
var safe_return_position := Vector3.ZERO


func prepare(player: PlayerCharacter) -> void:
	actor = player
	var variants: Dictionary = {}
	for mesh: MeshInstance3D in player.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		meshes.append({"node": mesh, "transparency": mesh.transparency, "shadow": mesh.cast_shadow})
		for index in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(index)
			if source == null:
				continue
			if not variants.has(source):
				var material := source.duplicate() as Material
				material.next_pass = null
				if material is BaseMaterial3D:
					material.stencil_mode = BaseMaterial3D.STENCIL_MODE_DISABLED
				variants[source] = material
			surfaces.append(
				{
					"mesh": mesh,
					"index": index,
					"override": mesh.material_override,
					"surface": mesh.get_surface_override_material(index),
					"fading": variants[source]
				}
			)
			if mesh.material_override:
				break
	for light: Light3D in player.find_children("*", "Light3D", true, false):
		lights.append({"node": light, "energy": light.light_energy})
	for kind in ["GPUParticles3D", "CPUParticles3D"]:
		for node in player.find_children("*", kind, true, false):
			particles.append({"node": node, "visible": node.visible, "emitting": node.emitting})


func begin(player: PlayerCharacter, portal: ScenePortal) -> void:
	if actor != player or meshes.is_empty():
		prepare(player)
	visibility = player.visible
	warming = false
	origin = portal.global_position
	direction = portal.exit_direction()
	safe_return_position = (
		origin - direction * (portal.trigger_size.z * .5 + player.definition.body_radius + .8)
	)
	player.visual.show_damage_protection(0.0, 1.0)
	ground_enabled = player.ground_feedback.enabled
	player.ground_feedback.enabled = false
	player.ground_feedback.clear()
	player.feedback.clear()
	player.visual.weapon.clear_swing()
	for entry in surfaces:
		if entry.override:
			entry.mesh.material_override = entry.fading
		else:
			entry.mesh.set_surface_override_material(entry.index, entry.fading)
	for entry in meshes:
		entry.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for entry in particles:
		entry.node.emitting = false
		entry.node.hide()
	for entry in lights:
		entry.energy = entry.node.light_energy
	update()


func prewarm() -> void:
	for entry in surfaces:
		if entry.override:
			entry.mesh.material_override = entry.fading
		else:
			entry.mesh.set_surface_override_material(entry.index, entry.fading)
	for entry in meshes:
		entry.node.transparency = maxf(entry.transparency, .001)


func finish_prewarm() -> void:
	for entry in surfaces:
		if is_instance_valid(entry.mesh):
			entry.mesh.material_override = entry.override
			entry.mesh.set_surface_override_material(entry.index, entry.surface)
	for entry in meshes:
		if is_instance_valid(entry.node):
			entry.node.transparency = entry.transparency
	warming = false


func update() -> void:
	if not is_instance_valid(actor):
		return
	var distance := (actor.global_position - origin).dot(direction)
	# Finish just before the actor centre crosses the opaque surface: no body,
	# equipment, shadow or x-ray pass ever reappears on its far side.
	var fade := smoothstep(-.55, -.04, distance)
	for entry in meshes:
		if is_instance_valid(entry.node):
			entry.node.transparency = lerpf(entry.transparency, 1.0, fade)
	for entry in lights:
		if is_instance_valid(entry.node):
			entry.node.light_energy = entry.energy * (1.0 - fade)
	if fade >= 1.0:
		actor.hide()


func restore() -> void:
	for entry in surfaces:
		if is_instance_valid(entry.mesh):
			entry.mesh.material_override = entry.override
			entry.mesh.set_surface_override_material(entry.index, entry.surface)
	if is_instance_valid(actor):
		actor.visible = visibility
		actor.ground_feedback.enabled = ground_enabled
		actor.global_position = safe_return_position
		actor.velocity = Vector3.ZERO
		actor.reset_physics_interpolation()
		var world := actor.get_tree().current_scene
		if world.has_method("reset_camera"):
			world.reset_camera()
	for entry in meshes:
		if is_instance_valid(entry.node):
			entry.node.transparency = entry.transparency
			entry.node.cast_shadow = entry.shadow
	for entry in lights:
		if is_instance_valid(entry.node):
			entry.node.light_energy = entry.energy
	for entry in particles:
		if is_instance_valid(entry.node):
			entry.node.visible = entry.visible
			entry.node.emitting = entry.emitting
