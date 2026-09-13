"""Add an entrance Action to the current accepted rig, without rebuilding any mesh."""
import ast, bpy, math, hashlib, shutil, json
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
source=ROOT/'assets/characters/red_panda/source.blend'
checkpoint=source.parent/'checkpoints/before_forest_entrance_20260913.blend'
if not checkpoint.exists(): shutil.copy2(source,checkpoint)
bpy.ops.wm.open_mainfile(filepath=str(source))
scene=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=scene
rig=bpy.data.objects['LanternPanda_Rig'];collection=bpy.data.collections['LanternPanda_Character']
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths={b.name:b.length for b in rig.data.bones}
V=Vector;T=Matrix.Translation
syntax=ast.parse((ROOT/'tools/lantern_village/refine_panda_motion.py').read_text())
exec(compile(ast.Module(body=[n for n in syntax.body if isinstance(n,ast.FunctionDef) and n.name in ['rot','pivot','clamp','ease','joint','aligned','arm','apply','geometry_hash']],type_ignores=[]),'panda_pose_math','exec'))
original_hash=geometry_hash()
def sampled(name,time):
 action=bpy.data.actions[name];rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
 scene.frame_set(round(time*scene.render.fps));bpy.context.view_layer.update()
 return {b.name:b.matrix.copy() for b in rig.pose.bones}
idle=sampled('idle',0)
flight=sampled('fall',.15)
seated={n:m.copy() for n,m in idle.items()}
body=T((0,-.015,-.115))@pivot(rot(.085),idle['pelvis'].translation)
for n in seated:
 if n!='root':seated[n]=body@seated[n]
for side,sign in [('L',-1),('R',1)]:
 foot=rest['foot_'+side].copy();foot.translation=V((sign*.14,.16,.052))
 hip=seated['pelvis']@rest['pelvis'].inverted()@rest['leg_'+side].translation
 knee,ankle=joint(hip,foot.translation,lengths['leg_'+side],lengths['knee_'+side],hip+V((sign*.10,.22,.01)))
 seated['leg_'+side]=aligned('leg_'+side,hip,knee);seated['knee_'+side]=aligned('knee_'+side,knee,ankle)
 foot.translation=ankle;seated['foot_'+side]=foot
arm(seated,'R',V((.265,.16,.20)),V((.60,.72,-.15)),body)
# Tail curls to the side of the seat with connected inherited transforms.
tail=body
for i,n in enumerate(['tail_01','tail_02','tail_03']):
 tail=tail@pivot(rot(.15,'Z')@rot(-.04),rest[n].translation)
 seated[n]=tail@idle[n]
old=bpy.data.actions.get('entrance')
if old:bpy.data.actions.remove(old)
action=bpy.data.actions.new('entrance');action.use_fake_user=True;rig.animation_data.action=action
for f in range(round(3.6*scene.render.fps)+1):
 t=f/scene.render.fps
 if t<2.0:
  m={n:p.copy() for n,p in seated.items()}
  breath=.0025*math.sin(t*math.tau/2.4)
  for n in m:
   if n not in ['root','leg_L','leg_R','knee_L','knee_R','foot_L','foot_R']:m[n]=T((0,0,breath))@m[n]
  m['head']=pivot(rot(.04*math.sin(t*2),'Z'),m['head'].translation)@m['head']
 elif t<2.46:
  weight=ease((t-2)/.46);m={n:seated[n].lerp(idle[n],weight) for n in idle}
 elif t<2.55:
  weight=math.sin(math.pi*(t-2.46)/.18);m={n:p.copy() for n,p in idle.items()}
  for n in m:
   if n!='root':m[n]=T((0,0,-.028*weight))@m[n]
 else:
  weight=ease((t-2.55)/.15);m={n:idle[n].lerp(flight[n],weight) for n in idle}
 apply(m,f)
action.use_frame_range=True;action.frame_start=0;action.frame_end=round(3.6*scene.render.fps)
action['duration_seconds']=3.6;action['in_place']=True
for layer in action.layers:
 for strip in layer.strips:
  for bag in strip.channelbags:
   for curve in bag.fcurves:
    for key in curve.keyframe_points:key.interpolation='LINEAR'
assert original_hash==geometry_hash(),'Entrance must not alter accepted geometry or weights'
rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
out=ROOT/'captures/forest';out.mkdir(parents=True,exist_ok=True)
(out/'panda_source_audit.json').write_text(json.dumps({'unchanged_geometry_weights':True,'sha256':original_hash,'actions':len(bpy.data.actions),'entrance_duration':3.6},indent=2))
print('FOREST_ENTRANCE_AUTHORED',len(bpy.data.actions))
