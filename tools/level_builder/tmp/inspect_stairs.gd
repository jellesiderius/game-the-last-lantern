extends Node
## Temporary: plateaus, bridges and cut pieces around the foot of Trap2.


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var root: Node = load("res://scenes/levels/BosOpening.tscn").instantiate()
	add_child(root)
	var terrain := root.get_node("Terrain") as LevelTerrain
	for child in terrain.get_children():
		if child is LevelTerrace:
			var points := PackedVector2Array()
			for i in child.curve.point_count:
				var p: Vector3 = child.transform * child.curve.get_point_position(i)
				points.append(Vector2(p.x, p.z))
			var near := false
			for point in points:
				if point.x < -4 and point.y > -2 and point.y < 16:
					near = true
			if near:
				print("TERRACE ", child.name, " h=", child.height, " pos=", child.position, " points=", points)
		elif child is LevelBridge:
			var a: Vector3 = child.transform * child.curve.get_point_position(0)
			var b: Vector3 = child.transform * child.curve.get_point_position(1)
			print("BRIDGE ", child.name, " a=", a, " b=", b, " width=", child.width)
	for region in terrain.outlines():
		var polygon: PackedVector2Array = region.polygon
		var touches := false
		for point in polygon:
			if point.x < -4 and point.x > -16 and absf(point.y - 5.0) < 2.5:
				touches = true
		if touches:
			print("REGION ", region.name, " h=", region.height, " landing=", region.get("landing", false), " ramp=", region.has("ramp_start"), " poly=", polygon)
	await get_tree().process_frame
	get_tree().quit()
