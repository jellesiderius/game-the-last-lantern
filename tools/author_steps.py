"""Plant each foot for half its cycle; remap clip speed in Godot to match travel."""
import bpy,math
from mathutils import Vector,Quaternion
r=bpy.data.objects['Crow_Rig'];s=bpy.context.scene
def rotate(n,x=0,y=0,z=0):
 b=r.pose.bones[n];basis=b.bone.matrix_local.to_quaternion();q=Quaternion((0,0,1),z)@Quaternion((0,1,0),y)@Quaternion((1,0,0),x);b.rotation_quaternion=basis.inverted()@q@basis
for name,duration,stride in [('walk',.8,.15),('run',.55,.24)]:
 a=bpy.data.actions[name];r.animation_data.action=a
 for f in range(round(duration*100)+1):
  s.frame_set(f);u=f/(duration*100)
  running=name=='run';lean=.46 if running else .23
  rotate('torso',x=-lean-.025*math.sin(u*math.tau*2),y=.035*math.sin(u*math.tau))
  rotate('neck',x=lean*.18);rotate('head',x=lean*.25)
  rotate('wing_L',x=-.22+.10*math.sin(u*math.tau),y=.07)
  rotate('wing_R',x=-.22-.10*math.sin(u*math.tau),y=-.07)
  for bone_name in ['torso','neck','head','wing_L','wing_R']:
   r.pose.bones[bone_name].keyframe_insert('rotation_quaternion',frame=f,group=bone_name)
  for suffix,offset in [('L',0),('R',.5)]:
   phase=(u+offset)%1
   if phase<.5:
    y=stride*(1-4*phase);lift=0
   else:
    q=(phase-.5)*2;y=stride*(-1+2*(q*q*(3-2*q)));lift=(.065 if name=='walk' else .095)*math.sin(math.pi*q)
   leg=r.pose.bones['leg_'+suffix]
   leg.location=leg.bone.matrix_local.to_3x3().inverted()@Vector((0,y*.62,lift*.45))
   leg.keyframe_insert('location',frame=f,group=leg.name)
   bpy.context.view_layer.update()
   foot=r.pose.bones['foot_'+suffix];target=foot.bone.matrix_local.copy()
   target.translation.y+=y;target.translation.z+=lift
   foot.matrix=target
   foot.keyframe_insert('location',frame=f,group=foot.name);foot.keyframe_insert('rotation_quaternion',frame=f,group=foot.name)
 a['natural_ground_speed']=4*stride/duration
r.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath='/Users/jelle/Godot-Projects/crow-test/assets/characters/crow/source.blend')
result={'walk_natural_speed':.75,'run_natural_speed':4*.24/.55,'root':'unchanged'}
