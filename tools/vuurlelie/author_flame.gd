extends SceneTree


## Offline saved effect geometry. One broad connected flame body, with a curved taper above the bronze petals.
func _initialize() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [.065, .17, .165, .12, .055, .001]
	var heights := [0.0, .13, .30, .49, .67, .88]
	var vertices: Array[Vector3] = []
	for row in radii.size():
		for side in 12:
			var angle := TAU * side / 12.0
			vertices.append(
				Vector3(
					cos(angle) * radii[row] + pow(float(row) / 5, 3) * .11,
					heights[row],
					sin(angle) * radii[row] * .72
				)
			)
	for row in 5:
		for side in 12:
			var a := row * 12 + side
			var b := row * 12 + (side + 1) % 12
			for index in [a, a + 12, b, b, a + 12, b + 12]:
				surface.set_smooth_group(0)
				surface.add_vertex(vertices[index])
	surface.generate_normals()
	var mesh := surface.commit()
	var result := ResourceSaver.save(mesh, "res://assets/environment/vuurlelie/flame.tres")
	quit(0 if result == OK else 1)
