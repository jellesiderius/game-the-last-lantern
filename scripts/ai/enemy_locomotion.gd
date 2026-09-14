class_name EnemyLocomotion
extends RefCounted
## Per-actor route cache and steering. No combat decisions or independent clocks.
var path := PackedVector3Array()
var destination := Vector3(INF, 0, INF)
var repath_left := 0.0
var speed := 0.0
var stuck_time := 0.0
var last_steering := Vector3.ZERO
var repaths := 0
var recovering_surface := false
var motion_query := PhysicsTestMotionParameters3D.new()
var motion_hit := PhysicsTestMotionResult3D.new()
var route_surface: EnemySurfaceNavigation
var offered_surface: EnemySurfaceNavigation
## Candidate steering is the most expensive query set. Re-evaluate it at 30 Hz or on a
## real heading change; the per-tick navmesh and collider safety check always runs.
const STEER_INTERVAL := 1.0 / 30.0
var steer_age := INF
var steer_toward := Vector3.ZERO
var steer_heading := Vector3.ZERO


func reset() -> void:
	path.clear()
	destination = Vector3(INF, 0, INF)
	repath_left = 0
	speed = 0
	stuck_time = 0
	last_steering = Vector3.ZERO
	repaths = 0
	recovering_surface = false
	route_surface = null
	offered_surface = null
	steer_age = INF
	steer_heading = Vector3.ZERO


func move(brain: EnemyBrain, goal: Vector3, pace: float, delta: float) -> Vector3:
	var profile := brain.settings.movement
	var navigation := NavigationWorld.surface_for(brain.actor, profile.radius, profile.height)
	if not navigation.ready:
		speed = 0
		return Vector3.ZERO
	var comfortable := NavigationWorld.surface_for(
		brain.actor, profile.radius + profile.preferred_path_clearance, profile.height
	)
	var offered := comfortable if comfortable.ready else navigation
	var position: Vector3 = brain.actor.global_position
	var nearest := navigation.closest_ground(position)
	var correction := nearest - position
	correction.y = 0
	if correction.length() > .055:
		recovering_surface = true
	if correction.length() < .015:
		recovering_surface = false
	if recovering_surface:
		# Recover from a knockback or a small corner overstep without teleporting.
		brain._face(correction.normalized(), delta)
		var aligned := brain.direction.dot(correction.normalized()) > .98
		brain.turning_in_place = not aligned
		repath_left = 0
		speed = minf(pace, correction.length() * 5) if aligned else 0.0
		return brain.direction * speed
	repath_left -= delta
	if (
		repath_left <= 0
		or goal.distance_to(destination) > profile.retarget_distance
		or offered != offered_surface
	):
		path = navigation.route(position, goal, profile.radius)
		route_surface = navigation
		offered_surface = offered
		if offered == comfortable and not path.is_empty():
			var relaxed := comfortable.route(position, goal, profile.radius)
			if (
				not relaxed.is_empty()
				and navigation.segment_clear(position, relaxed[0], profile.radius)
			):
				# Connect the final short approach on the physical-size surface.
				# Disconnected/narrow passages fall back to the normal route.
				if (
					relaxed[-1].distance_to(path[-1]) < .8
					and navigation.segment_clear(relaxed[-1], path[-1], profile.radius)
				):
					if relaxed[-1].distance_to(path[-1]) > .05:
						relaxed.append(path[-1])
					path = relaxed
					route_surface = comfortable
		destination = goal
		repath_left = profile.path_interval * brain.personality.get("reaction", 1.0)
		repaths += 1
		steer_age = INF
	while (
		path.size() > 1
		and Vector2(position.x - path[0].x, position.z - path[0].z).length() < .07
		and absf(position.y - path[0].y) < .3
	):
		path.remove_at(0)
	if path.is_empty():
		speed = 0
		return Vector3.ZERO
	var smoothing_surface := (
		route_surface
		if route_surface.ready and route_surface.segment_clear(position, position, profile.radius)
		else navigation
	)
	# Skip intermediate corners only if the entire capsule has clearance.
	for i in range(path.size() - 1, 0, -1):
		if (
			position.distance_to(path[i]) < 1.2
			and smoothing_surface.segment_clear(position, path[i], profile.radius)
		):
			for j in i:
				path.remove_at(0)
			break
	var offset := _look_ahead(position, pace, smoothing_surface, profile) - position
	offset.y = 0
	var target_speed := pace
	if path.size() == 1:
		target_speed *= clampf(offset.length() / profile.arrival_radius, 0, 1)
	if offset.length() < .06:
		speed = 0
		return Vector3.ZERO
	var toward := offset.normalized()
	steer_age += delta
	if steer_age >= STEER_INTERVAL or toward.dot(steer_toward) < .985:
		steer_age = 0.0
		steer_toward = toward
		steer_heading = (
			_steer(
				brain, navigation, toward, target_speed, _neighbors(brain, profile), offset.length()
			)
			. normalized()
		)
	var steering := steer_heading * target_speed
	brain._face(steering, delta)
	var alignment := brain.direction.dot(steering.normalized())
	# Ordinary bends are arcs: slow down as the turn grows while still moving
	# along the body's facing. Only a reversal plants the feet completely.
	var weight := clampf(alignment, 0, 1)
	brain.turning_in_place = steering.length_squared() > .001 and weight < .1
	var desired_speed := steering.length() * weight
	speed = move_toward(
		speed,
		desired_speed,
		delta * (profile.acceleration if desired_speed > speed else profile.braking)
	)
	# Walking translation follows the nose. Large turns are planted steps.
	var velocity := brain.direction * speed * weight
	if (
		not navigation.segment_clear(position, position + velocity * delta * 2, profile.radius)
		or not _physical_motion_clear(brain.actor, velocity * delta * 2)
	):
		velocity = Vector3.ZERO
		speed = 0
		repath_left = minf(repath_left, .08)
	if brain.actor.get_real_velocity().length() < .08 and not brain.turning_in_place:
		stuck_time += delta
	else:
		stuck_time = 0
	if stuck_time >= profile.stuck_repath_time:
		repath_left = 0
		stuck_time = 0
	last_steering = steering.normalized()
	return velocity


func _look_ahead(
	position: Vector3,
	pace: float,
	navigation: EnemySurfaceNavigation,
	profile: EnemyMovementSettings
) -> Vector3:
	# Follow a point along the route ahead, turning before reaching each vertex.
	var remaining := clampf(pace * profile.path_look_ahead_time, .35, 1.2)
	var anchor := position
	var chosen := path[0]
	for point in path:
		var span := Vector2(point.x - anchor.x, point.z - anchor.z).length()
		var candidate := anchor.lerp(point, minf(1, remaining / maxf(span, .001)))
		if not navigation.segment_clear(position, candidate, profile.radius):
			break
		chosen = candidate
		remaining -= span
		if remaining <= 0:
			break
		anchor = point
	return chosen


func _neighbors(brain: EnemyBrain, profile: EnemyMovementSettings) -> Array:
	var result: Array = []
	for other in NavigationWorld.neighbors(
		brain.actor.global_position, profile.neighbor_distance, brain
	):
		if other == brain or not other.operational():
			continue
		var offset: Vector3 = other.actor.global_position - brain.actor.global_position
		offset.y = 0
		if offset.length() > profile.neighbor_distance:
			continue
		result.append(
			{
				"rid": other.actor.get_rid(),
				"offset": offset,
				"velocity": other.actor.get_real_velocity(),
				"radius": other.settings.movement.radius if other.settings.movement else .3
			}
		)
	result.sort_custom(func(a, b): return a.offset.length_squared() < b.offset.length_squared())
	return result.slice(0, profile.maximum_neighbors)


func _steer(
	brain: EnemyBrain,
	navigation: EnemySurfaceNavigation,
	toward: Vector3,
	pace: float,
	neighbors: Array,
	remaining: float
) -> Vector3:
	var profile := brain.settings.movement
	var position: Vector3 = brain.actor.global_position
	var best := -INF
	var chosen := Vector3.ZERO
	# Neighbors have predictive avoidance; a static sweep through their current
	# position must not override their predicted departure from this corridor.
	var predicted: Array[RID] = [brain.target.get_rid()]
	for neighbor in neighbors:
		predicted.append(neighbor.rid)
	motion_query.exclude_bodies = predicted
	# Stable passing-side ordering prevents head-on mirror deadlocks. A little
	# directional inertia prevents left/right oscillation around a neighbor.
	for angle in [0, 25, -25, 50, -50, 75, -75, 100, -100]:
		var heading := toward.rotated(Vector3.UP, deg_to_rad(angle))
		var velocity := heading * pace
		var probe := position + heading * minf(remaining, minf(pace * profile.prediction_time, .65))
		if not navigation.segment_clear(
			position, position + heading * minf(remaining, .02), profile.radius
		):
			continue
		if not navigation.segment_clear(position, probe, profile.radius):
			continue
		var score := heading.dot(toward) * 2.0 + heading.dot(last_steering) * .22
		for neighbor in neighbors:
			var relative: Vector3 = velocity - neighbor.velocity
			relative.y = 0
			var closest_time := clampf(
				neighbor.offset.dot(relative) / maxf(relative.length_squared(), .001),
				0,
				profile.prediction_time
			)
			var clearance: float = (neighbor.offset - relative * closest_time).length()
			var safe_radius: float = profile.radius + neighbor.radius + profile.personal_space
			if clearance < safe_radius:
				score -= (1.0 - clearance / safe_radius) * 12.0
		if (
			score <= -.4
			or score <= best
			or not _physical_motion_clear(brain.actor, probe - position)
		):
			continue
		# Prefer a wider bend when space permits. This is a preference, so a
		# physically passable narrow corridor stays usable with the same capsule.
		if not _physical_motion_clear(brain.actor, probe - position, profile.obstacle_clearance):
			score -= .8
		if score > best:
			best = score
			chosen = velocity
	# Waiting is preferable to driving into a neighbor or a blocked corner.
	return chosen


func _physical_motion_clear(actor: CharacterBody3D, motion: Vector3, clearance := 0.0) -> bool:
	# Navmesh climb tolerance can connect a low edge that the real capsule cannot
	# enter sideways. Also includes passive/moving bodies absent from the navmesh.
	motion_query.motion = motion
	motion_query.margin = actor.safe_margin
	motion_query.max_collisions = 4
	motion_query.recovery_as_collision = clearance > 0
	# Lateral probes keep floor contact unchanged. Inflating the full capsule's
	# margin would hit the floor first and hide the nearby wall from this check.
	for side in [-1.0, 1.0] if clearance > 0 else [0.0]:
		motion_query.from = actor.global_transform
		motion_query.from.origin += motion.normalized().cross(actor.up_direction) * clearance * side
		if not PhysicsServer3D.body_test_motion(actor.get_rid(), motion_query, motion_hit):
			continue
		for i in motion_hit.get_collision_count():
			var normal := motion_hit.get_collision_normal(i)
			if (
				normal.dot(actor.up_direction) < cos(actor.floor_max_angle)
				and (clearance > 0 or motion.dot(normal) < -.001)
			):
				return false
	return true
