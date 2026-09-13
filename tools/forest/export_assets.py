"""Export reviewed sources; batch static parts by material on a disposable working copy."""
import bpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
for source in sorted((ROOT/'assets/environment').glob('forest_*/source.blend')):
 if source.parent.name=='forest_ground':continue
 bpy.ops.wm.open_mainfile(filepath=str(source))
 if source.parent.name!='forest_butterfly':
  groups={}
  for o in list(bpy.context.scene.objects):
   if o.type=='MESH' and len(o.data.materials)==1:groups.setdefault(o.data.materials[0].name,[]).append(o)
  for name,objects in groups.items():
   bpy.ops.object.select_all(action='DESELECT')
   for o in objects:o.select_set(True)
   bpy.context.view_layer.objects.active=objects[0]
   if len(objects)>1:bpy.ops.object.join()
   objects[0].name=name
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=str(source.parent/'model.glb'),export_format='GLB',use_selection=True,export_animations=False)
 print('EXPORTED_REVIEWED',source.parent.name,flush=True)
