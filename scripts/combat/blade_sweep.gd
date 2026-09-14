class_name BladeSweep
extends MeshInstance3D
## Short, world-space history of the actual blade and its visible energy extension.
## The weapon supplies the same endpoints to the damage sweep. No independent clock.
@export_range(0.02, 0.15, 0.005) var lifetime := 0.075
@export_range(0.02, 0.15, 0.005) var charged_lifetime := 0.095
var samples: Array = []
var ribbon := ImmediateMesh.new()
var duration := 0.075


func _ready() -> void:
	mesh = ribbon
	material_override = material_override.duplicate()


func configure(definition: WeaponDefinition) -> void:
	material_override.set_shader_parameter("slash_color", definition.slash_color)
	material_override.set_shader_parameter("hot_color", definition.hot_color())


func clear() -> void:
	samples.clear()
	ribbon.clear_surfaces()
	hide()


func sample_blade(base: Vector3, tip: Vector3, edge: Vector3, charged: bool) -> void:
	duration = charged_lifetime if charged else lifetime
	samples.append([base, tip, edge, GameClock.elapsed])
	refresh()


func refresh() -> void:
	while not samples.is_empty() and GameClock.elapsed - samples[0][3] > duration:
		samples.pop_front()
	ribbon.clear_surfaces()
	visible = samples.size() >= 2
	if not visible:
		return
	# Round the fading history without spline overshoot at slow/coincident samples.
	# Convex interpolation keeps the trail inside the measured path. The current
	# blade and energy endpoint remain exact; only their cosmetic wake is rounded.
	var points := samples.duplicate()
	for subdivision in 2:
		var refined: Array = [points.front()]
		for i in range(points.size() - 1):
			var a: Array = points[i]
			var b: Array = points[i + 1]
			for weight in [0.25, 0.75]:
				var point: Array = []
				for band in 3:
					point.append(a[band].lerp(b[band], weight))
				point.append(lerpf(a[3], b[3], weight))
				refined.append(point)
		refined.append(points.back())
		points = refined
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, points.size()):
		for band in 2:
			for corner in [
				[i - 1, band],
				[i - 1, band + 1],
				[i, band + 1],
				[i - 1, band],
				[i, band + 1],
				[i, band]
			]:
				var point: Array = points[corner[0]]
				var age := clampf((GameClock.elapsed - point[3]) / duration, 0.0, 1.0)
				ribbon.surface_set_uv(Vector2(1.0 - age, [0.0, 0.4, 1.0][corner[1]]))
				ribbon.surface_add_vertex(point[corner[1]])
	ribbon.surface_end()
