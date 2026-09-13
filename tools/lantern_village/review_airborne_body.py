"""Review changed body-follow and airborne poses from the current editable source."""
import bpy
from pathlib import Path
from mathutils import Matrix
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['LanternPanda_Production'];rig=bpy.data.objects['LanternPanda_Rig']
script=(ROOT/'tools/lantern_village/review_blender.py').read_text()
poses=[('fall',15,'airborne_fall'),('land',5,'airborne_land'),('land',16,'airborne_recover'),('heavy_charge',60,'heavy_source_windup'),('heavy_release',26,'heavy_normal_impact'),('heavy_release_charged',26,'heavy_source_impact')]
poses += [(f'light_{style}_{side}',frame,f'light_{style}_{side}_{label}') for style in ['level','rising','falling'] for side in ['left','right'] for frame,label in [(8,'start'),(18,'end')]]
for clip,frame,label in poses:
 bpy.context.window.scene=s
 rig.animation_data.action=bpy.data.actions[clip];rig.animation_data.action_slot=rig.animation_data.action.slots[0];s.frame_set(frame);bpy.context.view_layer.update()
 bpy.data.objects['Preview_sunblade'].matrix_world=rig.matrix_world@rig.pose.bones['sword_socket'].matrix
 bpy.data.objects['Preview_hand_lantern'].matrix_world=Matrix.Translation((rig.matrix_world@rig.pose.bones['lantern_socket'].matrix).translation)
 exec(compile(script,'review_blender.py','exec'),{'REVIEW_LABEL':label,'REVIEW_SIZE':1.8,'REVIEW_VIEWS':{'front':(0,6,0),'left':(-6,0,0),'right':(6,0,0),'back':(0,-6,0),'game':(4,4,6.7)}})
bpy.context.window.scene=s;rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];s.frame_set(0);bpy.context.view_layer.update()
bpy.data.objects['Preview_sunblade'].matrix_world=rig.matrix_world@rig.pose.bones['sword_socket'].matrix
bpy.data.objects['Preview_hand_lantern'].matrix_world=Matrix.Translation((rig.matrix_world@rig.pose.bones['lantern_socket'].matrix).translation)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'current_source_renders':len(poses)*5,'source':bpy.data.filepath}
