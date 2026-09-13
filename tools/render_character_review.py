"""Render current source from three neutral views without changing geometry."""
import bpy
from mathutils import Vector
ROOT='/Users/jelle/Godot-Projects/crow-test'
s=bpy.context.scene
r=bpy.data.objects['Crow_Rig']
r.animation_data.action=bpy.data.actions['idle']
s.frame_set(0)
c=s.camera
old_matrix=c.matrix_world.copy()
s.render.engine='CYCLES'
s.cycles.samples=48
s.cycles.use_denoising=True
s.render.resolution_x=800
s.render.resolution_y=900
s.render.resolution_percentage=100
c.data.type='ORTHO'
c.data.ortho_scale=1.48
paths=[]
for name,loc in [('front',(0,5,.62)),('back',(0,-5,.62)),('side',(5,0,.62))]:
    c.location=loc
    c.rotation_euler=(Vector((0,0,.62))-c.location).to_track_quat('-Z','Y').to_euler()
    s.render.filepath=ROOT+'/captures/character_'+name+'.png'
    bpy.ops.render.render(write_still=True)
    paths.append(s.render.filepath)
c.matrix_world=old_matrix
result={'renders':paths}
