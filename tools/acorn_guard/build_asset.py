"""Offline authoring of the reference acorn guard. Never edits existing characters.

Blender --background --python tools/acorn_guard/build_asset.py
Refuses to replace a reviewed source; pass -- --replace-generated for a deliberate
iteration of this new asset. Exports are a separate step after source review.
"""
import bpy
import math
import random
import sys
from pathlib import Path
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from asset_geometry import mesh_object, material, tube, ellipsoid, activate

DEST = ROOT / 'assets/characters/acorn_guard'
if (DEST / 'source.blend').exists() and '--replace-generated' not in sys.argv:
    raise RuntimeError('Existing source: inspect it before explicitly revising this generated asset.')
scene = bpy.data.scenes.new('AcornGuard_Production')
bpy.context.window.scene = scene
scene.render.fps = 120
scene.frame_start = 0
scene.frame_end = 240
character = bpy.data.collections.new('AcornGuard_Character')
scene.collection.children.link(character)
equipment = bpy.data.collections.new('Equipment_Preview')
scene.collection.children.link(equipment)
wood = material('Shell_honey_wood', (.66, .44, .23), .83)
capmat = material('Cap_olive_brown', (.35, .31, .21), .93)
bark = material('Branch_dark_wood', (.37, .28, .20), .87)
endgrain = material('Club_endgrain', (.60, .44, .28), .9)
maskmat = material('Eye_mask_charcoal', (.17, .155, .115), .94)
ivory = material('Eyes_warm_ivory', (.95, .90, .75), .55)
pupilmat = material('Pupils', (.12, .105, .075), .62)
leafmat = material('Autumn_leaf_ochre', (.69, .48, .22), .8)
veinmat = material('Leaf_veins', (.47, .33, .17), .86)
bindings = {}
random.seed(21)


def bind(obj, bone):
    bindings[obj.name] = bone
    return obj


def flat(obj):
    for p in obj.data.polygons:
        p.use_smooth = False
    return obj


def lathe(name, rings, mat, bone, count=24, variation=.0):
    vertices, faces = [], []
    for j, (z, rx, ry, cy) in enumerate(rings):
        for i in range(count):
            a = math.tau*i/count
            irregularity = 1 + variation*math.sin(a*3 + j*.8)
            vertices.append((rx*math.sin(a)*irregularity, cy+ry*math.cos(a)*irregularity, z))
    for j in range(len(rings)-1):
        for i in range(count):
            a = j*count+i
            b = j*count+(i+1)%count
            faces.append((a, b, b+count, a+count))
    faces += [tuple(range(count-1, -1, -1)), tuple((len(rings)-1)*count+i for i in range(count))]
    return bind(flat(mesh_object(name, vertices, faces, character, mat)), bone)


shell_rings = [(.16,.05,.055,0), (.205,.12,.105,0), (.28,.18,.145,0),
               (.39,.22,.174,0), (.52,.243,.188,0), (.64,.238,.18,0), (.71,.21,.158,0)]
shell = lathe('Acorn_shell', shell_rings, wood, 'torso', 28)
# Longitudinal wooden facets, with gentle deterministic shifts between panels.
for i in range(7):
    shade = wood.copy()
    shade.name = 'Shell_panel_%02d' % i
    shade.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = tuple(c*(.86+i*.042) for c in wood.diffuse_color[:3])+(1,)
    shell.data.materials.append(shade)
for p in shell.data.polygons:
    p.material_index = [2,3,4,3,1,4,5,3,2,4,3,5,2,3,4,2,3,5,4,3,2,4,3,5,4,2,3,4][p.index % 28] if len(p.vertices)==4 else 0

cap = lathe('Broad_acorn_cap', [(.586,.252,.192,-.018),(.602,.332,.262,-.008),
    (.643,.371,.285,0),(.704,.359,.277,-.009),(.744,.324,.257,-.021),
    (.824,.282,.226,-.032),(.889,.195,.168,-.036),(.922,.106,.099,-.036),(.933,.025,.03,-.032)], capmat, 'cap', 28, .022)
# A tilted brow and irregular folded lip, already part of the cap surface.
for v in cap.data.vertices:
    v.co.z += .042 * max(0., min(1., (.80-v.co.z)/.13))
    v.co.z += -.035*v.co.x + .012*math.sin(v.co.x*7)*max(0., (v.co.y+.2)/.5)
for i in range(5):
    shade=capmat.copy();shade.name='Cap_facet_%d'%i
    shade.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=tuple(c*(.86+i*.062) for c in capmat.diffuse_color[:3])+(1,)
    cap.data.materials.append(shade)
for p in cap.data.polygons:
    p.material_index = (p.index*13 + p.index//28)%6


shell.data.calc_loop_triangles()
shell_surface = BVHTree.FromPolygons([v.co for v in shell.data.vertices],
    [t.vertices for t in shell.data.loop_triangles], all_triangles=True)


def shell_front(x, z):
    hit = shell_surface.ray_cast(Vector((x,1,z)),Vector((0,-1,0)))[0]
    if hit is None:raise ValueError('Facial patch extends past shell: %s' % ((x,z),))
    return hit.y


def face_patch(name, outline, mat, offset, bone='torso'):
    center=Vector((sum(p[0] for p in outline)/len(outline),sum(p[1] for p in outline)/len(outline)))
    verts=[];faces=[]
    # Dense patches conform to the actual faceted shell, including its seams.
    # A single fan crossed underneath the convex shell between its vertices.
    n=12
    for k in range(len(outline)):
        a=center;b=Vector(outline[k]);c=Vector(outline[(k+1)%len(outline)])
        indices={}
        for i in range(n+1):
            for j in range(n+1-i):
                p=a+(b-a)*i/n+(c-a)*j/n
                indices[i,j]=len(verts);verts.append((p.x,shell_front(p.x,p.y)+offset,p.y))
        for i in range(n):
            for j in range(n-i):
                faces.append((indices[i,j],indices[i+1,j],indices[i,j+1]))
                if i+j<n-1:faces.append((indices[i+1,j],indices[i+1,j+1],indices[i,j+1]))
    return bind(mesh_object(name,verts,faces,character,mat),bone)


# The upper black edge disappears under the actual cap, forming a stern brow.
face_patch('Dark_eye_mask',[(-.206,.650),(-.166,.686),(-.095,.692),(0,.682),(.095,.692),(.171,.675),(.208,.635),(.196,.557),(.152,.534),(.096,.532),(.047,.551),(0,.556),(-.050,.546),(-.103,.530),(-.158,.535),(-.198,.565)],maskmat,.003)
for side,sign in [('L',-1),('R',1)]:
    cx=sign*.112
    # Almond/oval eyes with a slanted upper edge; no floating sphere stacks.
    shape=[(.047*math.cos(i*math.tau/20),.050*math.sin(i*math.tau/20)) for i in range(20)]
    eye=[(cx+x,min(.590+z,.619+sign*x*.48)) for x,z in shape]
    face_patch('Eye_'+side,eye,ivory,.0065)
    pcx=cx-sign*.008
    pupil=[(pcx+.013*math.cos(i*math.tau/14),.602+.029*math.sin(i*math.tau/14)) for i in range(14)]
    face_patch('Pupil_'+side,pupil,pupilmat,.010)

stem = bind(flat(tube('Bent_stem', [(0,-.033,.915,.043),(-.01,-.035,.970,.039),
             (.028,-.033,1.044,.044),(.075,-.025,1.075,.034),(.099,-.015,1.057,.020)], character,bark,8,1)), 'stem')
# Thick folded leaf: visible side/rear volume and carved veins on the front.
leaf_points=[(.079,-.017,1.057),(.163,-.028,1.081),(.250,-.030,1.059),(.298,-.010,1.011),
             (.336,.008,.933),(.229,.007,.942),(.155,-.010,.980)]
leaf_center=(.215,-.035,1.016)
verts=[leaf_center]+leaf_points+[(x,y-.008,z) for x,y,z in [leaf_center]+leaf_points]
faces=[(0,i+1,(i+1)%7+1) for i in range(7)]
faces += [(8,(i+1)%7+9,i+9) for i in range(7)]
faces += [(i+1,i+9,(i+1)%7+9,(i+1)%7+1) for i in range(7)]
bind(flat(mesh_object('Golden_leaf',verts,faces,character,leafmat)), 'leaf')
for name,points in [('Leaf_midvein',[(.093,.000,1.058,.004),(.210,-.004,1.023,.004),(.311,.012,.955,.0025)]),
    ('Leaf_vein_1',[(.173,-.003,1.035,.0025),(.203,.000,.982,.002)]),
    ('Leaf_vein_2',[(.210,-.004,1.023,.0025),(.261,-.004,1.034,.0015)])]:
    bind(flat(tube(name,points,character,veinmat,6,1)), 'leaf')

# Front reference has the leaf on the viewer's right, opposite the club.
for name,bone in list(bindings.items()):
    if bone in ['stem','leaf']:
        for v in bpy.data.objects[name].data.vertices:v.co.x *= -1

bones = [
 ('root',None,(0,0,0),(0,0,.1)),('pelvis','root',(0,0,.19),(0,0,.37)),
 ('torso','pelvis',(0,0,.37),(0,0,.67)),('cap','torso',(0,0,.67),(0,-.025,.925)),
 ('stem','cap',(0,-.03,.915),(-.082,-.02,1.058)),('leaf','stem',(-.082,-.02,1.058),(-.28,0,.97))]
for side,sign in [('L',-1),('R',1)]:
    shoulder=Vector((sign*.235,0,.51));elbow=Vector((sign*.298,.025,.375));wrist=Vector((sign*.333,.076,.307))
    hip=Vector((sign*.118,0,.224));knee=Vector((sign*.148,.008,.147));ankle=Vector((sign*.156,.025,.067))
    bones += [('arm_'+side,'torso',shoulder,elbow),('forearm_'+side,'arm_'+side,elbow,wrist),
              ('hand_'+side,'forearm_'+side,wrist,wrist+Vector((0,.025,-.038))),
              ('leg_'+side,'pelvis',hip,knee),('shin_'+side,'leg_'+side,knee,ankle),
              ('foot_'+side,'shin_'+side,ankle,ankle+Vector((0,.075,-.036)))]
    bind(flat(tube('Upper_branch_'+side,[(*shoulder,.050),(*(shoulder.lerp(elbow,.55)),.045),(*elbow,.044)],character,bark,9,1)),'arm_'+side)
    bind(flat(tube('Fore_branch_'+side,[(*elbow,.046),(*(elbow.lerp(wrist,.55)),.042),(*wrist,.047)],character,bark,9,1)),'forearm_'+side)
    bind(flat(ellipsoid('Elbow_joint_'+side,elbow,(.048,.049,.049),character,bark,10,8)),'forearm_'+side)
    bind(flat(ellipsoid('Knuckle_'+side,wrist,(.063,.064,.058),character,bark,12,8)),'hand_'+side)
    # Thumb pads meet the fist; the gripping hand surrounds the club handle.
    bind(flat(ellipsoid('Thumb_'+side,wrist+Vector((-sign*.034,.038,.011)),(.027,.036,.028),character,bark,10,6)),'hand_'+side)
    bind(flat(tube('Upper_leg_'+side,[(*hip,.052),(*knee,.045)],character,bark,9,1)),'leg_'+side)
    bind(flat(tube('Lower_leg_'+side,[(*knee,.047),(*ankle,.055)],character,bark,9,1)),'shin_'+side)
    bind(flat(ellipsoid('Knee_joint_'+side,knee,(.049,.050,.050),character,bark,10,8)),'shin_'+side)
    foot=lathe('Wooden_foot_'+side,[(.007,.077,.092,.048),(.030,.083,.098,.050),(.073,.068,.076,.037),(.113,.046,.052,.017)],bark,'foot_'+side,12)
    for v in foot.data.vertices:v.co.x+=sign*.156

club_direction=Vector((.49,.08,.87)).normalized()
club_grip=Vector((.333,.076,.309))
bones.append(('club_socket','hand_R',club_grip,club_grip+club_direction*.10))
data=bpy.data.armatures.new('AcornGuard_Skeleton');rig=bpy.data.objects.new('AcornGuard_Rig',data);character.objects.link(rig)
activate(rig);bpy.ops.object.mode_set(mode='EDIT')
for name,parent,head,tail in bones:
    b=data.edit_bones.new(name);b.head=head;b.tail=tail
    if parent:b.parent=data.edit_bones[parent]
    b.use_deform=name not in ['root','club_socket']
bpy.ops.object.mode_set(mode='OBJECT')
for name,bone in bindings.items():
    o=bpy.data.objects[name];g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1.,'REPLACE')
    mod=o.modifiers.new('Authored skeleton','ARMATURE');mod.object=rig
    o.parent=rig

# Independent editable weapon scene with +Y along the handle-to-head direction.
weapon_scene=bpy.data.scenes.new('WoodenClub_Production')
weapon=bpy.data.collections.new('WoodenClub_Asset');weapon_scene.collection.children.link(weapon)
club=flat(tube('Tapered_wooden_club',[(0,-.063,0,.025),(0,0,0,.030),(0,.105,0,.038),
            (.003,.275,0,.060),(.002,.378,0,.074),(0,.406,0,.070)],weapon,bark,10,1))
club.data.materials.append(endgrain)
club.data.polygons[-1].material_index=1
# Concentric low-poly end grain, inset safely into the wooden head surface.
for radius in [.022,.047]:
    points=[(radius*math.cos(i*math.tau/16),.4068,radius*math.sin(i*math.tau/16),.0012) for i in range(17)]
    flat(tube('Endgrain_ring',points,weapon,endgrain,5,1))
preview=bpy.data.objects.new('Preview_wooden_club',None);preview.instance_type='COLLECTION';preview.instance_collection=weapon
equipment.objects.link(preview)
constraint=preview.constraints.new('COPY_TRANSFORMS');constraint.target=rig;constraint.subtarget='club_socket'
bpy.context.window.scene=weapon_scene
bpy.context.view_layer.update()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/weapons/wooden_club/source.blend'),copy=True)
bpy.context.window.scene=scene

# Bake connected limb poses to standard transforms. The gameplay root stays fixed.
rest={b.name:b.matrix_local.copy() for b in rig.data.bones}
parents={b.name:b.parent.name if b.parent else None for b in rig.data.bones}
lengths={b.name:b.length for b in rig.data.bones}
T=Matrix.Translation


def pivot(m,p):return T(p)@m@T(-Vector(p))
def rot(axis,angle):return Matrix.Rotation(angle,4,axis)
def smooth(t):t=max(0.,min(1.,t));return t*t*(3-2*t)


def align(n,a,b):
    m=(rest[n].to_3x3()@Vector((0,1,0))).rotation_difference((b-a).normalized()).to_matrix().to_4x4()@rest[n]
    m.translation=a;return m


def joint(a,b,l1,l2,pole):
    axis=b-a;d=min(axis.length,l1+l2-.0001);axis.normalize();b=a+axis*d
    along=(d*d+l1*l1-l2*l2)/(2*max(d,.0001));height=math.sqrt(max(0,l1*l1-along*along))
    bend=Vector(pole)-a;bend-=axis*bend.dot(axis);bend.normalize()
    return a+axis*along+bend*height,b


def pose(clip,u):
    wave=math.sin(u*math.tau);bob=-.006;lean=.035;yaw=0.;weight=0.;roll=0.
    grip=club_grip.copy();direction=club_direction.copy()
    if clip=='idle':bob+=.003*wave
    if clip=='walk':bob=-.050+.005*math.cos(u*math.tau*2);lean=.12;yaw=.035*wave
    if clip in ['windup','strike','recover']:
        if clip=='windup':weight=smooth(u);travel=0.
        elif clip=='strike':weight=1.;travel=smooth(u)
        else:weight=1-smooth(u);travel=1.
        ready=Vector((.33,-.005,.49));finish=Vector((.07,.28,.36))
        ready_dir=Vector((.62,.05,.78)).normalized();finish_dir=Vector((-.65,.75,-.13)).normalized()
        if clip=='windup':grip=grip.lerp(ready,weight);direction=direction.lerp(ready_dir,weight).normalized()
        elif clip=='strike':grip=ready.lerp(finish,travel);direction=ready_dir.lerp(finish_dir,travel).normalized()
        else:grip=finish.lerp(grip,1-weight);direction=finish_dir.lerp(direction,1-weight).normalized()
        yaw=(-.34+.76*travel)*weight;lean=(-.12+.40*travel)*weight;bob=-.006-.023*weight
    if clip=='hurt':weight=math.sin(math.pi*u);lean=-.22*weight;bob-=.014*weight
    if clip=='death':weight=smooth(u);roll=-1.32*weight;bob-=.15*weight
    base=T((.006*wave if clip=='walk' else 0,0,bob))@pivot(rot('X',roll),(0,0,.24))
    body=base@pivot(rot('Z',yaw)@rot('X',-lean),(0,0,.30))
    m={'root':rest['root'].copy(),'pelvis':base@rest['pelvis']}
    for n in ['torso','cap','stem','leaf']:m[n]=body@rest[n]
    cap_sway=.018*wave if clip in ['idle','walk'] else -.025*math.sin(math.pi*u)
    for n in ['cap','stem','leaf']:m[n]=body@pivot(rot('Z',cap_sway),rest['cap'].translation)@rest[n]
    m['leaf']=m['stem']@rest['stem'].inverted()@pivot(rot('X',.06*math.sin(u*math.tau-.5)),rest['leaf'].translation)@rest['leaf']
    for side,sign in [('L',-1),('R',1)]:
        hip=base@rest['leg_'+side].translation;ankle=rest['foot_'+side].translation.copy()
        if clip=='walk':
            p=(u+(0 if side=='L' else .5))%1
            if p<.55:y=.115-.230*p/.55;lift=0
            else:t=(p-.55)/.45;y=-.115+.230*smooth(t);lift=.032*math.sin(math.pi*t)**2
            ankle.y+=y;ankle.z+=lift
        if clip=='death':ankle=base@ankle
        k,ankle=joint(hip,ankle,lengths['leg_'+side],lengths['shin_'+side],hip+Vector((sign*.02,.25,0)))
        m['leg_'+side]=align('leg_'+side,hip,k);m['shin_'+side]=align('shin_'+side,k,ankle)
        m['foot_'+side]=rest['foot_'+side].copy();m['foot_'+side].translation=ankle
        if clip=='death':m['foot_'+side]=base@rest['foot_'+side]
        if side=='R':
            if clip=='walk':grip.y+=.014*wave
            socket=direction.to_track_quat('Y','Z').to_matrix().to_4x4();socket.translation=grip
            hand=socket@rest['club_socket'].inverted()@rest['hand_R']
        else:
            swing=.22*wave if clip=='walk' else -.14*weight
            hand=body@pivot(rot('X',swing),rest['arm_L'].translation)@rest['hand_L']
        if clip=='death':hand=body@rest['hand_'+side]
        shoulder=body@rest['arm_'+side].translation
        elbow,wrist=joint(shoulder,hand.translation,lengths['arm_'+side],lengths['forearm_'+side],Vector((sign*.44,0,.33)))
        hand.translation=wrist
        m['arm_'+side]=align('arm_'+side,shoulder,elbow);m['forearm_'+side]=align('forearm_'+side,elbow,wrist);m['hand_'+side]=hand
    m['club_socket']=m['hand_R']@rest['hand_R'].inverted()@rest['club_socket']
    return m


rig.animation_data_create()
durations={'idle':2.,'walk':.40,'windup':.65,'strike':.18,'recover':.65,'hurt':.30,'death':.65}
for name,duration in durations.items():
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data.action=action
    frames=round(duration*120)
    for f in range(frames+1):
        matrices=pose(name,f/frames)
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
rig.show_in_front=True
scene['reference']='res://assets/references/acorn_guard/turnaround.png'
scene['review_notes']='Broad olive cap, tapered wooden shell, attached dark eye mask, short branch limbs, right-hand club; original reference is authoritative.'
bpy.ops.wm.save_as_mainfile(filepath=str(DEST/'source.blend'))
print('ACORN_SOURCE_SAVED',len(character.objects),'objects;',len(data.bones),'bones;',list(durations))
REVIEW_SOURCE=scene.name;REVIEW_LABEL='acorn_guard_neutral';REVIEW_SIZE=1.5;REVIEW_TARGET=(0,0,.56)
exec((ROOT/'tools/lantern_village/review_blender.py').read_text())
