class_name CharacterVisual
extends Node3D
@export var stow_at_rest := true
## Opt-in for clips authored with matching left/right contact phases.
@export var synchronize_gait_phase := false
@export_range(0.01, 0.2, 0.005) var locomotion_blend_half_life := 0.035
var gait_phase := 0.0
var idle_time := 0.0
var displayed_speed := 0.0
## Optional clips supplied by each character's own imported rig.
@export_node_path("Node3D") var carried_light_emitter_path: NodePath
@export var kindle_clip := "idle"
@export var rest_clip := "idle"
@export var fall_clip := ""
@export var landing_clip := ""
## Optional carried props stay upright and are stowed when both hands are needed.
@export var upright_accessory_paths: Array[NodePath] = []
@export var vertex_color_materials: PackedStringArray = []
var movement := MovementSettings.new()
var locomotion: AnimationNodeBlendSpace1D
## Gameplay owns time. AnimationTree is evaluated manually once per physics sample.
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var tree: AnimationTree
var action_node: AnimationNodeAnimation
var action_mix: AnimationNodeBlend2
var action_blend := 0.0
var current_clip := ""
var weapon: MeleeWeapon
var socket: BoneAttachment3D
var bow: BowVisual
var bow_socket: BoneAttachment3D
var draw_socket: BoneAttachment3D
var stowed := true
var mount_blend := 1.0
var transition_age := 1.0
var previous_positions: Array[Vector3] = []
var previous_rotations: Array[Quaternion] = []
var damage_material := ShaderMaterial.new()
var damage_meshes: Array[MeshInstance3D] = []
var damage_overlays: Array[Material] = []
var damage_feedback_active := false


func _ready() -> void:
	var model = $Model
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0]
	animation_player = model.find_children("*", "AnimationPlayer", true, false)[0]
	damage_material.shader = preload("res://shaders/damage_protection.gdshader")
	damage_material.render_priority = 20
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_active_material(surface) as StandardMaterial3D
			if material and material.resource_name in vertex_color_materials:
				material = material.duplicate()
				material.vertex_color_use_as_albedo = true
				material.albedo_color = Color.WHITE
				mesh.set_surface_override_material(surface, material)
		if mesh.skin:
			damage_meshes.append(mesh)
			damage_overlays.append(mesh.material_overlay)
	for clip in animation_player.get_animation_list():
		var anim = animation_player.get_animation(clip)
		anim.loop_mode = (
			Animation.LOOP_LINEAR
			if clip in ["idle", "walk", "run", "heavy_hold", "bow_aim", "bow_hold", fall_clip]
			else Animation.LOOP_NONE
		)
	animation_player.stop()
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.anim_player = tree.get_path_to(animation_player)
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var blend_tree = AnimationNodeBlendTree.new()
	locomotion = AnimationNodeBlendSpace1D.new()
	locomotion.min_space = 0.0
	locomotion.max_space = 4.5
	locomotion.sync = true
	for pair in [["idle", 0.0], ["walk", 1.8], ["run", 4.5]]:
		var node = AnimationNodeAnimation.new()
		node.animation = pair[0]
		if synchronize_gait_phase:
			var gait := AnimationNodeBlendTree.new()
			gait.add_node("Clip", node)
			gait.add_node("Seek", AnimationNodeTimeSeek.new())
			gait.connect_node("Seek", 0, "Clip")
			gait.connect_node("output", 0, "Seek")
			locomotion.add_blend_point(gait, pair[1], -1, pair[0])
		else:
			locomotion.add_blend_point(node, pair[1], -1, pair[0])
	blend_tree.add_node("Locomotion", locomotion, Vector2(0, 0))
	action_node = AnimationNodeAnimation.new()
	action_node.animation = "idle"
	blend_tree.add_node("Action", action_node, Vector2(0, 180))
	blend_tree.add_node("LocomotionRate", AnimationNodeTimeScale.new(), Vector2(210, 0))
	blend_tree.connect_node("LocomotionRate", 0, "Locomotion")
	blend_tree.add_node("ActionSeek", AnimationNodeTimeSeek.new(), Vector2(220, 180))
	action_mix = AnimationNodeBlend2.new()
	# Refusal is upper-body feedback. Locomotion keeps owning pelvis and foot tracks.
	var reference_clip := animation_player.get_animation("idle")
	for i in reference_clip.get_track_count():
		var track_path := reference_clip.track_get_path(i)
		var bone := String(track_path.get_subname(0)) if track_path.get_subname_count() else ""
		if bone not in ["root", "pelvis", "leg_L", "leg_R", "knee_L", "knee_R", "foot_L", "foot_R"]:
			action_mix.set_filter_path(track_path, true)
	blend_tree.add_node("Mix", action_mix, Vector2(450, 0))
	blend_tree.connect_node("ActionSeek", 0, "Action")
	blend_tree.connect_node("Mix", 0, "LocomotionRate")
	blend_tree.connect_node("Mix", 1, "ActionSeek")
	blend_tree.connect_node("output", 0, "Mix")
	tree.tree_root = blend_tree
	tree.active = true
	socket = skeleton.get_node("SwordAttachment")
	weapon = socket.get_node("Weapon")
	bow_socket = skeleton.get_node("BowAttachment")
	draw_socket = skeleton.get_node("BowDrawAttachment")
	bow = bow_socket.get_node("Bow")
	bow.apply_appearance(weapon.definition)
	sample("", 0.0, 0.0, 0.0)
	OcclusionSilhouette.apply(model)


func sample(clip: String, action_time: float, speed: float, delta: float) -> void:
	action_mix.filter_enabled = (
		clip == "bow_empty"
		or (
			speed > .05
			and (
				clip
				in ["bow_equip", "bow_aim", "bow_draw", "bow_hold", "heavy_charge", "heavy_hold"]
			)
		)
	)
	if clip != current_clip:
		previous_positions.clear()
		previous_rotations.clear()
		for i in skeleton.get_bone_count():
			previous_positions.append(skeleton.get_bone_pose_position(i))
			previous_rotations.append(skeleton.get_bone_pose_rotation(i))
		transition_age = 0.0
		current_clip = clip
		if not clip.is_empty():
			action_node.animation = clip
	var desired := 0.0 if clip.is_empty() else 1.0
	action_blend = move_toward(action_blend, desired, delta / 0.045) if delta > 0 else desired
	if synchronize_gait_phase:
		displayed_speed = (
			lerpf(displayed_speed, speed, 1.0 - pow(0.5, delta / locomotion_blend_half_life))
			if delta > 0.0
			else speed
		)
	else:
		displayed_speed = speed
	tree.set("parameters/Locomotion/blend_position", displayed_speed)
	var natural_speed: float = (
		movement.walk_cycle_speed * minf(speed / movement.walk_blend_speed, 1.0)
		if speed < movement.walk_blend_speed
		else lerpf(
			movement.walk_cycle_speed,
			movement.run_cycle_speed,
			clampf(
				(
					(speed - movement.walk_blend_speed)
					/ maxf(.01, movement.max_speed - movement.walk_blend_speed)
				),
				0,
				1
			)
		)
	)
	tree.set(
		"parameters/LocomotionRate/scale",
		clampf(speed / maxf(.01, natural_speed), 1.0, movement.maximum_locomotion_rate)
	)
	if synchronize_gait_phase:
		var gait_mix := clampf(
			(
				(displayed_speed - movement.walk_blend_speed)
				/ maxf(.01, movement.max_speed - movement.walk_blend_speed)
			),
			0.0,
			1.0
		)
		var walk_length := animation_player.get_animation("walk").length
		var run_length := animation_player.get_animation("run").length
		var cycle_distance := lerpf(
			movement.walk_cycle_speed * walk_length, movement.run_cycle_speed * run_length, gait_mix
		)
		# Below the walk point the idle mix reduces stride length, not foot cadence.
		cycle_distance *= minf(displayed_speed / movement.walk_blend_speed, 1.0)
		if speed > .005:
			gait_phase = fposmod(gait_phase + delta * speed / maxf(.025, cycle_distance), 1.0)
		idle_time = fposmod(idle_time + delta, animation_player.get_animation("idle").length)
		for pair in [
			["idle", idle_time],
			["walk", gait_phase * walk_length],
			["run", gait_phase * run_length]
		]:
			tree.set("parameters/Locomotion/" + pair[0] + "/Seek/seek_request", pair[1])
	tree.set("parameters/Mix/blend_amount", action_blend)
	if not clip.is_empty():
		tree.set("parameters/ActionSeek/seek_request", action_time)
	tree.advance(delta)
	transition_age += delta
	var transition_duration := .015 if clip == "bow_release" else (.12 if clip.is_empty() else .065)
	if transition_age < transition_duration and delta > 0 and not previous_positions.is_empty():
		var weight := smoothstep(0.0, transition_duration, transition_age)
		for i in skeleton.get_bone_count():
			skeleton.set_bone_pose_position(
				i, previous_positions[i].lerp(skeleton.get_bone_pose_position(i), weight)
			)
			skeleton.set_bone_pose_rotation(
				i, previous_rotations[i].slerp(skeleton.get_bone_pose_rotation(i), weight)
			)
	skeleton.force_update_all_bone_transforms()
	# Explicit sync for immediate physics queries; BoneAttachment stays authoritative.
	var hand = skeleton.get_bone_global_pose(skeleton.find_bone("sword_socket"))
	var back_index = skeleton.find_bone("back_sword_socket")
	var back = (
		skeleton.get_bone_global_pose(back_index) if back_index >= 0 and stow_at_rest else hand
	)
	mount_blend = (
		move_toward(mount_blend, 1.0 if stowed else 0.0, delta / .065)
		if delta > 0
		else (1.0 if stowed else 0.0)
	)
	socket.bone_name = (
		"back_sword_socket" if stowed and stow_at_rest and back_index >= 0 else "sword_socket"
	)
	socket.transform = hand.interpolate_with(back, mount_blend)
	bow_socket.transform = skeleton.get_bone_global_pose(skeleton.find_bone("bow_socket"))
	draw_socket.transform = skeleton.get_bone_global_pose(skeleton.find_bone("bow_draw_socket"))
	for path in upright_accessory_paths:
		var item := get_node(path) as Node3D
		var attachment := item.get_parent() as BoneAttachment3D
		attachment.transform = skeleton.get_bone_global_pose(
			skeleton.find_bone(attachment.bone_name)
		)
		item.global_basis = Basis.IDENTITY
		item.visible = not bow.visible and clip not in ["dodge_roll", "death"]


func reset_visual() -> void:
	show_damage_protection(0.0, 1.0)
	current_clip = ""
	action_blend = 0.0
	gait_phase = 0.0
	idle_time = 0.0
	displayed_speed = 0.0
	previous_positions.clear()
	previous_rotations.clear()
	transition_age = 1.0
	weapon.clear_swing()
	sample("", 0, 0, 0)


func configure_locomotion(profile: MovementSettings) -> void:
	movement = profile
	locomotion.max_space = movement.max_speed
	locomotion.set_blend_point_position(1, movement.walk_blend_speed)
	locomotion.set_blend_point_position(2, movement.max_speed)


func set_bow_mode(enabled: bool) -> void:
	bow.visible = enabled
	weapon.visible = not enabled
	for path in upright_accessory_paths:
		get_node(path).visible = not enabled and current_clip not in ["dodge_roll", "death"]
	if not enabled:
		bow.held_arrow.hide()


func show_damage_protection(remaining: float, duration: float) -> void:
	var enabled := remaining > 0.0
	if enabled != damage_feedback_active:
		damage_feedback_active = enabled
		for i in damage_meshes.size():
			damage_meshes[i].material_overlay = damage_material if enabled else damage_overlays[i]
	if not enabled:
		return
	var age := maxf(0.0, duration - remaining)
	var strength := .9 * (1.0 - age / .075) if age < .075 else .22 + .17 * sin(age * TAU * 4)
	damage_material.set_shader_parameter("strength", strength)
	damage_material.set_shader_parameter(
		"tint", Color.WHITE if age < .075 else Color(1.0, .87, .62)
	)


func carried_light_origin() -> Vector3:
	if not carried_light_emitter_path.is_empty():
		return get_node(carried_light_emitter_path).global_position
	if not upright_accessory_paths.is_empty():
		return get_node(upright_accessory_paths[0]).global_position + Vector3.UP * .12
	return global_position + Vector3.UP * .45 - global_basis.z * .3
