"""Add light alternating club jabs to the saved AcornGuard; preserve accepted geometry/weights.

Six Actions: jab_windup/strike/recover (forehand, from the right) and jab_back_* (backhand).
The club rises only to shoulder height and sweeps across the front instead of the overhead
slam. Uses only mathematical helpers from the historical builder, never its mesh entry point.
Review current-source poses (review_poses.py --jabs) before exporting.
"""
import ast
import bpy
import hashlib
import json
import math
import shutil
from pathlib import Path
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / 'assets/characters/acorn_guard'
checkpoint = DEST / 'checkpoints/before_light_jabs_20260914.blend'
if not checkpoint.exists():
    shutil.copy2(DEST / 'source.blend', checkpoint)
bpy.ops.wm.open_mainfile(filepath=str(DEST / 'source.blend'))
scene = bpy.data.scenes['AcornGuard_Production']
bpy.context.window.scene = scene
rig = bpy.data.objects['AcornGuard_Rig']
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
parents = {b.name: b.parent.name if b.parent else None for b in rig.data.bones}
lengths = {b.name: b.length for b in rig.data.bones}
club_grip = Vector((.333, .076, .309))
club_direction = Vector((.49, .08, .87)).normalized()
T = Matrix.Translation
tree = ast.parse((ROOT / 'tools/acorn_guard/build_asset.py').read_text())
helpers = [n for n in tree.body if isinstance(n, ast.FunctionDef)
           and n.name in ['pivot', 'rot', 'smooth', 'align', 'joint', 'pose']]
exec(compile(ast.Module(body=helpers, type_ignores=[]), 'acorn_pose_math', 'exec'))
base_pose = pose
upper = ['torso', 'cap', 'stem', 'leaf', 'arm_L', 'forearm_L', 'hand_L',
         'arm_R', 'forearm_R', 'hand_R', 'club_socket']
# (grip position, club direction, torso yaw) in rig space: +X right, +Y forward, +Z up.
SWINGS = {
    'forehand': {
        'ready': (Vector((.40, -.04, .50)), Vector((.62, -.28, .73)), -.26),
        'finish': (Vector((.06, .30, .36)), Vector((-.60, .79, -.08)), .22),
    },
    'backhand': {
        # Low and forward: the raised club must not cross the eyes or the cap brim.
        'ready': (Vector((.16, .32, .40)), Vector((-.72, .34, .60)), .18),
        'finish': (Vector((.42, .24, .38)), Vector((.64, .76, -.10)), -.20),
    },
}


def geometry_hash():
    data = []
    for obj in sorted(bpy.data.collections['AcornGuard_Character'].objects, key=lambda o: o.name):
        if obj.type == 'MESH':
            data.append((obj.name, [(tuple(v.co), [(g.group, g.weight) for g in v.groups])
                                    for v in obj.data.vertices]))
    return hashlib.sha256(json.dumps(data).encode()).hexdigest()


def arm(matrices, side, hand):
    body = matrices['torso'] @ rest['torso'].inverted()
    shoulder = body @ rest['arm_' + side].translation
    sign = 1 if side == 'R' else -1
    elbow, wrist = joint(shoulder, hand.translation, lengths['arm_' + side],
                         lengths['forearm_' + side], shoulder + Vector((sign * .24, -.10, .03)))
    hand.translation = wrist
    matrices['arm_' + side] = align('arm_' + side, shoulder, elbow)
    matrices['forearm_' + side] = align('forearm_' + side, elbow, wrist)
    matrices['hand_' + side] = hand


def pose_jab(swing, phase, u):
    matrices = base_pose('idle', 0.0)
    ready_grip, ready_direction, ready_yaw = SWINGS[swing]['ready']
    finish_grip, finish_direction, finish_yaw = SWINGS[swing]['finish']
    if phase == 'windup':
        weight = smooth(u / .85)
        grip = club_grip.lerp(ready_grip, weight)
        direction = club_direction.lerp(ready_direction, weight).normalized()
        yaw = ready_yaw * weight
        lean = -.04 * weight
        stance = weight
    elif phase == 'strike':
        weight = smooth(u / .75)
        grip = ready_grip.lerp(finish_grip, weight)
        direction = ready_direction.lerp(finish_direction, weight).normalized()
        yaw = ready_yaw + (finish_yaw - ready_yaw) * weight
        lean = -.04 + .14 * weight
        stance = 1.0
    else:
        weight = smooth((u - .15) / .85)
        grip = finish_grip.lerp(club_grip, weight)
        direction = finish_direction.lerp(club_direction, weight).normalized()
        yaw = finish_yaw * (1 - weight)
        lean = .10 * (1 - weight)
        stance = 1 - weight
    compress = -.010 * stance
    body_delta = T((0, 0, compress)) @ pivot(rot('Z', yaw) @ rot('X', -lean), (0, 0, .30))
    matrices['pelvis'] = T((0, 0, compress)) @ matrices['pelvis']
    for name in upper:
        matrices[name] = body_delta @ matrices[name]
    for side, sign in [('L', -1), ('R', 1)]:
        foot = rest['foot_' + side].translation.copy()
        foot.y += sign * .025 * stance
        hip = matrices['pelvis'] @ rest['pelvis'].inverted() @ rest['leg_' + side].translation
        knee, ankle = joint(hip, foot, lengths['leg_' + side], lengths['shin_' + side],
                            hip + Vector((sign * .02, .25, 0)))
        matrices['leg_' + side] = align('leg_' + side, hip, knee)
        matrices['shin_' + side] = align('shin_' + side, knee, ankle)
        matrices['foot_' + side] = rest['foot_' + side].copy()
        matrices['foot_' + side].translation = ankle
    socket = direction.to_track_quat('Y', 'Z').to_matrix().to_4x4()
    socket.translation = grip
    hand = socket @ rest['club_socket'].inverted() @ rest['hand_R']
    arm(matrices, 'R', hand)
    # The free hand counterbalances opposite to the sweep.
    body = matrices['torso'] @ rest['torso'].inverted()
    hand = body @ rest['hand_L']
    swing_side = 1 if swing == 'forehand' else -1
    hand.translation += Vector((-.03 * swing_side * stance, -.03 * stance, .05 * stance))
    arm(matrices, 'L', hand)
    matrices['club_socket'] = matrices['hand_R'] @ rest['hand_R'].inverted() @ rest['club_socket']
    return matrices


before_hash = geometry_hash()
report = {}
durations = {'windup': .40, 'strike': .14, 'recover': .36}
for swing, prefix in [('forehand', 'jab_'), ('backhand', 'jab_back_')]:
    for phase, duration in durations.items():
        name = prefix + phase
        if name in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[name])
        action = bpy.data.actions.new(name)
        action.use_fake_user = True
        rig.animation_data.action = action
        count = round(duration * scene.render.fps)
        tips = []
        for frame in range(count + 1):
            matrices = pose_jab(swing, phase, frame / count)
            tips.append(list(matrices['club_socket'] @ Vector((0, .407, 0))))
            for bone in rig.pose.bones:
                parent = parents[bone.name]
                basis = rest[bone.name].inverted() @ (rest[parent] @ matrices[parent].inverted()
                        if parent else Matrix.Identity(4)) @ matrices[bone.name]
                bone.rotation_mode = 'QUATERNION'
                bone.location, bone.rotation_quaternion, bone.scale = basis.decompose()
                for prop in ['location', 'rotation_quaternion', 'scale']:
                    bone.keyframe_insert(prop, frame=frame, group=bone.name)
        action.use_frame_range = True
        action.frame_start = 0
        action.frame_end = count
        action['duration_seconds'] = count / scene.render.fps
        action['in_place'] = True
        action['revision'] = 'light_jabs_20260914'
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:
                            key.interpolation = 'LINEAR'
        report[name] = {'duration': count / scene.render.fps,
                        'club_tip_min_z': min(v[2] for v in tips),
                        'club_tip_max_z': max(v[2] for v in tips)}
assert geometry_hash() == before_hash
rig.animation_data.action = bpy.data.actions['idle']
rig.animation_data.action_slot = rig.animation_data.action.slots[0]
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(DEST / 'source.blend'))
output = ROOT / 'captures/acorn_guard/light_jabs'
output.mkdir(parents=True, exist_ok=True)
(output / 'source_audit.json').write_text(json.dumps({'geometry_weights_sha256': before_hash,
    'unchanged_geometry_weights': True, 'clips': report}, indent=2))
print('LIGHT_JABS', json.dumps(report))
