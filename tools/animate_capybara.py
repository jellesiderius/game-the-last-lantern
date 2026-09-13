"""Author in-place capybara Actions using anatomically sized limb targets.
Analytical two-bone placement is baked to normal bone transforms, no runtime IK required.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
rig=bpy.data.objects['Capybara_Rig'];c=bpy.data.collections['Capybara_Character']
if globals().get('REAUTHOR_CAPYBARA',False):
 checkpoint=ROOT/'assets/characters/capybara/checkpoints/before_pose_revision.blend'
 if not checkpoint.exists():bpy.data.libraries.write(str(checkpoint),{s},fake_user=True)
 rig.animation_data.action=None
 for a in list(bpy.data.actions):bpy.data.actions.remove(a)
assert not rig.animation_data or not rig.animation_data.action, 'Inspect existing authored actions before replacing.'
rig.animation_data_create();rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths={b.name:b.length for b in rig.data.bones}
V=Vector

def clamp(x,a=0,b=1):return max(a,min(b,x))
def ease(x):x=clamp(x);return x*x*(3-2*x)
def mix(a,b,t):return a+(b-a)*t
def T(v):return Matrix.Translation(v)
def RX(a):return Matrix.Rotation(a,4,'X')
def RZ(a):return Matrix.Rotation(a,4,'Z')
def pivot(m,p):return T(p)@m@T(-V(p))
def aligned(name,head,tail):
 q=(rest[name].to_3x3()@V((0,1,0))).rotation_difference((tail-head).normalized())
 out=q.to_matrix().to_4x4()@rest[name];out.translation=head;return out

def socket_matrix(position,direction):
 y=V(direction).normalized();x=y.cross(V((0,0,1)))
 if x.length<.01:x=V((1,0,0))
 x.normalize();z=x.cross(y).normalized();m=Matrix((x,y,z)).transposed().to_4x4();m.translation=position;return m

def joint(a,b,first,second,pole):
 axis=b-a;distance=min(axis.length,first+second-.001);axis.normalize();b=a+axis*distance
 along=(distance*distance+first*first-second*second)/(2*max(.001,distance))
 rise=math.sqrt(max(0,first*first-along*along));bend=V(pole)-a;bend-=axis*bend.dot(axis)
 if bend.length<.001:bend=axis.cross(V((1,0,0)))
 bend.normalize();return a+axis*along+bend*rise,b

# Representative actual skinned vertices, including lowest toes and face, for floor correction.
samples=[]
for o in c.objects:
 if o.type!='MESH':continue
 indices=set(range(0,len(o.data.vertices),max(1,len(o.data.vertices)//500)))
 indices.add(min(o.data.vertices,key=lambda v:v.co.z).index)
 for i in indices:
  v=o.data.vertices[i];weights=[(o.vertex_groups[g.group].name,g.weight) for g in v.groups]
  samples.append((v.co.copy(),weights))

def ground(matrices):
 transforms={name:matrices[name]@rest[name].inverted() for name in rest}
 minimum=10
 for position,weights in samples:
  z=sum((transforms[name]@position).z*weight for name,weight in weights)
  minimum=min(minimum,z)
 correction=max(0,.006-minimum)
 if correction:
  for name,m in matrices.items():
   if name!='root':m.translation.z+=correction
 return minimum,correction

def arm_pose(m,side,grip,weapon_dir,socket_name,body_transform,curl=.65):
 # Socket-to-palm relationship remains constant, so the hand actually carries the weapon.
 socket=socket_matrix(V(grip),weapon_dir)
 hand=socket@rest[socket_name].inverted()@rest['hand_'+side]
 shoulder=body_transform@rest['arm_upper_'+side].translation
 elbow,wrist=joint(shoulder,hand.translation,lengths['arm_upper_'+side],lengths['forearm_'+side],V(((-1 if side=='L' else 1)*.58,-.12,.76)))
 hand.translation+=wrist-hand.translation
 m['arm_upper_'+side]=aligned('arm_upper_'+side,shoulder,elbow)
 m['forearm_'+side]=aligned('forearm_'+side,elbow,wrist)
 m['hand_'+side]=hand
 m['fingers_'+side]=hand@rest['hand_'+side].inverted()@pivot(RX(curl),rest['fingers_'+side].translation)@rest['fingers_'+side]
 for name in ['sword_socket','bow_socket','bow_draw_socket']:
  if parents.get(name)=='hand_'+side:m[name]=hand@rest['hand_'+side].inverted()@rest[name]

def pose(clip,t,duration):
 u=clamp(t/duration);lean=0.;yaw=0.;bob=-.004;roll=0.;head_turn=0.;bow=0.;draw=0.;finger=.9
 grip=V((.38,.16,.64));blade=V((.20,.90,-.38)).normalized()
 left_grip=V((-.49,.09,.55));left_dir=V((0,1,0));foot_phase=None;stride=.16;lift=.06;gait=0.;sway=0.
 if clip=='neutral':bob=0.
 if clip=='idle':
  bob=-.004-.003*(1-math.cos(u*math.tau));lean=.018*math.sin(u*math.tau);head_turn=.025*math.sin(u*math.tau)
  grip.z+=.004*math.sin(u*math.tau)
 if clip in ['walk','run']:
  fast=clip=='run';gait=math.sin(u*math.tau);lean=.34 if fast else .16
  bob=(-.058 if fast else -.025)-(.014 if fast else .010)*(1-math.cos(u*math.tau*2))*.5
  foot_phase=u;stride=.205 if fast else .15;lift=.075 if fast else .055
  yaw=.045*gait;sway=(.020 if fast else .014)*gait
 if clip in ['heavy_charge','heavy_hold']:
  a=ease(u) if clip=='heavy_charge' else 1.;bob=-.085*a;lean=-.18*a;yaw=-.43*a
  grip=grip.lerp(V((.42,-.10,1.03)),a);blade=blade.lerp(V((.87,-.33,.35)).normalized(),a).normalized()
  left_grip=left_grip.lerp(V((-.23,.24,.83)),a)
  if clip=='heavy_hold':head_turn=.016*math.sin(u*math.tau)
 attacks={'attack_1':(.08,.10,1),'attack_2':(.09,.10,-1),'attack_3':(.12,.12,1),'heavy_release':(.16,.16,1),'heavy_release_charged':(.16,.16,1),'roll_attack':(.07,.12,1)}
 if clip in attacks:
  wind,active,sign=attacks[clip];heavy=clip.startswith('heavy');strong=clip=='heavy_release_charged';finisher=clip=='attack_3'
  before=V((.43,-.045,1.02 if heavy else .78));after=V((.035,.36,.67 if heavy else .75))
  begin_angle=1.93;end_angle=-1.47
  if sign<0:before,after=after,before;begin_angle,end_angle=end_angle,begin_angle
  if t<wind:
   amount=ease(t/wind);grip=grip.lerp(before,amount);angle=mix(math.atan2(.20,.90),begin_angle,amount);weight=amount
   yaw=-.45*sign*amount;lean=-.18*amount if heavy else -.06*amount
  elif t<wind+active:
   amount=ease((t-wind)/active);grip=before.lerp(after,amount);angle=mix(begin_angle,end_angle,amount);weight=1.
   yaw=mix(-.45*sign,.48*sign,amount);lean=mix(-.18 if heavy else -.06,.44 if strong else (.3 if heavy or finisher else .17),amount)
  else:
   amount=ease((t-wind-active)/(duration-wind-active));grip=after.lerp(grip,amount);angle=mix(end_angle,math.atan2(.20,.90),amount);weight=1-amount
   yaw=.48*sign*weight;lean=(.44 if strong else (.3 if heavy or finisher else .17))*weight
  blade=V((math.sin(angle),math.cos(angle),-.08 if t>=wind else (.28 if heavy else .0))).normalized()
  bob=-.055*weight if not strong else -.095*weight
  left_grip=left_grip.lerp(V((-.24,.19,.81)),weight)
 if clip=='dodge_roll':
  tuck=math.sin(math.pi*u)**.65;roll=-math.tau*ease(u);bob=-.07*tuck
  grip=grip.lerp(V((.30,.18,.85)),tuck);left_grip=left_grip.lerp(V((-.30,.18,.85)),tuck)
  blade=V((.6,.1,-.8));lean=0
 if clip=='hurt':
  weight=math.sin(math.pi*u);lean=-.20*weight;bob=-.04*weight;left_grip.z+=.10*weight;head_turn=.08*weight
 if clip=='death':
  weight=ease(u);roll=-1.48*weight;bob=-.23*weight;grip.z+=.13*weight;left_grip.z+=.15*weight;finger=.4
 if clip.startswith('bow_') and clip!='bow_empty':
  bow=1.;draw=0.
  if clip=='bow_equip':bow=ease(u)
  elif clip=='bow_unequip':bow=1-ease(u)
  elif clip=='bow_draw':draw=ease(u)
  elif clip=='bow_hold':draw=1
  elif clip=='bow_release':draw=1-ease(t/.03)
  lean=.055*bow;yaw=-.08*bow;bob=-.015*bow
  left_grip=left_grip.lerp(V((.02,.56,.61)),bow)
  grip=grip.lerp(V((.02,.50-.14*draw,.61)),bow)
  if clip=='bow_release':grip.y-=.045*math.sin(math.pi*u)
 if clip=='bow_empty':
  weight=math.sin(math.pi*u)**1.4;lean=-.09*weight;head_turn=.18*math.sin(u*math.tau)*math.sin(math.pi*u)
  left_grip.x-=.05*weight;left_grip.z+=.14*weight;grip.z+=.10*weight
 base=T((sway,0,bob))@pivot(RX(roll),V((0,0,.48)))
 body_transform=base@pivot(RZ(yaw)@RX(-lean),V((0,0,.48)))
 m={'root':rest['root'].copy()}
 for name in ['pelvis','torso','neck','head','back_sword_socket']:m[name]=body_transform@rest[name]
 m['head']=body_transform@pivot(RZ(head_turn-yaw*.6)@RX(lean*.50),rest['head'].translation)@rest['head']
 # Roll/death tuck the entire arm target with the body; attack grips stay aimed in world space.
 if clip in ['dodge_roll','death']:
  grip=body_transform@grip;left_grip=body_transform@left_grip;blade=body_transform.to_3x3()@blade;left_dir=body_transform.to_3x3()@left_dir
 if clip in ['neutral','idle','walk','run']:
  # Free hands preserve the reference's relaxed shoulders; the sword is on the back.
  # Counter-swing comes from the shoulder, with a small elbow bend during the forward swing.
  for sign,side in [(-1,'L'),(1,'R')]:
   swing=sign*gait*(.48 if clip=='run' else .30)
   shoulder=rest['arm_upper_'+side].translation
   upper=body_transform@pivot(RX(swing-.10),shoulder)
   elbow=rest['forearm_'+side].translation
   lower=upper@pivot(RX(-.16+max(0,-swing)*.28),elbow)
   m['arm_upper_'+side]=upper@rest['arm_upper_'+side]
   # Distribute pronation through the forearm and wrist; palms face the body.
   # Mirrored signs follow each arm's downward longitudinal axis.
   fore_axis=rest['forearm_'+side].to_3x3()@V((0,1,0))
   hand_axis=rest['hand_'+side].to_3x3()@V((0,1,0))
   fore_twist=pivot(Matrix.Rotation(-sign*.38,4,fore_axis),elbow)
   hand_twist=pivot(Matrix.Rotation(-sign*.72,4,hand_axis),rest['hand_'+side].translation)
   m['forearm_'+side]=lower@fore_twist@rest['forearm_'+side]
   palm=lower@fore_twist@hand_twist
   m['hand_'+side]=palm@rest['hand_'+side]
   m['fingers_'+side]=palm@pivot(RX(.10),rest['fingers_'+side].translation)@rest['fingers_'+side]
   for name in ['sword_socket','bow_socket','bow_draw_socket']:
    if parents.get(name)=='hand_'+side:m[name]=palm@rest[name]
 elif bow>0:
  arm_pose(m,'L',left_grip,(0,1,0),'bow_socket',body_transform,.8)
  arm_pose(m,'R',grip,(0,1,0),'bow_draw_socket',body_transform,.38+draw*.40)
 else:
  arm_pose(m,'R',grip,blade,'sword_socket',body_transform,finger)
  arm_pose(m,'L',left_grip,left_dir,'bow_socket',body_transform,.18)
 for sign,side in [(-1,'L'),(1,'R')]:
  ankle=rest['foot_'+side].translation.copy();foot_matrix=rest['foot_'+side].copy()
  if foot_phase is not None:
   cycle=(foot_phase+(0 if side=='L' else .5))%1
   if cycle<.5:ankle.y+=stride*(1-4*cycle)
   else:
    swing=(cycle-.5)*2;ankle.y+=stride*(-1+2*ease(swing));ankle.z+=lift*math.sin(math.pi*swing)
   foot_matrix.translation=ankle
   # Roll over the planted toe before lifting; the sole never rotates through the floor.
   if .32<cycle<.5:
    toe=ankle+V((0,.15,-.045));foot_matrix=pivot(RX(-.20*ease((cycle-.32)/.18)),toe)@foot_matrix
    ankle=foot_matrix.translation.copy()
   elif cycle>=.5:
    foot_matrix=pivot(RX(.18*math.sin(math.pi*(cycle-.5)*2)),ankle)@foot_matrix
  if clip in ['dodge_roll','death']:
   amount=math.sin(math.pi*u)**.65 if clip=='dodge_roll' else ease(u)
   ankle=body_transform@(ankle.lerp(V((sign*.21,.12,.34)),amount))
   foot_matrix=body_transform@rest['foot_'+side];foot_matrix.translation=ankle
  hip=body_transform@rest['leg_'+side].translation
  knee,ankle_clamped=joint(hip,ankle,lengths['leg_'+side],lengths['knee_'+side],body_transform@V((sign*.23,.30,.25)))
  foot_matrix.translation=ankle_clamped
  m['leg_'+side]=aligned('leg_'+side,hip,knee)
  m['knee_'+side]=aligned('knee_'+side,knee,ankle_clamped)
  m['foot_'+side]=foot_matrix
 return m

clips={'neutral':.01,'idle':2.,'walk':.8,'run':.55,'dodge_roll':.42,'attack_1':.36,'attack_2':.38,'attack_3':.48,'heavy_charge':.6,'heavy_hold':.5,'heavy_release':.65,'heavy_release_charged':.65,'roll_attack':.45,'hurt':.25,'death':.9,'bow_equip':.18,'bow_aim':.6,'bow_draw':.25,'bow_hold':.5,'bow_release':.2,'bow_unequip':.14,'bow_empty':.32}
floor_report={}
for name,duration in clips.items():
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
 worst=0.;minimum=10.
 for frame in range(round(duration*100)+1):
  matrices=pose(name,frame/100,duration)
  if name!='neutral':
   low,fix=ground(matrices);worst=max(worst,fix);minimum=min(minimum,low+fix)
  for bone in rig.pose.bones:
   parent=parents[bone.name]
   basis=rest[bone.name].inverted()@(rest[parent]@matrices[parent].inverted() if parent else Matrix.Identity(4))@matrices[bone.name]
   bone.location,bone.rotation_quaternion,bone.scale=basis.decompose()
   for prop in ['location','rotation_quaternion','scale']:bone.keyframe_insert(prop,frame=frame,group=bone.name)
 action['duration_seconds']=duration;action['in_place']=True
 action.use_frame_range=True;action.frame_start=0;action.frame_end=duration*100
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:key.interpolation='LINEAR'
 floor_report[name]={'lowest_sample':round(minimum,5),'vertical_correction_max':round(worst,5)}
rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/capybara/source.blend'))
import json
(ROOT/'captures/capybara/animation_floor_audit.json').write_text(json.dumps(floor_report,indent=2))
result={'actions':clips,'floor_audit':floor_report,'source':bpy.data.filepath}
