"""Review revision 1: joined muzzle, rounded cheeks, relaxed fingers, shorter plush tail.
Edits the new red panda draft only; preserves previous source as a checkpoint.
"""
import bpy,sys,math,bmesh
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
s=bpy.data.scenes['RedPanda_Production'];bpy.context.window.scene=s
c=bpy.data.collections['RedPanda_Character'];body=c.objects['RedPanda_Body'];head=c.objects['RedPanda_Head']
assert not bpy.data.objects.get('RedPanda_Rig'),'Neutral geometry revision precedes skinning.'
checkpoint=ROOT/'assets/characters/red_panda/checkpoints/neutral_first_pass.blend'
if not checkpoint.exists():bpy.data.libraries.write(str(checkpoint),{s},fake_user=True)
cream=bpy.data.materials['Panda_Warm_Cream'];orange=bpy.data.materials['Panda_Caramel_Rust'];dark=bpy.data.materials.get('Panda_Chocolate') or material('Panda_Chocolate',(.245,.19,.17))
# Lower skull narrows into the short muzzle. Preserve eye-level width and full cranium.
for v in head.data.vertices:
 z=v.co.z
 if z<.86:
  a=max(0,min(1,(.86-z)/.15));v.co.x*=1-.10*a
 if z>1.10:v.co.z-=.007*max(0,1-abs(v.co.x)/.15)
for obj in c.objects:
 if obj.name=='Cream_Muzzle':
  for v in obj.data.vertices:
   v.co.y-=.025
   if v.co.y<.225:v.co.y-=.025
 if obj.name in ['Nose','Philtrum','Mouth_L','Mouth_R']:
  for v in obj.data.vertices:v.co.y-=.020
 if obj.name.startswith('Eye_Glint'):
  center=sum((v.co for v in obj.data.vertices),Vector())/len(obj.data.vertices)
  for v in obj.data.vertices:v.co=center+(v.co-center)*.55

# Replace pinched radial cheek surfaces with smoothly curved, solid three-lobed tufts.
for obj in list(c.objects):
 if obj.name.startswith(('Cream_Cheek','Outer_Cheek')):bpy.data.objects.remove(obj,do_unlink=True)
def cheek_patch(name,points,mat):
 boundary=smooth_curve(points,7,True);center=sum(boundary,Vector((0,0)))/len(boundary);n=len(boundary)
 vertices=[];faces=[]
 for layer in range(2):
  for r in [0,.18,.36,.55,.74,.89,1.]:
   for p in boundary:
    x,z=center+(p-center)*r
    # Follow head curvature without a failed ray causing a deep spike at an overhanging tuft.
    y=.197-.12*(abs(x)/.31)**2
    y+=(.020*(1-r*r) if not layer else -.026*(1-r*r))
    vertices.append((x,y,z))
  for j in range(6):
   for i in range(n):
    k=layer*7*n+j*n+i;nb=layer*7*n+j*n+(i+1)%n
    faces.append((k,nb,nb+n,k+n))
 for i in range(n):faces.append((6*n+i,6*n+(i+1)%n,13*n+(i+1)%n,13*n+i))
 o=mesh_object(name,vertices,faces,c,mat);o['skin_region']='head'
 return o
for sign,side in [(-1,'L'),(1,'R')]:
 outer=[(.232,.938),(.264,.935),(.290,.905),(.317,.890),(.308,.870),(.294,.865),(.313,.833),(.329,.816),(.305,.805),(.316,.784),(.299,.764),(.269,.765),(.253,.749),(.220,.774)]
 cheek_patch('Outer_Cheek_'+side,[(sign*x,z) for x,z in outer],orange)
 points=[(.190,.944),(.212,.938),(.236,.916),(.247,.894),(.269,.875),(.269,.861),(.250,.855),(.270,.828),(.268,.811),(.252,.809),(.250,.779),(.237,.753),(.216,.747),(.193,.755),(.181,.773),(.190,.807),(.177,.847)]
 o=cheek_patch('Cream_Cheek_'+side,[(sign*x,z) for x,z in points],cream)
 for v in o.data.vertices:v.co.y+=.020

# Cut only the malformed distal hands, union newly rounded digits into continuous wrists.
bm=bmesh.new();bm.from_mesh(body.data)
remove=[v for v in bm.verts if abs(v.co.x)>.265 and v.co.z<.365 and v.co.z>.20]
bmesh.ops.delete(bm,geom=remove,context='VERTS')
edges=[e for e in bm.edges if e.is_boundary]
bmesh.ops.holes_fill(bm,edges=edges,sides=0);bm.to_mesh(body.data);bm.free()
parts=[body]
for sign,side in [(-1,'L'),(1,'R')]:
 parts.append(ellipsoid('Palm_new_'+side,(sign*.340,.025,.350),(.059,.068,.075),c,dark))
 for i,(y,end) in enumerate([(-.019,.286),(.027,.273),(.072,.287)]):
  parts.append(tube('Finger_new_'+side+str(i),[(sign*.350,y,.355,.023),(sign*.354,y,.321,.025),(sign*.347,y,end+.010,.023),(sign*.334,y,end,.015)],c,dark,24,5))
  parts.append(ellipsoid('Finger_tip_'+side+str(i),(sign*.341,y,end+.009),(.023,.022,.023),c,dark,32,20))
 parts.append(tube('Thumb_new_'+side,[(sign*.303,.063,.372,.026),(sign*.286,.080,.352,.025),(sign*.287,.085,.329,.021)],c,dark,24,6))
 parts.append(ellipsoid('Thumb_tip_'+side,(sign*.287,.085,.329),(.021,.022,.023),c,dark,32,20))
body=fuse(parts,'RedPanda_Body',.0027,3,.5);body['skin_region']='body'
body.data.materials.clear();mat=bpy.data.materials['Panda_Body_Coat'];body.data.materials.append(mat)
attr=body.data.color_attributes.get('CoatColours') or body.data.color_attributes.new(name='CoatColours',type='FLOAT_COLOR',domain='POINT')
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
rust=Vector(linear_color((.65,.275,.12)));choc=Vector(linear_color((.245,.19,.17)));crem=Vector(linear_color((.96,.84,.69)))
for v in body.data.vertices:
 x,y,z=v.co
 if z<.009:v.co.z=.004
 width=.198*math.sqrt(max(0,1-((z-.46)/.39)**2))
 belly=(1-smooth(width-.015,width+.010,abs(x)))*smooth(.016,.058,y)
 arm=smooth(.23,.285,abs(x))*(1-smooth(.525,.550,z));legs=1-smooth(.24,.30,z)
 attr.data[v.index].color=(*rust.lerp(choc,max(belly,arm,legs)),1)
orange.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*rust,1)
orange.diffuse_color=(*rust,1)

# Round-tipped tail sampled in arc length, with three broad cream rings.
bpy.data.objects.remove(c.objects['Ringed_Tail'],do_unlink=True)
spine=smooth_curve([(0,-.145,.325),(-.035,-.31,.329),(-.120,-.50,.342),(-.201,-.69,.392),(-.228,-.82,.489),(-.226,-.908,.554)],24)
vertices=[];faces=[];n=64;last=len(spine)-1
for j,p in enumerate(spine):
 u=j/last;axis=(spine[min(j+1,last)]-spine[max(j-1,0)]).normalized();normal=axis.cross(Vector((1,0,0))).normalized();other=axis.cross(normal).normalized()
 radius=.073+.105*smooth(0,.3,u)
 if u>.68:radius=.178*math.sqrt(max(.00001,1-((u-.68)/.32)**2))
 for i in range(n):
  a=i*math.tau/n;vertices.append(p+(normal*math.cos(a)+other*math.sin(a))*radius)
for j in range(last):
 for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
faces.extend([tuple(range(n-1,-1,-1)),tuple(last*n+i for i in range(n))])
tail=mesh_object('Ringed_Tail',vertices,faces,c,bpy.data.materials['Panda_Tail_Rings']);tail['skin_region']='tail'
attr=tail.data.color_attributes.new(name='CoatColours',type='FLOAT_COLOR',domain='POINT')
for v in tail.data.vertices:
 u=(v.index//n)/last;amount=0
 for a,b in [(.14,.22),(.38,.50),(.665,.80)]:amount=max(amount,smooth(a-.003,a+.003,u)*(1-smooth(b-.003,b+.003,u)))
 attr.data[v.index].color=(*rust.lerp(crem,amount),1)
# Side cameras centre the full tail + body rather than clipping the reference silhouette.
for name in ['left','right']:
 cam=bpy.data.objects['Review_'+name];cam.location.y=-.25
 cam.rotation_euler=(Vector((0,-.25,.62))-cam.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'source':bpy.data.filepath,'body_vertices':len(body.data.vertices)}
