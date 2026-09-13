"""Revise only locomotion Actions on the accepted panda. No mesh/rig/weight changes.
Run on the current source in background Blender; checkpoints and contact audit are saved.
The source remains authoritative. Review it before exporting with export_character.py.
"""
import bpy, math, json, hashlib, sys, shutil
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[2]
scene=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=scene
rig=bpy.data.objects['LanternPanda_Rig'];collection=bpy.data.collections['LanternPanda_Character']
if bpy.context.object and bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
checkpoint=ROOT/'assets/characters/red_panda/checkpoints/before_motion_20260913.blend'
if not checkpoint.exists():shutil.copy2(bpy.data.filepath,checkpoint)
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths={b.name:b.length for b in rig.data.bones}
V=Vector
T=Matrix.Translation

def rot(a,axis='X'):return Matrix.Rotation(a,4,axis)
def pivot(m,p):return T(p)@m@T(-V(p))
def clamp(x):return max(0.,min(1.,x))
def ease(x):x=clamp(x);return x*x*(3-2*x)
def joint(a,b,first,second,pole):
 axis=b-a;distance=min(axis.length,first+second-.0003);axis.normalize();b=a+axis*distance
 along=(distance*distance+first*first-second*second)/(2*max(.0001,distance))
 bend=V(pole)-a;bend-=axis*bend.dot(axis);bend.normalize()
 return a+axis*along+bend*math.sqrt(max(0,first*first-along*along)),b

def aligned(name,head,tail):
 q=(rest[name].to_3x3()@V((0,1,0))).rotation_difference((tail-head).normalized())
 m=q.to_matrix().to_4x4()@rest[name];m.translation=head;return m

def arm(m,side,grip,direction,body):
 socket_name='sword_socket' if side=='R' else 'lantern_socket'
 y=V(direction).normalized();x=y.cross(V((0,0,1)))
 if x.length<.001:x=V((1,0,0))
 x.normalize();z=x.cross(y).normalized()
 socket=Matrix((x,y,z)).transposed().to_4x4();socket.translation=grip
 hand=socket@rest[socket_name].inverted()@rest['hand_'+side]
 shoulder=body@rest['arm_upper_'+side].translation
 sign=1 if side=='R' else -1
 elbow,wrist=joint(shoulder,hand.translation,lengths['arm_upper_'+side],lengths['forearm_'+side],shoulder+V((sign*.14,-.06,-.13)))
 hand.translation=wrist
 m['arm_upper_'+side]=aligned('arm_upper_'+side,shoulder,elbow)
 m['forearm_'+side]=aligned('forearm_'+side,elbow,wrist)
 m['hand_'+side]=hand
 palm=hand@rest['hand_'+side].inverted()
 m['fingers_'+side]=palm@rest['fingers_'+side]
 for n in rest:
  if parents[n]=='hand_'+side and n.endswith('socket'):m[n]=palm@rest[n]

# Fingerprint geometry + weights so authoring cannot silently rebuild the accepted anatomy.
def geometry_hash():
 h=hashlib.sha256()
 for o in sorted(collection.all_objects,key=lambda o:o.name):
  if o.type!='MESH':continue
  h.update(o.name.encode())
  for v in o.data.vertices:
   h.update(str(tuple(v.co)).encode());h.update(str([(g.group,g.weight) for g in v.groups]).encode())
 return h.hexdigest()
before_hash=geometry_hash()
# Flat sole offset is measured from current skinned boot geometry, in rig space.
sole_offset={}
for side in ['L','R']:
 o=bpy.data.objects['Boot_Foot_'+side]
 sole_offset[side]=.004-min((rig.matrix_world.inverted()@o.matrix_world@v.co).z for v in o.data.vertices)

# Contact interval is explicit and its rearward velocity determines playback speed.
GAITS={'walk':{'duration':.8,'half_stride':.075,'stance':.55,'lift':.033,'drop':.026,'lean':.065},
       'run':{'duration':.56,'half_stride':.105,'stance':.16,'lift':.052,'drop':.040,'lean':.25}}

def locomotion(name,u):
 moving=name in GAITS;fast=name=='run';g=GAITS.get(name)
 phase=u*math.tau;wave=math.cos(phase);double=math.cos(phase*2)
 if moving:
  # Compression during support, a restrained flight arc between steps.
  half=(u% .5)/.5
  bob=(-g['drop']+.009*(1-double)) if fast else (-g['drop']+.0035*(1-double))
  sway=(-.006 if fast else -.010)*wave
  hip_yaw=.045*wave;hip_roll=.012*math.sin(phase)
  lean=g['lean']+(.018 if fast else .007)*math.sin(phase*2)
 else:
  bob=-.010+.002*math.sin(phase);sway=.001*math.sin(phase);hip_yaw=0;hip_roll=0;lean=.010*math.sin(phase)
 offset=max(sole_offset.values())
 base=T((sway,0,offset+bob))@pivot(rot(hip_yaw,'Z')@rot(hip_roll,'Y'),rest['pelvis'].translation)
 body=base@pivot(rot(-hip_yaw*1.5,'Z')@rot(-lean),rest['torso'].translation)
 m={n:body@r for n,r in rest.items()};m['root']=rest['root'].copy();m['pelvis']=base@rest['pelvis']
 # Neck carries the head; counter pitch and yaw keep the face readable.
 m['head']=body@pivot(rot(lean*.70)@rot(hip_yaw*.5,'Z'),rest['head'].translation)@rest['head']
 for sign,side in [(-1,'L'),(1,'R')]:
  ankle=rest['foot_'+side].translation.copy();ankle.z+=sole_offset[side]
  pitch=0.
  if moving:
   v=(u+(0 if side=='L' else .5))%1.;stance=g['stance'];stride=g['half_stride']
   if v<stance:
    q=v/stance;ankle.y=-.012+stride*(1-2*q)
    # Sole flat through support, then roll around the toe for the final push.
    pitch=-.30*ease((q-.70)/.30) if fast else -.19*ease((q-.76)/.24)
   else:
    q=(v-stance)/(1-stance)
    # Hermite return begins/ends at stance velocity, avoiding a heel-speed pop.
    tangent=-2*stride*(1-stance)/stance
    # Early follow-through stays short enough for the tiny shins; long middle swing.
    if q<.13:
     ankle.y=-.012-stride-.015*math.sin(math.pi*q/.26)
    elif q>.87:
     ankle.y=-.012+stride+.010*math.sin(math.pi*(1-q)/.26)
    else:
     ankle.y=-.012-stride-.015+(2*stride+.025)*ease((q-.13)/.74)
    ankle.z+=g['lift']*math.sin(math.pi*q)**1.25
    pitch=-.30*(1-ease(q/.30))+.14*math.sin(math.pi*q)
  foot=rest['foot_'+side].copy();foot.translation=ankle
  if pitch<0:
   toe=ankle+V((0,.070,-.039));foot=pivot(rot(pitch),toe)@foot
  else:foot=pivot(rot(pitch),ankle)@foot
  hip=base@rest['leg_'+side].translation
  knee,actual=joint(hip,foot.translation,lengths['leg_'+side],lengths['knee_'+side],hip+V((sign*.015,.20,0)))
  m['leg_'+side]=aligned('leg_'+side,hip,knee);m['knee_'+side]=aligned('knee_'+side,knee,actual)
  foot.translation=actual;m['foot_'+side]=foot
 # Relaxed right elbow, forward/down blade with clear ground clearance.
 # Counter-swing carries the whole weapon; the wrist does not spin independently.
 swing=math.cos(phase+.18) if moving else .04*math.sin(phase)
 grip=V((.266,.100+(.047 if fast else .023)*swing,.303+(.008 if fast else .004)*math.sin(phase*2)))
 grip+=V((sway*.35,0,bob*.30))
 blade=V((.30,.84,-.40));blade=rot((.13 if fast else .065)*swing).to_3x3()@blade
 arm(m,'R',grip,blade,body)
 # Lantern arm counterbalances with restrained shoulder/elbow motion and an upright handle.
 shoulder=rest['arm_upper_L'].translation
 upper=body@pivot(rot(-.12-(.32 if fast else .16)*swing),shoulder)
 lower=upper@pivot(rot(-.12+.06*math.sin(phase)),rest['forearm_L'].translation)
 m['arm_upper_L']=upper@rest['arm_upper_L']
 for n in ['forearm_L','hand_L','fingers_L','bow_socket','lantern_socket']:m[n]=lower@rest[n]
 # Three connected segments propagate a delayed, diminishing balance wave.
 tail=base@pivot(rot(-.15 if fast else -.025),rest['tail_01'].translation)
 for i,n in enumerate(['tail_01','tail_02','tail_03']):
  amplitude=(.075 if fast else .039) if moving else .014
  tail=tail@pivot(rot(amplitude*math.sin(phase-i*.65),'Z')@rot(amplitude*.55*math.sin(phase*2-i*.65)),rest[n].translation)
  m[n]=tail@rest[n]
 return m

def apply(m,frame):
 for bone in rig.pose.bones:
  parent=parents[bone.name]
  basis=rest[bone.name].inverted()@(rest[parent]@m[parent].inverted() if parent else Matrix.Identity(4))@m[bone.name]
  bone.rotation_mode='QUATERNION';bone.location,bone.rotation_quaternion,bone.scale=basis.decompose()
  for prop in ['location','rotation_quaternion','scale']:bone.keyframe_insert(prop,frame=frame,group=bone.name)

report={};rig.animation_data.action=None
for name,duration in [('idle',2.4),('walk',.8),('run',.56)]:
 old=bpy.data.actions.get(name)
 if old:bpy.data.actions.remove(old)
 action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
 count=round(duration*scene.render.fps)
 for f in range(count+1):apply(locomotion(name,f/count),f)
 action.use_frame_range=True;action.frame_start=0;action.frame_end=count
 action['duration_seconds']=duration;action['in_place']=True;action['revision']='grounded_motion_20260913'
 if name in GAITS:
  g=GAITS[name];action['natural_speed']=2*g['half_stride']/(duration*g['stance']);action['stance_fraction']=g['stance']
 for layer in action.layers:
  for strip in layer.strips:
   for bag in strip.channelbags:
    for curve in bag.fcurves:
     for key in curve.keyframe_points:key.interpolation='LINEAR'
 report[name]={'duration':duration,'natural_speed':action.get('natural_speed',0)}
assert geometry_hash()==before_hash
rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0];scene.frame_set(0);bpy.context.view_layer.update()
for name,socket in [('Preview_sunblade','sword_socket'),('Preview_hand_lantern','lantern_socket')]:
 if name in bpy.data.objects:
  m=rig.matrix_world@rig.pose.bones[socket].matrix
  bpy.data.objects[name].matrix_world=T(m.translation) if 'lantern' in name else m
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
out=ROOT/'captures/panda_motion';out.mkdir(parents=True,exist_ok=True)
(out/'source_audit.json').write_text(json.dumps({'geometry_weights_sha256':before_hash,'unchanged_geometry_weights':True,'clips':report,'sole_offset':sole_offset},indent=2))
print('MOTION_AUTHORING',json.dumps(report))
