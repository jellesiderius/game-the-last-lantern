import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
rig=bpy.data.objects['Capybara_Rig'];cam=s.camera;cam.data.ortho_scale=2.25
s.render.resolution_x=950;s.render.resolution_y=950;s.cycles.samples=24
for label,clip,frame,location in [
 ('armed_front','idle',0,(0,5,.78)),('armed_rear','idle',0,(3,-5,1.4)),
 ('armed_game','idle',0,(3,5,4)),('run','run',14,(4,5,2)),
 ('light_swing','attack_1',13,(3,5,3)),('heavy_charge','heavy_charge',58,(3,5,3)),
 ('heavy_impact','heavy_release_charged',26,(3,5,3)),('roll','dodge_roll',21,(3,5,2)),
 ('bow_draw','bow_hold',15,(3,5,2)),('death','death',90,(3,5,2))]:
 rig.animation_data.action=bpy.data.actions[clip];s.frame_set(frame)
 bpy.data.objects['Amber_Sword'].hide_render=clip.startswith('bow_')
 cam.location=location;cam.rotation_euler=(Vector((0,0,.74))-cam.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(ROOT/'captures/capybara'/('pose_'+label+'.png'));bpy.ops.render.render(write_still=True)
