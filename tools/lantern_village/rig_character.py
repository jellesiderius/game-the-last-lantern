"""Bind the compact lantern panda to its own measured limb lengths, with reusable socket names."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character']
assert not c.objects.get('LanternPanda_Rig')
bpy.data.libraries.write(str(ROOT/'assets/characters/red_panda/checkpoints/lantern_reviewed_neutral.blend'),{s},fake_user=True)
arm=bpy.data.armatures.new('LanternPanda_Skeleton');rig=bpy.data.objects.new('LanternPanda_Rig',arm);c.objects.link(rig);activate(rig);rig.show_in_front=True
bpy.ops.object.mode_set(mode='EDIT')
def bone(name,head,tail,parent=None):
 b=arm.edit_bones.new(name);b.head=head;b.tail=tail
 if parent:b.parent=arm.edit_bones[parent]
 return b
bone('root',(0,0,0),(0,0,.10));bone('pelvis',(0,0,.20),(0,0,.30),'root');bone('torso',(0,0,.30),(0,0,.455),'pelvis');bone('neck',(0,0,.455),(0,0,.52),'torso');bone('head',(0,0,.52),(0,0,.95),'neck')
for sign,side in [(-1,'L'),(1,'R')]:
 bone('arm_upper_'+side,(sign*.173,0,.448),(sign*.235,.01,.363),'torso')
 bone('forearm_'+side,(sign*.235,.01,.363),(sign*.278,.039,.286),'arm_upper_'+side)
 bone('hand_'+side,(sign*.278,.039,.286),(sign*.279,.058,.25),'forearm_'+side)
 bone('fingers_'+side,(sign*.279,.058,.25),(sign*.279,.070,.234),'hand_'+side)
 bone('leg_'+side,(sign*.12,-.012,.191),(sign*.133,.005,.108),'pelvis')
 bone('knee_'+side,(sign*.133,.005,.108),(sign*.134,.024,.039),'leg_'+side)
 bone('foot_'+side,(sign*.134,.024,.039),(sign*.134,.099,.025),'knee_'+side)
bone('sword_socket',(.263,.075,.27),(.263,.175,.27),'hand_R')
bone('bow_socket',(-.263,.075,.27),(-.263,.175,.27),'hand_L')
bone('bow_draw_socket',(.263,.075,.27),(.263,.175,.27),'hand_R')
bone('lantern_socket',(-.284,.085,.28),(-.284,.085,.38),'hand_L')
back=bone('back_sword_socket',(0,-.23,.49),(0,-.23,.38),'torso');back.roll=math.pi/2
bone('tail_01',(0,-.13,.25),(-.025,-.30,.25),'pelvis');bone('tail_02',(-.025,-.30,.25),(-.065,-.50,.29),'tail_01');bone('tail_03',(-.065,-.50,.29),(-.09,-.71,.365),'tail_02')
bpy.ops.object.mode_set(mode='OBJECT')
for b in arm.bones:b.use_deform=b.name!='root' and 'socket' not in b.name
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
segments={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in arm.bones}
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def segdist(p,a,b):
 d=b-a;t=max(0,min(1,(p-a).dot(d)/d.length_squared));return (p-a-d*t).length
def limb(p,names,falloff):
 ds={n:math.exp(-min(100,(segdist(p,*segments[n])/falloff)**2)) for n in names};total=sum(ds.values());return {n:w/total for n,w in ds.items()}
def bodyweights(p):
 x,y,z=p;side='L' if x<0 else 'R';upper=smooth(.21,.41,z);ws={'pelvis':1-upper,'torso':upper}
 if z>.435:
  neck=smooth(.435,.51,z);ws={n:w*(1-neck) for n,w in ws.items()};ws['neck']=neck
 arms=smooth(.204,.24,abs(x))*smooth(.195,.24,z)
 if arms:
  aws=limb(p,['arm_upper_'+side,'forearm_'+side,'hand_'+side],.043)
  ws={n:w*(1-arms) for n,w in ws.items()}
  for n,w in aws.items():ws[n]=w*arms
 legs=(1-smooth(.13,.205,z))*smooth(.04,.085,abs(x))
 if legs:
  lw=limb(p,['leg_'+side,'knee_'+side,'foot_'+side],.04) if z>.061 else {'foot_'+side:1.}
  ws={n:w*(1-legs) for n,w in ws.items()}
  for n,w in lw.items():ws[n]=w*legs
 return ws
for o in c.objects:
 if o.type!='MESH':continue
 o.parent=rig;groups={n:o.vertex_groups.new(name=n) for n in segments}
 for v in o.data.vertices:
  region=o.get('skin_region','head')
  if region=='body':ws=bodyweights(v.co)
  elif region=='tail':ws=limb(v.co,['tail_01','tail_02','tail_03'],.09)
  elif region=='cape':ws={'torso':1.}
  else:ws={'head':1.}
  ws=sorted([(n,w) for n,w in ws.items() if w>.005],key=lambda nw:-nw[1])[:4];total=sum(w for n,w in ws)
  for n,w in ws:groups[n].add([v.index],w/total,'REPLACE')
 mod=o.modifiers.new('Character skin','ARMATURE');mod.object=rig
s.render.fps=100;bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'rig':rig.name,'bones':len(arm.bones)}
