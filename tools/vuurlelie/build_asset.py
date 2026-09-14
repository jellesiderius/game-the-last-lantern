"""Editable five-petal bronze Vuurlelie. Review saved source before --export.
Blender: --background --python tools/vuurlelie/build_asset.py [-- --export]
"""
import bpy, math, random, sys, json, shutil
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'assets/environment/vuurlelie';CAP=ROOT/'captures/vuurlelie/source'
DEST.mkdir(parents=True,exist_ok=True);CAP.mkdir(parents=True,exist_ok=True)
if '--export' in sys.argv:
 bpy.ops.wm.open_mainfile(filepath=str(DEST/'source.blend'))
 for obj in bpy.data.objects:obj.select_set(False)
 for obj in bpy.data.collections['Vuurlelie'].all_objects:obj.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(DEST/'model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_yup=True)
 print('VUURLELIE_EXPORTED');sys.exit()
if (DEST/'source.blend').exists():
 checkpoint=DEST/'checkpoints/before_rebuild.blend';checkpoint.parent.mkdir(exist_ok=True)
 if not checkpoint.exists():shutil.copy2(DEST/'source.blend',checkpoint)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.name='Vuurlelie_Production'
asset=bpy.data.collections.new('Vuurlelie');scene.collection.children.link(asset)
review=bpy.data.collections.new('Review');scene.collection.children.link(review)
rng=random.Random(193)
def mat(name,color,metal=0,rough=.6):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Metallic'].default_value=metal;n.inputs['Roughness'].default_value=rough
 return m
def rgb(h):
 vals=[int(h[i:i+2],16)/255 for i in (0,2,4)]
 return [v/12.92 if v<.04045 else ((v+.055)/1.055)**2.4 for v in vals]
bronze=[mat('Bronze_%d'%i,[c*f for c in rgb('795828')],.64,.48) for i,f in enumerate([.86,.95,1.0,1.07])]
inside=[mat('AmberInterior_%d'%i,[c*f for c in rgb('b98430')],.60,.43) for i,f in enumerate([.9,1,1.08])]
rim=mat('CastBronzeRim',rgb('bd934b'),.7,.38)
stone=[mat('PetrolStone_%d'%i,[c*f for c in rgb('3f4b45')],.03,.87) for i,f in enumerate([.84,.94,1.02,1.09])]
core=mat('Charcoal',rgb('3a2711'),.18,.89)
def mesh(name,verts,faces,mats,indices=None,parent=None):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
 ob=bpy.data.objects.new(name,me);asset.objects.link(ob)
 for m in mats:me.materials.append(m)
 for i,p in enumerate(me.polygons):p.material_index=indices[i] if indices else rng.randrange(len(mats))
 if parent:ob.parent=parent
 return ob
def ring_shape(name,rings,materials,n=10,caps=True):
 vs=[(r*math.cos(j*math.tau/n),r*math.sin(j*math.tau/n),z) for r,z in rings for j in range(n)]
 fs=[]
 for i in range(len(rings)-1):
  for j in range(n):fs.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
 if caps:fs += [tuple(reversed(range(n))),tuple((len(rings)-1)*n+j for j in range(n))]
 return mesh(name,vs,fs,materials)
ring_shape('StonePlinth',[(.22,0),(.225,.025),(.186,.12),(.16,.13)],stone,8)
ring_shape('BronzeFoot',[(.125,.13),(.143,.142),(.135,.168)],bronze+[rim],10)
ring_shape('FireBowl',[(.073,.163),(.083,.185),(.130,.25),(.134,.265),(.113,.265),(.083,.205)],bronze+[rim],10)
ring_shape('Core',[(.082,.205),(.082,.21)], [core],10)
ring_shape('GoldenBowlLip',[(.133,.252),(.135,.265),(.119,.268),(.112,.259)],[rim],10,False)
zs=[0,.09,.20,.29,.36,.41];ws=[.073,.135,.151,.12,.055,.002];xs=[0,.02,.022,-.015,-.075,-.129]
cols=[-1,-.65,0,.65,1]
vs=[]
for shell in range(2):
 for i,(z,w,x) in enumerate(zip(zs,ws,xs)):
  for c in cols:
   vs.append((x+.028*(1-c*c)*math.sin(math.pi*i/5)+shell*.016,c*w,z))
faces=[];ids=[]
for shell in range(2):
 for row in range(5):
  for col in range(4):
   a=shell*30+row*5+col;b=a+1;c=a+6;d=a+5
   pair=[(a,b,c),(a,c,d)] if (row+col)%2 else [(a,b,d),(b,c,d)]
   if shell==0:pair=[tuple(reversed(f)) for f in pair]
   faces+=pair;ids += [4+rng.randrange(3) if shell==0 else rng.randrange(4)]*2
# Thick bright perimeter closes both shells; no transparent leaf planes.
perimeter=[i*5 for i in range(6)]+[26,27,28,29]+[i*5+4 for i in range(4,-1,-1)]+[3,2,1]
for a,b in zip(perimeter,perimeter[1:]+perimeter[:1]):faces.append((a,b,b+30,a+30));ids.append(7)
for side in [-1,1]:
 for row in range(5):
  start=len(vs)
  for r,shrink in [(row,0),(row+1,0),(row+1,.007),(row,.007)]:
   vs.append((xs[r]-.002,side*max(.001,ws[r]-shrink),zs[r]))
  faces.append(tuple(range(start,start+4)));ids.append(7)
for i in range(5):
 phi=math.pi/2+i*math.tau/5
 pivot=bpy.data.objects.new('Petal%d'%i,None);asset.objects.link(pivot)
 pivot.location=(.13*math.cos(phi),.13*math.sin(phi),.16);pivot.rotation_euler.z=phi
 pivot.empty_display_size=.04;pivot['opening_degrees']=62.0
 mesh('BronzePetal%d'%i,vs,faces,bronze+inside+[rim],ids,pivot)
# Review lighting/material color is neutral; production collection has no review floor/light.
def move_review(ob):
 for c in list(ob.users_collection):c.objects.unlink(ob)
 review.objects.link(ob)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.003));floor=bpy.context.object;floor.name='ReviewGround';move_review(floor);floor.data.materials.append(mat('ReviewIvory',rgb('ddd5c6'),0,.9))
world=bpy.data.worlds.new('ReviewWorld');scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.42,.45,.46,1);world.node_tree.nodes['Background'].inputs[1].default_value=.55
for name,loc,power,size in [('Key',(-1.5,-2.5,3),190,2.0),('Fill',(2,-1,1.6),65,2),('Rim',(.1,2,2.5),140,1.5)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
 ob=bpy.data.objects.new(name,data);review.objects.link(ob);ob.location=loc;ob.rotation_euler=(Vector((0,0,.3))-ob.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add();cam=bpy.context.object;move_review(cam);scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=1.3
scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
scene.render.resolution_x=720;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
# Save authoring controls in the closed state. Opening is mechanical around each tangent hinge.
for i in range(5):bpy.data.objects['Petal%d'%i].rotation_euler.y=0
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'source.blend'))
views={'front':(0,-2,1.0),'left':(-2,0,1.0),'right':(2,0,1.0),'back':(0,2,1.0),'game':(1.4,-1.4,2.35)}
for state,angle in [('closed',0),('open',62)]:
 for i in range(5):bpy.data.objects['Petal%d'%i].rotation_euler.y=math.radians(angle)
 for name,loc in views.items():
  cam.location=loc;cam.rotation_euler=(Vector((0,0,.29))-cam.location).to_track_quat('-Z','Y').to_euler()
  scene.render.filepath=str(CAP/(state+'_'+name+'.png'));bpy.ops.render.render(write_still=True)
print('VUURLELIE_SOURCE_REVIEW_READY')
