@tool
extends Node3D
## Exactly two appearances: dormant grey and completed amber. No activation state.
var completed := false
var materials: Array[Dictionary] = []
var effect_time := 0.0


func _ready() -> void:
	for mesh: MeshInstance3D in $Model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var material := source.duplicate() as StandardMaterial3D
			mesh.set_surface_override_material(surface, material)
			materials.append(
				{
					"material": material,
					"color": material.albedo_color,
					"light": source.resource_name in ["GateCrystal", "GateInnerRim"]
				}
			)
	$Veil.material_override = $Veil.material_override.duplicate()
	set_completed(completed)


func set_completed(value: bool) -> void:
	completed = value
	if not is_node_ready():
		return
	for entry in materials:
		var material: StandardMaterial3D = entry.material
		if entry.light:
			material.albedo_color = Color("ffc154") if completed else Color("7b8388")
			material.emission_enabled = completed
			material.emission = Color("ffaf25")
			material.emission_energy_multiplier = 3.0
		else:
			material.albedo_color = (
				entry.color.lerp(Color("b38448"), .28) if completed else entry.color
			)
	$Veil.material_override.set_shader_parameter("completed", completed)
	$WarmLight.visible = completed
	$CrownLight.visible = completed
	$Motes.emitting = completed
	$Motes.visible = completed


func _process(delta: float) -> void:
	var step := delta if Engine.is_editor_hint() else GameClock.dt
	effect_time += step
	$Veil.material_override.set_shader_parameter("game_time", effect_time)
	$Motes.speed_scale = 1.0 if Engine.is_editor_hint() or step > 0.0 else 0.0
