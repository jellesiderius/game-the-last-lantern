"""Rebuild the two checkpointed draft props to the supplied detailed turnarounds."""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
gold=material('Amber_Brass',(.70,.47,.16),.4,.6)
leather=material('Amber_Leather',(.28,.17,.105),.78)
wrap=material('Amber_Leather_Wrap',(.34,.21,.13),.76)
blade_mat=material('Amber_Crystal',(1,.69,.14),.34,.05)
edge_mat=material('Amber_Cutting_Edge',(1,.9,.47),.36)
glass=material('Lantern_Amber_Glass',(1,.56,.10),.35)
for mat,power,col in [(blade_mat,1.5,(1,.58,.07,1)),(edge_mat,2.,(1,.83,.27,1)),(glass,.3,(1,.50,.08,1))]:
    p=mat.node_tree.nodes['Principled BSDF'];p.inputs['Emission Color'].default_value=col;p.inputs['Emission Strength'].default_value=power
glass.node_tree.nodes['Principled BSDF'].inputs['Alpha'].default_value=.18
glass.diffuse_color=(*glass.diffuse_color[:3],.18);glass.surface_render_method='DITHERED'
def begin(key,folder):
    global scene,c
    old=bpy.data.scenes['Asset_'+key];d=ROOT/folder/key
    checkpoint=d/'checkpoints/first_draft.blend';checkpoint.parent.mkdir(parents=True,exist_ok=True)
    if not checkpoint.exists():bpy.data.libraries.write(str(checkpoint),{old},fake_user=True)
    old.name='Draft_'+key
    scene=bpy.data.scenes.new('Asset_'+key);bpy.context.window.scene=scene;scene.unit_settings.system='METRIC'
    c=bpy.data.collections.new('Detail_'+key);scene.collection.children.link(c)
def bevel(o,amount=.004):
    activate(o);mod=o.modifiers.new('Soft metal edges','BEVEL');mod.width=amount;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Planar highlights','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def box(name,pos,size,mat=gold,rounding=.004):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for col in list(o.users_collection):col.objects.unlink(o)
    c.objects.link(o);o.data.materials.append(mat)
    if rounding:bevel(o,rounding)
    return o
def cylinder(name,pos,radius,depth,mat=gold,vertices=16,axis='Z'):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos);o=bpy.context.object;o.name=name
    for col in list(o.users_collection):col.objects.unlink(o)
    c.objects.link(o);o.data.materials.append(mat)
    if axis=='Y':o.rotation_euler.x=math.pi/2
    return bevel(o,.003)
def beam(name,a,b,width=.008,depth=.009):
    a=Vector(a);b=Vector(b);o=box(name,(a+b)/2,(width,depth,(b-a).length),gold,.0015);o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o
def crystal(name,rings,mat=blade_mat):
    verts=[];faces=[]
    for y,w,h in rings:verts.extend([(-w,y,0),(0,y,h),(w,y,0),(0,y,-h)])
    faces.append((3,2,1,0))
    for j in range(len(rings)-1):
        for i in range(4):faces.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
    faces.append(tuple((len(rings)-1)*4+i for i in range(4)))
    o=mesh_object(name,verts,faces,c,mat)
    for f in o.data.polygons:f.use_smooth=False
    return o
def finish(key,folder):
    bpy.context.view_layer.update();d=ROOT/folder/key
    bpy.data.libraries.write(str(d/'source.blend'),{scene},fake_user=True)
    for o in bpy.data.objects:o.select_set(False)
    for o in c.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(d/'model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False)
begin('sunblade','assets/weapons')
cylinder('Dark_Grip',(0,-.005,0),.022,.108,leather,32,'Y')
points=[]
for i in range(161):
    t=i/160;a=t*math.tau*4;points.append((.023*math.cos(a),-.055+t*.104,.023*math.sin(a),.0025))
tube('Spiral_Leather_Wrap',points,c,wrap,8,1)
cylinder('Octagonal_Pommel',(0,-.071,0),.032,.025,gold,8,'Y')
# Curved U-shaped guard, chunky bevels and a clear open silhouette.
outline=[(-.093,.093),(-.080,.103),(-.067,.095),(-.060,.079),(-.032,.068),(0,.065),(.032,.068),(.060,.079),(.067,.095),(.080,.103),(.093,.093),(.097,.058),(.077,.043),(.036,.032),(0,.028),(-.036,.032),(-.077,.043),(-.097,.058)]
verts=[(x,y,z) for z in [-.023,.023] for x,y in outline];n=len(outline)
faces=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
guard=mesh_object('Curved_Golden_Guard',verts,faces,c,gold)
for f in guard.data.polygons:f.use_smooth=False
bevel(guard,.007)
blade=crystal('Broad_Amber_Crystal',[(.072,.040,.018),(.25,.053,.025),(.351,.068,.020),(.472,.0001,.0001)])
for side in [-1,1]:
    points=[(side*w,y,0,.0017) for y,w in [(.073,.040),(.25,.053),(.351,.068),(.472,0)]]
    tube('Bright_Cutting_Edge',points,c,edge_mat,8,1)
for side in [-1,1]:
    tube('Crystal_Ridge',[(0,.074,side*.018,.001),(0,.25,side*.025,.001),(0,.351,side*.020,.001),(0,.472,0,.0008)],c,edge_mat,8,1)
finish('sunblade','assets/weapons')
begin('hand_lantern','assets/props')
# Grip origin is the middle of the upper handle; total lamp height .25 m.
tube('Rounded_Rectangular_Handle',[(-.052,0,-.068,.008),(-.052,0,-.020,.008),(-.039,0,.002,.008),(0,0,.008,.008),(.039,0,.002,.008),(.052,0,-.020,.008),(.052,0,-.068,.008)],c,gold,16,8)
for x in [-.053,.053]:
    o=cylinder('Handle_Pivot',(x,0,-.065),.013,.015,gold,20);o.rotation_euler.y=math.pi/2
box('Upper_Rim',(0,0,-.089),(.15,.125,.023))
box('Lower_Rim',(0,0,-.234),(.15,.125,.026),rounding=.008)
# Four-sided tapered cap.
verts=[(x,y,z) for z,rx,ry in [(-.079,.073,.060),(-.058,.043,.033)] for x,y in [(-rx,-ry),(rx,-ry),(rx,ry),(-rx,ry)]]
o=mesh_object('Tapered_Cap',verts,[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],c,gold)
for f in o.data.polygons:f.use_smooth=False
bevel(o,.002)
cylinder('Top_Button',(0,0,-.053),.018,.010)
for x in [-.057,.057]:
    for y in [-.044,.044]:box('Corner_Post',(x,y,-.16),(.014,.014,.125),rounding=.002)
for y in [-.045,.045]:
    beam('Cross_Brace',(-.05,y,-.214),(.05,y,-.103),.007,.008)
    beam('Cross_Brace',(.05,y,-.214),(-.05,y,-.103),.007,.008)
    box('Amber_Window',(0,y,-.16),(.105,.001,.118),glass,0)
for x in [-.057,.057]:box('Side_Window',(x,0,-.16),(.001,.078,.118),glass,0)
o=crystal('Luminous_Heart',[(-.060,.0001,.0001),(-.036,.026,.024),(.036,.026,.024),(.062,.0001,.0001)])
o.rotation_euler.x=math.pi/2;o.location.z=-.16
finish('hand_lantern','assets/props')
bpy.context.window.scene=bpy.data.scenes['LanternPanda_Production']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'separate_assets':['sunblade','hand_lantern'],'source':'detailed reference construction'}
