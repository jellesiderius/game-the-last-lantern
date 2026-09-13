"""Add one refusal Action to the current crow rig; preserve all meshes and other clips."""
import math
import shutil
from pathlib import Path

import bpy
from mathutils import Quaternion

ROOT = Path('/Users/jelle/Godot-Projects/crow-test')
scene = bpy.context.scene
rig = bpy.data.objects['Crow_Rig']
assert scene.name == 'Crow_Production' and scene.render.fps == 100
assert bpy.context.mode == 'OBJECT'
source = ROOT / 'assets/characters/crow/source.blend'
checkpoint = ROOT / 'assets/characters/crow/checkpoints/crow_before_bow_empty.blend'
if not checkpoint.exists():
    shutil.copy2(source, checkpoint)

# Sample the accepted idle pose. No retargeting, new bones or geometry edits.
rig.animation_data.action = bpy.data.actions['idle']
scene.frame_set(0)
neutral = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy())
           for b in rig.pose.bones}
rig.animation_data.action = None
old = bpy.data.actions.get('bow_empty')
if old:
    bpy.data.actions.remove(old)
action = bpy.data.actions.new('bow_empty')
action.use_fake_user = True
rig.animation_data.action = action


def turn(name, axis, angle):
    bone = rig.pose.bones[name]
    basis = bone.bone.matrix_local.to_quaternion()
    bone.rotation_quaternion = neutral[name][1] @ basis.inverted() @ Quaternion(axis, angle) @ basis


for frame in range(33):
    t = frame / 100.0
    u = t / .32
    # Fast recoiling shrug, then a relaxed return. Feet/root remain planted.
    pulse = math.sin(math.pi * u) ** 1.4
    shake = math.sin(math.tau * u) * math.sin(math.pi * u)
    for bone in rig.pose.bones:
        loc, rot, scale = neutral[bone.name]
        bone.location, bone.rotation_quaternion, bone.scale = loc, rot, scale
    turn('torso', (1, 0, 0), .11 * pulse)
    turn('neck', (1, 0, 0), -.05 * pulse)
    turn('head', (0, 0, 1), .24 * shake)
    turn('wing_L', (0, 1, 0), .38 * pulse)
    turn('wing_R', (0, 1, 0), -.38 * pulse)
    for bone in rig.pose.bones:
        for channel in ('location', 'rotation_quaternion', 'scale'):
            bone.keyframe_insert(channel, frame=frame, group=bone.name)

action['duration_seconds'] = .32
action['in_place'] = True
rig.animation_data.action = bpy.data.actions['idle']
scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
result = {'action': action.name, 'duration': .32, 'checkpoint': str(checkpoint),
          'meshes': 'unchanged', 'actions': [a.name for a in bpy.data.actions]}
