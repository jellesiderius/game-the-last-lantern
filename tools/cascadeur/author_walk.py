"""Cascadeur Python: author a 24-frame in-place walk on the original panda joints.

Run with rpc.py after importing red_panda_rest.fbx into a separate Cascadeur tab.
Uses ordinary editable joint keys; no AutoPhysics/AutoPosing claim is made.
"""
import json
import math
from pathlib import Path
import csc
import numpy as np

ROOT = Path('/Users/jelle/Godot-Projects/crow-test')
OUT = ROOT / 'assets/characters/red_panda/cascadeur'
source = json.loads((OUT / 'skeleton.json').read_text())
rest = {n: np.array(b['matrix']) for n, b in source.items()}
idle = {n: np.array(m) for n, m in json.loads((OUT / 'idle_pose.json').read_text()).items()}
C = np.array([[1., 0., 0.], [0., 0., 1.], [0., -1., 0.]])
FRAMES = 24
FPS = 30


def translation(v):
    m = np.eye(4)
    m[:3, 3] = v
    return m


def rotation(axis, angle):
    c, s = math.cos(angle), math.sin(angle)
    m = np.eye(4)
    if axis == 'X':
        m[:3, :3] = [[1, 0, 0], [0, c, -s], [0, s, c]]
    elif axis == 'Y':
        m[:3, :3] = [[c, 0, s], [0, 1, 0], [-s, 0, c]]
    else:
        m[:3, :3] = [[c, -s, 0], [s, c, 0], [0, 0, 1]]
    return m


def pivot(m, p):
    return translation(p) @ m @ translation(-np.array(p))


def align(name, head, tail):
    old = rest[name][:3, 1]
    new = tail - head
    new /= np.linalg.norm(new)
    v = np.cross(old, new)
    c = np.dot(old, new)
    skew = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    r = np.eye(3) + skew + skew @ skew / max(1e-8, 1 + c)
    m = rest[name].copy()
    m[:3, :3] = r @ rest[name][:3, :3]
    m[:3, 3] = head
    return m


def knee(hip, ankle, side):
    a, b = source['leg_' + side]['length'], source['knee_' + side]['length']
    line = ankle - hip
    d = np.linalg.norm(line)
    assert d < a + b, ('Unreachable foot', side, d, a + b)
    direction = line / d
    along = (d*d + a*a - b*b) / (2*d)
    pole = np.array([0., 1., 0.])
    pole -= direction * np.dot(pole, direction)
    pole /= np.linalg.norm(pole)
    return hip + direction * along + pole * math.sqrt(max(0, a*a - along*along))


def pose(u):
    phase = math.tau * u
    # Two weight changes per cycle; the root remains at the origin.
    pelvis = translation((.006 * math.sin(phase), 0., -.018 - .004 * math.cos(phase * 2)))
    body = pelvis @ pivot(rotation('Z', .025 * math.sin(phase)) @ rotation('X', -.065), (0, 0, .23))
    m = {'root': rest['root'].copy(), 'pelvis': pelvis @ rest['pelvis']}
    for name in ['torso', 'neck', 'head', 'back_sword_socket']:
        m[name] = body @ rest[name]
    m['head'] = body @ pivot(rotation('X', .04) @ rotation('Z', -.018 * math.sin(phase)), rest['head'][:3, 3]) @ rest['head']
    for side, offset in [('L', 0.), ('R', .5)]:
        p = (u + offset) % 1
        # Constant backwards support travel, with a raised smooth return.
        if p < .55:
            y = .039 - .078 * p / .55
            lift = 0.
        else:
            t = (p - .55) / .45
            y = -.039 + .078 * (t*t*(3 - 2*t))
            lift = .026 * math.sin(math.pi*t)**2
        ankle = rest['foot_' + side][:3, 3].copy()
        ankle += np.array((0., y, lift + .004))
        hip = (pelvis @ rest['leg_' + side])[:3, 3]
        joint = knee(hip, ankle, side)
        m['leg_' + side] = align('leg_' + side, hip, joint)
        m['knee_' + side] = align('knee_' + side, joint, ankle)
        m['foot_' + side] = rest['foot_' + side].copy()
        m['foot_' + side][:3, 3] = ankle
        # Preserve the accepted grip; the whole carrying arm counter-swings.
        swing = .10 * math.cos(phase + math.tau * offset)
        arm_delta = body @ pivot(rotation('X', swing), rest['arm_upper_' + side][:3, 3]) @ np.linalg.inv(idle['torso'] @ np.linalg.inv(rest['torso']))
        for name in ['arm_upper_' + side, 'forearm_' + side, 'hand_' + side, 'fingers_' + side]:
            m[name] = arm_delta @ idle[name]
        for name in ['sword_socket', 'bow_socket', 'bow_draw_socket', 'lantern_socket']:
            if source[name]['parent'] == 'hand_' + side:
                m[name] = arm_delta @ idle[name]
    tail = pelvis
    for i, name in enumerate(['tail_01', 'tail_02', 'tail_03']):
        tail = tail @ pivot(rotation('Z', .035 * math.sin(phase - i*.7)) @ rotation('X', .018 * math.cos(phase*2 - i*.6)), rest[name][:3, 3])
        m[name] = tail @ rest[name]
    for i, name in enumerate(['cape_L', 'cape_R', 'cape_back']):
        m[name] = body @ pivot(rotation('X', .018 * math.sin(phase*2 - i*.5)), rest[name][:3, 3]) @ rest[name]
    assert set(m) == set(rest)
    return m


app = csc.app.get_application()
view = app.get_scene_manager().current_scene()
scene = view.domain_scene()
mv = scene.model_viewer()
bv = mv.behaviour_viewer()
dv = mv.data_viewer()
ids = {}
for bh in bv.get_behaviours('Joint'):
    obj = bv.get_behaviour_owner(bh)
    name = mv.get_object_name(obj)
    if name in rest:
        tr = bv.get_behaviour_by_name(obj, 'Transform')
        ids[name] = (bv.get_behaviour_data(tr, 'global_position'), bv.get_behaviour_data(tr, 'global_rotation'))
assert set(ids) == set(rest), 'Import the original panda rest FBX first.'
poses = [pose(frame / FRAMES) for frame in range(FRAMES + 1)]


def modify(model, update, updater):
    le, de = model.layers_editor(), model.data_editor()
    layers = list(scene.layers_viewer().all_layer_ids())
    for layer in layers:
        le.set_section(csc.layers.layer.Section(), FRAMES + 1, layer)
    model.fit_animation_size_by_layers()
    updater.generate_update()
    for frame, matrices in enumerate(poses):
        actuals = set()
        for name, m in matrices.items():
            position, orientation = ids[name]
            de.set_data_value(position, frame, np.array(C @ m[:3, 3] * 100, dtype=np.float32))
            de.set_data_value(orientation, frame, csc.math.Rotation.from_rotation_matrix(np.array(C @ m[:3, :3], dtype=np.float32)))
            actuals.update((position, orientation))
        for layer in layers:
            le.set_fixed_interpolation_or_key_if_need(layer, frame, True)
        model.set_fixed_interpolation_if_need(actuals, frame)
        updater.run_update(actuals, frame)
    le.normalize_sections(scene)


assert scene.modify_update('Red panda - basic walk cycle', modify)
view.animation_boundary().first_frame = 0
view.animation_boundary().last_frame = FRAMES
view.animation_boundary().first_visible_frame = 0
view.animation_boundary().last_visible_frame = FRAMES
scene.set_current_frame(0)
view.save(str(OUT / 'red_panda_walk.casc'))
# Read evaluated data back from Cascadeur, rather than exporting the input arrays.
evaluated = []
for frame in range(FRAMES + 1):
    row = {}
    for name, (position, orientation) in ids.items():
        row[name] = {'position_cm': dv.get_data_value(position, frame).tolist(),
                     'rotation': dv.get_data_value(orientation, frame).to_rotation_matrix().tolist()}
    evaluated.append(row)
report = {
    'fps': FPS, 'frames': FRAMES + 1, 'duration_seconds': FRAMES / FPS,
    'joint_count': len(ids), 'export_available': app.is_export_available(),
    'root_displacement_cm': max(np.linalg.norm(row['root']['position_cm']) for row in evaluated),
    'loop_position_error_cm': max(np.linalg.norm(np.array(evaluated[0][n]['position_cm']) - evaluated[-1][n]['position_cm']) for n in ids),
    'foot_lift_cm': {n: max(row[n]['position_cm'][1] for row in evaluated) - min(row[n]['position_cm'][1] for row in evaluated) for n in ['foot_L', 'foot_R']},
}
(ROOT / 'captures/cascadeur_walk/walk_audit.json').write_text(json.dumps(report, indent=2))
if app.is_export_available():
    loader = app.get_tools_manager().get_tool('FbxSceneLoader').get_fbx_loader(view)
    settings = csc.fbx.FbxSettings()
    settings.mode = csc.fbx.FbxSettingsMode.Binary
    settings.up_axis = csc.fbx.FbxSettingsAxis.Y
    settings.bake_animation = True
    loader.set_settings(settings)
    loader.export_all_objects(str(OUT / 'red_panda_walk.fbx'))
print('WALK_SAVED', FRAMES + 1, 'keys per joint;', len(ids), 'joints;', FRAMES / FPS, 'seconds')
