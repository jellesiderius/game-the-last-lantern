"""Current-source early/late light poses, with props on the evaluated sockets."""
import bpy
from pathlib import Path
from mathutils import Matrix
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['LanternPanda_Production'];rig=bpy.data.objects['LanternPanda_Rig']
script=(ROOT/'tools/lantern_village/review_blender.py').read_text()
for style in ['level','rising','falling']:
 for side in ['left','right']:
  for frame,label in [(8,'start'),(18,'end')]:
   bpy.context.window.scene=s
   rig.animation_data.action=bpy.data.actions[f'light_{style}_{side}'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];s.frame_set(frame);bpy.context.view_layer.update()
   bpy.data.objects['Preview_sunblade'].matrix_world=rig.matrix_world@rig.pose.bones['sword_socket'].matrix
   bpy.data.objects['Preview_hand_lantern'].matrix_world=Matrix.Translation((rig.matrix_world@rig.pose.bones['lantern_socket'].matrix).translation)
   exec(compile(script,'review_blender.py','exec'),{'REVIEW_LABEL':f'light_{style}_{side}_{label}','REVIEW_SIZE':1.8,'REVIEW_VIEWS':{'front':(0,6,0),'left':(-6,0,0),'right':(6,0,0),'back':(0,-6,0),'game':(4,4,6.7)}})
bpy.context.window.scene=s;rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];s.frame_set(0);bpy.context.view_layer.update()
bpy.data.objects['Preview_sunblade'].matrix_world=rig.matrix_world@rig.pose.bones['sword_socket'].matrix
bpy.data.objects['Preview_hand_lantern'].matrix_world=Matrix.Translation((rig.matrix_world@rig.pose.bones['lantern_socket'].matrix).translation)
result={'rendered':60,'source':'current red_panda/source.blend','clips':6}
