"""Separate reference-sized amber sword and lantern, editable and exported as real meshes."""
import bpy,sys,math
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
M={n:material(n,col,r,metal) for n,col,r,metal in [('Amber_Blade', (1,.69,.18),.35,.05),('Amber_Edge',(1,.89,.49),.32,.05),('Lantern_Gold',(.68,.44,.13),.4,.65),('Lantern_Grip',(.26,.16,.10),.7,0),('Lantern_Glass',(1,.61,.13),.3,0)]}
for n,power in [('Amber_Blade',1.4),('Amber_Edge',2.2),('Lantern_Glass',2.)]:
 p=M[n].node_tree.nodes['Principled BSDF'];p.inputs['Emission Color'].default_value=(1,.62,.10,1);p.inputs['Emission Strength'].default_value=power

def begin(name):
 global s,c
 s=bpy.data.scenes.new('Asset_'+name);bpy.context.window.scene=s;c=bpy.data.collections.new('Equipment_'+name);s.collection.children.link(c);s.unit_settings.system='METRIC'
def box(name,pos,size,mat,bevel=.005):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for col in list(o.users_collection):col.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(M[mat]);activate(o)
 mod=o.modifiers.new('Crafted bevel','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def cyl(name,pos,r,d,mat):
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d,location=pos);o=bpy.context.object;o.name=name
 for col in list(o.users_collection):col.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(M[mat]);return o
def finish(name,folder):
 d=ROOT/folder/name;d.mkdir(parents=True,exist_ok=True)
 for o in bpy.context.selected_objects:o.select_set(False)
 for o in c.objects:o.select_set(True)
 bpy.data.libraries.write(str(d/'source.blend'),{s},fake_user=True)
 bpy.ops.export_scene.gltf(filepath=str(d/'model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False)
begin('sunblade')
# The grip origin is shared by the closed hand. Blade points +Y in Blender / -Z in Godot.
g=cyl('Wrapped_Grip',(0,0,0),.023,.11,'Lantern_Grip');g.rotation_euler.x=math.pi/2
for y in [-.042,-.022,0,.022,.042]:
 o=cyl('Grip_Band',(0,y,0),.024,.004,'Lantern_Gold');o.rotation_euler.x=math.pi/2
box('Golden_Guard',(0,.065,0),(.155,.035,.045),'Lantern_Gold',.012)
ellipsoid('Pommel',(0,-.069,0),(.031,.025,.025),c,M['Lantern_Gold'],16,12)
# Diamond section retains visible geometry and bright bevelled cutting edges.
verts=[]
for y,w,h in [(.082,.063,.018),(.345,.055,.014),(.472,.001,.001)]:
 verts += [(-w,y,0),(0,y,h),(w,y,0),(0,y,-h)]
faces=[(0,3,2,1)]
for j in range(2):
 for i in range(4):faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
blade=mesh_object('Faceted_Amber_Blade',verts,faces,c,M['Amber_Blade'])
for f in blade.data.polygons:f.use_smooth=False
for sign in [-1,1]:
 strip=[(sign*.063,.082,0),(sign*.055,.345,0),(0,.472,0),(sign*.048,.345,.007),(sign*.055,.082,.007)]
 o=mesh_object('Bright_Edge',strip,[(0,1,3,4),(1,2,3)],c,M['Amber_Edge'])
finish('sunblade','assets/weapons')
begin('hand_lantern')
# Handle upper arc sits inside the carrying hand; lamp body hangs below it.
points=[]
for i in range(65):
 a=math.tau*i/64;points.append((.040*math.sin(a),0,-.024+.040*math.cos(a),.006))
tube('Carry_Ring',points,c,M['Lantern_Gold'],10,1)
for z in [-.087,-.222]:
 cyl('Rim',(0,0,z),.072,.022,'Lantern_Gold')
box('Warm_Glass',(0,0,-.154),(.087,.087,.12),'Lantern_Glass',.009)
for x in [-.048,.048]:
 for y in [-.048,.048]:box('Cage_Post',(x,y,-.153),(.012,.012,.13),'Lantern_Gold',.002)
bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.073,radius2=.042,depth=.042,location=(0,0,-.059));o=bpy.context.object;o.name='Tapered_Cap'
for col in list(o.users_collection):col.objects.unlink(o)
c.objects.link(o);o.data.materials.append(M['Lantern_Gold'])
finish('hand_lantern','assets/props')
result={'assets':['sunblade','hand_lantern']}
