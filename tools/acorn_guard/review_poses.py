"""Review deformed source geometry before exporting the authored action set."""
import bpy,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/acorn_guard/source.blend'))
scene=bpy.data.scenes['AcornGuard_Production'];bpy.context.window.scene=scene
rig=bpy.data.objects['AcornGuard_Rig']
poses=[('walk',15),('windup',78),('strike',11),('death',78)]
if 'run' in bpy.data.actions:poses=[('run',16),('turn',26),('lunge_windup',67),('lunge_strike',13),('lunge_recover',20)]
if '--idle-only' in sys.argv:poses=[('idle',60),('look_around',95)]
if '--jabs' in sys.argv:poses=[('jab_windup',48),('jab_strike',17),('jab_back_windup',48),('jab_back_strike',17),('jab_recover',10)]
for clip,frame in poses:
    rig.animation_data.action=bpy.data.actions[clip]
    rig.animation_data.action_slot=rig.animation_data.action.slots[0]
    scene.frame_set(frame)
    scope={'REVIEW_SOURCE':scene.name,'REVIEW_LABEL':'acorn_guard_'+clip,'REVIEW_SIZE':1.6,
        'REVIEW_TARGET':(0,0,.5),'REVIEW_VIEWS':{'front':(0,6,0),'side':(6,0,0),'left':(-6,0,0),'back':(0,-6,0),'game':(4,4,6.7)}}
    exec((ROOT/'tools/lantern_village/review_blender.py').read_text(),scope)
