"""Saved orthographic review cameras for an existing source, no character geometry changes.
Set REVIEW_ID and REVIEW_COLLECTION when executing through Blender MCP.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
asset_id=globals().get('REVIEW_ID','red_panda')
collection_name=globals().get('REVIEW_COLLECTION','RedPanda_Character')
s=bpy.context.scene;c=bpy.data.collections[collection_name]
studio=bpy.data.collections.get('Review_Studio')
if not studio:
 studio=bpy.data.collections.new('Review_Studio');s.collection.children.link(studio)
 world=bpy.data.worlds.new('Review_World');world.use_nodes=True
 world.node_tree.nodes['Background'].inputs[0].default_value=(.35,.32,.29,1)
 world.node_tree.nodes['Background'].inputs[1].default_value=.6;s.world=world
 def link(obj):
  for old in list(obj.users_collection):old.objects.unlink(obj)
  studio.objects.link(obj)
 bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002));floor=bpy.context.object;floor.name='Review_Floor';link(floor)
 mat=bpy.data.materials.new('Review_Greige');mat.diffuse_color=(.28,.26,.24,1);floor.data.materials.append(mat)
 for name,pos,power,size in [('Key',(-3,4,5),430,4),('Fill',(3,2,3),210,3),('Rim',(1,-3,4),360,3)]:
  data=bpy.data.lights.new('Review_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size
  obj=bpy.data.objects.new(data.name,data);studio.objects.link(obj);obj.location=pos;obj.rotation_euler=(Vector((0,0,.6))-obj.location).to_track_quat('-Z','Y').to_euler()
 for name,pos,aim in [('front',(0,5,.62),(0,0,.62)),('left',(5,0,.62),(0,0,.62)),('back',(0,-5,.62),(0,0,.62)),('right',(-5,0,.62),(0,0,.62)),('front_quarter',(3,4,2.2),(0,-.05,.60)),('rear_quarter',(-3,-4,2.2),(0,-.05,.60)),('game',(3,3,5.6),(0,-.05,.60))]:
  data=bpy.data.cameras.new('Review_'+name);data.type='ORTHO';data.ortho_scale=1.55 if name in ['front','back'] else 1.68
  obj=bpy.data.objects.new(data.name,data);studio.objects.link(obj);obj.location=pos;obj.rotation_euler=(Vector(aim)-obj.location).to_track_quat('-Z','Y').to_euler()
s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
s.render.resolution_x=700;s.render.resolution_y=700;s.render.resolution_percentage=100
s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
out=ROOT/'captures'/asset_id/'reference_review';out.mkdir(parents=True,exist_ok=True)
views=globals().get('REVIEW_VIEWS',['front','left','back','right','front_quarter','rear_quarter','game'])
for name in views:
 s.camera=studio.objects['Review_'+name];s.render.filepath=str(out/(globals().get('REVIEW_PREFIX','neutral_')+name+'.png'))
 bpy.ops.render.render(write_still=True)
s.camera=studio.objects['Review_front_quarter']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters'/asset_id/'source.blend'))
result={'renders':[str(out/(globals().get('REVIEW_PREFIX','neutral_')+n+'.png')) for n in views]}
