"""Rig the reviewed neutral capybara; fixed root, smooth limb weights, rigid face.
The source is checkpointed. This is not a crow retarget or a destructive crow generator.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
c=bpy.data.collections['Capybara_Character'];body=c.objects['Capybara_Body']
assert not bpy.data.objects.get('Capybara_Rig'), 'Rig already exists; edit it, do not rebuild.'
bpy.data.libraries.write(str(ROOT/'assets/characters/capybara/checkpoints/neutral_reviewed.blend'),{s},fake_user=True)
if bpy.context.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
for o in bpy.context.selected_objects:o.select_set(False)
for o in c.objects:
 if o.type!='MESH':continue
 o.select_set(True);bpy.context.view_layer.objects.active=o
 modifier=o.modifiers.new('Game topology reduction','DECIMATE');modifier.ratio=.12 if o==body else .35
 bpy.ops.object.modifier_apply(modifier=modifier.name)
 for p in o.data.polygons:p.use_smooth=True
 o.select_set(False)
arm=bpy.data.armatures.new('Capybara_Skeleton');rig=bpy.data.objects.new('Capybara_Rig',arm);c.objects.link(rig)
rig.show_in_front=True;rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
 b=arm.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=arm.edit_bones[parent]
 return b
bone('root',(0,0,0),(0,0,.15))
bone('pelvis',(0,0,.48),(0,0,.60),'root')
bone('torso',(0,0,.60),(0,0,1.05),'pelvis')
bone('neck',(0,0,1.05),(0,0,1.22),'torso')
bone('head',(0,0,1.22),(0,.12,1.44),'neck')
for sign,side in [(-1,'L'),(1,'R')]:
 bone('arm_upper_'+side,(sign*.275,0,1.0),(sign*.433,.008,.80),'torso')
 bone('forearm_'+side,(sign*.433,.008,.80),(sign*.54,.025,.58),'arm_upper_'+side)
 bone('hand_'+side,(sign*.54,.025,.58),(sign*.554,.073,.49),'forearm_'+side)
 bone('fingers_'+side,(sign*.558,.031,.53),(sign*.558,.073,.44),'hand_'+side)
 bone('leg_'+side,(sign*.18,0,.435),(sign*.226,.016,.24),'pelvis')
 bone('knee_'+side,(sign*.226,.016,.24),(sign*.245,.03,.105),'leg_'+side)
 bone('foot_'+side,(sign*.245,.03,.105),(sign*.245,.19,.064),'knee_'+side)
# Attachment Y axes point along the associated weapon; Godot wrapper maps weapon -Z to socket +Y.
grip=Vector((.552,.078,.52));direction=Vector((.8,.18,-.57)).normalized()
bone('sword_socket',grip,grip+direction*.12,'hand_R')
bone('back_sword_socket',(0,-.245,1.04),(0,-.245,.92),'torso')
bone('bow_socket',(-.552,.078,.52),(-.552,.198,.52),'hand_L')
bone('bow_draw_socket',(.552,.078,.52),(.552,.198,.52),'hand_R')
bpy.ops.object.mode_set(mode='OBJECT')
for b in rig.pose.bones:b.rotation_mode='QUATERNION'

def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def segdist(p,a,b):
 ab=b-a;t=max(0,min(1,(p-a).dot(ab)/ab.length_squared));return (p-a-ab*t).length
segments={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in arm.bones}
def limb_weights(p,names):
 values={name:math.exp(-(segdist(p,*segments[name])/.11)**2) for name in names}
 total=sum(values.values());return {name:v/total for name,v in values.items()} if total>.000001 else {names[0]:1.0}
def body_weights(p):
 x,y,z=p;side='L' if x<0 else 'R'
 if z>1.23:return {'head':1.0}
 if z>1.12:
  t=smooth(1.12,1.23,z);return {'neck':1-t,'head':t}
 torso=smooth(.50,.90,z);weights={'pelvis':1-torso,'torso':torso}
 if z>1.02:
  n=smooth(1.02,1.15,z);weights={k:v*(1-n) for k,v in weights.items()};weights['neck']=n
 boundary=.343 if z<.8 else .343-(min(z,1.08)-.8)*.34
 arm_mix=smooth(boundary+.005,boundary+.085,abs(x))*smooth(.40,.48,z)
 if arm_mix>0:
  limb=limb_weights(p,['arm_upper_'+side,'forearm_'+side,'hand_'+side])
  weights={k:v*(1-arm_mix) for k,v in weights.items()}
  for k,v in limb.items():weights[k]=v*arm_mix
 leg_mix=(1-smooth(.26,.46,z))*smooth(.05,.15,abs(x))
 if leg_mix>0:
  limb=limb_weights(p,['leg_'+side,'knee_'+side,'foot_'+side]) if z>.09 else {'foot_'+side:1.0}
  weights={k:v*(1-leg_mix) for k,v in weights.items()}
  for k,v in limb.items():weights[k]=v*leg_mix
 return weights
for o in list(c.objects):
 if o.type!='MESH':continue
 o.parent=rig
 groups={name:o.vertex_groups.new(name=name) for name in segments}
 region=o.get('skin_region','')
 if o.name.startswith('Finger_'):region='fingers_'+o.name.split('_')[1][0]
 for v in o.data.vertices:
  weights=body_weights(v.co) if o==body else {region or 'head':1.0}
  weights=sorted([(k,w) for k,w in weights.items() if w>.005],key=lambda x:-x[1])[:4]
  total=sum(w for _,w in weights)
  for name,w in weights:groups[name].add([v.index],w/total,'REPLACE')
 mod=o.modifiers.new('Character skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
body['rig_review']='Continuous mesh; max four normalized weights. Face details rigid to head.'
s.render.fps=100;s.frame_start=0;s.frame_end=200
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/capybara/source.blend'))
result={'bones':len(arm.bones),'body_vertices':len(body.data.vertices),'all_vertices':sum(len(o.data.vertices) for o in c.objects if o.type=='MESH'),'source':bpy.data.filepath}
