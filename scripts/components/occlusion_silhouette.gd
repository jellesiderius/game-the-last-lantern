class_name OcclusionSilhouette
extends RefCounted
## All visible actor surfaces write the same stencil value before any silhouette.
## This prevents a hidden tail/arm drawing gray over its own visible torso.
const STYLE = preload("res://settings/occlusion_silhouette.tres")


static func apply(root: Node) -> void:
	var materials: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.mesh:
			continue
		mesh.ignore_occlusion_culling = true
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as BaseMaterial3D
			if not original:
				continue
			if not materials.has(original):
				var material := original.duplicate() as BaseMaterial3D
				material.render_priority = STYLE.render_priority
				material.stencil_reference = STYLE.stencil_reference
				material.stencil_color = STYLE.stencil_color
				material.stencil_mode = BaseMaterial3D.STENCIL_MODE_XRAY
				materials[original] = material
			if mesh.material_override:
				mesh.material_override = materials[original]
				break
			mesh.set_surface_override_material(surface, materials[original])
