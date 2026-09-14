"""Add kindle/rest to accepted panda rig. Preserve mesh, weights and every older Action.
Creates multi-view source renders before the separate character export step.
"""
import bpy, ast, math, json, hashlib, shutil
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2];source=ROOT/'assets/characters/red_panda/source.blend'
checkpoint=source.parent/'checkpoints/before_vuurlelie_20260913.blend'
if not checkpoint.exists():shutil.copy2(source,checkpoint)
bpy.ops.wm.open_mainfile(filepath=str(source));scene=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=scene
rig=bpy.data.objects['LanternPanda_Rig'];collection=bpy.data.collections['LanternPanda_Character']
rest={b.name:b.matrix_local.copy() for b in rig.data.bones};parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones};lengths={b.name:b.length for b in rig.data.bones}
V=Vector;T=Matrix.Translation
syntax=ast.parse((ROOT/'tools/lantern_village/refine_panda_motion.py').read_text())
exec(compile(ast.Module(body=[n for n in syntax.body if isinstance(n,ast.FunctionDef) and n.name in ['rot','pivot','clamp','ease','joint','aligned','arm','apply','geometry_hash']],type_ignores=[]),'pose_math','exec'))
before_geometry=geometry_hash()
def curve_hash(action):
 h=hashlib.sha256()
 for l in action.layers:
  for st in l.strips:
   for bag in st.channelbags:
    for curve in bag.fcurves:
     h.update(str((curve.data_path,curve.array_index,[(tuple(k.co),k.interpolation) for k in curve.keyframe_points])).encode())
 return h.hexdigest()
before_actions={a.name:curve_hash(a) for a in bpy.data.actions if a.name not in ['kindle','rest']}
def sampled(name,time):
 a=bpy.data.actions[name];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];scene.frame_set(round(time*scene.render.fps));bpy.context.view_layer.update()
 return {b.name:b.matrix.copy() for b in rig.pose.bones}
idle=sampled('idle',0);seated=sampled('entrance',0)
offer={n:m.copy() for n,m in idle.items()}
body=T((0,0,-.025))@pivot(rot(-.12),idle['pelvis'].translation)
for n in offer:
 if n!='root':offer[n]=body@idle[n]
for side in ['L','R']:
 foot=idle['foot_'+side].copy();hip=offer['pelvis']@rest['pelvis'].inverted()@rest['leg_'+side].translation
 knee,ankle=joint(hip,foot.translation,lengths['leg_'+side],lengths['knee_'+side],hip+V((0,.2,.01)))
 offer['leg_'+side]=aligned('leg_'+side,hip,knee);offer['knee_'+side]=aligned('knee_'+side,knee,ankle);foot.translation=ankle;offer['foot_'+side]=foot
arm(offer,'L',V((-.26,.33,.47)),V((0,.9,-.1)),body)
# Keep lantern just above the floor while seated and the hand connected to its handle.
seat_body=seated['pelvis']@idle['pelvis'].inverted()
arm(seated,'L',V((-.255,.11,.225)),V((0,.9,-.1)),seat_body)
def blend(a,b,w):return {n:a[n].lerp(b[n],w) for n in a}
for name,duration in [('kindle',2.25),('rest',1.4)]:
 if bpy.data.actions.get(name):bpy.data.actions.remove(bpy.data.actions[name])
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
 for f in range(round(duration*scene.render.fps)+1):
  t=f/scene.render.fps
  if name=='rest':m=blend(idle,seated,ease(t/.45))
  elif t<.58:m=blend(idle,offer,ease(t/.58))
  elif t<1.37:m={n:p.copy() for n,p in offer.items()}
  else:m=blend(offer,seated,ease((t-1.37)/.78))
  apply(m,f)
 action.use_frame_range=True;action.frame_start=0;action.frame_end=round(duration*scene.render.fps)
 action['duration_seconds']=duration;action['in_place']=True
 for l in action.layers:
  for st in l.strips:
   for bag in st.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:key.interpolation='LINEAR'
assert before_geometry==geometry_hash()
assert all(curve_hash(bpy.data.actions[n])==h for n,h in before_actions.items())
rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
report={'geometry_weights_unchanged':True,'older_actions_unchanged':True,'geometry_hash':before_geometry,'old_action_count':len(before_actions),'actions':len(bpy.data.actions),'new_actions':['kindle','rest']}
(ROOT/'captures/vuurlelie/panda_audit.json').write_text(json.dumps(report,indent=2))
# Actual current rig + current Action in review scenes. Preview props follow the sampled socket.
for name,time in [('kindle',.95),('rest',.55)]:
 bpy.context.window.scene=scene;a=bpy.data.actions[name];rig.animation_data.action=a;rig.animation_data.action_slot=a.slots[0];scene.frame_set(round(time*scene.render.fps));bpy.context.view_layer.update()
 for n,bone in [('Preview_sunblade','sword_socket'),('Preview_hand_lantern','lantern_socket')]:
  if n in bpy.data.objects:
   m=rig.matrix_world@rig.pose.bones[bone].matrix
   bpy.data.objects[n].matrix_world=T(m.translation) if 'lantern' in n else m
 REVIEW_SOURCE='LanternPanda_Production';REVIEW_LABEL='vuurlelie_'+name;REVIEW_SIZE=1.65;REVIEW_TARGET=(0,0,.54)
 exec(compile((ROOT/'tools/lantern_village/review_blender.py').read_text(),'review_blender','exec'))
print('VUURLELIE_PANDA_READY',json.dumps(report))
