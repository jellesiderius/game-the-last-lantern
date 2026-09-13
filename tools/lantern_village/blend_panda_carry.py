"""Connect existing action starts/recoveries to the revised relaxed carry pose.
Reads the preserved pre-motion checkpoint for deterministic non-accumulating corrections.
Sword paths inside every active damage interval are untouched.
"""
import bpy,json,math
from pathlib import Path
from mathutils import Quaternion,Vector
ROOT=Path(__file__).resolve().parents[2]
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;r=bpy.data.objects['LanternPanda_Rig']
bones=['arm_upper_R','forearm_R','hand_R','fingers_R']
def sample(action,frame):
 r.animation_data.action=action;r.animation_data.action_slot=action.slots[0];s.frame_set(frame);bpy.context.view_layer.update()
 return {n:(r.pose.bones[n].location.copy(),r.pose.bones[n].rotation_quaternion.copy(),r.pose.bones[n].scale.copy()) for n in bones}
new=sample(bpy.data.actions['idle'],0)
# Import only Actions, never meshes. Original action names are restored on cleanup.
with bpy.data.libraries.load(str(ROOT/'assets/characters/red_panda/checkpoints/before_motion_20260913.blend'),link=False) as (src,dst):
 dst.actions=list(src.actions)
original={a.name.split('.')[0]:a for a in dst.actions}
old=sample(original['idle'],0)
# Fade lengths chosen to finish BEFORE each clip's active swing or bow release.
windows={
 'attack_1':(.055,.18),'attack_2':(.055,.20),'attack_3':(.085,.30),'attack_3_reverse':(.085,.30),
 'light_level_left':(.055,.22),'light_level_right':(.055,.22),'light_rising_left':(.055,.22),'light_rising_right':(.055,.22),'light_falling_left':(.055,.22),'light_falling_right':(.055,.22),
 'heavy_charge':(.10,None),'heavy_release':(None,.50),'heavy_release_charged':(None,.50),
 'roll_attack':(None,.34),'bow_equip':(.08,None),'bow_unequip':(None,.035),
 'hurt':(.035,.15),'dodge_roll':(.035,.35),'land':(None,.12)
}
report={}
for name,(start_fade,end_begin) in windows.items():
 source=original[name];values=[];end=int(source.frame_range[1]);duration=end/s.render.fps
 for f in range(end+1):values.append(sample(source,f))
 a=bpy.data.actions[name];r.animation_data.action=a;r.animation_data.action_slot=a.slots[0]
 changed=0
 for f,poses in enumerate(values):
  t=f/s.render.fps
  w=max((1-min(1,t/start_fade))**2 if start_fade else 0, min(1,max(0,(t-end_begin)/(duration-end_begin)))**2*(3-2*min(1,max(0,(t-end_begin)/(duration-end_begin)))) if end_begin is not None else 0)
  if w<=0:continue
  changed+=1
  for n,(pos,q,scale) in poses.items():
   b=r.pose.bones[n];b.rotation_mode='QUATERNION'
   correction=new[n][1]@old[n][1].inverted()
   b.rotation_quaternion=Quaternion().slerp(correction,w)@q
   b.keyframe_insert('rotation_quaternion',frame=f,group=n)
 report[name]={'changed_frames':changed,'start_fade_end':start_fade,'recovery_start':end_begin}
# Remove loaded checkpoint actions; source keeps the same named clips only.
r.animation_data.action=bpy.data.actions['idle'];r.animation_data.action_slot=r.animation_data.action.slots[0]
for a in dst.actions:bpy.data.actions.remove(a)
s.frame_set(0);bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
(ROOT/'captures/panda_motion/carry_blend_audit.json').write_text(json.dumps(report,indent=2))
print('CARRY_BLENDS',json.dumps(report))
