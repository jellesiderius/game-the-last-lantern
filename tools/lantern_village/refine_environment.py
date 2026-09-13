"""Fix observed overlapping stair surfaces and roof-wall intersections in current sources."""
import bpy,sys,math
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate,mesh_object,smooth_curve
for key in ['stone_stairs','cottage','smithy']:
 s=bpy.data.scenes['Asset_'+key];bpy.context.window.scene=s;c=bpy.data.collections['Village_'+key]
 if key=='stone_stairs':
  o=c.objects['Continuous_Stair_Core']
  for v in o.data.vertices:
   if v.co.z>.10:v.co.z-=.09
 else:
  # The first draft's Catmull-Rom profile was too concave and cut the gable at the ridge.
  for o in list(c.objects):
   if not o.name.startswith('Roof_Panel'):continue
   side=1 if 'Panel_1_' in o.name else -1
   panel=int(o.name.split('_')[-1].split('.')[0]);oldname=o.name;bpy.data.objects.remove(o,do_unlink=True)
   width=3.50 if key=='cottage' else 3.42;depth=2.95
   points=[(0,3.02),(.28,2.86),(.90,2.49),(1.42,2.15),(width/2,2.055)]
   profile=smooth_curve(points,5);outline=[(side*p.x,p.y+.07) for p in profile]+[(side*p.x,p.y-.07) for p in reversed(profile)]
   n=len(outline);verts=[(x,d,z) for d in [-depth/8+.007,depth/8-.007] for x,z in outline]
   faces=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
   obj=mesh_object(oldname,verts,faces,c,bpy.data.materials['Village_Roof']);obj.location.y=-depth/2+(panel+.5)*depth/4
   for f in obj.data.polygons:f.use_smooth=False
   activate(obj);mod=obj.modifiers.new('Soft roof edges','BEVEL');mod.width=.035;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name)
   mod=obj.modifiers.new('Stable roof normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 for o in bpy.context.selected_objects:o.select_set(False)
 for o in c.objects:o.select_set(True)
 dest=ROOT/'assets/environment'/key
 bpy.data.libraries.write(str(dest/'source.blend'),{s},fake_user=True)
 bpy.ops.export_scene.gltf(filepath=str(dest/'model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_yup=True)
result={'refined':['stone_stairs','cottage','smithy']}
