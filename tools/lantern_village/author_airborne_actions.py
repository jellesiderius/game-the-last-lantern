"""Add fall/landing Actions to the inspected panda; keep all meshes and prior clips."""
import ast, bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
rig=bpy.data.objects['LanternPanda_Rig'];c=bpy.data.collections['LanternPanda_Character']
checkpoint=ROOT/'assets/characters/red_panda/checkpoints/before_fall_body_follow_20260910.blend'
if not checkpoint.exists():bpy.data.libraries.write(str(checkpoint),{s},fake_user=True)
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths={b.name:b.length for b in rig.data.bones};V=Vector
source=ast.parse((ROOT/'tools/lantern_village/animate_character.py').read_text())
exec(compile(ast.Module(body=[n for n in source.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'pose_math','exec'))
samples=[]
for o in c.objects:
 if o.type!='MESH':continue
 for v in o.data.vertices:
  if v.index%max(1,len(o.data.vertices)//650) and v.co.z>.04:continue
  samples.append((v.co.copy(),[(o.vertex_groups[g.group].name,g.weight) for g in v.groups]))

def airborne_pose(clip,t,duration):
 u=t/duration;air=clip=='fall'
 load=1.0 if air else (ease(t/.045) if t<.045 else 1-ease((t-.045)/.175))
 base=T((0,0,-.045*load if not air else 0))
 lean=(.07+.02*math.sin(u*math.tau)) if air else .17*load
 body=base@pivot(RX(-lean),V((0,0,.25)))
 m=pose('idle',0,2.);m['root']=rest['root'].copy();m['pelvis']=base@rest['pelvis']
 for name in ['torso','neck','head','back_sword_socket','cape_L','cape_R','cape_back']:m[name]=body@rest[name]
 m['head']=body@pivot(RX(lean*.45),rest['head'].translation)@rest['head']
 for sign,side in [(-1,'L'),(1,'R')]:
  shoulder=rest['arm_upper_'+side].translation;elbow=rest['forearm_'+side].translation
  spread=(.33+.025*math.sin(u*math.tau)) if air else .14*load
  upper=body@pivot(Matrix.Rotation(-sign*spread,4,'Y')@RX(-.10),shoulder)
  lower=upper@pivot(RX(-.24 if air else -.10*load),elbow)
  m['arm_upper_'+side]=upper@rest['arm_upper_'+side]
  for name in ['forearm_'+side,'hand_'+side,'fingers_'+side]:m[name]=lower@rest[name]
  for name in ['sword_socket','bow_socket','bow_draw_socket','lantern_socket']:
   if parents.get(name)=='hand_'+side:m[name]=lower@rest[name]
  if air:
   upper_leg=base@pivot(RX(-.32-sign*.04),rest['leg_'+side].translation)
   lower_leg=upper_leg@pivot(RX(.72+sign*.06),rest['knee_'+side].translation)
   m['leg_'+side]=upper_leg@rest['leg_'+side];m['knee_'+side]=lower_leg@rest['knee_'+side]
   m['foot_'+side]=lower_leg@pivot(RX(-.12),rest['foot_'+side].translation)@rest['foot_'+side]
  else:
   hip=base@rest['leg_'+side].translation;ankle=rest['foot_'+side].translation.copy()
   knee,ankle=joint(hip,ankle,lengths['leg_'+side],lengths['knee_'+side],hip+V((sign*.02,.2,0)))
   m['leg_'+side]=aligned('leg_'+side,hip,knee);m['knee_'+side]=aligned('knee_'+side,knee,ankle)
   m['foot_'+side]=rest['foot_'+side].copy();m['foot_'+side].translation=ankle
 tail=base@pivot(RX(-.18 if air else -.07*load),V((0,-.13,.25)))
 for i,name in enumerate(['tail_01','tail_02','tail_03']):
  tail=tail@pivot(RZ(.025*math.sin(u*math.tau-i*.4)) if air else RZ(0),rest[name].translation)
  m[name]=tail@rest[name]
 return m

report={};rig.animation_data.action=None
for name,duration in [('fall',.6),('land',.22)]:
 old=bpy.data.actions.get(name)
 if old:bpy.data.actions.remove(old)
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
 low=10.;max_fix=0.
 for frame in range(round(duration*100)+1):
  m=airborne_pose(name,frame/100,duration)
  minimum,fix=ground(m);low=min(low,minimum+fix);max_fix=max(max_fix,fix)
  for bone in rig.pose.bones:
   parent=parents[bone.name]
   basis=rest[bone.name].inverted()@(rest[parent]@m[parent].inverted() if parent else Matrix.Identity(4))@m[bone.name]
   bone.rotation_mode='QUATERNION';bone.location,bone.rotation_quaternion,bone.scale=basis.decompose()
   for prop in ['location','rotation_quaternion','scale']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
  action.use_frame_range=True;action.frame_start=0;action.frame_end=duration*100
  action['duration_seconds']=duration;action['in_place']=True
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:key.interpolation='LINEAR'
 report[name]={'lowest_vertex_sample':low,'max_floor_correction':max_fix}
rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];s.frame_set(0);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
(ROOT/'captures/lantern_village/airborne_source_audit.json').write_text(json.dumps(report,indent=2))
result={'added_clips':report,'checkpoint':str(checkpoint)}
