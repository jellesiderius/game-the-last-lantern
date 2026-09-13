"""Reauthor six attack clips on the saved AcornGuard; preserve accepted geometry/weights.

Uses only mathematical helpers from the historical builder, never its mesh entry point.
Review current-source poses before export. EnemyBrain remains the owner of attack time.
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
checkpoint = DEST / 'checkpoints/before_readable_attack_20260913.blend'
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
# Import pure pose math, not the original asset-building statements.
tree = ast.parse((ROOT / 'tools/acorn_guard/build_asset.py').read_text())
helpers = [n for n in tree.body if isinstance(n, ast.FunctionDef)
           and n.name in ['pivot', 'rot', 'smooth', 'align', 'joint', 'pose']]
exec(compile(ast.Module(body=helpers, type_ignores=[]), 'acorn_pose_math', 'exec'))
base_pose = pose
upper = ['torso', 'cap', 'stem', 'leaf', 'arm_L', 'forearm_L', 'hand_L',
         'arm_R', 'forearm_R', 'hand_R', 'club_socket']


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


def pose_attack(phase, u, long_step):
    matrices = base_pose('idle', 0.0)
    ready = Vector((.36, -.05, .64))
    ready_direction = Vector((.35, -.14, .926)).normalized()
    finish = Vector((.18, .30, .35))
    finish_direction = Vector((.06, .90, -.44)).normalized()
    catch = 0.0
    settling = 0.0
    roll = 0.0
    if phase == 'windup':
        weight = smooth(u / .80)
        grip = club_grip.lerp(ready, weight)
        direction = club_direction.lerp(ready_direction, weight).normalized()
        yaw = -.20 * weight
        lean = -.10 * weight
        compress = -.018 * weight
        balance = weight
        stance = weight
    elif phase == 'strike':
        weight = smooth(u / .78)
        grip = ready.lerp(finish, weight)
        direction = ready_direction.lerp(finish_direction, weight).normalized()
        yaw = -.20 + .48 * weight
        lean = -.10 + .46 * weight
        compress = -.018 - .012 * math.sin(math.pi * weight)
        balance = 1.0
        stance = 1.0
    else:
        # Hold the low follow-through before regaining the original stance.
        settling = smooth((u - .35) / .65)
        grip = finish.lerp(club_grip, settling)
        direction = finish_direction.lerp(club_direction, settling).normalized()
        yaw = .28 * (1 - settling)
        lean = .36 * (1 - settling) + .065 * math.sin(math.pi * min(1., u / .38))
        compress = -.018 * (1 - settling) - .009 * math.sin(math.pi * u)
        roll = .13 * math.sin(math.pi * min(1., u / .70))
        balance = 1 - settling
        stance = 1 - settling
        catch = smooth((u - .04) / .22) * (1 - smooth((u - .55) / .35))
    offset = Vector((-.014 * math.sin(roll), .012 * catch, compress))
    body_delta = T(offset) @ pivot(rot('Z', yaw) @ rot('X', -lean) @ rot('Y', roll), (0, 0, .30))
    matrices['pelvis'] = T(offset) @ matrices['pelvis']
    for name in upper:
        matrices[name] = body_delta @ matrices[name]
    # The heavy cap and leaf settle after the torso instead of snapping as one block.
    cap_lag = -.035 * math.sin(math.pi * u) if phase == 'recover' else 0.0
    cap_delta = pivot(rot('Y', cap_lag), matrices['cap'].translation)
    for name in ['cap', 'stem', 'leaf']:
        matrices[name] = cap_delta @ matrices[name]
    leaf_lag = .065 * math.sin(3 * math.pi * u) * math.sin(math.pi * u) if phase == 'recover' else 0.0
    matrices['leaf'] = pivot(rot('X', leaf_lag), matrices['leaf'].translation) @ matrices['leaf']
    for side, sign in [('L', -1), ('R', 1)]:
        foot = rest['foot_' + side].translation.copy()
        foot.y += sign * (.045 if long_step else .030) * stance
        if phase == 'recover' and side == 'L':
            foot.y += .095 * catch
            if .04 < u < .26:
                foot.z += .038 * math.sin(math.pi * (u - .04) / .22)
            elif .55 < u < .90:
                foot.z += .025 * math.sin(math.pi * (u - .55) / .35)
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
    body = matrices['torso'] @ rest['torso'].inverted()
    hand = body @ rest['hand_L']
    hand.translation += Vector((-.035 * balance, -.045 * balance, .080 * balance))
    arm(matrices, 'L', hand)
    matrices['club_socket'] = matrices['hand_R'] @ rest['hand_R'].inverted() @ rest['club_socket']
    return matrices


before_hash = geometry_hash()
report = {}
durations = {'windup': .68, 'strike': .20, 'recover': .80,
             'lunge_windup': .76, 'lunge_strike': .22, 'lunge_recover': .90}
for name, duration in durations.items():
    if name in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[name])
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data.action = action
    count = round(duration * scene.render.fps)
    tips = []
    for frame in range(count + 1):
        matrices = pose_attack(name.removeprefix('lunge_'), frame / count, name.startswith('lunge_'))
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
    action['revision'] = 'readable_single_blow_20260913'
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
    report[name] = {'duration': count / scene.render.fps, 'club_tip_min_z': min(v[2] for v in tips),
                    'club_tip_max_z': max(v[2] for v in tips)}
assert geometry_hash() == before_hash
rig.animation_data.action = bpy.data.actions['idle']
rig.animation_data.action_slot = rig.animation_data.action.slots[0]
scene.frame_set(0)
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(DEST / 'source.blend'))
output = ROOT / 'captures/acorn_guard/attack_revision'
output.mkdir(parents=True, exist_ok=True)
(output / 'source_audit.json').write_text(json.dumps({'geometry_weights_sha256': before_hash,
    'unchanged_geometry_weights': True, 'clips': report}, indent=2))
print('READABLE_ATTACK', json.dumps(report))
