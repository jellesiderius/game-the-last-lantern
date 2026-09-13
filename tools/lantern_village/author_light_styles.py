"""Six distinct baked light-swing paths on the inspected current chibi rig.
Only light_{level,rising,falling}_{left,right} Actions are authored; no mesh edits.
"""
import ast, bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT = Path('/Users/jelle/Godot-Projects/crow-test')
s = bpy.data.scenes['LanternPanda_Production']; bpy.context.window.scene = s
if bpy.context.object and bpy.context.object.mode != 'OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
rig = bpy.data.objects['LanternPanda_Rig']; c = bpy.data.collections['LanternPanda_Character']
checkpoint = ROOT/'assets/characters/red_panda/checkpoints/before_light_styles_20260910.blend'
if not checkpoint.exists(): bpy.data.libraries.write(str(checkpoint), {s}, fake_user=True)
rest = {b.name:b.matrix_local.copy() for b in rig.data.bones}
parents = {b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths = {b.name:b.length for b in rig.data.bones}; V = Vector
helper_source = (ROOT/'tools/lantern_village/animate_character.py').read_text()
tree = ast.parse(helper_source)
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)], type_ignores=[]), 'pose_helpers', 'exec'))
samples = []
for o in c.objects:
 if o.type != 'MESH': continue
 for v in o.data.vertices:
  if v.index % max(1,len(o.data.vertices)//550) and v.co.z > .04: continue
  samples.append((v.co.copy(), [(o.vertex_groups[g.group].name,g.weight) for g in v.groups]))

def light_pose(style, direction, t):
 # Blender +Y is forward. Rotation around +Y equals the Godot forward-plane tilt.
 slope = {'level':0.,'rising':20.,'falling':-20.}[style]
 plane = Matrix.Rotation(math.radians(-direction*slope),4,'Y')
 start_angle = -direction*math.radians(75); end_angle = -start_angle
 idle_grip = V((.265,.115,.29)); idle_blade = V((.35,.82,.45)).normalized()
 def target(angle):
  offset = plane @ V((.17*math.sin(angle), .14*math.cos(angle), 0))
  return V((.12,.10,.405))+offset, (plane @ V((math.sin(angle),math.cos(angle),0))).normalized()
 before, begin_blade = target(start_angle); after,end_blade = target(end_angle)
 if t < .08:
  w=ease(t/.08); travel=0.; grip=idle_grip.lerp(before,w); blade=idle_blade.lerp(begin_blade,w).normalized()
 elif t < .18:
  w=1.; travel=(t-.08)/.10
  # Constant angular travel matches the shared active-time shader / damage front.
  grip,blade=target(mix(start_angle,end_angle,travel))
 else:
  recovery=ease((t-.18)/.18); w=1-recovery;travel=1.
  grip=after.lerp(idle_grip,recovery);blade=end_blade.lerp(idle_blade,recovery).normalized()
 sign=-direction
 yaw=mix(-.65*sign,.80*sign,travel)*w
 if style=='falling': lean=mix(-.11,.32,travel)*w
 elif style=='rising': lean=mix(.26,-.10,travel)*w
 else: lean=mix(-.025,.12,travel)*w
 crouch=(-.028 if style=='rising' else -.015)*w
 # Weight shifts and hip turn support the hand path; root and world aim stay fixed.
 base=T((mix(-.012*sign,.018*sign,travel)*w,.018*travel*w,crouch-.014*w))@pivot(RZ(yaw*.32),V((0,0,.2)))
 body=T((0,0,crouch-.014*w))@pivot(RZ(yaw)@RX(-lean),V((0,0,.25)))
 m={n:a.copy() for n,a in pose('idle',0.,2.).items()};m['root']=rest['root'].copy();m['pelvis']=base@rest['pelvis']
 for name in ['torso','neck','head','back_sword_socket']:m[name]=body@rest[name]
 m['head']=body@pivot(RZ(-yaw*.18)@RX(lean*.30),rest['head'].translation)@rest['head']
 arm_pose(m,'R',grip,blade,'sword_socket',body,.95)
 for name in ['arm_upper_L','forearm_L','hand_L','fingers_L','bow_socket','lantern_socket']:
  m[name]=body@rest[name]
 for side,foot_sign in [('L',-1),('R',1)]:
  hip=base@rest['leg_'+side].translation; ankle=rest['foot_'+side].translation.copy()
  # Heel pivot, a tiny weight-transfer step, and bent knees instead of a rigid stance.
  stepping=(side=='R') if direction<0 else (side=='L')
  if stepping:
   ankle.y+=.026*travel*w
   ankle.z+=.009*math.sin(math.pi*travel)*w
  knee,ankle=joint(hip,ankle,lengths['leg_'+side],lengths['knee_'+side],hip+V((foot_sign*.015,.2,0)))
  m['leg_'+side]=aligned('leg_'+side,hip,knee);m['knee_'+side]=aligned('knee_'+side,knee,ankle)
  m['foot_'+side]=pivot(RZ(yaw*.18),rest['foot_'+side].translation)@rest['foot_'+side];m['foot_'+side].translation=ankle
 for name in ['cape_L','cape_R','cape_back']:m[name]=body@rest[name]
 for name in ['tail_01','tail_02','tail_03']:m[name]=base@pivot(RZ(-yaw*.18),V((0,-.13,.25)))@rest[name]
 return m

report={}; rig.animation_data.action=None
for style in ['level','rising','falling']:
 for label,direction in [('left',-1),('right',1)]:
  name=f'light_{style}_{label}';old=bpy.data.actions.get(name)
  if old:bpy.data.actions.remove(old)
  action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
  maximum_fix=0.;path=[]
  for frame in range(37):
   m=light_pose(style,direction,frame/100);minimum,fix=ground(m);maximum_fix=max(fix,maximum_fix)
   for bone in rig.pose.bones:
    parent=parents[bone.name]
    basis=rest[bone.name].inverted()@(rest[parent]@m[parent].inverted() if parent else Matrix.Identity(4))@m[bone.name]
    bone.rotation_mode='QUATERNION';bone.location,bone.rotation_quaternion,bone.scale=basis.decompose()
    for prop in ['location','rotation_quaternion','scale']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
   if frame in [8,13,18]:
    socket=m['sword_socket'];tip=socket@V((0,.472,0));path.append({'frame':frame,'grip':list(socket.translation),'tip':list(tip)})
  action.use_frame_range=True;action.frame_start=0;action.frame_end=36
  action['duration_seconds']=.36;action['in_place']=True;action['style']=style
  for layer in action.layers:
   for strip in layer.strips:
    for bag in strip.channelbags:
     for curve in bag.fcurves:
      for key in curve.keyframe_points:key.interpolation='LINEAR'
  report[name]={'floor_correction_max':maximum_fix,'active_path':path}
rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];s.frame_set(0);bpy.context.view_layer.update()
bpy.data.objects['Preview_sunblade'].matrix_world=rig.matrix_world@rig.pose.bones['sword_socket'].matrix
lantern=bpy.data.objects['Preview_hand_lantern'];lantern.matrix_world=Matrix.Translation((rig.matrix_world@rig.pose.bones['lantern_socket'].matrix).translation)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
(ROOT/'captures/lantern_village/light_styles_source_audit.json').write_text(json.dumps(report,indent=2))
result={'actions':list(report),'audit':report,'checkpoint':str(checkpoint)}
