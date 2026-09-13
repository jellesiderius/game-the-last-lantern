"""Separate orange blade, gold hardware and a wrapped brown grip. Local +Y follows blade."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');root=ROOT/'assets/weapons/amber_sword';root.mkdir(parents=True,exist_ok=True)
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
assert not bpy.data.collections.get('AmberSword_Export')
c=bpy.data.collections.new('AmberSword_Export');s.collection.children.link(c)
def mat(name,color,metal=0,glow=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*color,1);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.4 if metal else .65
 if glow:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
 return m
blade=mat('Blade_Amber_Core',(1,.15,.008),0,2.5);edge=mat('Blade_Amber_Edge',(1,.46,.065),0,3.)
gold=mat('Sword_Gold_Hardware',(.58,.31,.065),.7);leather=mat('Sword_Dark_Leather',(.06,.026,.011));wrap=mat('Sword_Grip_Wrap',(.12,.053,.022))
def put(o,name,m):
 o.name=name
 for coll in list(o.users_collection):coll.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(m);return o
v=[]
for y,width,thickness in [(.135,.080,.023),(.69,.077,.024),(.75,.056,.018)]:
 v.extend([(thickness,y,0),(0,y,width),(-thickness,y,0),(0,y,-width)])
v.append((0,.87,0));f=[]
for j in range(2):
 for i in range(4):f.append((j*4+i,j*4+(i+1)%4,(j+1)*4+(i+1)%4,(j+1)*4+i))
for i in range(4):f.append((8+i,8+(i+1)%4,12))
f.append((3,2,1,0))
mesh=bpy.data.meshes.new('Faceted_Blade');mesh.from_pydata(v,[],f);mesh.update();o=bpy.data.objects.new('Amber_Blade',mesh);c.objects.link(o);mesh.materials.append(blade);mesh.materials.append(edge)
for p in mesh.polygons:p.material_index=1 if p.index%4 in [1,3] else 0
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.108,0));o=put(bpy.context.object,'Gold_Crossguard',gold);o.dimensions=(.07,.052,.28);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);m=o.modifiers.new('Rounded guard edges','BEVEL');m.width=.012;m.segments=2;bpy.ops.object.modifier_apply(modifier=m.name)
bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.034,depth=.235,location=(0,-.022,0),rotation=(math.pi/2,0,0));put(bpy.context.object,'Leather_Grip',leather)
curve=bpy.data.curves.new('Spiral_Grip','CURVE');curve.dimensions='3D';curve.bevel_depth=.0055;curve.bevel_resolution=2
spline=curve.splines.new('POLY');spline.points.add(100)
for i,p in enumerate(spline.points):
 t=i/100;a=t*math.tau*5;p.co=(math.cos(a)*.035,-.137+t*.222,math.sin(a)*.035,1)
o=bpy.data.objects.new('Grip_Wrapping',curve);c.objects.link(o);curve.materials.append(wrap)
for ob in bpy.context.selected_objects:ob.select_set(False)
o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
bpy.ops.mesh.primitive_uv_sphere_add(segments=10,ring_count=5,radius=.059,location=(0,-.175,0));o=put(bpy.context.object,'Gold_Pommel',gold);o.scale=(1,.7,1);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
# Join keeps named material slots; the entire weapon is one separate mesh object.
for ob in bpy.context.selected_objects:ob.select_set(False)
for ob in c.objects:ob.select_set(True)
bpy.context.view_layer.objects.active=c.objects['Amber_Blade'];bpy.ops.object.join();sword=bpy.context.object;sword.name='Amber_Sword'
weapon_scene=bpy.data.scenes.new('AmberSword_Production');weapon_scene.unit_settings.system='METRIC'
source=sword.copy();source.data=sword.data;weapon_scene.collection.objects.link(source);source.name='Amber_Sword_Source'
bpy.context.window.scene=weapon_scene
bpy.data.libraries.write(str(root/'source.blend'),{weapon_scene},fake_user=True)
for ob in bpy.context.selected_objects:ob.select_set(False)
source.select_set(True);bpy.context.view_layer.objects.active=source
bpy.ops.export_scene.gltf(filepath=str(root/'model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False)
bpy.context.window.scene=s
constraint=sword.constraints.new('COPY_TRANSFORMS');constraint.name='Right hand preview attachment';constraint.target=bpy.data.objects['Capybara_Rig'];constraint.subtarget='sword_socket'
rig=bpy.data.objects['Capybara_Rig'];rig.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/capybara/source.blend'))
result={'weapon':str(root/'model.glb'),'mesh':sword.name,'materials':[m.name for m in sword.data.materials],'grip':'Right hand socket; source axis +Y'}
