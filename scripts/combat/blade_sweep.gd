class_name BladeSweep
extends MeshInstance3D
## World-space energy slash. With full_arc the weapon supplies the whole crescent every
## tick plus one eased head value shared with the blade rotation: the crescent is filled
## from the start of the cut up to the sword, then thins and erodes from its tail
## (Death's Door style). Blade samples are still recorded; without full_arc they draw
## the legacy fading ribbon.
@export var full_arc := true
@export_range(0.05, 0.5, 0.01) var arc_lifetime := 0.18
@export_range(0.05, 0.5, 0.01) var charged_arc_lifetime := 0.24
@export_range(0.02, 0.15, 0.005) var lifetime := 0.075
@export_range(0.02, 0.15, 0.005) var charged_lifetime := 0.095
var samples: Array = []
var ribbon := ImmediateMesh.new()
var duration := 0.075
var arc_shown := false
var arc_start := -1.0
var arc_duration := 0.18


func _ready() -> void:
	mesh = ribbon
	material_override = material_override.duplicate()


func configure(definition: WeaponDefinition) -> void:
	material_override.set_shader_parameter("slash_color", definition.slash_color)
	material_override.set_shader_parameter("hot_color", definition.hot_color())


func clear() -> void:
	samples.clear()
	arc_shown = false
	arc_start = -1.0
	ribbon.clear_surfaces()
	hide()


## rows: one [inner, middle, outer] world-space triple per step along the full swing.
## head: shared swing progress; everything behind it is lit at once.
func show_arc(rows: Array, head: float, charged: bool) -> void:
	if not full_arc:
		return
	arc_shown = true
	arc_start = -1.0
	arc_duration = charged_arc_lifetime if charged else arc_lifetime
	material_override.set_shader_parameter("arc_mode", true)
	material_override.set_shader_parameter("head", head)
	material_override.set_shader_parameter("age", 0.0)
	ribbon.clear_surfaces()
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, rows.size()):
		for band in 2:
			for corner in [
				[i - 1, band], [i - 1, band + 1], [i, band + 1], [i - 1, band], [i, band + 1], [i, band]
			]:
				ribbon.surface_set_uv(
					Vector2(float(corner[0]) / (rows.size() - 1), [0.0, 0.5, 1.0][corner[1]])
				)
				ribbon.surface_add_vertex(rows[corner[0]][corner[1]])
	ribbon.surface_end()
	visible = head > 0.0


## The cut is complete: freeze the crescent in place and start dissolving it.
func release_arc() -> void:
	if arc_shown and arc_start < 0.0:
		arc_start = GameClock.elapsed
		material_override.set_shader_parameter("head", 1.0)


func sample_blade(base: Vector3, tip: Vector3, edge: Vector3, charged: bool) -> void:
	duration = charged_lifetime if charged else lifetime
	samples.append([base, tip, edge, GameClock.elapsed])
	refresh()


func refresh() -> void:
	while not samples.is_empty() and GameClock.elapsed - samples[0][3] > duration:
		samples.pop_front()
	if full_arc:
		if arc_start >= 0.0:
			var age := (GameClock.elapsed - arc_start) / arc_duration
			material_override.set_shader_parameter("age", minf(age, 1.0))
			if age >= 1.0:
				arc_shown = false
				arc_start = -1.0
				visible = false
		return
	material_override.set_shader_parameter("arc_mode", false)
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
