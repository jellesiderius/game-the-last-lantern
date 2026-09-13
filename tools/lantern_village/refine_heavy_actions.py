"""Revise only heavy poses and add an opposite finisher on the current chibi rig.
Run inside Blender after inspecting the current source. No meshes/weights are replaced.
"""
import ast, bpy, math, json
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['LanternPanda_Production']; bpy.context.window.scene=s
if bpy.context.object and bpy.context.object.mode!='OBJECT': bpy.ops.object.mode_set(mode='OBJECT')
rig=bpy.data.objects['LanternPanda_Rig']; c=bpy.data.collections['LanternPanda_Character']
checkpoint=ROOT/'assets/characters/red_panda/checkpoints/before_heavy_chop_20260910.blend'
if not checkpoint.exists(): bpy.data.libraries.write(str(checkpoint),{s},fake_user=True)
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths={b.name:b.length for b in rig.data.bones}; V=Vector
# Load mathematical helpers only, never the historical full-action rebuild.
tree=ast.parse((ROOT/'tools/lantern_village/animate_character.py').read_text())
exec(compile(ast.Module(body=[n for n in tree.body if isinstance(n,ast.FunctionDef)],type_ignores=[]),'pose_helpers','exec'))
samples=[]
for o in c.objects:
 if o.type!='MESH': continue
 for v in o.data.vertices:
  if v.index%max(1,len(o.data.vertices)//700) and v.co.z>.04: continue
  samples.append((v.co.copy(),[(o.vertex_groups[g.group].name,g.weight) for g in v.groups]))

def heavy_pose(clip,t,duration):
 # A shoulder-high backswing clears the oversized head; a planted diagonal chop
 # is followed by a low held pose and slower recovery, unlike the waist-high lights.
 idle=pose('idle',0,2.)
 if clip in ['heavy_charge','heavy_hold']:
  q=ease(t/duration) if clip=='heavy_charge' else 1.
  lean=mix(0,-.20,q); yaw=-.28*q; crouch=-.022*q
  grip=V((.265,.115,.29)).lerp(V((.335,-.025,.535)),q)
  blade=V((.35,.82,.45)).lerp(V((.35,-.25,.90)),q).normalized()
  foot_step=.018*q; load=q
 else:
  strong=clip=='heavy_release_charged'
  # t, lean, torso yaw, hip drop, grip xyz, blade xyz, planted forward foot
  keys=[(0.,-.20,-.28,-.022,(.335,-.025,.535),(.35,-.25,.90),.018),
        (.13,-.27,-.39,-.028,(.34,-.055,.55),(.40,-.36,.88),.035),
        (.16,-.22,-.30,-.023,(.335,-.025,.54),(.42,-.13,.92),.04),
        (.255,.52 if strong else .36,.36,-.036,(.04,.245,.34),(-.40,.91,-.08),.045),
        (.32,.44 if strong else .30,.49,-.03,(-.035,.255,.34),(-.82,.53,-.10),.045),
        (.44,.39 if strong else .24,.43,-.028,(-.015,.235,.34),(-.70,.70,-.06),.045),
        (.65,0,0,-.004,(.265,.115,.29),(.35,.82,.45),0.)]
  for a,b in zip(keys,keys[1:]):
   if t<=b[0]+1e-6:
    q=ease((t-a[0])/(b[0]-a[0])); break
  lean=mix(a[1],b[1],q);yaw=mix(a[2],b[2],q);crouch=mix(a[3],b[3],q)
  grip=V(a[4]).lerp(V(b[4]),q);blade=V(a[5]).lerp(V(b[5]),q).normalized();foot_step=mix(a[6],b[6],q)
  load=1-ease((t-.44)/.21)
 yaw*=1.35
 base=T((0,.018*load,crouch))@pivot(RZ(yaw*.3),V((0,0,.2))); body=base@pivot(RZ(yaw)@RX(-lean),V((0,0,.23)))
 m={name:mat.copy() for name,mat in idle.items()};m['root']=rest['root'].copy()
 m['pelvis']=base@rest['pelvis']
 for name in ['torso','neck','head','back_sword_socket']: m[name]=body@rest[name]
 m['head']=body@pivot(RZ(-yaw*.18)@RX(lean*.30),rest['head'].translation)@rest['head']
 arm_pose(m,'R',grip,blade,'sword_socket',body,.9)
 for name in ['arm_upper_L','forearm_L','hand_L','fingers_L','bow_socket','lantern_socket']:
  m[name]=body@rest[name]
 # Bent knees with planted ankles: crouching must not translate both feet underground.
 for side,sign in [('L',-1),('R',1)]:
  hip=base@rest['leg_'+side].translation
  ankle=rest['foot_'+side].translation.copy();ankle.y+=foot_step if side=='R' else -.008*load
  knee,ankle=joint(hip,ankle,lengths['leg_'+side],lengths['knee_'+side],hip+V((sign*.015,.2,0)))
  m['leg_'+side]=aligned('leg_'+side,hip,knee)
  m['knee_'+side]=aligned('knee_'+side,knee,ankle)
  m['foot_'+side]=rest['foot_'+side].copy();m['foot_'+side].translation=ankle
 for name in ['cape_L','cape_R','cape_back']:m[name]=body@rest[name]
 for name in ['tail_01','tail_02','tail_03']:m[name]=base@pivot(RZ(-yaw*.18),V((0,-.13,.25)))@rest[name]
 return m

# Reversed finisher reuses the inspected IK helper but reverses its authored blade path.
source=ast.get_source_segment((ROOT/'tools/lantern_village/animate_character.py').read_text(),next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='pose'))
source=source.replace('def pose(', 'def reverse_pose(').replace("'attack_3':(.12,.12,1)","'attack_3':(.12,.12,-1)")
exec(source)
clips={'heavy_charge':.6,'heavy_hold':.5,'heavy_release':.65,'heavy_release_charged':.65,'attack_3_reverse':.48}
report={}
rig.animation_data.action=None
for name,duration in clips.items():
 old=bpy.data.actions.get(name)
 if old:bpy.data.actions.remove(old)
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
 minimum=10.;maximum_fix=0.
 for frame in range(round(duration*100)+1):
  matrices=reverse_pose('attack_3',frame/100,duration) if name=='attack_3_reverse' else heavy_pose(name,frame/100,duration)
  low,fix=ground(matrices);minimum=min(minimum,low+fix);maximum_fix=max(maximum_fix,fix)
  for bone in rig.pose.bones:
   parent=parents[bone.name]
   basis=rest[bone.name].inverted()@(rest[parent]@matrices[parent].inverted() if parent else Matrix.Identity(4))@matrices[bone.name]
   bone.location,bone.rotation_quaternion,bone.scale=basis.decompose()
   for prop in ['location','rotation_quaternion','scale']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
 action.use_frame_range=True;action.frame_start=0;action.frame_end=duration*100
 action['duration_seconds']=duration;action['in_place']=True
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:key.interpolation='LINEAR'
 report[name]={'lowest_sample':minimum,'maximum_floor_correction':maximum_fix}
rig.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
(ROOT/'captures/lantern_village/heavy_floor_audit.json').write_text(json.dumps(report,indent=2))
result={'revised_actions':list(clips),'floor_audit':report,'checkpoint':str(checkpoint)}
