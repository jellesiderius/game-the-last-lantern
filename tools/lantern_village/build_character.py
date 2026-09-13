"""New lantern-panda source from the September 10 turnaround, separate from historical designs."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
assert not bpy.data.collections.get('LanternPanda_Character')
s=bpy.data.scenes.new('LanternPanda_Production');bpy.context.window.scene=s;s.unit_settings.system='METRIC'
c=bpy.data.collections.new('LanternPanda_Character');s.collection.children.link(c)
M={n:material('LanternPanda_'+n,col,.74 if n!='Eyes' else .28) for n,col in {'Coat':(.78,.33,.16),'Cream':(.96,.84,.66),'Body':(.26,.18,.15),'EarInner':(.31,.15,.10),'Eyes':(.065,.052,.047),'Nose':(.19,.12,.10),'Cape':(.15,.39,.42),'CapeHem':(.19,.44,.46)}.items()}
def ell(name,pos,scale,mat='Coat',region='head',segs=48,rings=32):
 o=ellipsoid(name,pos,scale,c,M[mat],segs,rings);o['skin_region']=region;return o
# Broad smooth cheeks and a rounded-square lower head: silhouette comes from the actual mesh.
head=loft('Head',[(.49,.04,.03,.00),(.515,.255,.19,.0),(.56,.37,.263,.0),(.69,.421,.295,-.01),(.83,.409,.292,-.015),(.97,.319,.24,-.02),(1.07,.16,.14,-.02),(1.096,.015,.015,-.02)],c,M['Coat'],96,7,2.25)
head['skin_region']='head'
# Curved color patches conform to the actual head surface instead of thick appliqué discs.
from mathutils.bvhtree import BVHTree
bvh=BVHTree.FromPolygons([v.co for v in head.data.vertices],[list(p.vertices) for p in head.data.polygons])
def patch(name,outline,mat='Cream'):
 outline=smooth_curve(outline,6,True);center=sum(outline,Vector((0,0)))/len(outline);N=len(outline);verts=[];faces=[]
 for j in range(9):
  r=j/8
  for point in outline:
   x,z=center.lerp(point,r);hit=bvh.ray_cast(Vector((x,1,z)),Vector((0,-1,0)))
   y=hit[0].y if hit[0] else .20
   verts.append((x,y+.0025+.003*(1-r*r),z))
 for j in range(8):
  for i in range(N):a=j*N+i;b=j*N+(i+1)%N;faces.append((a,b,b+N,a+N))
 o=mesh_object(name,verts,faces,c,M[mat]);o['skin_region']='head';return o
for sign,side in [(-1,'L'),(1,'R')]:
 outline=[(.225,.72),(.313,.77),(.365,.70),(.375,.63),(.301,.57),(.224,.558),(.239,.63)]
 patch('Cheek_'+side,[(sign*x,z) for x,z in outline])
 ell('Eye_'+side,(sign*.156,.289,.735),(.035,.022,.052),'Eyes')
 ell('Brow_'+side,(sign*.156,.276,.846),(.043,.008,.031),'Cream')
# Muzzle is short, creamy and pear shaped, with a tiny brown triangular nose.
muzzle=loft('Muzzle',[(.527,.014,.012,.265),(.535,.072,.025,.285),(.57,.133,.044,.284),(.63,.135,.061,.277),(.696,.080,.049,.285),(.718,.02,.014,.285)],c,M['Cream'],64,5,2.1);muzzle['skin_region']='head'
nose=mesh_object('Nose',[(-.033,.342,.691),(.033,.342,.691),(0,.355,.661),(-.024,.369,.687),(.024,.369,.687),(0,.372,.67)],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],c,M['Nose']);nose['skin_region']='head'
activate(nose);mod=nose.modifiers.new('Rounded nose corners','BEVEL');mod.width=.008;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
# Round triangular ears, thick cream rim, recessed warm-brown bowl. Both sides share the contour.
for sign,side in [(-1,'L'),(1,'R')]:
 contour=smooth_curve([(.245,.979),(.243,1.082),(.304,1.205),(.36,1.191),(.394,1.102),(.38,.993)],8,True)
 center=Vector((.317,1.084));verts=[];faces=[];N=len(contour)
 for y,scale in [(-.065,.82),(.008,1.),(.059,.96),(.057,.70),(.023,.60)]:
  for p in contour:
   q=center+(p-center)*scale;verts.append((sign*q.x,y,q.y))
 faces.append(tuple(range(N-1,-1,-1)))
 for j in range(4):
  for i in range(N):a=j*N+i;b=j*N+(i+1)%N;faces.append((a,b,b+N,a+N))
 faces.append(tuple(4*N+i for i in range(N)))
 ear=mesh_object('Ear_'+side,verts,faces,c,M['Coat']);ear.data.materials.append(M['Cream']);ear.data.materials.append(M['EarInner'])
 for f in ear.data.polygons:f.material_index=0 if f.index<=N else (1 if f.index<3*N+1 else 2)
 ear['skin_region']='head'
# Connected short torso, hips, legs and arms, no disconnected spheres at the joints.
bodyparts=[ell('Torso',(0,-.007,.30),(.224,.168,.226),'Body','body'),ell('Neck',(0,0,.49),(.165,.135,.12),'Body','body')]
for sign,side in [(-1,'L'),(1,'R')]:
 bodyparts += [ell('Haunch_'+side,(sign*.123,-.005,.168),(.100,.112,.118),'Body','body'),ell('Shin_'+side,(sign*.133,.003,.072),(.073,.09,.076),'Body','body'),ell('Foot_'+side,(sign*.134,.04,.032),(.079,.113,.034),'Body','body')]
 arm=tube('Arm_'+side,[(sign*.172,0,.452,.077),(sign*.235,.00,.381,.066),(sign*.276,.033,.30,.055)],c,M['Body'],24,6);bodyparts.append(arm)
 bodyparts.append(ell('Palm_'+side,(sign*.28,.037,.277),(.057,.053,.068),'Body','body'))
 for i in range(3):
  bodyparts.append(ell('Finger_'+side+str(i),(sign*(.261+i*.018),.061,.245),(.015,.027,.027),'Body','body',24,16))
 bodyparts.append(ell('Thumb_'+side,(sign*.242,.079,.275),(.025,.028,.034),'Body','body',28,20))
body=fuse(bodyparts,'Connected_Body',.003,4,.42);body['skin_region']='body'
# Teardrop chest marking on the torso, thin and conforming.
verts=[];faces=[];N=64
bodybvh=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
for j in range(13):
 r=j/12
 for i in range(N):
  a=math.tau*i/N;z=.29+r*.145*math.cos(a);x=r*.098*math.sin(a)*(1-.30*math.cos(a));hit=bodybvh.ray_cast(Vector((x,1,z)),Vector((0,-1,0)))
  verts.append((x,hit[0].y+.003 if hit[0] else .17,z))
for j in range(12):
 for i in range(N):a=j*N+i;b=j*N+(i+1)%N;faces.append((a,b,b+N,a+N))
belly=mesh_object('Belly_Marking',verts,faces,c,M['Cream']);belly['skin_region']='body'
# Ringed plush tail, with true material bands around one continuous mesh.
tail=tube('Ringed_Tail',[(0,-.126,.255,.082),(-.025,-.30,.257,.15),(-.09,-.49,.30,.176),(-.12,-.67,.40,.177),(-.11,-.80,.48,.13),(-.10,-.857,.49,.008)],c,M['Coat'],48,10)
tail.data.materials.append(M['Cream']);tail['skin_region']='tail'
for f in tail.data.polygons:
 cy=sum(tail.data.vertices[i].co.y for i in f.vertices)/len(f.vertices)
 f.material_index=1 if -.38<cy<-.265 or -.66<cy<-.515 else 0
# Cape wraps shoulders and drapes lower at the back. Open front gives the chest its silhouette.
verts=[];faces=[];N=112;R=15
for j in range(R):
 t=j/(R-1)
 for i in range(N+1):
  a=.18+i*(math.tau-.36)/N;front=max(0,math.cos(a));back=max(0,-math.cos(a))
  radius=.17+(.11+.015*math.sin(a)**2)*math.sin(t*math.pi/2)
  x=math.sin(a)*radius;y=math.cos(a)*(radius*.78)
  hem=.405-.235*back**.7+.035*front**5
  z=.513*(1-t)+hem*t
  y-=.055*t*t*back
  verts.append((x,y,z))
for j in range(R-1):
 for i in range(N):a=j*(N+1)+i;faces.append((a,a+1,a+N+2,a+N+1))
cape=mesh_object('Teal_Cape',verts,faces,c,M['Cape']);cape['skin_region']='cape'
activate(cape);mod=cape.modifiers.new('Thick cloth edge','SOLIDIFY');mod.thickness=.012;mod.offset=0;bpy.ops.object.modifier_apply(modifier=mod.name)
mod=cape.modifiers.new('Soft cape edges','BEVEL');mod.width=.006;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
# Save neutral source before any rigging or props are introduced.
s.render.fps=100;s.view_settings.view_transform='AgX'
path=ROOT/'assets/characters/red_panda/checkpoints/lantern_neutral.blend';bpy.data.libraries.write(str(path),{s},fake_user=True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'source':bpy.data.filepath,'meshes':len(c.objects),'triangles':sum(len(p.vertices)-2 for o in c.objects for p in o.data.polygons)}
