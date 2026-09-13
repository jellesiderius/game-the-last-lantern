"""Fit facial shells against actual head/muzzle surfaces; keep compatible rigid head skin."""
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character'];rig=c.objects['LanternPanda_Rig']
rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
bpy.data.libraries.write(str(ROOT/'assets/characters/red_panda/checkpoints/before_facial_contact_fix.blend'),{s},fake_user=True)
head=c.objects['Head'];tree=BVHTree.FromPolygons([v.co for v in head.data.vertices],[list(p.vertices) for p in head.data.polygons]);report={}
for prefix,old_center,embed in [('Brow_',.276,.0005),('Eye_',.289,.0000)]:
 for side in ['L','R']:
  o=c.objects[prefix+side];count=0
  for v in o.data.vertices:
   hit=tree.ray_cast(Vector((v.co.x,1,v.co.z)),Vector((0,-1,0)))
   if hit[0]:v.co.y=hit[0].y+(v.co.y-old_center)+embed;count+=1
  report[o.name]={'fitted_vertices':count,'skin':'head'}
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result=report
