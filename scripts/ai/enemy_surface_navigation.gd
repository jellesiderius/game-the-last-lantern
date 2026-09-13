class_name EnemySurfaceNavigation
extends RefCounted
## Same movement contract, backed by a world-space 3D NavigationMesh.
var queries := 0
var map_rid := RID()
var region_rid := RID()
var mesh: NavigationMesh
var baked_radius := .3
var baked_height := 1.0
var installed := false
var minimum_iteration := 1
var synchronized := false
var ready: bool:
	get:
		if (
			not installed
			or not map_rid.is_valid()
			or NavigationServer3D.map_get_iteration_id(map_rid) < minimum_iteration
		):
			return false
		if not synchronized:
			# Region geometry and map topology synchronize separately. An iteration
			# counter alone can still describe the previous empty map.
			synchronized = (
				NavigationServer3D.map_get_closest_point_owner(map_rid, mesh.get_vertices()[0])
				== region_rid
			)
		return synchronized


func route(from: Vector3, to: Vector3, radius: float) -> PackedVector3Array:
	queries += 1
	if not ready or radius > baked_radius:
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(map_rid, from, to, true)


func segment_clear(from: Vector3, to: Vector3, radius: float) -> bool:
	if not ready or radius > baked_radius:
		return false
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var samples := maxi(1, ceili(length / .12))
	var previous := closest_ground(from)
	if Vector2(previous.x - from.x, previous.z - from.z).length() > .055:
		return false
	for i in range(1, samples + 1):
		var point := from.lerp(to, float(i) / samples)
		# Follow the surface vertically; a steering probe has a horizontal goal.
		point.y = previous.y
		var projected := NavigationServer3D.map_get_closest_point(map_rid, point)
		if Vector2(projected.x - point.x, projected.z - point.z).length() > .035:
			return false
		if absf(projected.y - previous.y) > length / samples + .055:
			return false
		previous = projected
	# A shortcut may not jump between stacked floors with identical X/Z.
	return absf(previous.y - to.y) < maxf(.22, length * .65 + .10)


func closest_ground(point: Vector3) -> Vector3:
	# Recast's sampled surface is slightly above the physical floor. This offset
	# avoids a horizontal projection error on slopes while retaining world height.
	return NavigationServer3D.map_get_closest_point(map_rid, point + Vector3.UP * .1)
