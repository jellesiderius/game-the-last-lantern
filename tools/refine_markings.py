"""Fit neck markings to the actual body surface; keep a narrow rear wrap.
Preserves mesh silhouette, rig and all Actions. Replaces only cream surface patches.
"""
import bpy, math, bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.context.scene;r=bpy.data.objects['Crow_Rig'];r.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
body=bpy.data.objects['Crow_Body'];bpy.context.view_layer.update()
bvh=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
def interp(points,z):
 for i in range(len(points)-1):
  a,x=points[i];b,y=points[i+1]
  if z<=b:
   t=max(0,(z-a)/(b-a));return x+(y-x)*t
 return points[-1][1]
def smooth(a,b,z):
 t=max(0,min(1,(z-a)/(b-a)));return t*t*(3-2*t)
front=[(.598,-.166),(.64,-.099),(.70,-.003),(.76,.098),(.80,.126),(.84,.080),(.91,.018),(.97,-.027),(1.018,-.064),(1.027,-.095)]
back=[(.598,-.166),(.64,-.137),(.70,-.116),(.76,-.098),(.80,-.088),(.84,-.080),(.91,-.078),(.97,-.081),(1.018,-.096),(1.027,-.095)]
for side in [-1,1]:
 o=bpy.data.objects['Cream_Neck_'+str(side)]
 v=[];f=[];nz=96;ny=32
 for j in range(nz+1):
  z=.598+(1.027-.598)*j/nz
  for i in range(ny+1):
   y=interp(back,z)+(interp(front,z)-interp(back,z))*i/ny
   loc,normal,_,_=bvh.ray_cast(Vector((side*1.0,y,z)),Vector((-side,0,0)),2)
   if loc is None:raise RuntimeError('Neck projection missed body')
   v.append(loc+normal*.0018)
 for j in range(nz):
  for i in range(ny):
   a=j*(ny+1)+i;f.append((a,a+1,a+ny+2,a+ny+1))
 mesh=bpy.data.meshes.new(o.name+'_Conformed');mesh.from_pydata(v,[],f);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
 old=o.data;o.data=mesh;bpy.data.meshes.remove(old)
 mesh.materials.append(bpy.data.materials['Crow_Warm_Cream'])
 for poly in mesh.polygons:poly.use_smooth=True
 o.vertex_groups.clear()
 groups={n:o.vertex_groups.new(name=n) for n in ['pelvis','torso','neck','head']}
 for vert in mesh.vertices:
  z=vert.co.z;ww={'pelvis':1-smooth(.31,.57,z),'torso':smooth(.31,.57,z)*(1-smooth(.73,.94,z)),'neck':smooth(.73,.94,z)*(1-smooth(1.005,1.09,z)),'head':smooth(1.005,1.09,z)}
  total=sum(ww.values())
  for n,w in ww.items():
   if w>0:groups[n].add([vert.index],w/total,'REPLACE')
# Brown belongs to the belly and short shanks; rear body stays black lower down.
attribute=body.data.color_attributes['FeatherColours']
black=Vector((.022,.025,.031));brown=Vector((.20,.143,.10))
for vertex,c in zip(body.data.vertices,attribute.data):
 p=vertex.co
 front_weight=smooth(-.14,.04,p.y)
 cutoff=.18+.105*front_weight
 brown_weight=1-smooth(cutoff-.006,cutoff+.006,p.z)
 color=black.lerp(brown,brown_weight)
 c.color=(*color,1)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/crow/source.blend'))
result={'neck_surface_offset_m':.0018,'rear_wrap':'narrow conformed strip','brown_rear_cutoff_m':.18}
