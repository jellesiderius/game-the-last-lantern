class_name WeaponDefinition
extends Resource
## Shared melee/ranged presentation. Equipped weapon data supplies every magic accent.
@export var id: StringName
@export var blade_material_prefix := "Blade_"
@export var glow_color := Color(1, .018, .15)
@export var slash_color := Color(1, .004, .024)
@export var trail_color := Color(1, .07, .35, .5)
@export var glow_energy := 3.2
@export var charged_glow_energy := 5.0
## Optional visible melee-energy extension, in metres from the wielder.
## Zero preserves physical-blade-only weapons. Presentation and hit sweeps share this data.
@export_range(0.0, 4.0, 0.05) var energy_reach := 0.0
@export_range(0.0, 4.0, 0.05) var charged_energy_reach := 0.0
@export_range(20.0, 85.0, 1.0) var energy_half_angle_degrees := 75.0
@export var randomize_energy_swing := false
@export var alternate_light_swings := false
@export var reverse_finisher_clip: StringName
## Empty uses the weapon's original light clips. Styles are selected without repeats.
@export var light_swing_styles: Array[MeleeSwingStyle] = []
@export_range(0.0, 20.0, 1.0) var swing_tilt_degrees := 16.0
@export_range(0.0, 6.0, 0.5) var swing_pitch_degrees := 3.0
@export_range(0.0, 10.0, 1.0) var swing_arc_variation_degrees := 5.0
@export_range(0.3, 1.2, 0.05) var energy_height := .72
@export_range(0.3, 1.2, 0.05) var charged_energy_height := .85
@export_range(0.0, 30.0, 1.0) var charged_swing_tilt_degrees := 20.0


func hot_color() -> Color:
	return glow_color.lerp(Color.WHITE, .72)


func tint_emissive_meshes(root: Node) -> void:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if not source or not source.emission_enabled:
				continue
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_color = glow_color.lerp(Color.WHITE, .15)
			material.emission = glow_color
			mesh.set_surface_override_material(surface, material)


func tint_shader(mesh: MeshInstance3D) -> void:
	var material := mesh.material_override.duplicate() as ShaderMaterial
	material.set_shader_parameter("energy_color", slash_color)
	material.set_shader_parameter("glow_color", glow_color)
	material.set_shader_parameter("hot_color", hot_color())
	mesh.material_override = material
