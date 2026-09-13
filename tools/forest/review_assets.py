"""Current-source review, not generator previews. Five matching views per forest asset."""
import bpy, math, sys
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
only=next((a.split('=',1)[1] for a in sys.argv if a.startswith('--only=')),None)
for source in sorted((ROOT/'assets/environment').glob('forest_*/source.blend')):
 if source.parent.name=='forest_ground' or (only and source.parent.name!=only):continue
 bpy.ops.wm.open_mainfile(filepath=str(source));s=bpy.context.scene
 asset=list(s.objects)
 points=[o.matrix_world@Vector(v) for o in asset if o.type=='MESH' for v in o.bound_box]
 lo=Vector(tuple(min(p[i] for p in points) for i in range(3)));hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 target=(lo+hi)*.5;size=max(hi-lo)*1.35
 s.render.engine='CYCLES';s.cycles.samples=16;s.cycles.use_denoising=True;s.render.resolution_x=480;s.render.resolution_y=480;s.render.resolution_percentage=100
 s.world=bpy.data.worlds.new('ReviewWorld');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.65,.65,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.55
 s.view_settings.view_transform='AgX'
 for pos,power in [((3,4,5),400),((-3,2,3),180),((1,-3,4),220)]:
  data=bpy.data.lights.new('ReviewLight','AREA');data.energy=power*size*size*.13;data.shape='DISK';data.size=size*2
  obj=bpy.data.objects.new('ReviewLight',data);s.collection.objects.link(obj);obj.location=target+Vector(pos)*size/2;obj.rotation_euler=(target-obj.location).to_track_quat('-Z','Y').to_euler()
 data=bpy.data.cameras.new('ReviewCamera');cam=bpy.data.objects.new('ReviewCamera',data);s.collection.objects.link(cam);s.camera=cam;data.type='ORTHO';data.ortho_scale=size
 out=ROOT/'captures/forest/assets'/source.parent.name;out.mkdir(parents=True,exist_ok=True)
 for name,off in [('front',(0,6,.7)),('left',(-6,0,.7)),('right',(6,0,.7)),('back',(0,-6,.7)),('game',(4,-4,6.7))]:
  cam.location=target+Vector(off)*size;cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(out/(name+'.png'));bpy.ops.render.render(write_still=True)
 print('REVIEWED',source.parent.name,flush=True)
