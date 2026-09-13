"""Repair limb influence spill into belly/torso. Skin fields respect the anatomical silhouette."""
import bpy,sys,math
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character'];rig=c.objects['LanternPanda_Rig']
rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0);rig.data.pose_position='POSE'
bpy.data.libraries.write(str(ROOT/'assets/characters/red_panda/checkpoints/before_skin_repair.blend'),{s},fake_user=True)
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def weights(p,marking=False):
 x,y,z=p;side='L' if x<0 else 'R';upper=smooth(.23,.38,z);ws={'pelvis':1-upper,'torso':upper}
 if marking:return ws
 # Forelimbs are lateral and behind the front of the chest. Belly must never follow hands.
 boundary=.237 if z<.36 else .237-(z-.36)*.70
 amount=smooth(boundary-.008,boundary+.025,abs(x))*smooth(.205,.245,z)*(1-smooth(.091,.133,abs(y-.025)))
 if amount:
  hand=1-smooth(.275,.312,z);upperarm=smooth(.341,.399,z)
  aws={'arm_upper_'+side:upperarm,'forearm_'+side:(1-upperarm)*(1-hand),'hand_'+side:(1-upperarm)*hand}
  ws={n:w*(1-amount) for n,w in ws.items()}
  for n,w in aws.items():ws[n]=w*amount
 # Front belly and medial crotch stay on pelvis. Broad haunch blends only into their own leg.
 leg=(1-smooth(.145,.22,z))*smooth(.048,.105,abs(x))
 if z>.09:leg*=1-smooth(.083,.142,abs(y))
 if leg:
  foot=1-smooth(.048,.085,z);thigh=smooth(.09,.145,z)
  lw={'leg_'+side:thigh,'knee_'+side:(1-thigh)*(1-foot),'foot_'+side:(1-thigh)*foot}
  ws={n:w*(1-leg) for n,w in ws.items()}
  for n,w in lw.items():ws[n]=w*leg
 return ws
for name in ['Connected_Body','Belly_Marking']:
 obj=c.objects[name]
 for group in list(obj.vertex_groups):obj.vertex_groups.remove(group)
 groups={n:obj.vertex_groups.new(name=n) for n in rig.data.bones.keys()}
 for v in obj.data.vertices:
  ws=sorted([(n,w) for n,w in weights(v.co,name=='Belly_Marking').items() if w>.002],key=lambda item:-item[1])[:4];total=sum(w for n,w in ws)
  for n,w in ws:groups[n].add([v.index],w/total,'REPLACE')
# Cloth is carried by torso; a generous smooth shoulder envelope clears upper arms.
obj=c.objects['Teal_Cape']
for v in obj.data.vertices:
 if abs(v.co.x)>.20 and v.co.z>.375:
  v.co.x*=1.075;v.co.z+=.012
for group in list(obj.vertex_groups):obj.vertex_groups.remove(group)
groups={n:obj.vertex_groups.new(name=n) for n in ['torso','cape_L','cape_R','cape_back']}
for v in obj.data.vertices:
 x,y,z=v.co;w=.6*max(0,min(1,(.405-z)/.15));side='L' if x<0 else 'R';back=max(0,1-abs(x)/.13) if y<0 else 0
 groups['torso'].add([v.index],1-w,'REPLACE');groups['cape_'+side].add([v.index],w*(1-back),'REPLACE');groups['cape_back'].add([v.index],w*back,'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'skin':'bounded anatomical influence regions','marking':'pelvis/torso only','cape':'stable shoulder envelope'}
