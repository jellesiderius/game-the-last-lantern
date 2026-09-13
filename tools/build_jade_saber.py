"""Standalone jade blade with bronze leaf guard. Uses +Y blade / Z broad-face normal."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
assert not bpy.data.collections.get('Jade_Saber'),'Preserve existing weapon geometry.'
s=bpy.data.scenes.new('JadeSaber_Production');bpy.context.window.scene=s;c=bpy.data.collections.new('Jade_Saber');s.collection.children.link(c)
s.unit_settings.system='METRIC'
jade=material('Jade_Blade',(.04,.66,.40),.28,.12)
bsdf=jade.node_tree.nodes['Principled BSDF'];bsdf.inputs['Emission Color'].default_value=(.005,.7,.30,1);bsdf.inputs['Emission Strength'].default_value=1.8
edge=material('Jade_Luminous_Edge',(.57,1,.78),.24,.15);b=edge.node_tree.nodes['Principled BSDF'];b.inputs['Emission Color'].default_value=(.18,1,.5,1);b.inputs['Emission Strength'].default_value=3.
bronze=material('Saber_Bronze',(.59,.36,.16),.32,.76);leather=material('Saber_Leather',(.155,.09,.054),.78);wrap=material('Saber_Grip_Bands',(.62,.44,.28),.57)
outline=smooth_curve([(-.066,.14),(-.078,.32),(-.085,.49),(-.045,.61),(.04,.692),(.177,.724),(.113,.673),(.060,.604),(.043,.517),(.057,.31),(.064,.14)],6,True)
center=Vector((0,.435));verts=[];faces=[];n=len(outline)
for side in [1,-1]:
 for radius in [0,.28,.65,.91,1.]:
  for point in outline:
   xy=center+(point-center)*radius;verts.append((xy.x,xy.y,side*(.017*(1-radius)+.0018)))
 for j in range(4):
  for i in range(n):
   off=(0 if side==1 else 5*n);a=off+j*n+i;b=off+j*n+(i+1)%n;faces.append((a,b,b+n,a+n))
for i in range(n):faces.append((4*n+i,4*n+(i+1)%n,9*n+(i+1)%n,9*n+i))
blade=mesh_object('Jade_Curved_Blade',verts,faces,c,jade);blade.data.materials.append(edge)
for f in blade.data.polygons:
 # Bright outer cutting edge, darker spine. Keep the broad faceted surface readable.
 region=f.index%(4*n);segment=f.index%n
 f.material_index=1 if (region//n==3 and segment<int(n*.50)) or f.index>=8*n else 0
 f.use_smooth=False
# Grip centre at origin; blade begins .14 m forward of it.
grip=tube('Leather_Grip',[(0,-.103,0,.020),(0,-.090,0,.025),(0,.088,0,.024),(0,.110,0,.020)],c,leather,16,2)
for i in range(5):
 y=-.077+i*.038
 ring=tube('Grip_Band_'+str(i),[(0,y-.004,0,.0255),(0,y+.004,0,.0255)],c,wrap,16,1)
pommel=ellipsoid('Bronze_Pommel',(0,-.13,0),(.032,.031,.027),c,bronze,12,8)
collar=ellipsoid('Bronze_Collar',(0,.122,0),(.045,.025,.034),c,bronze,16,12)
for sign in [-1,1]:
 leaf_outline=smooth_curve([(sign*.006,.143),(sign*.065,.167),(sign*.127,.137),(sign*.153,.102),(sign*.094,.095),(sign*.038,.111)],5,True)
 center=sum(leaf_outline,Vector((0,0)))/len(leaf_outline);vertices=[];faces=[];N=len(leaf_outline)
 for z,r in [(.032,0),(.029,.45),(.004,1.),(-.008,1.),(-.017,0)]:
  for p in leaf_outline:
   q=center+(p-center)*r;vertices.append((q.x,q.y,z))
 for j in range(4):
  for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
 mesh_object('Leaf_Guard_'+str(sign),vertices,faces,c,bronze)
 vein=tube('Leaf_Vein_'+str(sign),[(sign*.014,.143,.030,.0035),(sign*.078,.135,.032,.003),(sign*.14,.106,.008,.001)],c,bronze,10,6)
for obj in bpy.data.objects:obj.select_set(False)
for obj in c.objects:obj.select_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/weapons/jade_saber/source.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/weapons/jade_saber/model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_yup=True)
result={'source':bpy.data.filepath,'objects':[o.name for o in c.objects],'blade_tip':[.177,.724,0]}
