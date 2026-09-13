# HISTORICAL GENERATOR: see README; do not run over the reviewed character sources.
"""Editable reference-based meshes and in-place skeletal Actions. Run inside Blender.
Builds a new scene; does not alter the user's original scene or source references.
Blender coordinates: +Y forward, +Z up. glTF: -Z forward, +Y up.
"""
import bpy, math, random, json, os
from mathutils import Vector, Quaternion, Matrix
from math import sin, cos, pi
ROOT='/Users/jelle/Godot-Projects/crow-test'
random.seed(41)
scene=bpy.data.scenes.new('Crow_Production')
bpy.context.window.scene=scene
scene.unit_settings.system='METRIC'
scene.unit_settings.scale_length=1.0
scene.render.fps=100
COL=bpy.data.collections.new('Crow_Character')
scene.collection.children.link(COL)

def move_to(obj,col=COL):
    for c in list(obj.users_collection): c.objects.unlink(obj)
    col.objects.link(obj)
    return obj

def material(name,color,rough=.46,metal=0,emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m
black=material('Crow_Obsidian',(0.026,.031,.039),.36)
cream=material('Crow_Warm_Cream',(.64,.50,.38),.61)
brown=material('Crow_Underbelly',(.22,.165,.115),.64)
white=material('Crow_Porcelain_Eyes',(.94,.96,.93),.24)
beakmat=material('Crow_Beak',(.52,.395,.29),.5)
beakseam=material('Crow_Beak_Seam',(.16,.12,.09),.63)
feetmat=material('Crow_Feet',(.025,.03,.034),.5)
pink=material('Blade_Rose_Emission',(.95,.015,.18),.27,.18,1.7)
pinkedge=material('Blade_Rose_Edges',(.52,.004,.077),.31,.2,1.1)
gripmat=material('Sword_Obsidian_Grip',(.025,.03,.043),.36,.25)
stone=[material('Stone_Warm_%02d'%i,(.29+i*.013,.285+i*.012,.265+i*.011),.85) for i in range(6)]
mortar=material('Stone_Mortar',(.19,.19,.175),.95)

meshes=[]
def mesh(name,verts,faces,mat,smooth=True,col=COL):
    d=bpy.data.meshes.new(name); d.from_pydata(verts,[],faces);d.update()
    o=bpy.data.objects.new(name,d);col.objects.link(o);d.materials.append(mat)
    for p in d.polygons:p.use_smooth=smooth
    return o

def apply(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)

def ellipsoid(name,loc,scale,mat,segments=24,rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=loc)
    o=move_to(bpy.context.object);o.name=name;o.scale=scale;apply(o);o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    return o

def box(name,loc,size,mat,bevel=.012,col=COL):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=move_to(bpy.context.object,col);o.name=name;o.scale=size;apply(o);o.data.materials.append(mat)
    if bevel:
        mod=o.modifiers.new('Soft stone edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

# Continuous pear body and tall neck, rounded flattened crown.
profile=[(.15,.09,.11,-.015),(.19,.17,.16,0),(.27,.225,.20,0),(.40,.26,.235,.008),(.54,.245,.225,.005),(.65,.21,.19,0),(.74,.165,.15,-.008),(.85,.14,.13,-.006),(.98,.132,.124,0),(1.09,.141,.135,0),(1.165,.14,.127,0),(1.19,.10,.10,0),(1.20,.018,.025,0)]
N=48
verts=[]
for z,rx,ry,cy in profile:
    for i in range(N):
        a=2*pi*i/N;verts.append((rx*sin(a),cy+ry*cos(a),z))
faces=[]
for j in range(len(profile)-1):
    for i in range(N):a=j*N+i;b=j*N+(i+1)%N;faces.append((a,b,b+N,a+N))
faces += [tuple(reversed(range(N))),tuple((len(profile)-1)*N+i for i in range(N))]
body=mesh('Crow_Body',verts,faces,black)
sub=body.modifiers.new('Silhouette smoothing','SUBSURF');sub.levels=2
bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=sub.name)
body.data.materials.append(brown)
for p in body.data.polygons:
    if p.center.z < .30:p.material_index=1

# Raised feather-colour patch hugs front of torso, with scalloped lower border.
v=[];f=[];rows=16;cols=28
for j in range(rows+1):
    t=j/rows
    for i in range(cols+1):
        u=-1+2*i/cols
        z=.305+(.61-.305)*t + .014*cos(u*pi*6)*(1-t)**8
        # Elliptical patch tapered at top and bottom; depth from body profile.
        width=.221*(.85+.15*sin(t*pi))*(1-.23*t*t)
        x=u*width
        ry=.231;rx=.254
        y=.018+ry*math.sqrt(max(.05,1-(x/rx)**2))
        y-=.018*(t-.4)**2
        # upper corners taper down into breast edge
        z-=.053*abs(u)**3*t**4
        v.append((x,y+.003,z))
for j in range(rows):
    for i in range(cols):a=j*(cols+1)+i;f.append((a,a+1,a+cols+2,a+cols+1))
belly=mesh('Cream_Breast_Feathers',v,f,cream)
# side neck cream sweeps, following body surface rather than clothing.
neckpatch=[]
for side in [-1,1]:
    v=[];f=[]
    for j in range(21):
        t=j/20;z=.65+.39*t
        rx=.14+.034*(1-t)**3;ry=.128+.026*(1-t)**3
        center=side*(1.16+.15*sin(t*pi))
        width=.54*(sin(pi*t)**.55)+.045
        for i in range(13):
            a=center+width*(-1+2*i/12)
            zz=z+.015*sin(i/12*pi)*sin(pi*t)
            v.append(((rx+.004)*sin(a),(ry+.004)*cos(a)-.005,zz))
    for j in range(20):
        for i in range(12):a=j*13+i;f.append((a,a+1,a+14,a+13))
    neckpatch.append(mesh('Cream_Neck_'+str(side),v,f,cream))

# Beak: two broad, flattened tapered mandibles with a seam.
for upper in [True,False]:
    vv=[];ff=[]
    for y,w,h,z in [( .104,.072,.015,1.064),(.17,.079,.039,1.064),(.265,.061,.027,1.064),(.323,.012,.003,1.064)]:
        for i in range(24):
            a=2*pi*i/24;vv.append((w*cos(a),y,z+sin(a)*h*(1 if upper else .65)+(0.009 if upper else -.014)))
    for j in range(3):
        for i in range(24):a=j*24+i;b=j*24+(i+1)%24;ff.append((a,b,b+24,a+24))
    ff.append(tuple(72+i for i in range(24)))
    meshes.append((mesh('Beak_Upper' if upper else 'Beak_Lower',vv,ff,beakmat),'head'))
for s in [-1,1]:
    meshes.append((ellipsoid('White_Eye_'+str(s),(s*.133,.047,1.118),(.026,.038,.048),white),'head'))
    # short backward crown point from profile.
    feather=ellipsoid('Crown_Sweep_'+str(s),(s*.075,-.109,1.14),(.056,.065,.025),black)
    meshes.append((feather,'head'))

# Lobed hanging wings. Separate feathers maintain their silhouette at the elbow.
wingobjects=[]
for s,suffix in [(-1,'L'),(1,'R')]:
    o=ellipsoid('Wing_Covert_'+suffix,(s*.252,-.016,.53),(.097,.116,.255),black)
    for vtx in o.data.vertices:vtx.co.x+=s*(.67-vtx.co.z)*.32
    wingobjects.append((o,suffix))
    for i in range(3):
        o=ellipsoid('Wing_Primary_'+suffix+str(i),(s*(.30+.064*i),-.022+.035*i,.29-.026*i),(.064,.073,.18+.014*i),black)
        for vtx in o.data.vertices:vtx.co.x+=s*(.40-vtx.co.z)*.12
        wingobjects.append((o,suffix))
    meshes.append((ellipsoid('Leg_Feathers_'+suffix,(s*.135,.008,.145),(.045,.051,.085),brown),'leg_'+suffix))
    meshes.append((ellipsoid('Ankle_'+suffix,(s*.135,.013,.061),(.024,.027,.043),feetmat),'foot_'+suffix))
    meshes.append((ellipsoid('Foot_'+suffix,(s*.135,.040,.024),(.046,.060,.023),feetmat),'foot_'+suffix))
    for i in [-1,0,1]:
        toe=ellipsoid('Toe_'+suffix+str(i),(s*.135+i*.033,.085-abs(i)*.007,.017),(.017,.046,.016),feetmat)
        meshes.append((toe,'foot_'+suffix))
    meshes.append((ellipsoid('Back_Toe_'+suffix,(s*.135,-.026,.018),(.019,.035,.016),feetmat),'foot_'+suffix))
for i in [-1,0,1]:
    o=ellipsoid('Tail_Feather_'+str(i),(i*.073,-.216,.285+abs(i)*.006),(.073,.10,.148-abs(i)*.02),black)
    meshes.append((o,'tail'))

# Armature. Rest axes consistently +Z; sword socket deliberately points +Y.
arm=bpy.data.armatures.new('Crow_Skeleton');rig=bpy.data.objects.new('Crow_Rig',arm);COL.objects.link(rig)
bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
def bone(n,p,parent=None,tail=None):
    b=arm.edit_bones.new(n);b.head=p;b.tail=tail or (p[0],p[1],p[2]+.1)
    if parent:b.parent=arm.edit_bones[parent]
    return b
bone('root',(0,0,0));bone('pelvis',(0,0,.30),'root');bone('torso',(0,0,.56),'pelvis');bone('neck',(0,0,.83),'torso');bone('head',(0,0,1.06),'neck')
for s,suf in [(-1,'L'),(1,'R')]:
    bone('wing_'+suf,(s*.185,0,.70),'torso');bone('wing_tip_'+suf,(s*.32,0,.43),'wing_'+suf)
    bone('leg_'+suf,(s*.135,0,.21),'pelvis');bone('foot_'+suf,(s*.135,.008,.045),'leg_'+suf)
bone('tail',(0,-.15,.35),'pelvis')
bone('sword_socket',(.365,0,.34),'wing_tip_R',(.365,.1,.34))
bpy.ops.object.mode_set(mode='OBJECT');rig.show_in_front=True

def skin(o,weights):
    o.parent=rig
    groups={n:o.vertex_groups.new(name=n) for n in weights}
    for v in o.data.vertices:
        vals={n:float(fn(v.co) if callable(fn) else fn) for n,fn in weights.items()};total=sum(vals.values())
        for n,w in vals.items():
            if w>0:groups[n].add([v.index],w/total,'REPLACE')
    m=o.modifiers.new('Crow skin','ARMATURE');m.object=rig

def blend_z(z,a,b):return max(0,min(1,(z-a)/(b-a)))
skin(body,{'pelvis':lambda p:1-blend_z(p.z,.30,.57),'torso':lambda p:blend_z(p.z,.30,.57)*(1-blend_z(p.z,.70,.9)),'neck':lambda p:blend_z(p.z,.70,.9)*(1-blend_z(p.z,1.01,1.10)),'head':lambda p:blend_z(p.z,1.01,1.10)})
skin(belly,{'pelvis':lambda p:1-blend_z(p.z,.3,.57),'torso':lambda p:blend_z(p.z,.3,.57)})
for o in neckpatch:skin(o,{'torso':lambda p:1-blend_z(p.z,.72,.9),'neck':lambda p:blend_z(p.z,.72,.9)})
for o,suf in wingobjects:skin(o,{'wing_'+suf:lambda p:blend_z(p.z,.36,.55),'wing_tip_'+suf:lambda p:1-blend_z(p.z,.36,.55)})
for o,b in meshes:skin(o,{b:1})

# Authored action poses. World-axis relative rotations converted to bone local axes.
def pose_reset():
    for b in rig.pose.bones:b.rotation_mode='QUATERNION';b.location=(0,0,0);b.rotation_quaternion=(1,0,0,0);b.scale=(1,1,1)
def rotate(n,x=0,y=0,z=0):
    b=rig.pose.bones[n];basis=b.bone.matrix_local.to_quaternion()
    q=Quaternion((0,0,1),z)@Quaternion((0,1,0),y)@Quaternion((1,0,0),x)
    b.rotation_quaternion=basis.inverted()@q@basis

def translate(n,v):
    b=rig.pose.bones[n];b.location=b.bone.matrix_local.to_3x3().inverted()@Vector(v)

def lerp(a,b,t):return a+(b-a)*t
def keyed(points,u):
    for i in range(len(points)-1):
        a,v=points[i];b,w=points[i+1]
        if u<=b:
            t=max(0,(u-a)/(b-a));t=t*t*(3-2*t);return lerp(v,w,t)
    return points[-1][1]

def wing_attack(angle,lift=1):
    # Lift around forward axis, then sweep the entire carrying wing in world Z.
    rotate('wing_R',x=.08,y=-1.12*lift,z=angle)
    rotate('wing_tip_R',y=-.12*lift)
    rotate('wing_L',x=-.15,y=.20,z=-angle*.18)
    # Grasp stays at the distal wing. Blade rest +Y is aimed outward by socket.
    rotate('sword_socket',x=0,y=.20*lift,z=-1.32*lift)

clips={'idle':2,'walk':.8,'run':.55,'dodge_roll':.42,'attack_1':.36,'attack_2':.38,'attack_3':.48,'heavy_charge':.6,'heavy_hold':.5,'heavy_release':.65,'roll_attack':.45,'hurt':.25,'death':.9}
for name,duration in clips.items():
    action=bpy.data.actions.new(name);action.use_fake_user=True;rig.animation_data_create();rig.animation_data.action=action
    end=round(duration*100)
    for frame in range(0,end+1):
        u=frame/end;t=frame/100;pose_reset()
        # Rest sword trails behind flank, never duplicated on back.
        rotate('sword_socket',x=-.55,z=pi)
        if name=='idle':
            translate('torso',(0,0,.007*sin(2*pi*u)));rotate('head',x=.024*sin(2*pi*u),z=.035*sin(2*pi*u))
            rotate('wing_L',y=.02*sin(2*pi*u));rotate('wing_R',y=-.02*sin(2*pi*u))
        elif name in ['walk','run']:
            speed=1 if name=='walk' else 1.6;a=2*pi*u
            # Foot translation describes a planted backward half-cycle and lifted return.
            for side,phase in [('L',a),('R',a+pi)]:
                lift=max(0,sin(phase));stride=.15*speed
                translate('leg_'+side,(0,stride*cos(phase),.055*speed*lift))
                rotate('leg_'+side,x=.18*speed*cos(phase));rotate('foot_'+side,x=-.18*speed*cos(phase)-.16*lift)
            translate('pelvis',(0,0,.012*speed*(1-cos(2*a))))
            rotate('torso',x=-.065*speed,y=.028*sin(a));rotate('head',x=.045*speed)
            rotate('wing_L',x=.13*sin(a),y=.04);rotate('wing_R',x=-.13*sin(a),y=-.04)
        elif name=='dodge_roll':
            angle=keyed([(0,0),(.13,.05),(.85,2*pi),(1,2*pi)],u)
            rotate('pelvis',x=-angle)
            # Pelvis is the roll pivot; root stays exactly fixed.
            translate('pelvis',(0,0,keyed([(0,0),(.12,-.08),(.35,.33),(.68,.33),(.9,.03),(1,0)],u)))
            fold=sin(pi*u)**.5
            rotate('neck',x=-.50*fold);rotate('head',x=-.22*fold)
            rotate('wing_L',x=-.5*fold,y=-.28*fold);rotate('wing_R',x=-.5*fold,y=.28*fold)
            rotate('leg_L',x=-.7*fold);rotate('leg_R',x=-.7*fold)
        elif name.startswith('attack_') or name in ['heavy_release','roll_attack']:
            timings={'attack_1':(.08,.18),'attack_2':(.09,.19),'attack_3':(.12,.24),'heavy_release':(.16,.32),'roll_attack':(.07,.19)}
            a,b=timings[name];start=a/duration;stop=b/duration
            reverse=name=='attack_2';sign=-1 if reverse else 1
            angle=keyed([(0,-1.0*sign),(start,-1.0*sign),(stop,1.35*sign),(1,0)],u)
            lift=keyed([(0,.22),(start,1),(stop,1),(1,0)],u)
            if name=='heavy_release':lift=keyed([(0,1),(stop,1),(.8,.6),(1,0)],u)
            wing_attack(angle,lift)
            rotate('torso',x=-.13*sin(pi*u),z=angle*.24)
            rotate('head',z=-angle*.14)
            translate('pelvis',(0,0,-.025*sin(pi*u)))
            rotate('leg_L',x=.10*sin(pi*u));rotate('leg_R',x=-.14*sin(pi*u))
        elif name in ['heavy_charge','heavy_hold']:
            strength=(u*u*(3-2*u)) if name=='heavy_charge' else 1
            wing_attack(-1.0,strength)
            rotate('torso',x=.09*strength,z=-.24*strength);rotate('head',z=.15*strength)
            translate('pelvis',(0,0,-.035*strength+.002*sin(u*2*pi)))
        elif name=='hurt':
            k=sin(pi*u);rotate('torso',x=.28*k);rotate('neck',x=-.12*k);rotate('wing_L',y=.45*k);rotate('wing_R',y=-.35*k)
        elif name=='death':
            k=keyed([(0,0),(.28,.25),(.72,1),(1,1)],u)
            rotate('pelvis',x=-1.40*k,z=.15*k);translate('pelvis',(0,0,-.035*k))
            rotate('neck',x=-.25*k);rotate('wing_L',y=.42*k);rotate('wing_R',y=-.3*k)
        for b in rig.pose.bones:
            b.keyframe_insert('location',frame=frame,group=b.name);b.keyframe_insert('rotation_quaternion',frame=frame,group=b.name)
    action['duration_seconds']=duration;action['in_place']=True
rig.animation_data.action=bpy.data.actions['idle'];scene.frame_start=0;scene.frame_end=200;scene.frame_set(0)

# Standalone sword. Handle at origin. Blade extends along +Y => Godot -Z.
SWORD=bpy.data.collections.new('Sword_Export');scene.collection.children.link(SWORD)
verts=[(-.059,.15,0),(.059,.15,0),(-.071,.70,0),(.071,.70,0),(0,.86,0),(0,.15,.026),(0,.67,.026),(0,.15,-.026),(0,.67,-.026)]
faces=[(0,2,6,5),(1,5,6,3),(2,4,6),(3,6,4),(0,7,8,2),(1,3,8,7),(2,8,4),(3,4,8),(0,5,1,7)]
blade=mesh('Roseblade',verts,faces,pink,False,SWORD);blade.data.materials.append(pinkedge)
for i in [1,3,5,7]:blade.data.polygons[i].material_index=1
box('Grip',(0,.014,0),(.041,.245,.044),gripmat,.007,SWORD)
box('Blade_Collar',(0,.139,0),(.118,.053,.06),gripmat,.004,SWORD)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.056,location=(0,-.13,0));pommel=move_to(bpy.context.object,SWORD);pommel.name='Diamond_Pommel';pommel.scale=(.7,1,.7);apply(pommel);pommel.data.materials.append(gripmat)

# Irregular stone polygons clipped to a square, with a continuous flat slab underneath.
GROUND=bpy.data.collections.new('Ground_Export');scene.collection.children.link(GROUND)
box('Tile_Base',(0,0,-.115),(2,2,.17),mortar,.007,GROUND)
seeds=[(-.65,-.66),(.24,-.71),(.75,-.52),(-.70,.12),(.02,.02),(.72,.19),(-.6,.77),(.13,.72),(.78,.77)]
def clip(poly,n,c):
    out=[]
    for a,b in zip(poly,poly[1:]+poly[:1]):
        da=a[0]*n[0]+a[1]*n[1]-c;db=b[0]*n[0]+b[1]*n[1]-c
        if da<=0:out.append(a)
        if (da<=0)!=(db<=0):
            t=da/(da-db);out.append((lerp(a[0],b[0],t),lerp(a[1],b[1],t)))
    return out
for k,s in enumerate(seeds):
    poly=[(-1,-1),(1,-1),(1,1),(-1,1)]
    for q in seeds:
        if s==q:continue
        n=(q[0]-s[0],q[1]-s[1]);c=(q[0]**2+q[1]**2-s[0]**2-s[1]**2)/2
        poly=clip(poly,n,c)
    cx=sum(p[0] for p in poly)/len(poly);cy=sum(p[1] for p in poly)/len(poly)
    poly=[(lerp(x,cx,.015),lerp(y,cy,.015)) for x,y in poly]
    n=len(poly);v=[(x,y,z) for z in [-.07,0] for x,y in poly];f=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    for i in range(n):j=(i+1)%n;f.append((i,j,n+j,n+i))
    o=mesh('Flagstone_%02d'%k,v,f,stone[k%6],False,GROUND)
    mod=o.modifiers.new('Stone arris','BEVEL');mod.width=.009;mod.segments=2
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Stone normals','WEIGHTED_NORMAL');bpy.ops.object.modifier_apply(modifier=mod.name)
WALL=bpy.data.collections.new('LowWall_Export');scene.collection.children.link(WALL)
box('Wall_Core',(0,0,.32),(1.98,.27,.64),mortar,.008,WALL)
for row in range(3):
    widths=([.43,.57,.51,.49] if row%2==0 else [.26,.52,.60,.37,.25])
    cursor=-1
    z=.11+row*.217
    for i,w in enumerate(widths):
        box('Wall_Stone_%d_%d'%(row,i),(cursor+w/2,0,z),(w-.012,.298,.213 if row<2 else .247),stone[(i+row*2)%6],.014,WALL);cursor+=w
# Exact wall bounds 2 x .3 x .7, bottom 0.

# Save before and after exports; no constraint dependency and every Action has own slot.
bpy.ops.object.select_all(action='DESELECT')
for o in COL.objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/source.blend')
def export(col,filename,animated=False):
    bpy.ops.object.select_all(action='DESELECT')
    for o in col.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/exports/'+filename,export_format='GLB',use_selection=True,export_yup=True,export_animations=animated,export_animation_mode='ACTIONS',export_merge_animation='NONE',export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_skins=True,export_def_bones=False,export_rest_position_armature=True)
export(COL,'crow.glb',True);export(SWORD,'sword.glb');export(GROUND,'ground_tile.glb');export(WALL,'low_wall.glb')
for c in [SWORD,GROUND,WALL]:c.hide_viewport=True;c.hide_render=True
rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(0)
# studio setup for inspecting editable character, not exported.
bpy.ops.object.camera_add(location=(2.2,3.8,2.0));cam=bpy.context.object;cam.name='Character_Review_Camera';cam.rotation_euler=(Vector((0,0,.62))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=1.7;scene.camera=cam
for loc,power,size in [((2,3,4),320,3),((-3,2,2),220,3),((0,-3,3),420,2)]:
    bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;o.rotation_euler=(Vector((0,0,.6))-o.location).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.19,.21,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.35
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=ROOT+'/captures/character_blender.png'
scene.view_settings.view_transform='AgX'
bpy.ops.object.select_all(action='DESELECT');body.select_set(True);bpy.context.view_layer.objects.active=body
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/source.blend')
manifest={'blender':bpy.app.version_string,'clips':clips,'bones':[b.name for b in arm.bones],'mesh_count':len([o for o in COL.objects if o.type=='MESH']),'forward':'Blender +Y -> Godot -Z','root_motion':False}
open(ROOT+'/assets/exports/manifest.json','w').write(json.dumps(manifest,indent=2))
result=manifest
