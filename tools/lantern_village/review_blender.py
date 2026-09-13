"""Render current editable objects from matching orthographic review angles."""
import bpy,math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
SOURCE=globals().get('REVIEW_SOURCE','LanternPanda_Production');LABEL=globals().get('REVIEW_LABEL','panda_neutral');SIZE=globals().get('REVIEW_SIZE',1.6);TARGET=Vector(globals().get('REVIEW_TARGET',(0,0,.59)))
source=bpy.data.scenes[SOURCE]
review=bpy.data.scenes.new('Review_'+LABEL);bpy.context.window.scene=review
for col in source.collection.children:review.collection.children.link(col)
review.frame_set(source.frame_current)
review.render.engine='CYCLES';review.cycles.samples=24;review.cycles.use_denoising=True
review.render.resolution_x=640;review.render.resolution_y=640;review.render.resolution_percentage=100
review.world=bpy.data.worlds.new('ReviewWorld');review.world.use_nodes=True;review.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.65,.65,1);review.world.node_tree.nodes['Background'].inputs[1].default_value=.5
review.view_settings.view_transform='AgX'
light_scale=globals().get('REVIEW_LIGHT_SCALE',1.0)
for name,pos,power,size in [('Key',(3,4,5),450,4),('Fill',(-3,2,3),220,4),('Rim',(1,-3,3),300,3)]:
 data=bpy.data.lights.new(name,'AREA');data.energy=power*light_scale**2;data.shape='DISK';data.size=size*light_scale
 obj=bpy.data.objects.new(name,data);review.collection.objects.link(obj);obj.location=Vector(pos)*light_scale;obj.rotation_euler=(TARGET-obj.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,globals().get('REVIEW_FLOOR_Z',-.008)));floor=bpy.context.object
floor.hide_render=not globals().get('REVIEW_FLOOR',True)
mat=bpy.data.materials.new('ReviewGround');mat.diffuse_color=(.65,.61,.55,1);floor.data.materials.append(mat)
data=bpy.data.cameras.new('ReviewCamera');camera=bpy.data.objects.new('ReviewCamera',data);review.collection.objects.link(camera);review.camera=camera;data.type='ORTHO';data.ortho_scale=SIZE
out=ROOT/'captures/lantern_village'/LABEL;out.mkdir(parents=True,exist_ok=True)
views=globals().get('REVIEW_VIEWS',{'front':(0,6,.0),'left':(-6,0,0),'back':(0,-6,0),'right':(6,0,0),'three_quarter':(4,6,2),'game':(4,4,6.7)})
for name,offset in views.items():
 camera.location=TARGET+Vector(offset);camera.rotation_euler=(TARGET-camera.location).to_track_quat('-Z','Y').to_euler();review.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
bpy.context.window.scene=source
result={'renders':str(out)}
