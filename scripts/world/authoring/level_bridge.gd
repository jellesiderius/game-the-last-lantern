@tool
class_name LevelBridge
extends Path3D
## A walkable bridge between two points, usually two plateau edges, possibly at
## different heights. The two curve points are the deck ends on those edges; short
## flat pads reach onto each plateau so stepping on and off is seamless. The bridge
## builds its own mesh and collision when it loads, so the ground below stays walkable.
const PAD := .35
## The visible deck floats just above the walkable surface, so planks on the pads
## never z-fight with or sink into the plateau top they rest on.
const DECK_LIFT := .05
const DECK_THICKNESS := .14
const PLANK_DEPTH := .3
const PLANK_GAP := .05
const RAIL_HEIGHT := .7
const POST_SPACING := 1.6
## Invisible side walls, taller than the rail so nothing is pushed over it.
const WALL_HEIGHT := 1.2
@export_range(1, 6, .5, "suffix:m") var width := 2.0:
	set(value):
		width = value
		_changed()
@export var railings := true:
	set(value):
		railings = value
		_changed()
## Ends take the height of the plateau or ground they rest on.
@export var follow_ground := true:
	set(value):
		follow_ground = value
		_changed()
@export var deck_color := Color("b07a44"):
	set(value):
		deck_color = value
		_changed()
@export var rail_color := Color("6b4424"):
	set(value):
		rail_color = value
		_changed()
var _queued := false


func _ready() -> void:
	rebuild()
	if Engine.is_editor_hint():
		curve_changed.connect(_changed)


func _changed() -> void:
	if not is_inside_tree():
		return
	if not _queued:
		_queued = true
		rebuild.call_deferred()
	if Engine.is_editor_hint() and get_parent() is LevelTerrain:
		get_parent().request_bake()


## Deck line in local space: pad, span, pad.
func deck_line() -> Array[Vector3]:
	var result: Array[Vector3] = []
	if curve == null or curve.point_count != 2:
		return result
	var a := curve.get_point_position(0)
	var b := curve.get_point_position(1)
	var flat := Vector3(b.x - a.x, 0, b.z - a.z)
	if flat.length() < .1:
		return result
	var forward := flat.normalized()
	result.append_array([a - forward * PAD, a, b, b + forward * PAD])
	return result


func rebuild() -> void:
	_queued = false
	var previous := get_node_or_null("Generated")
	if previous:
		remove_child(previous)
		previous.queue_free()
	var line := deck_line()
	if line.is_empty():
		return
	var forward := Vector3(line[2].x - line[1].x, 0, line[2].z - line[1].z).normalized()
	var side := Vector3(-forward.z, 0, forward.x)
	var half := width / 2
	var total := 0.0
	for i in 3:
		total += Vector2(line[i + 1].x - line[i].x, line[i + 1].z - line[i].z).length()
	var raised: Array[Vector3] = []
	for point in line:
		raised.append(point + Vector3.UP * DECK_LIFT)
	var visual := SurfaceTool.new()
	visual.begin(Mesh.PRIMITIVE_TRIANGLES)
	var planks := maxi(1, floori(total / (PLANK_DEPTH + PLANK_GAP)))
	var pitch := total / planks
	for i in planks:
		var start := _along(raised, i * pitch + PLANK_GAP / 2)
		var end := _along(raised, (i + 1) * pitch - PLANK_GAP / 2)
		var shade := .88 + .2 * fposmod(sin(i * 12.9898) * 43758.5453, 1.0)
		_beam(visual, start, end, side, half - .02, DECK_THICKNESS, deck_color * shade)
	for sign in [-1.0, 1.0]:
		var offset: Vector3 = side * sign * (half - .06)
		# Side beams only under the span: on the pads they would cut into the plateau.
		for i in [1]:
			_beam(
				visual,
				raised[i] + offset + Vector3.DOWN * DECK_THICKNESS,
				raised[i + 1] + offset + Vector3.DOWN * DECK_THICKNESS,
				side,
				.07,
				.18,
				rail_color
			)
		if railings:
			var posts := maxi(1, ceili(total / POST_SPACING))
			for post in posts + 1:
				var base := _along(raised, total * post / posts) + offset
				_beam(visual, base, base + Vector3.UP * RAIL_HEIGHT, side, .06, .12, rail_color)
			for i in 3:
				_beam(
					visual,
					raised[i] + offset + Vector3.UP * RAIL_HEIGHT,
					raised[i + 1] + offset + Vector3.UP * RAIL_HEIGHT,
					side,
					.05,
					.08,
					rail_color
				)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = .9
	visual.set_material(material)
	# Collision: the smooth deck top plus invisible side walls.
	var faces := PackedVector3Array()
	for i in 3:
		var p := line[i]
		var q := line[i + 1]
		faces.append_array(
			PackedVector3Array(
				[p - side * half, q - side * half, q + side * half, p - side * half, q + side * half, p + side * half]
			)
		)
		if railings:
			for sign in [-1.0, 1.0]:
				var edge: Vector3 = side * sign * half
				var lift := Vector3.UP * WALL_HEIGHT
				faces.append_array(
					PackedVector3Array(
						[p + edge, q + edge, q + edge + lift, p + edge, q + edge + lift, p + edge + lift]
					)
				)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	# Unowned: rebuilt on every load, never saved into the scene.
	var generated := Node3D.new()
	generated.name = "Generated"
	add_child(generated)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	mesh_instance.mesh = visual.commit()
	generated.add_child(mesh_instance)
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1
	body.collision_mask = 0
	generated.add_child(body)
	var shape_node := CollisionShape3D.new()
	shape_node.name = "Shape"
	shape_node.shape = shape
	body.add_child(shape_node)


## Point on the deck line at a horizontal distance from its start.
static func _along(line: Array[Vector3], distance: float) -> Vector3:
	for i in line.size() - 1:
		var p := line[i]
		var q := line[i + 1]
		var length := Vector2(q.x - p.x, q.z - p.z).length()
		if distance <= length or i == line.size() - 2:
			return p.lerp(q, clampf(distance / maxf(length, .0001), 0, 1))
		distance -= length
	return line[line.size() - 1]


## A box from `from` to `to`, `half_width` to each side and `thickness` below.
static func _beam(
	surface: SurfaceTool,
	from: Vector3,
	to: Vector3,
	side: Vector3,
	half_width: float,
	thickness: float,
	color: Color
) -> void:
	var axis := to - from
	if axis.length_squared() < .000001:
		return
	var across := side.normalized() * half_width
	var down := axis.normalized().cross(side.normalized())
	if down.y > 0:
		down = -down
	down *= thickness
	var c := [
		from - across,
		to - across,
		to + across,
		from + across,
		from - across + down,
		to - across + down,
		to + across + down,
		from + across + down
	]
	var center := (from + to) * .5 + down * .5
	var linear := color.srgb_to_linear()
	for face in [[0, 1, 2, 3], [7, 6, 5, 4], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		var quad := [c[face[0]], c[face[1]], c[face[2]], c[face[3]]]
		var normal: Vector3 = (quad[1] - quad[0]).cross(quad[2] - quad[0]).normalized()
		var middle: Vector3 = (quad[0] + quad[1] + quad[2] + quad[3]) * .25
		if normal.dot(middle - center) < 0:
			normal = -normal
		for index in LevelTerrain._front_order(quad, normal):
			surface.set_normal(normal)
			surface.set_color(linear)
			surface.add_vertex(quad[index])
