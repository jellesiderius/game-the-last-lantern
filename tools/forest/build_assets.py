"""Offline forest kit authoring. New independent, editable assets from the forest turnarounds.
Run Blender --background --python tools/forest/build_assets.py -- [--export] [--only=id]
The saved sources are authoritative; this is an explicit rebuild, never a runtime dependency.
"""
import bpy, bmesh, math, random, sys, json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[2]
TAU=math.tau
rng=random.Random(913)
ATLAS=ROOT/'assets/environment/forest_materials/atlas.png'
EXPORT='--export' in sys.argv
ONLY=next((v.split('=',1)[1] for v in sys.argv if v.startswith('--only=')),None)

def material(name,color,tile=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.88
 if tile is not None:
  tex=m.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ATLAS),check_existing=True)
  m.node_tree.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
 m['atlas_tile']=tile if tile is not None else -1
 return m

def mesh(name,verts,faces,mat,uv=None):
 data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
 obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj);data.materials.append(mat)
 layer=data.uv_layers.new(name='UVMap')
 tile=int(mat.get('atlas_tile',-1))
 for poly in data.polygons:
  for li in poly.loop_indices:
   idx=data.loops[li].vertex_index
   co=uv[idx] if uv else ((verts[idx][0]+2)/4,(verts[idx][2]+2)/4)
   if tile>=0:
    co=(.015+co[0]*.47+(tile%2)*.5,.015+co[1]*.47+(1-tile//2)*.5)
   layer.data[li].uv=co
 return obj

def tube(name,centers,radii,mat,sides=10,cap=True):
 verts=[];uv=[]
 for j,(c,r) in enumerate(zip(centers,radii)):
  c=Vector(c)
  tangent=Vector(centers[min(len(centers)-1,j+1)])-Vector(centers[max(0,j-1)])
  tangent.normalize();axis=tangent.cross(Vector((0,1,0)))
  if axis.length<.01:axis=tangent.cross(Vector((1,0,0)))
  axis.normalize();other=tangent.cross(axis)
  for i in range(sides+1):
   a=i/sides*TAU;verts.append(c+r*(math.cos(a)*axis+math.sin(a)*other));uv.append((i/sides,j/(len(centers)-1)))
 faces=[]
 for j in range(len(centers)-1):
  for i in range(sides):
   a=j*(sides+1)+i;b=a+sides+1;faces.append((a,a+1,b+1,b))
 if cap:faces.extend([tuple(range(sides-1,-1,-1)),tuple((len(centers)-1)*(sides+1)+i for i in range(sides))])
 return mesh(name,verts,faces,mat,uv)

def blob(name,at,scale,mat,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=at)
 o=bpy.context.object;o.name=name
 for v in o.data.vertices:
  k=1+rng.uniform(-.06,.06);v.co.x*=scale[0]*k;v.co.y*=scale[1]*k;v.co.z*=scale[2]*k
 o.data.materials.append(mat)
 return o

def leaf(name,base,length,width,angle,lift,mat,notched=False):
 # Segmented folded ribbon: each section follows the arc without a central fan.
 rows=[(0,0)]
 if notched:
  for i in range(1,5):
   t=i/5;w=math.sin(math.pi*t)**.65
   rows += [(t-.055,w*.86),(t-.035,w),(t+.035,w*.95),(t+.060,w*.48)]
 else:rows += [(.25,.78),(.53,1),(.78,.65)]
 rows += [(1,0)]
 verts=[]
 for t,w in rows:
  y=t*length
  for side in [-1,0,1]:
   x=side*w*width;z=lift*math.sin(t*math.pi*.70)+(.009 if side==0 else 0)
   verts.append((base[0]+x*math.cos(angle)+y*math.sin(angle),base[1]-x*math.sin(angle)+y*math.cos(angle),base[2]+z))
 faces=[]
 for j in range(len(rows)-1):
  a=j*3;b=a+3;faces += [(a,b,b+1,a+1),(a+1,b+1,b+2,a+2)]
 o=mesh(name,verts,faces,mat)
 sol=o.modifiers.new('Leaf_thickness','SOLIDIFY');sol.thickness=.008
 bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=sol.name)
 return o

def stump():
 n=72;verts=[];uv=[]
 for j,(z,rad,root_amount) in enumerate([(0,1.36,.53),(.075,1.39,.53),(.27,1.36,.34),(.70,1.29,.10),(1.14,1.29,0),(1.18,1.26,0)]):
  for i in range(n+1):
   a=i/n*TAU;phase=abs(math.atan2(math.sin(a*6+.2),math.cos(a*6+.2)))
   t=max(0,min(1,(1.15-phase)/.60));root=t*t*(3-2*t)
   r=rad+root*root_amount+.012*math.sin(a*12)
   verts.append((r*math.cos(a),r*math.sin(a),z));uv.append((i/n,j/5))
 faces=[]
 for j in range(5):
  for i in range(n):
   a=j*(n+1)+i;b=a+n+1;faces.append((a,a+1,b+1,b))
 mesh('Broad_buttress_roots',verts,faces,bark,uv)
 # Golden cut lip has a real lower face and bevel, no paper-thin circular top.
 rimv=[];rimuv=[]
 for r,z in [(1.26,1.15),(1.30,1.19),(1.27,1.23)]:
  for i in range(48):
   a=i/48*TAU;rimv.append((r*math.cos(a),r*math.sin(a),z));rimuv.append((.5+.495*math.cos(a),.5+.495*math.sin(a)))
 mesh('Golden_beveled_lip',rimv,[(j*48+i,j*48+(i+1)%48,(j+1)*48+(i+1)%48,(j+1)*48+i) for j in range(2) for i in range(48)],cutedge,rimuv)
 disk('Honey_cut_surface',(0,0,1.23),1.27,wood,48)
 tube('Broken_side_branch',[(-.23,1.18,.03),(-.27,1.37,.35),(-.27,1.37,.38)],[.30,.23,.21],bark,10)
 disk('Side_branch_cut',(-.27,1.37,.385),.21,wood,10)
 for center,span,drop in [(.40,.22,.12),(2.0,.19,.21),(3.1,.28,.15),(4.4,.17,.08)]:
  vv=[];ff=[];count=8
  for j in range(4):
   for i in range(count):
    a=center+(i/(count-1)-.5)*span*2
    z=[1.242,1.245,1.18,1.18-drop*(.78+.22*math.cos(i*1.9))][j]
    r=[1.12+.035*math.sin(i*2.1),1.28,1.31,1.325][j]
    vv.append((r*math.cos(a),r*math.sin(a),z))
  for j in range(3):
   for i in range(count-1):ff.append((j*count+i,j*count+i+1,(j+1)*count+i+1,(j+1)*count+i))
  o=mesh('Draped_rim_moss',vv,ff,moss);solid=o.modifiers.new('Moss_thickness','SOLIDIFY');solid.thickness=.02
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=solid.name)


def disk(name,at,r,mat,n=32):
 verts=[at];uv=[(.5,.5)]
 for i in range(n):
  a=i/n*TAU;verts.append((at[0]+r*math.cos(a),at[1]+r*math.sin(a),at[2]));uv.append((.5+.5*math.cos(a),.5+.5*math.sin(a)))
 return mesh(name,verts,[(0,1+i,1+(i+1)%n) for i in range(n)],mat,uv)

def crown(name,at,scale,mat):
 # A perturbed geodesic dual gives broad irregular pentagonal/hexagonal facets,
 # without either latitude bands or a repeated equilateral triangle pattern.
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
 temp=bpy.context.object;co=[v.co.copy() for v in temp.data.vertices];polys=[tuple(p.vertices) for p in temp.data.polygons]
 for k,point in enumerate(co):point*=1+.065*math.sin(k*2.43)
 centers=[sum((co[k] for k in face),Vector())/3 for face in polys]
 v=[]
 for k,c in enumerate(centers):
  c=c.normalized()*(1+.035*math.sin(k*1.72));v.append((at[0]+scale[0]*c.x,at[1]+scale[1]*c.y,at[2]+scale[2]*c.z))
 f=[]
 for i,point in enumerate(co):
  adjacent=[j for j,face in enumerate(polys) if i in face]
  normal=point.normalized();axis=normal.cross(Vector((0,0,1)))
  if axis.length<.01:axis=normal.cross(Vector((0,1,0)))
  axis.normalize();other=normal.cross(axis)
  adjacent.sort(key=lambda j:math.atan2(centers[j].dot(other),centers[j].dot(axis)))
  f.append(tuple(adjacent))
 bpy.data.objects.remove(temp,do_unlink=True)
 return mesh(name,v,f,mat)


def oak():
 tube('Sinuous_trunk',[(0,0,0),(.13,.015,.48),(.11,.04,.95),(-.08,.03,1.44),(.10,.02,1.95),(.28,0,2.52),(.36,0,2.85)],[.35,.27,.25,.23,.19,.145,.10],oakbark,10)
 for a in [0,1.4,3,4.6]:tube('Stout_root',[(0,0,.30),(.36*math.cos(a),.36*math.sin(a),.12),(.57*math.cos(a),.57*math.sin(a),.07)],[.21,.15,.07],oakbark,8)
 for end,mid in [((-.72,.04,2.5),(-.37,.04,2.1)),((.86,.08,2.6),(.50,.04,2.33))]:tube('Integrated_fork',[(0,0,1.7),mid,end],[.205,.15,.10],oakbark,9)
 for i,(c,sc) in enumerate([((.19,.01,3.13),(.97,.79,.77)),((-.73,.02,2.56),(.80,.70,.68)),((.84,.13,2.58),(.67,.60,.58))]):crown('Irregular_crown_'+str(i),c,sc,leaves[0])


def pine(variant=0):
 # Sculpted drooping leaf panels over a single inner crown, with clear exposed trunks.
 width=[1.30,1.08,1.40][variant];stretch=[1.0,1.03,.96][variant]
 tube('Pine_trunk',[(0,0,0),(.04,.035,.65),(-.035,.06,1.5),(.03,0,3.0),(0,0,5.25*stretch)],[.30,.235,.21,.12,.02],oakbark,11)
 for a in [0,1.5,3.3,4.8]:tube('Pine_root',[(0,0,.3),(.40*math.cos(a),.40*math.sin(a),.12),(.57*math.cos(a),.57*math.sin(a),.06)],[.20,.12,.05],oakbark,8)
 for a in [.3,2.6,4.8]:tube('Crown_support',[(0,0,1.55),(.6*math.cos(a),.6*math.sin(a),2.0)],[.10,.035],oakbark,7)
 # Three/four asymmetrically spaced bough masses, rather than identical concentric skirts.
 tiers=[(1.73,1.38,1.87),(2.58,1.11,1.69),(3.38,.78,1.52),(4.10,.48,1.28)]
 if variant==1:tiers=[(1.75,1.30,2.05),(2.85,.95,1.96),(3.99,.58,1.51)]
 elif variant==2:tiers=[(1.80,1.45,1.92),(2.47,1.20,1.91),(3.24,.89,1.66),(4.0,.58,1.43)]
 for tier,(z,r,h) in enumerate(tiers):
  z*=stretch;h*=stretch;r*=width
  count=11 if tier<2 else 9
  for k in range(count):
   angle=k/count*TAU+tier*.19+variant*.21
   radial=Vector((math.cos(angle),math.sin(angle),0));tangent=Vector((-math.sin(angle),math.cos(angle),0))
   width_bottom=TAU*r/count*.54;tip_drop=.10*math.sin(k*2.5+tier)
   v=[];f=[]
   rows=[(0,.05,.035),(.30,.34,.40),(.64,.74,.83),(.93,1.,1.),(1.,.99,.80)]
   for row,(t,radius,spread) in enumerate(rows):
    for col in [-1,0,1]:
     rr=radius*r+(.035*(1-abs(col))*math.sin(math.pi*t))
     zz=z+h*(1-t)+tip_drop*t+(.10 if row==4 and col else 0)
     point=radial*rr+tangent*(col*width_bottom*spread);v.append((point.x,point.y,zz))
   for row in range(4):
    a=row*3;f += [(a,a+1,a+4,a+3),(a+1,a+2,a+5,a+4)]
   o=mesh('Drooping_bough_%d_%d'%(tier,k),v,f,pines[min(tier,2)])
   solid=o.modifiers.new('Leaf_edge_depth','SOLIDIFY');solid.thickness=.10;solid.offset=-1
   bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=solid.name)
  # A recessed interior closes the crown while leaving the individual bough ends visible.
  tube('Inner_crown',[(0,0,z+.13),(0,0,z+h*.55),(0,0,z+h)],[r*.87,r*.43,.012],pines[min(tier,2)],22)

 # Fuse overlapping bough edges into one sculpted volume before simplifying its facets.
 objects=[o for o in bpy.context.scene.objects if o.name.startswith(('Drooping_bough','Inner_crown'))]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();o=objects[0];o.name='Sculpted_canopy'
 remesh=o.modifiers.new('Joined_bough_volume','REMESH');remesh.mode='VOXEL';remesh.voxel_size=.035;remesh.use_smooth_shade=False
 bpy.ops.object.modifier_apply(modifier=remesh.name)
 smooth=o.modifiers.new('Soft_leaf_edges','SMOOTH');smooth.factor=.55;smooth.iterations=3;bpy.ops.object.modifier_apply(modifier=smooth.name)
 dec=o.modifiers.new('Broad_low_poly_facets','DECIMATE');dec.ratio=.020;bpy.ops.object.modifier_apply(modifier=dec.name)
 o.data.materials.clear();o.data.materials.append(pines[1])
 for face in o.data.polygons:face.material_index=0


def log():
 n=16;v=[];uv=[]
 # Four rings at each lip form a thick inner and outer bevel.
 rings=[(-1.12,.43),(-1.18,.415),(-1.18,.335),(-1.10,.315),(1.10,.315),(1.18,.335),(1.18,.415),(1.12,.43)]
 for x,r in rings:
  for i in range(n):
   a=TAU*i/n;rr=r*(1+.026*math.sin(i*2.3));v.append((x,rr*math.cos(a),.44+rr*math.sin(a)));uv.append((i/n,(x+1.18)/2.36))
 for a,b,mat in [(0,7,bark),(3,4,dark),(0,1,cutedge),(1,2,wood),(2,3,cutedge),(4,5,cutedge),(5,6,wood),(6,7,cutedge)]:
  uvs=uv if mat==bark else [(.5+y,.5+z-.44) for x,y,z in v]
  mesh('Bark' if mat==bark else 'Hollow_inner' if mat==dark else 'Rounded_cut_lip',v,[(a*n+i,a*n+(i+1)%n,b*n+(i+1)%n,b*n+i) for i in range(n)],mat,uvs)
 tube('Angled_branch',[(.40,0,.70),(.58,.015,.96),(.72,.02,1.12)],[.15,.125,.095],bark,9)
 # Moss follows the barrel curvature and drapes over both shoulders.
 vv=[];ff=[];nx=9;ny=7
 for j in range(ny):
  for i in range(nx):
   x=-.88+i/(nx-1)*1.38
   theta=(-.7+j/(ny-1)*1.45)*(1+.12*math.sin(i*1.7))
   radius=.444;vv.append((x,radius*math.sin(theta),.44+radius*math.cos(theta)))
 for j in range(ny-1):
  for i in range(nx-1):a=j*nx+i;ff.append((a,a+1,a+1+nx,a+nx))
 o=mesh('Surface_fitted_moss',vv,ff,moss);mod=o.modifiers.new('Moss_depth','SOLIDIFY');mod.thickness=.018;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)


def fern():
 # Five long fan fronds. Broad clipped lobes are concentrated above the tapered base.
 ends=[((0,.035,.45),.070),((-.27,.08,.36),.067),((.27,-.02,.37),.068),((-.41,.18,.20),.062),((.41,-.14,.21),.062)]
 rows=[(0,0),(.18,.24),(.30,.50),(.36,.69),(.40,.74),(.425,.40),(.45,.39),
       (.465,.85),(.52,.95),(.58,.98),(.60,.92),(.615,.48),(.65,.45),
       (.665,.95),(.71,1),(.765,.93),(.78,.86),(.795,.42),(.82,.40),
       (.84,.78),(.88,.84),(.94,.50),(1,0)]
 for i,(end,width) in enumerate(ends):
  tip=Vector(end);side=tip.cross(Vector((0,1,.65))).normalized();v=[];f=[]
  for t,w in rows:
   center=tip*t+Vector((0,-.085*math.sin(math.pi*t),.022*math.sin(math.pi*t)))
   for sign in [-1,0,1]:
    pos=center+side*sign*w*width
    if sign==0:pos.y+=.008*math.sin(math.pi*t)
    v.append(pos)
  for j in range(len(rows)-1):
   q=j*3;r=q+3;f += [(q,q+1,r+1,r),(q+1,q+2,r+2,r+1)]
  obj=mesh('Sculpted_frond_'+str(i),v,f,fernmat)
  mod=obj.modifiers.new('Frond_depth','SOLIDIFY');mod.thickness=.012;bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)

def stone_block(name,center,scale,mat,seed=0):
 # Broken asymmetric silhouette, slanted planes and a broad weathered crown.
 randomizer=random.Random(42+seed);n=7;v=[];f=[]
 radii=[randomizer.uniform(.84,1.14) for _ in range(n)]
 heights=[randomizer.uniform(-.14,.14) for _ in range(n)]
 for j,(height,radius) in enumerate([(-1,.77),(-.52,1),(.62,.90),(1,.67)]):
  for k in range(n):
   a=k/n*TAU+.13
   v.append((center[0]+scale[0]*radius*radii[k]*math.cos(a)+.07*scale[0]*j,
             center[1]+scale[1]*radius*radii[k]*math.sin(a)-.045*scale[1]*j,
             center[2]+scale[2]*(height+heights[k]*(1 if j>1 else .3))))
 for j in range(3):
  for k in range(n):f.append((j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k))
 f.append(tuple(3*n+k for k in range(n)));f.append(tuple(range(n-1,-1,-1)))
 return mesh(name,v,f,mat)

def conform_moss(obj, supports):
 verts=[];faces=[]
 for rock in supports:
  start=len(verts);verts.extend([rock.matrix_world@v.co for v in rock.data.vertices]);faces.extend([tuple(start+i for i in p.vertices) for p in rock.data.polygons])
 bvh=BVHTree.FromPolygons(verts,faces)
 for vertex in obj.data.vertices:
  co=vertex.co;hit=bvh.ray_cast(Vector((co.x,co.y,5)),Vector((0,0,-1)))
  if hit[0] is not None:co.z=hit[0].z+.015
  else:
   nearest=bvh.find_nearest(co)
   if nearest[0] is not None:vertex.co=nearest[0]+nearest[1]*.015

def rocks():
 for i,(c,sc) in enumerate([((0,0,.22),(.50,.39,.37)),((.42,.18,.11),(.34,.28,.19)),((-.37,-.2,.065),(.28,.22,.13))]):
  support=stone_block('Weathered_boulder',c,sc,stones[i%3],i)
  # Irregular moss patch follows the sloping upper plane; never a regular green coin.
  v=[(c[0]+.04,c[1],c[2]+sc[2]+.027)]
  for k in range(7):
   a=k/7*TAU;rr=.55+.12*math.sin(k*2.7)
   v.append((c[0]+.13*sc[0]+sc[0]*rr*math.cos(a),c[1]+sc[1]*rr*math.sin(a),c[2]+sc[2]*(.95+.06*math.sin(k*2.1))))
  patch=mesh('Fitted_moss_patch',v,[(0,k+1,(k+1)%7+1) for k in range(7)],moss);conform_moss(patch,[support])

def flowers(blue=True):
 for i in range(8):
  a=rng.random()*TAU;r=rng.random()*.31;x=r*math.cos(a);y=r*math.sin(a);z=.12+rng.random()*.16
  tube('Stem',[(x,y,0),(x,y,z)],[.010,.005],fernmat,5)
  for j in range(5):
   a=j*TAU/5;blob('Petal',(x+.043*math.cos(a),y+.043*math.sin(a),z),(.046,.030,.019),flowerblue if blue else cream,1)
  blob('Golden_center',(x,y,z+.009),(.015,.015,.012),gold,1)
  leaf('Ground_leaf',(x,y,.01),.13,.035,rng.random()*TAU,.04,fernmat)

def shrub():
 for i in range(24):
  a=rng.random()*TAU;z=rng.random()*.3;base=(math.cos(a)*.14,math.sin(a)*.14,z)
  leaf('Broad_leaf',base,rng.uniform(.14,.26),rng.uniform(.06,.09),a,.10,leaves[i%3])

def mushrooms():
 for x,y,h,r in [(0,0,.28,.15),(.23,.08,.17,.095),(-.15,.16,.13,.085)]:
  tube('Cream_stalk',[(x,y,0),(x+.01,y,h)],[.035,.025],cream,7)
  verts=[(x,y,h+.085)];faces=[]
  for i in range(12):
   a=TAU*i/12;verts.append((x+r*math.cos(a),y+r*math.sin(a),h))
  for i in range(12):faces.append((0,i+1,(i+1)%12+1))
  faces.append(tuple(range(12,0,-1)));mesh('Copper_cap',verts,faces,copper)
  for i in range(3):
   a=i*TAU/3;blob('Cream_speck',(x+r*.45*math.cos(a),y+r*.45*math.sin(a),h+.059),(.020,.017,.006),cream,1)

def cliff():
 # A connected broad shelf module. Neighbour modules tuck into the terrain cap.
 supports=[]
 for i,(x,w,h,depth) in enumerate([(-.65,.58,1.62,.48),(.12,.58,1.53,.56),(.72,.42,1.65,.43)]):
  supports.append(stone_block('Fractured_slate_ledge',(x,0,h*.47),(w,depth,h*.55),stones[i],12+i))
 # Moss overhang has an irregular edge and drapes down the ledge face.
 v=[];f=[]
 for j in range(3):
  for i in range(13):
   x=-1.08+i*.18;y=[-.36,.13,.36][j]+.025*math.sin(i*2.2)
   z=1.58+.035*math.sin(i*1.2)-(.14+.04*math.sin(i*2.5) if j==2 else 0)
   v.append((x,y,z))
 for j in range(2):
  for i in range(12):a=j*13+i;f.append((a,a+1,a+14,a+13))
 patch=mesh('Connected_moss_lip',v,f,moss);conform_moss(patch,supports)

def fence():
 for x in [-.64,.64]:
  tube('Post',[(x,0,0),(x+.018,0,.9)],[.10,.085],bark,7)
  disk('Post_cut',(x+.018,0,.905),.085,wood,7)
 for z in [.34,.69]:tube('Rail',[(-.66,0,z),(.66,0,z-.025)],[.055,.055],bark,7)

def gate():
 for x in [-1.4,1.4]:
  tube('Gate_post',[(x,0,0),(x+.06,0,2.8)],[.15,.12],bark,9)
  disk('Post_top',(x+.06,0,2.805),.12,wood,9)
 tube('Lintel',[(-1.75,0,2.48),(1.75,0,2.53)],[.13,.13],bark,9)
 for x in [-1.34,1.46]:
  for z in [2.37,2.45,2.53,2.61]:
   tube('Rope_lashing',[(x-.18,-.15,z),(x+.18,-.15,z+.08)],[.028,.028],rope,6)

def reeds():
 for i in range(7):
  x=rng.uniform(-.22,.22);y=rng.uniform(-.22,.22);h=rng.uniform(.4,.72)
  leaf('Reed_blade',(x,y,0),.22,.025,rng.random()*TAU,h,fernmat)
  if i%2==0:
   tube('Reed_stem',[(x,y,0),(x,y,h)],[.01,.006],fernmat,5)
   tube('Cattail',[(x,y,h*.72),(x,y,h)],[.032,.028],copper,7)

def lily():
 for x,y,r in [(0,0,.24),(.34,.17,.16)]:
  vertices=[(x,y,.015)]+[(x+r*math.cos(i/16*TAU),y+r*math.sin(i/16*TAU),.015) for i in range(16)]
  mesh('Lily_pad',vertices,[(0,i+1,(i+1)%16+1) for i in range(1,15)],moss)

def butterfly():
 teal=material('Butterfly_dark_teal',(.035,.12,.14))
 blob('Thorax',(0,0,.012),(.024,.045,.022),teal,2)
 blob('Abdomen',(0,-.060,.009),(.018,.040,.017),teal,1)
 blob('Head',(0,.061,.017),(.027,.025,.026),teal,2)
 for sign in [-1,1]:
  tube('Curved_antenna',[(sign*.012,.08,.026),(sign*.026,.109,.033),(sign*.043,.133,.039)],[.004,.0035,.003],teal,6)
  blob('Antenna_tip',(sign*.043,.133,.039),(.009,.009,.008),teal,1)
  parent=bpy.data.objects.new('Wing_'+('L' if sign<0 else 'R'),None);bpy.context.collection.objects.link(parent)
  shapes=[(True,[(.01,.016),(.035,.067),(.074,.115),(.132,.153),(.156,.151),(.166,.133),(.164,.087),(.15,.039),(.132,.013),(.090,.006)]),(False,[(.013,.004),(.075,-.006),(.112,-.021),(.122,-.050),(.111,-.081),(.090,-.101),(.064,-.101),(.048,-.089),(.023,-.044)])]
  for upper,points in shapes:
   center=Vector((sum(x for x,y in points)/len(points),sum(y for x,y in points)/len(points)))
   verts=[];n=len(points)
   for inset,z in [(1,.004),(.92,.017)]:
    for x,y in points:
     q=center+(Vector((x,y))-center)*inset;verts.append((sign*q.x,q.y,z+q.x*.12))
   faces=[tuple(range(n,2*n)),tuple(range(n-1,-1,-1))]+[(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
   o=mesh('Blue_upper_wing' if upper else 'Cream_lower_wing',verts,faces,wingblue if upper else cream);o.parent=parent


def terrain_tile(kind):
 def field(x,y):
  if kind in ['grass','slope']:return 1.
  if kind=='clearing':return -1.
  if kind=='straight':return abs(x)-.5
  if kind=='junction':return min(abs(x),abs(y))-.5
  return abs(math.hypot(x+1,y-1)-1)-.5
 def clipped(points,sign):
  out=[]
  for a,b in zip(points,points[1:]+points[:1]):
   fa=field(*a)*sign;fb=field(*b)*sign
   if fa>=0:out.append(a)
   if (fa<0)!=(fb<0):
    t=fa/(fa-fb);out.append((a[0]+t*(b[0]-a[0]),a[1]+t*(b[1]-a[1])))
  return out
 verts=[];faces=[];uv=[];owners=[];area=0.;n=24
 for j in range(n):
  for i in range(n):
   x=-1+i*2/n;y=-1+j*2/n;d=2/n
   for tri in [[(x,y),(x+d,y),(x+d,y+d)],[(x,y),(x+d,y+d),(x,y+d)]]:
    for sign in [1,-1]:
     poly=clipped(tri,sign)
     if len(poly)<3:continue
     start=len(verts)
     for px,py in poly:
      verts.append((px,py,(px+1)*.25 if kind=='slope' else 0));uv.append(((px+1)/2,(py+1)/2))
     faces.append(tuple(range(start,len(verts))));owners.append(0 if sign==1 else 1)
     area+=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))*.5
 assert abs(area-4)<1e-5,(kind,area)
 o=mesh('Exclusive_ground_surface',verts,faces,grassmat,uv);o.data.materials.append(sandmat)
 for p,owner in zip(o.data.polygons,owners):
  p.material_index=owner
  if owner:
   for li in p.loop_indices:o.data.uv_layers.active.data[li].uv.x+=.5
 for a,b in [((-1,-1),(-1,1)),((-1,1),(1,1)),((1,1),(1,-1)),((1,-1),(-1,-1))]:
  za=(a[0]+1)*.25 if kind=='slope' else 0;zb=(b[0]+1)*.25 if kind=='slope' else 0
  mesh('Tile_edge',[(a[0],a[1],za),(b[0],b[1],zb),(b[0],b[1],-.2),(a[0],a[1],-.2)],[(0,1,2,3)],moss)

BUILDERS={'forest_stump':stump,'forest_oak':oak,'forest_pine':pine,'forest_pine_b':lambda:pine(1),'forest_pine_c':lambda:pine(2),'forest_hollow_log':log,'forest_fern':fern,'forest_rocks':rocks,'forest_pebbles':lambda:[blob('Embedded_pebble',(x,y,.03),(r,r*.74,.07),stones[1],1) for x,y,r in [(0,0,.13),(.24,.14,.08),(-.21,.09,.07)]],'forest_flowers_blue':lambda:flowers(True),'forest_flowers_cream':lambda:flowers(False),'forest_shrub':shrub,'forest_mushrooms':mushrooms,'forest_cliff':cliff,'forest_fence':fence,'forest_gate':gate,'forest_reeds':reeds,'forest_lily':lily,'forest_butterfly':butterfly}
for kind in ['grass','straight','corner','junction','clearing','slope']:BUILDERS['forest_tile_'+kind]=lambda k=kind:terrain_tile(k)
if __name__=='__main__':
 for name,build in BUILDERS.items():
  if ONLY and name!=ONLY:continue
  bpy.ops.wm.read_factory_settings(use_empty=True);rng.seed(913+sum(map(ord,name)))
  scene=bpy.context.scene;scene.name=name+'_Production'
  bark=material('Quiet_bark',(.235,.139,.082));oakbark=material('Warm_oak_bark',(.40,.235,.112));cutedge=material('Golden_cut_bevel',(.66,.40,.17));wood=material('Honey_growth_rings',(.72,.47,.21),1)
  grassmat=material('Meadow_surface',(.27,.36,.13),2);sandmat=material('Warm_path',(.72,.48,.24),3)
  moss=material('Moss',(.26,.33,.12));fernmat=material('Fern',(.28,.39,.18))
  leaves=[material('Olive_leaf',(.20,.30,.16)),material('Sage_leaf',(.29,.38,.20)),material('Forest_leaf',(.14,.28,.18))]
  pines=[material('Pine_deep',(.045,.145,.112)),material('Pine_mid',(.05,.16,.12)),material('Pine_tip',(.060,.175,.126))]
  stones=[material('Slate_lilac',(.19,.175,.265)),material('Slate_light',(.25,.23,.32)),material('Slate_shadow',(.15,.16,.23))]
  dark=material('Wood_inside',(.095,.068,.034));cream=material('Warm_cream',(.89,.78,.50));gold=material('Pollen',(.94,.57,.13))
  flowerblue=material('Cornflower',(.28,.52,.79));wingblue=material('Butterfly_blue',(.39,.63,.77));copper=material('Mushroom_copper',(.66,.27,.075));rope=material('Hemp',(.57,.39,.19))
  build()
  for obj in scene.objects:
   if obj.type=='MESH':
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
  dest=ROOT/'assets/environment'/name;dest.mkdir(parents=True,exist_ok=True)
  scene.render.fps=60
  for im in bpy.data.images:
   if im.filepath:im.pack()
  bpy.ops.wm.save_as_mainfile(filepath=str(dest/'source.blend'))
  if EXPORT:
   for obj in scene.objects:obj.select_set(True)
   bpy.ops.export_scene.gltf(filepath=str(dest/'model.glb'),export_format='GLB',use_selection=True,export_animations=False)
  print('FOREST_ASSET',name,sum(len(o.data.polygons) for o in scene.objects if o.type=='MESH'))
