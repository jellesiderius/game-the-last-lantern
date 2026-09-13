"""Cascadeur: build an extended Sunblade performance from the current game clips.

Adds torso follow-through, head counter-motion and delayed tail movement while
preserving the original sword-hand paths. Output is an editable native .casc;
the segment manifest keeps the existing gameplay clip names and charge timing.
"""
import ast
import json
import math
from pathlib import Path
import csc
import numpy as np

ROOT = Path('/Users/jelle/Godot-Projects/crow-test')
OUT = ROOT / 'assets/characters/red_panda/cascadeur'
FPS = 120
source = json.loads((OUT / 'skeleton.json').read_text())
rest = {n: np.array(b['matrix']) for n, b in source.items()}
bank = json.loads((OUT / 'combat_source_poses.json').read_text())['clips']
C = np.array([[1., 0., 0.], [0., 0., 1.], [0., -1., 0.]])
# Mathematical functions only: never execute the walk authoring entry point here.
tree = ast.parse((ROOT / 'tools/cascadeur/author_walk.py').read_text())
helpers = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in ['translation', 'rotation', 'pivot', 'align']]
exec(compile(ast.Module(body=helpers, type_ignores=[]), 'walk_math_helpers', 'exec'))


def matrix_mix(a, b, weight):
    result = np.eye(4)
    qa = csc.math.Rotation.from_rotation_matrix(a[:3, :3].astype(np.float32)).to_quaternion()
    qb = csc.math.Rotation.from_rotation_matrix(b[:3, :3].astype(np.float32)).to_quaternion()
    qa = np.array([qa.w(), qa.x(), qa.y(), qa.z()])
    qb = np.array([qb.w(), qb.x(), qb.y(), qb.z()])
    dot = np.dot(qa, qb)
    if dot < 0:
        qb = -qb
        dot = -dot
    if dot > .9995:
        q = qa + weight * (qb - qa)
        q /= np.linalg.norm(q)
    else:
        angle = math.acos(min(1., dot))
        q = (math.sin((1-weight)*angle)*qa + math.sin(weight*angle)*qb) / math.sin(angle)
    result[:3, :3] = csc.math.Rotation.from_quaternion(*q).to_rotation_matrix()
    result[:3, 3] = a[:3, 3]*(1-weight) + b[:3, 3]*weight
    return result


def sample(name, u):
    frames = bank[name]['frames']
    pos = min(1., max(0., u)) * (len(frames)-1)
    a, b = int(pos), min(len(frames)-1, int(pos)+1)
    return {n: matrix_mix(np.array(frames[a][n]), np.array(frames[b][n]), pos-a) for n in rest}


def solve_joint(hip, target, first, second, pole):
    line = target - hip
    distance = min(np.linalg.norm(line), first+second-.00001)
    axis = line / np.linalg.norm(line)
    target = hip + axis * distance
    along = (distance**2 + first**2 - second**2) / (2*distance)
    bend = pole-hip
    bend -= axis*np.dot(bend, axis)
    if np.linalg.norm(bend) < .00001:
        bend = np.cross(axis, [0., 0., 1.])
    bend /= np.linalg.norm(bend)
    joint = hip + axis*along + bend*math.sqrt(max(0., first**2-along**2))
    return joint, target


def enhance(m, name, u):
    if name == 'idle':
        return m
    heavy = name.startswith('heavy')
    envelope = math.sin(math.pi*u)**2
    sign = -1. if name.endswith('left') else 1.
    turn = sign * (.065 if heavy else .045) * math.sin(math.pi*2*u) * envelope
    torso_delta = pivot(rotation('Z', turn), m['pelvis'][:3, 3])
    old_torso = m['torso'].copy()
    for n in ['torso', 'neck', 'head', 'back_sword_socket', 'cape_L', 'cape_R', 'cape_back']:
        m[n] = torso_delta @ m[n]
    m['head'] = pivot(rotation('Z', -turn*.65), m['head'][:3, 3]) @ m['head']
    # Re-solve shoulders/elbows so the hand and blade remain on the authored arc.
    for side in ['L', 'R']:
        arm = 'arm_upper_' + side
        elbow = 'forearm_' + side
        hand = 'hand_' + side
        shoulder = (torso_delta @ m[arm])[:3, 3]
        joint, wrist = solve_joint(shoulder, m[hand][:3, 3], source[arm]['length'],
                                   source[elbow]['length'], m[elbow][:3, 3])
        m[arm] = align(arm, shoulder, joint)
        m[elbow] = align(elbow, joint, wrist)
        shift = wrist - m[hand][:3, 3]
        for n in [hand, 'fingers_' + side] + [n for n in rest if source[n]['parent'] == hand and n != 'fingers_' + side]:
            m[n][:3, 3] += shift
    # Delayed, diminishing secondary motion, returning exactly at both endpoints.
    tail_delta = np.eye(4)
    for i, n in enumerate(['tail_01', 'tail_02', 'tail_03']):
        angle = sign * (.035 if heavy else .025) * envelope * math.sin(math.tau*u - i*.65)
        tail_delta = pivot(rotation('Z', angle), m[n][:3, 3]) @ tail_delta
        m[n] = tail_delta @ m[n]
    return m


app = csc.app.get_application()
sm = app.get_scene_manager()
# Reload the offline 120-FPS native base; do not change the saved walk scene.
assert app.get_data_source_manager().load_scene(str(OUT / 'red_panda_combat_base.casc'))
view = sm.current_scene()
scene = view.domain_scene()
mv, bv, dv = scene.model_viewer(), scene.behaviour_viewer(), scene.data_viewer()
ids = {}
for bh in bv.get_behaviours('Joint'):
    obj = bv.get_behaviour_owner(bh)
    n = mv.get_object_name(obj)
    if n in rest:
        tr = bv.get_behaviour_by_name(obj, 'Transform')
        ids[n] = (bv.get_behaviour_data(tr, 'global_position'), bv.get_behaviour_data(tr, 'global_rotation'))
assert set(ids) == set(rest)

# A review performance: these scheduled demo segments add no input queue to the game.
sequence = [
    ('ready', 'idle', .65),
    ('light_level_left', 'light_level_left', .36), ('reset_01', 'idle', .20),
    ('light_rising_right', 'light_rising_right', .36), ('reset_02', 'idle', .20),
    ('light_falling_left', 'light_falling_left', .36), ('reset_03', 'idle', .30),
    ('light_level_right', 'light_level_right', .36), ('reset_04', 'idle', .20),
    ('light_rising_left', 'light_rising_left', .36), ('reset_05', 'idle', .20),
    ('light_falling_right', 'light_falling_right', .36), ('reset_06', 'idle', .30),
    ('heavy_charge', 'heavy_charge', .45), ('heavy_release', 'heavy_release', .65),
    ('reset_07', 'idle', .35),
    ('heavy_charge_full', 'heavy_charge', .45), ('heavy_release_charged', 'heavy_release_charged', .65),
    ('reset_08', 'idle', .35), ('roll_attack', 'roll_attack', .45),
    ('recover', 'idle', .70),
]
poses, manifest = [], []
previous = sample('idle', 0.)
max_hand_shift = 0.
for label, name, duration in sequence:
    length = round(duration * FPS)
    start = len(poses)
    for i in range(length):
        u = i / length
        m = sample(name, u)
        original_hand = m['hand_R'][:3, 3].copy()
        m = enhance(m, name, u)
        max_hand_shift = max(max_hand_shift, np.linalg.norm(m['hand_R'][:3, 3]-original_hand))
        # Idle bridges settle the preceding clip over 80ms instead of snapping.
        if name == 'idle':
            t = min(1., i / (FPS*.08))
            t = t*t*(3-2*t)
            m = {n: matrix_mix(previous[n], m[n], t) for n in rest}
        poses.append(m)
    previous = poses[-1]
    manifest.append({'name': label, 'gameplay_clip': name, 'start_frame': start,
                     'end_frame_exclusive': len(poses), 'duration_seconds': length/FPS})
poses.append(sample('idle', 0.))


def modify(model, update, updater):
    le, de = model.layers_editor(), model.data_editor()
    layers = list(scene.layers_viewer().all_layer_ids())
    for layer in layers:
        le.set_section(csc.layers.layer.Section(), len(poses), layer)
    model.fit_animation_size_by_layers()
    updater.generate_update()
    for frame, matrices in enumerate(poses):
        actuals = set()
        for n, m in matrices.items():
            position, orientation = ids[n]
            de.set_data_value(position, frame, (C @ m[:3, 3] * 100).astype(np.float32))
            de.set_data_value(orientation, frame, csc.math.Rotation.from_rotation_matrix((C @ m[:3, :3]).astype(np.float32)))
            actuals.update((position, orientation))
        for layer in layers:
            le.set_fixed_interpolation_or_key_if_need(layer, frame, True)
        model.set_fixed_interpolation_if_need(actuals, frame)
        updater.run_update(actuals, frame)
    le.normalize_sections(scene)


assert scene.modify_update('Sunblade - extended combat performance', modify)
view.animation_boundary().first_frame = 0
view.animation_boundary().last_frame = len(poses)-1
view.animation_boundary().first_visible_frame = 0
view.animation_boundary().last_visible_frame = len(poses)-1
scene.set_current_frame(0)
camera = view.active_viewport().domain_viewport().camera_struct()
camera.position = np.array([180., 120., -290.], dtype=np.float32)
camera.target = np.array([0., 48., 0.], dtype=np.float32)
view.active_viewport().domain_viewport().set_camera_struct(camera)
view.save(str(OUT / 'red_panda_sword_combat.casc'))
report = {'fps': FPS, 'duration_seconds': (len(poses)-1)/FPS,
          'segments': manifest, 'joint_count': len(ids),
          'max_hand_adjustment_m': max_hand_shift,
          'root_displacement_cm': max(np.linalg.norm(dv.get_data_value(ids['root'][0], frame)) for frame in range(len(poses))),
          'export_available': app.is_export_available(),
          'authored_in': 'Cascadeur 2026.2.2', 'gameplay_integration': False}
(OUT / 'combat_segments.json').write_text(json.dumps(report, indent=2, default=float))
print('COMBAT_SAVED', report['duration_seconds'], 'seconds;', len(poses), 'frames;', len(manifest), 'segments')
