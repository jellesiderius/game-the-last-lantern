"""Refine existing crow Actions in Blender. Preserve meshes; bake grip orientation.
Run inside the open Crow_Production scene with Blender MCP.
"""
import bpy, math
from math import sin, cos, pi
from mathutils import Vector, Quaternion, Matrix
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
scene=bpy.context.scene
rig=bpy.data.objects['Crow_Rig']
assert scene.name=='Crow_Production'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/crow/checkpoints/crow_before_combat_revision.blend'),copy=True)
bpy.context.view_layer.objects.active=rig
if bpy.context.object.mode!='OBJECT':bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
b=rig.data.edit_bones['back_sword_socket']
b.head=(0,-.295,.94);b.tail=(0,-.295,.84);b.align_roll(Vector((0,1,0)))
bpy.ops.object.mode_set(mode='OBJECT')
def reset():
    for b in rig.pose.bones:
        b.rotation_mode='QUATERNION';b.location=(0,0,0);b.rotation_quaternion=(1,0,0,0);b.scale=(1,1,1)
def rotate(n,x=0,y=0,z=0):
    b=rig.pose.bones[n];basis=b.bone.matrix_local.to_quaternion()
    q=Quaternion((0,0,1),z)@Quaternion((0,1,0),y)@Quaternion((1,0,0),x)
    b.rotation_quaternion=basis.inverted()@q@basis

def translate(n,v):
    b=rig.pose.bones[n];b.location=b.bone.matrix_local.to_3x3().inverted()@Vector(v)
def smooth(v):
    v=max(0,min(1,v));return v*v*(3-2*v)
def mix(a,b,u):return a+(b-a)*u

def carry(theta,lift=1,twist=0,lean=0,crouch=0,step=0,energy=1):
    # Shoulder yaw counteracts torso twist, preserving the intended forward sword arc.
    yaw=pi/2-theta-twist
    rotate('torso',x=lean,z=twist)
    rotate('neck',x=-lean*.30,z=-twist*.25)
    rotate('head',x=-lean*.25,z=-twist*.24)
    rotate('wing_R',x=-lean*.65,y=-.65*lift,z=yaw*lift)
    rotate('wing_tip_R',y=-.035*lift,x=.10*energy*sin(theta))
    rotate('wing_L',x=.16*energy,y=.16*lift,z=-twist*.6-.12*energy)
    translate('pelvis',(.025*sin(twist),.045*energy,crouch))
    # Staggered planting: one foot catches the strike while the other braces.
    translate('leg_L',(0,step*.55,0));translate('leg_R',(0,-step*.4,0))
    rotate('leg_L',x=-.28*energy);rotate('leg_R',x=.18*energy)
    bpy.context.view_layer.update()
    for suffix,y in [('L',step),('R',-step*.65)]:
        foot=rig.pose.bones['foot_'+suffix]
        target=foot.bone.matrix_local.copy()
        target.translation.y+=y
        target.translation.z+=max(0,crouch)*.2
        foot.matrix=target
    bpy.context.view_layer.update()
    socket=rig.pose.bones['sword_socket'];parent=socket.parent
    neutral=parent.matrix @ parent.bone.matrix_local.inverted() @ socket.bone.matrix_local
    d=Vector((sin(theta),cos(theta),0))
    up=Vector((0,0,1));right=d.cross(up)
    matrix=Matrix((right,d,up)).transposed().to_4x4();matrix.translation=neutral.translation
    socket.matrix=matrix

spec={'attack_1':(.36,.08,.10),'attack_2':(.38,.09,.10),'attack_3':(.48,.12,.12),'heavy_release':(.65,.16,.16),'roll_attack':(.45,.07,.12),'heavy_charge':(.6,0,0),'heavy_hold':(.5,0,0)}
for name,(duration,windup,active) in spec.items():
    if rig.animation_data.action and rig.animation_data.action.name==name:rig.animation_data.action=None
    old=bpy.data.actions.get(name)
    if old:bpy.data.actions.remove(old)
    action=bpy.data.actions.new(name);action.use_fake_user=True
    rig.animation_data.action=action
    for frame in range(round(duration*100)+1):
        reset();t=frame/100;u=t/duration
        if name in ('heavy_charge','heavy_hold'):
            k=smooth(u) if name=='heavy_charge' else 1.0
            breath=.008*sin(u*pi*2) if name=='heavy_hold' else 0
            carry(mix(1.05,1.78,k),mix(.72,1,k),twist=-.42*k,lean=.10*k,crouch=-.055*k+breath,step=-.07*k,energy=.7*k)
        else:
            sign=-1 if name=='attack_2' else 1
            power=1.35 if name=='attack_3' else (1.55 if name=='heavy_release' else 1.0)
            reach=1.14 if name!='heavy_release' else 1.22
            if t<windup:
                k=smooth(t/windup)
                theta=sign*mix(.82,reach,k)
                lift=mix(.72,1,k)
                twist=-sign*.40*k*power
                lean=mix(-.03,.10,k)
                crouch=-.048*k
                footstep=-.065*k
                energy=.5*k
            elif t<windup+active:
                phase=smooth((t-windup)/active)
                theta=sign*mix(reach,-reach,phase);lift=1
                twist=sign*mix(-.40,.48,phase)*power
                lean=mix(.10,-.28*power,phase)
                crouch=mix(-.048,-.055,phase)
                footstep=mix(-.065,.11,phase)
                energy=mix(.5,1,phase)
            else:
                recovery=(t-windup-active)/(duration-windup-active)
                settle=smooth(recovery)
                theta=-sign*mix(reach,reach+.12,sin(pi*recovery))
                lift=mix(1,.70,settle)
                twist=sign*.48*power*(1-settle)
                lean=-.28*power*(1-settle)
                crouch=-.055*(1-settle)
                footstep=.11*(1-settle)
                energy=1-settle
            carry(theta,lift,twist,lean,crouch,footstep,energy)
        for b in rig.pose.bones:
            b.keyframe_insert('location',frame=frame,group=b.name)
            b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
    action['duration_seconds']=duration;action['in_place']=True
    action['combat_notes']='Horizontal forward blade sweep; socket baked from wing wrist transform'
rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/crow/source.blend'))
result={'updated':list(spec),'back_grip':[0,-.295,.94],'back_tip_height':.10,'root_fixed':True}
