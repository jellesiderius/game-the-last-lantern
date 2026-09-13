"""Bind the reviewed red panda source. Dedicated limb dimensions, fixed root and tail chain."""
import bpy, math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate
s=bpy.data.scenes['RedPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['RedPanda_Character']
assert not bpy.data.objects.get('RedPanda_Rig'),'Do not overwrite an authored rig.'
bpy.data.libraries.write(str(ROOT/'assets/characters/red_panda/checkpoints/neutral_reviewed.blend'),{s},fake_user=True)
arm=bpy.data.armatures.new('RedPanda_Skeleton');rig=bpy.data.objects.new('RedPanda_Rig',arm);c.objects.link(rig);activate(rig);rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
 b=arm.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=arm.edit_bones[parent]
 return b
bone('root',(0,0,0),(0,0,.10));bone('pelvis',(0,0,.30),(0,0,.43),'root')
bone('torso',(0,0,.43),(0,0,.68),'pelvis');bone('neck',(0,0,.68),(0,0,.77),'torso');bone('head',(0,0,.77),(0,0,1.04),'neck')
for sign,side in [(-1,'L'),(1,'R')]:
 bone('arm_upper_'+side,(sign*.163,0,.681),(sign*.280,.005,.536),'torso')
 bone('forearm_'+side,(sign*.280,.005,.536),(sign*.339,.025,.381),'arm_upper_'+side)
 bone('hand_'+side,(sign*.339,.025,.381),(sign*.341,.029,.309),'forearm_'+side)
 bone('fingers_'+side,(sign*.347,.030,.327),(sign*.342,.030,.278),'hand_'+side)
 bone('leg_'+side,(sign*.112,-.008,.288),(sign*.163,.012,.161),'pelvis')
 bone('knee_'+side,(sign*.163,.012,.161),(sign*.188,.019,.061),'leg_'+side)
 bone('foot_'+side,(sign*.188,.019,.061),(sign*.188,.132,.029),'knee_'+side)
bone('sword_socket',(.318,.030,.323),(.318,.150,.323),'hand_R')
back=bone('back_sword_socket',(0,-.226,.90),(0,-.254,.78),'torso');back.roll=math.pi/2
bone('bow_socket',(-.318,.030,.323),(-.318,.150,.323),'hand_L')
bone('bow_draw_socket',(.318,.030,.323),(.318,.150,.323),'hand_R')
bone('tail_01',(0,-.133,.325),(-.067,-.390,.33),'pelvis')
bone('tail_02',(-.067,-.390,.33),(-.180,-.640,.37),'tail_01')
bone('tail_03',(-.180,-.640,.37),(-.226,-.906,.555),'tail_02')
bpy.ops.object.mode_set(mode='OBJECT')
for b in arm.bones:b.use_deform=b.name!='root' and 'socket' not in b.name
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
segments={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in arm.bones}
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def segdist(p,a,b):
 ab=b-a;t=max(0,min(1,(p-a).dot(ab)/ab.length_squared));return (p-a-ab*t).length
def limb(p,names,falloff=.07):
 vals={name:math.exp(-min(100,(segdist(p,*segments[name])/falloff)**2)) for name in names}
 total=sum(vals.values());return {name:v/total for name,v in vals.items()}
def weights(p):
 x,y,z=p;side='L' if x<0 else 'R';torso=smooth(.31,.59,z);values={'pelvis':1-torso,'torso':torso}
 if z>.65:
  n=smooth(.65,.77,z);values={k:v*(1-n) for k,v in values.items()};values['neck']=n
 boundary=.22 if z<.58 else .22-(z-.58)*.65
 arms=smooth(boundary+.005,boundary+.052,abs(x))*smooth(.245,.33,z)
 if arms:
  bones=['arm_upper_'+side,'forearm_'+side,'hand_'+side]
  armw=limb(p,bones,.068)
  if z<.32:
   finger=smooth(.32,.285,z)*smooth(.30,.331,abs(x))
   armw={k:v*(1-finger) for k,v in armw.items()};armw['fingers_'+side]=finger
  values={k:v*(1-arms) for k,v in values.items()}
  for k,v in armw.items():values[k]=v*arms
 legs=(1-smooth(.19,.29,z))*smooth(.045,.10,abs(x))
 if legs:
  lw=limb(p,['leg_'+side,'knee_'+side,'foot_'+side],.055) if z>.066 else {'foot_'+side:1.}
  values={k:v*(1-legs) for k,v in values.items()}
  for k,v in lw.items():values[k]=v*legs
 return values
for obj in c.objects:
 if obj.type!='MESH':continue
 obj.parent=rig;groups={name:obj.vertex_groups.new(name=name) for name in segments}
 region=obj.get('skin_region','head')
 for v in obj.data.vertices:
  if region=='body':ws=weights(v.co)
  elif region=='tail':ws=limb(v.co,['tail_01','tail_02','tail_03'],.12)
  else:ws={'head':1.}
  ws=sorted([(n,w) for n,w in ws.items() if w>.004],key=lambda item:-item[1])[:4];total=sum(w for n,w in ws)
  for name,w in ws:groups[name].add([v.index],w/total,'REPLACE')
  # Remove empty groups only after binding all vertex indices; stable group IDs during mutation.
 mod=obj.modifiers.new('Character skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=True
s.render.fps=100;s.view_settings.exposure=-.65
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'source':bpy.data.filepath,'bones':len(arm.bones),'vertices':sum(len(o.data.vertices) for o in c.objects if o.type=='MESH')}
