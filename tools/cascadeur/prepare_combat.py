"""Blender -> Cascadeur exchange of existing combat poses and equipped panda.

Read-only with respect to source.blend/model.glb. Never runs historical generators.
"""
import json
from pathlib import Path
import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/characters/red_panda/cascadeur'
scene = bpy.data.scenes['LanternPanda_Production']
bpy.context.window.scene = scene
rig = bpy.data.objects['LanternPanda_Rig']
collection = bpy.data.collections['LanternPanda_Character']
FPS = 120
clips = ['idle', 'light_level_left', 'light_rising_right', 'light_falling_left',
         'light_level_right', 'light_rising_left', 'light_falling_right',
         'heavy_charge', 'heavy_release', 'heavy_release_charged', 'roll_attack']
bank = {}
for name in clips:
    action = bpy.data.actions[name]
    rig.animation_data.action = action
    rig.animation_data.action_slot = action.slots[0]
    duration = (action.frame_range.y - action.frame_range.x) / scene.render.fps
    count = round(duration * FPS)
    poses = []
    for frame in range(count + 1):
        time = frame / count * duration
        source_frame = time * scene.render.fps
        scene.frame_set(int(source_frame), subframe=source_frame % 1)
        bpy.context.view_layer.update()
        poses.append({b.name: [list(row) for row in b.matrix] for b in rig.pose.bones})
    bank[name] = {'duration': duration, 'frames': poses}
(OUT / 'combat_source_poses.json').write_text(json.dumps({'fps': FPS, 'clips': bank}))

rig.animation_data.action = bpy.data.actions['idle']
rig.animation_data.action_slot = rig.animation_data.action.slots[0]
scene.frame_set(0)
bpy.context.view_layer.update()
exchange = bpy.data.collections.new('Cascadeur_Equipment_Exchange')
scene.collection.children.link(exchange)
for preview, socket in [('Preview_sunblade', 'sword_socket'), ('Preview_hand_lantern', 'lantern_socket')]:
    src = bpy.data.objects[preview]
    assert src.type == 'MESH'
    obj = src.copy()
    obj.data = src.data.copy()
    obj.name = 'Cascadeur_' + preview.removeprefix('Preview_')
    obj.animation_data_clear()
    obj.parent = None
    obj.constraints.clear()
    obj.modifiers.clear()
    obj.vertex_groups.clear()
    # Existing preview geometry and accepted local roll, relocated to the rest socket.
    local_grip = rig.pose.bones[socket].matrix.inverted() @ src.matrix_world
    transform = rig.data.bones[socket].matrix_local @ local_grip
    obj.data.transform(transform)
    obj.matrix_world = Matrix.Identity(4)
    group = obj.vertex_groups.new(name=socket)
    group.add(list(range(len(obj.data.vertices))), 1., 'REPLACE')
    modifier = obj.modifiers.new('Follow_original_socket', 'ARMATURE')
    modifier.object = rig
    exchange.objects.link(obj)

rig.animation_data.action = None
rig.data.pose_position = 'REST'
for obj in bpy.data.objects:
    obj.select_set(False)
for obj in [*collection.all_objects, *exchange.objects]:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
scene.render.fps = 120
bpy.ops.export_scene.fbx(filepath=str(OUT / 'red_panda_equipped_rest.fbx'),
    use_selection=True, object_types={'ARMATURE', 'MESH'}, add_leaf_bones=False,
    bake_anim=False, axis_forward='-Z', axis_up='Y',
    use_armature_deform_only=False, mesh_smooth_type='FACE')
print('Prepared', len(bank), 'existing clips and original equipped character; source unchanged.')
