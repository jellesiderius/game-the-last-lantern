"""Four comparable unarmed views of the current saved source, without changing the source."""
import bpy
from pathlib import Path
from mathutils import Vector
root=next(p for p in Path(bpy.data.filepath).parents if (p/'project.godot').is_file())
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
r=bpy.data.objects['Capybara_Rig'];r.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
bpy.data.objects['Amber_Sword'].hide_render=True
s.render.resolution_x=950;s.render.resolution_y=950;s.cycles.samples=24;s.camera.data.ortho_scale=1.85
for view,position in [('front',(0,5,.77)),('back',(0,-5,.77)),('left',(-5,0,.77)),('right',(5,0,.77))]:
 s.camera.location=position;s.camera.rotation_euler=(Vector((0,0,.77))-s.camera.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(root/'captures/capybara'/('neutral_'+view+'.png'));bpy.ops.render.render(write_still=True)
