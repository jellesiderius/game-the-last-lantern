"""Fit cape outside actual shoulder geometry and couple the shoulder panels to the local skin."""
import bpy,math,sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character'];rig=c.objects['LanternPanda_Rig']
rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
body=c.objects['Connected_Body'];cape=c.objects['Teal_Cape']
bvh=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
expanded=0
for v in cape.data.vertices:
 axis=Vector((v.co.x,v.co.y,0));radius=axis.length
 if radius<.01:continue
 axis.normalize();start=Vector((0,0,v.co.z));last=0
 for i in range(12):
  hit=bvh.ray_cast(start,axis,.70)
  if not hit[0]:break
  last=max(last,Vector((hit[0].x,hit[0].y,0)).length);start=hit[0]+axis*.0001
 if radius<last+.018:
  v.co.x=axis.x*(last+.018);v.co.y=axis.y*(last+.018);expanded+=1
# Near the shoulder, cloth and the body share the same local deformation.
for name in ['arm_upper_L','arm_upper_R','forearm_L','forearm_R']:
 if not cape.vertex_groups.get(name):cape.vertex_groups.new(name=name)
for v in cape.data.vertices:
 if v.co.z<.39 or abs(v.co.x)<.18:continue
 near=bvh.find_nearest(v.co)
 if not near[0]:continue
 poly=body.data.polygons[near[2]];bv=min((body.data.vertices[i] for i in poly.vertices),key=lambda p:(p.co-v.co).length_squared)
 factor=min(.65,max(0,(abs(v.co.x)-.18)/.09))
 old={cape.vertex_groups[g.group].name:g.weight*(1-factor) for g in v.groups}
 for g in bv.groups:
  name=body.vertex_groups[g.group].name
  if not cape.vertex_groups.get(name):cape.vertex_groups.new(name=name)
  old[name]=old.get(name,0)+g.weight*factor
 for group in cape.vertex_groups:group.remove([v.index])
 top=sorted(old.items(),key=lambda item:-item[1])[:4];total=sum(w for n,w in top)
 for n,w in top:
  if w>0:cape.vertex_groups[n].add([v.index],w/total,'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'fitted_cape_vertices':expanded}
