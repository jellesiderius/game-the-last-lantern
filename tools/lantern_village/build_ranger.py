"""Reference revision: fitted ranger jacket and taller limbs, preserving the reviewed face mesh.
This is a one-time revision of the checkpointed cape source, not a routine export.
"""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character'];rig=c.objects['LanternPanda_Rig']
rig.data.pose_position='REST';rig.animation_data.action=None
for a in list(bpy.data.actions):bpy.data.actions.remove(a)
# Delete replaced clothes/body only. Face, ears, rigid markings and smooth banded tail are retained.
for name in ['Connected_Body','Belly_Marking','Teal_Cape']:
 if c.objects.get(name):bpy.data.objects.remove(c.objects[name],do_unlink=True)
M={n:bpy.data.materials.get('LanternPanda_'+n) for n in ['Coat','Cream','Eyes','Nose','EarInner']}
M.update({n:material('Ranger_'+n,col,rough,metal) for n,col,rough,metal in [('Jacket',(.19,.35,.37),.82,0),('Shirt',(.82,.53,.19),.86,0),('Leather',(.29,.19,.135),.77,0),('LeatherEdge',(.36,.235,.15),.75,0),('Gold',(.74,.49,.17),.38,.65)]})
# Head now occupies ~43% of standing height, with the broad flared cheek outline in the new sheet.
def headmap(p):
 x,y,z=p;flare=1+.07*math.exp(-((z-.62)/.10)**2)
 return Vector((x*.90*flare,y*.94,.73+(z-.49)*.85))
for o in list(c.objects):
 if o.type!='MESH' or o.get('skin_region')=='tail':continue
 for mod in list(o.modifiers):
  if mod.type=='ARMATURE':o.modifiers.remove(mod)
 o.parent=None
 for v in o.data.vertices:v.co=headmap(v.co)
# Brow tilt is mirrored, fitted back onto the transformed head surface afterwards.
head=c.objects['Head'];bvh=BVHTree.FromPolygons([v.co for v in head.data.vertices],[list(p.vertices) for p in head.data.polygons])
for sign,side in [(-1,'L'),(1,'R')]:
 brow=c.objects['Brow_'+side];center=sum((v.co for v in brow.data.vertices),Vector())/len(brow.data.vertices)
 for v in brow.data.vertices:
  q=v.co-center;q=Matrix.Rotation(-sign*.38,3,'Y')@q;v.co=center+q
  hit=bvh.ray_cast(Vector((v.co.x,1,v.co.z)),Vector((0,-1,0)))
  if hit[0]:v.co.y=hit[0].y+.003
 # A small sloping upper eyelid reinforces the determined expression.
 pts=[]
 for i in range(8):
  u=i/7;x=sign*(.106+.091*u);z=.964+.026*u;hit=bvh.ray_cast(Vector((x,1,z)),Vector((0,-1,0)))
  pts.append((x,hit[0].y+.003 if hit[0] else .26,z,.0035))
 o=tube('Upper_Lid_'+side,pts,c,M['Nose'],8,1);o['skin_region']='head'
# Closed mouth lies on the actual muzzle, never floating in front of it.
m=c.objects['Muzzle'];bvh_m=BVHTree.FromPolygons([v.co for v in m.data.vertices],[list(p.vertices) for p in m.data.polygons])
for i,coords in enumerate([[(0,.878),(0,.84)],[(-.033,.822),(0,.84),(.033,.822)]]):
 pts=[]
 for x,z in coords:
  hit=bvh_m.ray_cast(Vector((x,1,z)),Vector((0,-1,0)));pts.append((x,hit[0].y+.001 if hit[0] else .32,z,.0025))
 o=tube('Closed_Mouth_'+str(i),pts,c,M['Nose'],8,5);o['skin_region']='head'
# Tail bands remain continuous; darker rust replaces the pale bands in this reference.
tail=c.objects['Ringed_Tail'];tail.parent=None
for mod in list(tail.modifiers):
 if mod.type=='ARMATURE':tail.modifiers.remove(mod)
for v in tail.data.vertices:
 v.co.x*=1.05;v.co.y*=1.10;v.co.z=.26+(v.co.z-.25)*.90
rust=material('Ranger_Tail_Rust',(.56,.23,.105),.8);tail.data.materials[1]=rust
M['EarInner'].diffuse_color=(*linear_color((.32,.16,.10)),1);M['EarInner'].node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=M['EarInner'].diffuse_color

def ell(name,pos,scale,mat,region,segs=40,rings=24):
 o=ellipsoid(name,pos,scale,c,M[mat],segs,rings);o['skin_region']=region;return o
def rounded(name,pos,size,mat,region,bevel=.008):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=True,rotation=False,scale=True)
 for col in list(o.users_collection):col.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(M[mat]);activate(o)
 mod=o.modifiers.new('Rounded leather edges','BEVEL');mod.width=bevel;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 for p in o.data.polygons:p.use_smooth=True
 o['skin_region']=region;return o
# Upper body / shirt is one calm volume, kept separate from moving limb skin regions.
shirt=loft('Ochre_Shirt',[(.30,.14,.11,0),(.34,.215,.15,0),(.43,.221,.15,0),(.59,.195,.145,0),(.72,.154,.12,0),(.748,.135,.11,0)],c,M['Shirt'],64,5,2.2);shirt['skin_region']='torso'
# Jacket shell opens at the front; sleeves cover the arm-root overlap and share arm weights.
verts=[];faces=[];N=92;R=20
for j in range(R):
 t=j/(R-1);z=.326+t*.409;rx=.23-.063*t;ry=.167-.037*t
 for i in range(N+1):
  a=.42+i*(math.tau-.84)/N
  hem_raise=.014*math.cos(a*2)*(1-t)**5
  verts.append((rx*math.sin(a),ry*math.cos(a),z+hem_raise))
for j in range(R-1):
 for i in range(N):a=j*(N+1)+i;faces.append((a,a+1,a+N+2,a+N+1))
jacket=mesh_object('Teal_Jacket',verts,faces,c,M['Jacket']);jacket['skin_region']='torso';activate(jacket)
mod=jacket.modifiers.new('Jacket thickness','SOLIDIFY');mod.thickness=.014;mod.offset=1;bpy.ops.object.modifier_apply(modifier=mod.name)
mod=jacket.modifiers.new('Tailored edge','BEVEL');mod.width=.006;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
for sign,side in [(-1,'L'),(1,'R')]:
 # Fitted short sleeve overlaps upper arm all around the shoulder.
 a=Vector((sign*.178,0,.677));b=Vector((sign*.247,.012,.582))
 sleeve=tube('Sleeve_'+side,[(*a,.097),(*(a.lerp(b,.5)),.091),(*b,.078)],c,M['Jacket'],40,6);sleeve['skin_region']='upper_'+side
 cuff=tube('Sleeve_Cuff_'+side,[(*(b+Vector((0,0,.008))),.081),(*(b+Vector((sign*.007,0,-.013))),.078)],c,M['Jacket'],40,2);cuff['skin_region']='upper_'+side
 arm=tube('Arm_'+side,[(sign*.184,0,.67,.074),(sign*.265,.014,.55,.068),(sign*.314,.052,.421,.055)],c,M['Coat'],40,8);arm['skin_region']='arm_'+side
 # Anatomical mitt with three curled fingers and a distinct inward thumb, inside leather glove.
 parts=[ell('GlovePalm_'+side,(sign*.317,.057,.405),(.057,.05,.069),'Leather','hand_'+side)]
 for i in range(3):parts.append(ell('GloveFinger',(sign*(.292+i*.019),.079,.373),(.016,.031,.032),'Leather','hand_'+side,24,16))
 parts.append(ell('GloveThumb',(sign*.278,.085,.416),(.029,.032,.036),'Leather','hand_'+side,24,16))
 glove=fuse(parts,'Glove_'+side,.0028,3,.5);glove['skin_region']='hand_'+side
 for k in range(2):
  z=.464+k*.023;o=tube('Glove_Cuff_'+side+str(k),[(sign*(.30-k*.009),.042,z,.065),(sign*(.295-k*.009),.038,z+.018,.065)],c,M['LeatherEdge'],32,2);o['skin_region']='forearm_'+side
 # Short trouser leg is bound to the thigh; top overlaps under the belt.
 leg=tube('Trouser_'+side,[(sign*.112,0,.36,.116),(sign*.125,.003,.28,.115),(sign*.145,.007,.205,.085)],c,M['Coat'],40,8);leg['skin_region']='thigh_'+side
 shin=tube('Boot_Shin_'+side,[(sign*.145,.007,.216,.071),(sign*.15,.012,.119,.067),(sign*.15,.02,.061,.068)],c,M['Leather'],32,6);shin['skin_region']='shin_'+side
 foot=ell('Boot_Foot_'+side,(sign*.15,.055,.041),(.078,.113,.044),'Leather','foot_'+side)
 for k in range(3):
  z=.09+k*.037;o=tube('Leg_Wrap_'+side+str(k),[(sign*.15,.013,z,.072),(sign*.15,.013,z+.016,.073)],c,M['LeatherEdge'],32,2);o['skin_region']='shin_'+side
 # Collar points lie against the neckline and front chest.
 pts=[(sign*.07,.143,.735),(sign*.162,.112,.742),(sign*.174,.126,.69),(sign*.107,.158,.672)]
 o=mesh_object('Collar_'+side,pts,[(0,1,2,3)],c,M['Jacket']);o['skin_region']='torso';activate(o);mod=o.modifiers.new('Collar thickness','SOLIDIFY');mod.thickness=.018;bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('Collar rounding','BEVEL');mod.width=.008;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
 pocket=rounded('Chest_Pocket_'+side,(sign*.145,.139,.568),(.055,.013,.065),'Jacket','torso',.008)
# Belt follows the torso contour, pouch hangs on the left hip.
verts=[];faces=[];N=96
for z in [.393,.446]:
 for i in range(N):a=i*math.tau/N;verts.append((.234*math.sin(a),.17*math.cos(a),z))
for i in range(N):faces.append((i,(i+1)%N,(i+1)%N+N,i+N))
belt=mesh_object('Leather_Belt',verts,faces,c,M['Leather']);belt['skin_region']='pelvis';activate(belt);mod=belt.modifiers.new('Belt thickness','SOLIDIFY');mod.thickness=.012;bpy.ops.object.modifier_apply(modifier=mod.name)
for pos,size in [((-.032,.183,.42),(.012,.015,.052)),((.032,.183,.42),(.012,.015,.052)),((0,.183,.446),(.065,.015,.009)),((0,.183,.394),(.065,.015,.009))]:rounded('Buckle',pos,size,'Gold','pelvis',.003)
rounded('Hip_Pouch',(-.183,.148,.393),(.087,.057,.132),'Leather','pelvis',.015)
rounded('Pouch_Flap',(-.183,.181,.426),(.09,.014,.049),'LeatherEdge','pelvis',.009)
ell('Pouch_Stud',(-.183,.191,.411),(.009,.005,.009),'Gold','pelvis',16,10)
# Narrow shoulder strap on the back, carrying the pouch. Follows jacket surface.
strap=tube('Back_Strap',[(-.15,-.154,.459,.010),(-.05,-.163,.555,.010),(.08,-.154,.645,.010),(.15,-.105,.711,.010)],c,M['Jacket'],10,8);strap['skin_region']='torso'
# Reposition the existing named skeleton to the new anatomy. No runtime special cases.
activate(rig);bpy.ops.object.mode_set(mode='EDIT')
for b in rig.data.edit_bones:
 for attr in ['head','tail']:
  p=getattr(b,attr).copy()
  if b.name.startswith('tail_'):p=Vector((p.x*1.05,p.y*1.10,.26+(p.z-.25)*.9))
  elif b.name=='head':p=headmap(p)
  elif b.name=='root':continue
  else:p=Vector((p.x*1.10,p.y*1.2,p.z*1.5))
  setattr(b,attr,p)
# Explicit landmarks make arm and leg segments coincide with the sleeve/glove and boot joints.
for sign,side in [(-1,'L'),(1,'R')]:
 poses={'arm_upper_'+side:((sign*.18,0,.674),(sign*.268,.019,.55)), 'forearm_'+side:((sign*.268,.019,.55),(sign*.317,.057,.414)), 'hand_'+side:((sign*.317,.057,.414),(sign*.317,.079,.378)), 'fingers_'+side:((sign*.317,.079,.378),(sign*.317,.085,.357)), 'leg_'+side:((sign*.12,0,.32),(sign*.145,.008,.205)), 'knee_'+side:((sign*.145,.008,.205),(sign*.15,.025,.060)), 'foot_'+side:((sign*.15,.025,.060),(sign*.15,.119,.035))}
 for n,(h,t) in poses.items():rig.data.edit_bones[n].head=h;rig.data.edit_bones[n].tail=t
for n,side in [('sword_socket',1),('bow_socket',-1),('bow_draw_socket',1)]:
 b=rig.data.edit_bones[n];b.head=(side*.30,.09,.398);b.tail=(side*.30,.19,.398)
b=rig.data.edit_bones['lantern_socket'];b.head=(-.318,.10,.405);b.tail=(-.318,.10,.50)
b=rig.data.edit_bones['neck'];b.head=(0,0,.68);b.tail=(0,0,.755)
b=rig.data.edit_bones['head'];b.head=(0,0,.755)
bpy.ops.object.mode_set(mode='OBJECT')
# Each garment belongs to its actual anatomical segment. No hand influence in chest/hip meshes.
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
for o in c.objects:
 if o.type!='MESH':continue
 for g in list(o.vertex_groups):o.vertex_groups.remove(g)
 o.parent=rig;groups={n:o.vertex_groups.new(name=n) for n in rig.data.bones.keys()}
 region=o.get('skin_region','head')
 for v in o.data.vertices:
  z=v.co.z
  if region=='head':ws={'head':1}
  elif region=='tail':
   t=max(0,min(1,(-v.co.y-.20)/.52));a=min(1,int(t*2));f=t*2-a;ws={['tail_01','tail_02'][a]:1-f,['tail_02','tail_03'][a]:f}
  elif region=='torso':
   w=smooth(.38,.54,z);ws={'pelvis':1-w,'torso':w}
  elif region=='pelvis':ws={'pelvis':1}
  else:
   part,side=region.rsplit('_',1)
   if part=='upper':ws={'arm_upper_'+side:1}
   elif part=='arm':
    w=smooth(.515,.590,z);ws={'arm_upper_'+side:w,'forearm_'+side:1-w}
   elif part=='forearm':ws={'forearm_'+side:1}
   elif part=='hand':ws={'hand_'+side:1}
   elif part=='thigh':
    w=smooth(.29,.36,z);ws={'pelvis':w,'leg_'+side:1-w}
   elif part=='shin':
    w=smooth(.065,.11,z);ws={'knee_'+side:w,'foot_'+side:1-w}
   else:ws={'foot_'+side:1}
  for n,w in ws.items():
   if w>0:groups[n].add([v.index],w,'REPLACE')
 if not any(mod.type=='ARMATURE' for mod in o.modifiers):mod=o.modifiers.new('Character skin','ARMATURE');mod.object=rig
rig.data.pose_position='REST';s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'source':bpy.data.filepath,'meshes':len([o for o in c.objects if o.type=='MESH']),'stage':'ranger neutral; animation pending'}
