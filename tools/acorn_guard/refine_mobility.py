"""Add run, turning steps and a lunging attack to the saved acorn rig only.

No meshes, weights, materials or accepted anatomy are recreated. A checkpoint
must exist before running this deliberate animation revision.
"""
import ast
import bpy
import hashlib
import json
import math
from pathlib import Path
from mathutils import Matrix, Vector

ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'assets/characters/acorn_guard'
assert (DEST/'checkpoints/before_tempo_20260912.blend').exists()
bpy.ops.wm.open_mainfile(filepath=str(DEST/'source.blend'))
scene=bpy.data.scenes['AcornGuard_Production'];bpy.context.window.scene=scene
rig=bpy.data.objects['AcornGuard_Rig']
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths={b.name:b.length for b in rig.data.bones}
club_grip=Vector((.333,.076,.309))
club_direction=Vector((.49,.08,.87)).normalized()
T=Matrix.Translation
# Reuse mathematical pose functions, never the geometry-building entry point.
tree=ast.parse((ROOT/'tools/acorn_guard/build_asset.py').read_text())
helpers=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ['pivot','rot','smooth','align','joint','pose']]
exec(compile(ast.Module(body=helpers,type_ignores=[]),'acorn_pose_math','exec'))
base_pose=pose
upper=['torso','cap','stem','leaf','arm_L','forearm_L','hand_L','arm_R','forearm_R','hand_R','club_socket']


def geometry_hash():
    raw=[(o.name,[tuple(v.co) for v in o.data.vertices]) for o in bpy.data.collections['AcornGuard_Character'].objects if o.type=='MESH']
    return hashlib.sha256(json.dumps(raw).encode()).hexdigest()


def legs(m,targets):
    for side,sign in [('L',-1),('R',1)]:
        hip=m['pelvis']@rest['pelvis'].inverted()@rest['leg_'+side].translation
        knee,ankle=joint(hip,targets[side],lengths['leg_'+side],lengths['shin_'+side],hip+Vector((sign*.02,.3,0)))
        m['leg_'+side]=align('leg_'+side,hip,knee)
        m['shin_'+side]=align('shin_'+side,knee,ankle)
        m['foot_'+side]=rest['foot_'+side].copy();m['foot_'+side].translation=ankle


def grip(m,position,direction):
    socket=direction.normalized().to_track_quat('Y','Z').to_matrix().to_4x4();socket.translation=position
    hand=socket@rest['club_socket'].inverted()@rest['hand_R']
    shoulder=m['arm_R'].translation
    elbow,wrist=joint(shoulder,hand.translation,lengths['arm_R'],lengths['forearm_R'],Vector((.50,-.04,.38)))
    hand.translation=wrist
    m['arm_R']=align('arm_R',shoulder,elbow);m['forearm_R']=align('forearm_R',elbow,wrist);m['hand_R']=hand
    m['club_socket']=hand@rest['hand_R'].inverted()@rest['club_socket']


def refined_pose(clip,u):
    if clip in ['idle','look_around']:
        m=base_pose('idle',u)
        breath=.006*math.sin(math.tau*u)
        m['pelvis']=T((0,0,breath))@m['pelvis']
        yaw=.045*math.sin(math.tau*u)
        if clip=='look_around':yaw+=.30*math.sin(math.tau*u)*math.sin(math.pi*u)**2
        shift=T((.006*math.sin(math.tau*u),0,breath))@pivot(rot('Z',yaw),rest['pelvis'].translation)
        for n in upper:m[n]=shift@m[n]
        legs(m,{side:rest['foot_'+side].translation.copy() for side in ['L','R']})
        return m
    if clip in ['run','turn']:
        m=base_pose('walk' if clip=='run' else 'idle',u)
        if clip=='run':
            flight=.04*(1-math.cos(4*math.pi*(u-.15)))*.5
            m['pelvis']=T((0,0,flight))@m['pelvis']
            tilt=T((0,0,flight))@pivot(rot('X',-.07),rest['pelvis'].translation)
            for n in upper:m[n]=tilt@m[n]
        targets={}
        for side in ['L','R']:
            p=(u+(0 if side=='L' else .5))%1
            foot=rest['foot_'+side].translation.copy()
            if clip=='run':
                if p<.30:y=.115-.23*p/.30;lift=0
                else:t=(p-.30)/.70;y=-.115+.23*smooth(t);lift=.065*math.sin(math.pi*t)**2
                foot.y+=y;foot.z+=lift
            else:
                foot.y+=.008*math.sin(p*math.tau)
                if p>.5:foot.z+=.02*math.sin((p-.5)*math.tau)**2
            targets[side]=foot
        legs(m,targets)
        return m
    phase=clip.removeprefix('lunge_')
    m=base_pose('recover' if phase=='recover' else phase,u)
    ready=Vector((.33,-.06,.40));finish=Vector((.13,.27,.37))
    ready_dir=Vector((.70,-.35,.63)).normalized();finish_dir=Vector((-.35,.89,-.30)).normalized()
    weight=smooth(u)
    if phase=='windup':position=club_grip.lerp(ready,weight);direction=club_direction.lerp(ready_dir,weight)
    elif phase=='strike':position=ready.lerp(finish,weight);direction=ready_dir.lerp(finish_dir,weight)
    else:position=finish.lerp(club_grip,weight);direction=finish_dir.lerp(club_direction,weight)
    hop=.045*math.sin(math.pi*u)**2 if phase=='strike' else 0.
    if hop:
        for n in ['pelvis']+upper:m[n]=T((0,0,hop))@m[n]
        position.z+=hop
    targets={}
    for side,sign in [('R',1),('L',-1)]:
        foot=rest['foot_'+side].translation.copy()
        stance=weight if phase=='windup' else (1-weight if phase=='recover' else 1.)
        foot.y+=sign*.035*stance
        if phase=='strike':foot.z+=.065*math.sin(math.pi*u)**2
        targets[side]=foot
    legs(m,targets);grip(m,position,direction)
    return m


before=geometry_hash()
durations={'idle':2.0,'look_around':2.4,'run':.34,'turn':.32,'lunge_windup':.56,'lunge_strike':.22,'lunge_recover':.50}
for name,duration in durations.items():
    if name in bpy.data.actions:bpy.data.actions.remove(bpy.data.actions[name])
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    frames=round(duration*120)
    for f in range(frames+1):
        matrices=refined_pose(name,f/frames)
        for b in rig.pose.bones:
            parent=parents[b.name]
            basis=rest[b.name].inverted()@(rest[parent]@matrices[parent].inverted() if parent else Matrix.Identity(4))@matrices[b.name]
            b.rotation_mode='QUATERNION';b.location,b.rotation_quaternion,b.scale=basis.decompose()
            for prop in ['location','rotation_quaternion','scale']:b.keyframe_insert(prop,frame=f,group=b.name)
    action.use_frame_range=True;action.frame_start=0;action.frame_end=frames
    action['duration_seconds']=frames/120;action['in_place']=True
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:key.interpolation='LINEAR'
rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=rig.animation_data.action.slots[0]
scene.frame_set(0);bpy.context.view_layer.update()
assert geometry_hash()==before,'Motion editing must not change any mesh vertices.'
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'source.blend'))
(ROOT/'captures/acorn_guard/mobility_source_checks.json').write_text(json.dumps({'mesh_vertices_unchanged':True,'geometry_sha256':before,'added_actions':durations,'natural_run_speed':.23/(.3*(41/120))},indent=2))
print('MOBILITY_SAVED',list(durations),'MESHES_UNCHANGED')
