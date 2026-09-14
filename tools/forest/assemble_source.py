"""Editable Blender assembly from the exact saved Godot world placement manifest."""
import bpy,json,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.name='ForestOpening_Assembly'
items=json.loads((ROOT/'assets/environment/forest_layout.json').read_text());collections={}
for name in set(p['asset'] for p in items)|{'forest_ground'}:
 path=ROOT/'assets/environment'/name/'source.blend'
 with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=src.objects
 collection=bpy.data.collections.new(name+'_Asset');collections[name]=collection
 for obj in dst.objects:
  if obj:collection.objects.link(obj)
for i,item in enumerate([dict(asset='forest_ground',x=0,y=0,z=0,scale=1,yaw=0)]+items):
 obj=bpy.data.objects.new(item['asset']+'_'+str(i),None);scene.collection.objects.link(obj);obj.instance_type='COLLECTION';obj.instance_collection=collections[item['asset']]
 obj.location=(item['x'],-item['z'],item['y']);obj.rotation_euler.z=-math.radians(item['yaw']);obj.scale=(item['scale'],)*3
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/environment/forest_opening.blend'))
print('SAVED_FOREST_ASSEMBLY',len(items))
