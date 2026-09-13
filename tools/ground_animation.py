"""Bake mesh-based ground clearance into pelvis, leaving root and collider fixed."""
import bpy, numpy as np, json
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
r=bpy.data.objects['Crow_Rig'];s=bpy.context.scene
objects=[o for o in bpy.data.collections['Crow_Character'].objects if o.type=='MESH']
report={}
for name in ['walk','run','dodge_roll','death']:
 a=bpy.data.actions[name];r.animation_data.action=a
 rows=[]
 for frame in range(int(round(a['duration_seconds']*100))+1):
  s.frame_set(frame);dg=bpy.context.evaluated_depsgraph_get();minimum=100
  for o in objects:
   ev=o.evaluated_get(dg);mesh=ev.to_mesh();arr=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',arr);arr=arr.reshape((-1,3))
   mat=np.array(ev.matrix_world);z=(arr@mat[2,:3])+mat[2,3]
   minimum=min(minimum,float(z.min()));ev.to_mesh_clear()
  if name in ['dodge_roll','death']:
   m=r.pose.bones['back_sword_socket'].matrix
   minimum=min(minimum,(m@Vector((0,.86,0))).z)
  lift=max(0,.005-minimum)
  if lift>0.00001:
   p=r.pose.bones['pelvis'];p.location+=p.bone.matrix_local.to_3x3().inverted()@Vector((0,0,lift));p.keyframe_insert('location',frame=frame,group=p.name)
  rows.append({'t':frame/100,'min_before':minimum,'pelvis_correction':lift})
 report[name]={'max_correction':max(x['pelvis_correction'] for x in rows),'samples':rows}
r.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
(ROOT/'captures/animation_floor_audit.json').write_text(json.dumps(report,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/crow/source.blend'))
result={name:{'max_floor_correction_m':data['max_correction']} for name,data in report.items()}
