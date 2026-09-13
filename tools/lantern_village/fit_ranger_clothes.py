"""Fit only the new outfit to the original chibi panda. Preserve reviewed head/body proportions."""
import bpy,sys,math,bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate,tube
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character'];rig=c.objects['LanternPanda_Rig'];rig.data.pose_position='REST'
rig.animation_data.action=bpy.data.actions.get('neutral');s.frame_set(0)
with bpy.data.libraries.load(str(ROOT/'assets/characters/red_panda/checkpoints/ranger_clothes_library.blend'),link=False) as (src,dst):dst.collections=['Ranger_Clothes_Transfer']
transfer=dst.collections[0]
landmarks=[(0,0),(.06,.039),(.205,.108),(.32,.191),(.414,.286),(.55,.363),(.674,.448),(.735,.52),(.80,.56)]
def height(z):
 for (a,x),(b,y) in zip(landmarks,landmarks[1:]):
  if z<=b:return x+(z-a)/(b-a)*(y-x)
 return .56+(z-.8)
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def torso_radius(z,angle):
 q=max(.12,math.sqrt(max(0,1-((z-.3)/.23)**2)))
 rx=.224*q;ry=.171*q
 if z>.405:
  neck=max(0,math.sqrt(max(0,1-((z-.49)/.125)**2)))
  rx=max(rx,.165*neck);ry=max(ry,.135*neck)
 return 1/math.sqrt((math.sin(angle)/rx)**2+(math.cos(angle)/ry)**2)
clothes=[]
for o in list(transfer.objects):
 if o.type!='MESH':continue
 c.objects.link(o);transfer.objects.unlink(o);o.parent=rig;clothes.append(o)
 for mod in list(o.modifiers):
  if mod.type=='ARMATURE':o.modifiers.remove(mod)
 region=o.get('skin_region','torso')
 limb=region not in ['torso','pelvis']
 for v in o.data.vertices:
  v.co.z=height(v.co.z);v.co.x*=.88 if limb else 1.0;v.co.y*=.85 if limb else 1.0
 # The shirt/jacket follow the original plump torso rather than widening it.
 if o.name.startswith(('Ochre_Shirt','Teal_Jacket','Leather_Belt')):
  offset=.004 if o.name.startswith('Ochre') else (.015 if o.name.startswith('Teal') else .025)
  for v in o.data.vertices:
   a=math.atan2(v.co.x,v.co.y);r=torso_radius(v.co.z,a)+offset
   v.co.x=math.sin(a)*r;v.co.y=math.cos(a)*r
 if o.name.startswith(('Buckle','Hip_Pouch','Pouch_','Chest_Pocket','Collar')):
  # Keep every accessory backed by the garment, not hanging off a guessed flat plane.
  for v in o.data.vertices:
   a=math.asin(max(-.99,min(.99,v.co.x/.224)))
   target=torso_radius(v.co.z,a)*math.cos(a)
   v.co.y=max(v.co.y,target+.018)
 for group in list(o.vertex_groups):o.vertex_groups.remove(group)
 groups={n:o.vertex_groups.new(name=n) for n in rig.data.bones.keys()}
 for v in o.data.vertices:
  z=v.co.z
  if region=='torso':
   w=smooth(.28,.43,z);ws={'pelvis':1-w,'torso':w}
  elif region=='pelvis':ws={'pelvis':1}
  else:
   part,side=region.rsplit('_',1)
   if part=='upper':
    w=smooth(.39,.47,z);ws={'torso':w,'arm_upper_'+side:1-w}
   elif part=='forearm':ws={'forearm_'+side:1}
   elif part=='hand':ws={'hand_'+side:1}
   elif part=='thigh':
    w=smooth(.16,.225,z);ws={'pelvis':w,'leg_'+side:1-w}
   elif part=='shin':
    w=smooth(.046,.070,z);ws={'knee_'+side:w,'foot_'+side:1-w}
   else:ws={'foot_'+side:1}
  for n,w in ws.items():
   if w>0:groups[n].add([v.index],w,'REPLACE')
 mod=o.modifiers.new('Outfit skin','ARMATURE');mod.object=rig
# Retain the full reviewed body as an editable unrendered fitting form outside the export collection.
backup=bpy.data.collections.new('Original_Body_Fitting_Form');s.collection.children.link(backup);backup.hide_render=True;backup.hide_viewport=True
body=c.objects['Connected_Body']
visible=body.copy();visible.data=body.data.copy();visible.name='Exposed_Forearms';c.objects.link(visible)
bm=bmesh.new();bm.from_mesh(visible.data)
remove=[v for v in bm.verts if not(abs(v.co.x)>.212 and .30<v.co.z<.395)]
bmesh.ops.delete(bm,geom=remove,context='VERTS');bm.to_mesh(visible.data);bm.free();visible['skin_region']='arm_skin'
for name in ['Connected_Body','Belly_Marking','Teal_Cape']:
 o=c.objects.get(name)
 if o:c.objects.unlink(o);backup.objects.link(o)
# Shoulder sleeves have rounded roots embedded under the jacket instead of upright pipe openings.
for side in ['L','R']:
 o=next(o for o in clothes if o.name=='Sleeve_'+side)
 sign=-1 if side=='L' else 1
 for v in o.data.vertices:
  if v.co.z>.438:
   amount=smooth(.438,.49,v.co.z);v.co.z-=.035*amount;v.co.x-=sign*.033*amount
 # Close the narrow orange seam between sleeve and rolled cuff.
 cuff=next(o for o in clothes if o.name=='Sleeve_Cuff_'+side)
 for v in cuff.data.vertices:v.co.z+=.011
# Animation evaluation is restored later; leave the reviewed original silhouette visible in neutral.
rig.data.pose_position='REST'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'outfit_meshes':len(clothes),'body_shape':'original chibi','head_unchanged':True}
