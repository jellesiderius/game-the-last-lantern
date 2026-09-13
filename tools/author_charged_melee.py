"""Add one charged finisher to the edited crow; preserve geometry and existing Actions."""
import bpy, ast, math, numpy as np
from math import sin, cos, pi
from mathutils import Vector, Matrix, Quaternion
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
scene=bpy.context.scene;rig=bpy.data.objects['Crow_Rig']
assert scene.name=='Crow_Production'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/crow/checkpoints/before_charged_finisher.blend'),copy=True)
assert bpy.data.actions.get('heavy_release_charged') is None, 'Inspect existing finisher before overwriting.'
# Reuse the established grip/foot coordinate contract, not the old destructive generator.
module=ast.parse((ROOT/'tools/author_combat.py').read_text())
functions=[node for node in module.body if isinstance(node,ast.FunctionDef)]
exec(compile(ast.Module(body=functions,type_ignores=[]),'established_pose_helpers','exec'))
a=bpy.data.actions.new('heavy_release_charged');a.use_fake_user=True;rig.animation_data.action=a
objects=[o for o in bpy.data.collections['Crow_Character'].objects if o.type=='MESH']
maxlift=0.
for frame in range(66):
 reset();t=frame/100
 if t<.16:
  k=smooth(t/.16)
  theta=mix(1.78,1.24,k);twist=mix(-.42,-.75,k);lean=mix(.10,-.10,k)
  crouch=mix(-.055,-.095,k);step=mix(-.07,-.12,k);energy=.7
 elif t<.32:
  k=smooth((t-.16)/.16)
  theta=mix(1.24,-1.24,k);twist=mix(-.75,.85,k);lean=mix(-.10,-.52,k)
  crouch=mix(-.095,-.07,k);step=mix(-.12,.16,k);energy=1.3
 else:
  k=smooth((t-.32)/.33)
  theta=-1.24-.10*sin(k*pi);twist=.85*(1-k);lean=-.52*(1-k)
  crouch=-.07*(1-k);step=.16*(1-k);energy=1.3*(1-k)
 carry(theta,1 if t<.32 else mix(1,.7,k),twist,lean,crouch,step,energy)
 bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();minimum=100
 for o in objects:
  ev=o.evaluated_get(dg);mesh=ev.to_mesh();xyz=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',xyz)
  mat=np.array(ev.matrix_world);z=xyz.reshape((-1,3))@mat[2,:3]+mat[2,3];minimum=min(minimum,float(z.min()));ev.to_mesh_clear()
 lift=max(0,.005-minimum);maxlift=max(maxlift,lift)
 rig.pose.bones['pelvis'].location+=rig.pose.bones['pelvis'].bone.matrix_local.to_3x3().inverted()@Vector((0,0,lift))
 for b in rig.pose.bones:
  b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
a['duration_seconds']=.65;a['in_place']=True;a['combat_notes']='Full-charge compression, forward cleave, planted catch and heavy recovery. Root fixed.'
rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/crow/source.blend'))
result={'new_action':a.name,'duration':.65,'floor_lift_max':maxlift,'mesh_changes':False}
