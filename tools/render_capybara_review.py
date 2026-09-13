"""Render the saved neutral capybara from all four reference directions."""
import bpy
from pathlib import Path
from mathutils import Vector
root=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
c=s.camera
for name,location in [('front',(0,5,.76)),('back',(0,-5,.76)),('left',(5,0,.76)),('right',(-5,0,.76))]:
    c.location=location;c.rotation_euler=(Vector((0,0,.76))-c.location).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=str(root/'captures/capybara'/('neutral_'+name+'.png'))
    bpy.ops.render.render(write_still=True)
result={'views':['front','back','left','right']}
