"""Low, compact dodge roll for the red panda (Death's Door style).
Replaces only the dodge_roll Action: the panda dives forward, tucks into a ball, rolls
once close to the ground and rises back into the relaxed carry pose. No mesh, weight
or other Action edits. The previous roll spun the upright body around hip height; the
floor correction then lifted it, which read as a standing somersault.

Run: blender -b assets/characters/red_panda/source.blend --python tools/lantern_village/author_dodge_roll.py
"""
import ast, bpy, json, math, shutil
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path('/Users/jelle/Godot-Projects/crow-test')
s = bpy.data.scenes['LanternPanda_Production']; bpy.context.window.scene = s
if bpy.context.object and bpy.context.object.mode != 'OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
rig = bpy.data.objects['LanternPanda_Rig']; c = bpy.data.collections['LanternPanda_Character']
checkpoint = ROOT/'assets/characters/red_panda/checkpoints/before_dodge_roll_20260914.blend'
if not checkpoint.exists(): shutil.copy2(bpy.data.filepath, checkpoint)
rest = {b.name: b.matrix_local.copy() for b in rig.data.bones}
parents = {b.name: b.parent.name if b.parent else None for b in rig.data.bones}
lengths = {b.name: b.length for b in rig.data.bones}; V = Vector
helper_source = (ROOT/'tools/lantern_village/animate_character.py').read_text()
tree = ast.parse(helper_source)
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name != 'pose'], type_ignores=[]), 'pose_helpers', 'exec'))
samples = []
for o in c.objects:
    if o.type != 'MESH': continue
    indices = set(range(0, len(o.data.vertices), max(1, len(o.data.vertices)//500)))
    indices.add(min(o.data.vertices, key=lambda v: v.co.z).index)
    for i in indices:
        v = o.data.vertices[i]
        samples.append((v.co.copy(), [(o.vertex_groups[g.group].name, g.weight) for g in v.groups]))

DURATION = .55
FPS = 100
# Tunables. Blender +Y is forward, +Z up. RX(negative) tips the top forward.
BALL_CENTER = V((0, .12, .34))   # rotation centre of the tucked ball
DIVE_LEAN = 1.2                  # forward curl of the torso (rad)
HEAD_TUCK = .8                   # chin to chest (rad)
LEG_FOLD = 1.9                   # thighs toward the chest (rad)
SHIN_FOLD = 2.2                  # heels toward the seat (rad)
TAIL_CURL = -1.0                 # per tail segment, wrapping over the back (rad)
DIVE_HEIGHT = .28                # peak of the forward jump above floor contact (m)
LEG_TRAIL = .6                   # legs stretched back during the dive (rad)


def skinned_points(m):
    transforms = {name: m[name] @ rest[name].inverted() for name in rest}
    points = []
    for position, weights in samples:
        total = sum(w for _, w in weights) or 1.
        p = V((0, 0, 0))
        for name, w in weights: p += (transforms[name] @ position) * (w/total)
        dominant = max(weights, key=lambda x: x[1])[0] if weights else '?'
        points.append((p, dominant))
    return points


def phases(t):
    u = clamp(t/DURATION)
    # push-off dip, then a landing squat once upright again
    # push-off dip, then knees absorb the landing and straighten slowly
    crouch = ease(u/.04) * (1 - ease((u - .04)/.04)) + .8 * ease((u - .66)/.1) * (1 - ease((u - .76)/.24))
    dive = ease((u - .02)/.08) * (1 - ease((u - .22)/.1))  # stretched flight
    # ball while rolling; opens gradually so the head never snaps up
    tuck = ease((u - .2)/.08) * (1 - ease((u - .5)/.3))
    hop = math.sin(math.pi*clamp((u - .03)/.28)) * DIVE_HEIGHT
    return u, crouch, dive, tuck, hop


ROLL_START, ROLL_END = .02, .82


def roll_pose(t, turn_enabled=True):
    u, crouch, dive, tuck, hop = phases(t)
    # Accelerating spin: a gentle forward pitch in the air, full speed through the ball,
    # and it stops only once the body is upright again (no lingering face-down pose).
    f = clamp((u - ROLL_START)/(ROLL_END - ROLL_START))
    # Quick to get going, then eases out as the feet come round, so the roll settles
    # into the landing instead of stopping dead at full spin speed.
    turn = -math.tau * (1 - math.cos(math.pi * f**.8)) / 2 if turn_enabled else 0.
    center = BALL_CENTER
    if turn_enabled and tuck > .01:
        # Spin around the centre of the tucked silhouette's smallest enclosing ball.
        # Height comes only from the body floor contact (body_ground), so the ball
        # touches the floor instead of hopping. The long tail is curled along the back
        # and excluded; fitting it would inflate the ball.
        pts = [p for p, bone in skinned_points(roll_pose(t, False)) if not bone.startswith('tail')]
        ball = sum(pts, V((0, 0, 0))) / len(pts)
        for i in range(60):
            far = max(pts, key=lambda p: (p - ball).length)
            ball += (far - ball) / (i + 2)
        ball.x = 0.
        center = BALL_CENTER.lerp(ball, clamp(tuck*1.5))
    base = T((0, 0, -.06*crouch)) @ pivot(RX(turn), center)
    # Crouches lean slightly forward (absorbing momentum), never back.
    body = base @ pivot(RX(-DIVE_LEAN*tuck - .15*crouch), V((0, 0, .3)))
    m = {'root': rest['root'].copy(), 'pelvis': base @ rest['pelvis']}
    for name in ['torso', 'neck', 'back_sword_socket', 'cape_L', 'cape_R', 'cape_back']:
        m[name] = body @ rest[name]
    m['head'] = body @ pivot(RX(-HEAD_TUCK*tuck), rest['head'].translation) @ rest['head']
    # Hands stay close to the chest; the right hand keeps the sword along the ball.
    carry = V((.265, .115, .29)); tucked = V((.19, .14, .34)); reach = V((.2, .3, .42))
    grip = body @ carry.lerp(reach, dive).lerp(tucked, tuck)
    blade = (body.to_3x3() @ V((.35, .82, .45)).normalized().lerp(V((.3, .9, .3)).normalized(), dive).lerp(V((.6, .1, -.8)).normalized(), tuck)).normalized()
    arm_pose(m, 'R', grip, blade, 'sword_socket', body, .9)
    left = body @ V((-.277, .06, .288)).lerp(V((-.2, .3, .42)), dive).lerp(V((-.19, .14, .34)), tuck)
    arm_pose(m, 'L', left, body.to_3x3() @ V((0, 1, 0)), 'bow_socket', body, .3)
    for side in ['L', 'R']:
        # Legs push back and trail during the flight, then fold into the ball.
        upper = base @ pivot(RX(LEG_FOLD*tuck - LEG_TRAIL*dive + .5*crouch), rest['leg_'+side].translation)
        lower = upper @ pivot(RX(-SHIN_FOLD*tuck - .4*dive - .9*crouch), rest['knee_'+side].translation)
        m['leg_'+side] = upper @ rest['leg_'+side]
        m['knee_'+side] = lower @ rest['knee_'+side]
        m['foot_'+side] = lower @ rest['foot_'+side]
    tail = base
    for name in ['tail_01', 'tail_02', 'tail_03']:
        tail = tail @ pivot(RX(TAIL_CURL*tuck), rest[name].translation)
        m[name] = tail @ rest[name]
    missing = set(rest) - set(m)
    assert not missing, missing
    return m


def body_ground(m):
    # Place the lowest body point (tail excluded) on the floor, up or down.
    lowest = min(p.z for p, bone in skinned_points(m) if not bone.startswith('tail'))
    shift = .006 - lowest
    for name, matrix in m.items():
        if name != 'root': matrix.translation.z += shift
    return lowest, shift


def sample_local(action, frame):
    rig.animation_data.action = action; rig.animation_data.action_slot = action.slots[0]
    s.frame_set(frame); bpy.context.view_layer.update()
    return {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in rig.pose.bones}


carry_pose = sample_local(bpy.data.actions['idle'], 0)
old = bpy.data.actions.get('dodge_roll')
if old: bpy.data.actions.remove(old)
action = bpy.data.actions.new('dodge_roll'); action.use_fake_user = True
rig.animation_data.action = action
report = {'frames': [], 'floor_correction_max': 0.}
frames = round(DURATION*FPS)
for frame in range(frames + 1):
    t = frame/FPS; u = t/DURATION
    m = roll_pose(t)
    low, fix = body_ground(m) if 0 < frame < frames else ground(m)
    if 0 < frame < frames:
        for name, matrix in m.items():
            if name != 'root': matrix.translation.z += phases(t)[4]
    report['floor_correction_max'] = max(report['floor_correction_max'], fix)
    # Leave and rejoin the relaxed carry pose so locomotion blends stay seamless.
    # Blend back only after the spin is complete, so the shortest rotation path
    # never unwinds the roll backwards.
    carry = max(1 - ease(u/.04), ease((u - .8)/.2))
    for bone in rig.pose.bones:
        parent = parents[bone.name]
        basis = rest[bone.name].inverted() @ (rest[parent] @ m[parent].inverted() if parent else Matrix.Identity(4)) @ m[bone.name]
        loc, rot, scale = basis.decompose()
        c_loc, c_rot, c_scale = carry_pose[bone.name]
        if rot.dot(c_rot) < 0: rot.negate()
        bone.rotation_mode = 'QUATERNION'
        bone.location = loc.lerp(c_loc, carry)
        bone.rotation_quaternion = rot.slerp(c_rot, carry)
        bone.scale = scale.lerp(c_scale, carry)
        for prop in ['location', 'rotation_quaternion', 'scale']:
            bone.keyframe_insert(prop, frame=frame, group=bone.name)
    if frame % 7 == 0:
        pts = skinned_points(m)
        lowest_point, lowest_bone = min(pts, key=lambda x: x[0].z)
        tucked = [x for x in skinned_points(roll_pose(t, False)) if not x[1].startswith('tail')]
        centroid = sum((p for p, _ in tucked), V((0, 0, 0))) / len(tucked)
        for i in range(60):
            far = max(tucked, key=lambda x: (x[0] - centroid).length)[0]
            centroid += (far - centroid) / (i + 2)
        radius = max((p - centroid).length for p, _ in tucked)
        far_bone = max(tucked, key=lambda x: (x[0] - centroid).length)[1]
        report['frames'].append({'t': t, 'lowest': round(low + fix, 4), 'lift': round(fix, 4),
                                 'lowest_bone': lowest_bone, 'ball_radius': round(radius, 3), 'farthest_bone': far_bone,
                                 'pelvis_z': round(m['pelvis'].translation.z, 3), 'head_z': round(m['head'].translation.z, 3)})
action.use_frame_range = True; action.frame_start = 0; action.frame_end = frames
action['duration_seconds'] = DURATION; action['in_place'] = True
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for curve in bag.fcurves:
                for key in curve.keyframe_points: key.interpolation = 'LINEAR'
rig.animation_data.action = bpy.data.actions['idle']; rig.animation_data.action_slot = rig.animation_data.action.slots[0]
s.frame_set(0); bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
(ROOT/'captures/panda_motion/dodge_roll_audit.json').write_text(json.dumps(report, indent=2))
print('DODGE_ROLL', json.dumps(report))
