"""Rebuild the reference crow with continuous contour meshes; retain rig + Actions.
Coordinates measured from the front, left and back panels of the supplied sheet.
Run in the Crow_Production scene after build_assets.py. No image planes in exports.
"""
import bpy, bmesh, math, os
from mathutils import Vector
from math import sin,cos,pi,sqrt
ROOT='/Users/jelle/Godot-Projects/crow-test'
scene=bpy.context.scene
rig=bpy.data.objects['Crow_Rig'];col=bpy.data.collections['Crow_Character']
rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/checkpoints/crow_before_contour_revision.blend')
for o in list(col.objects):
    if o.type=='MESH':bpy.data.objects.remove(o,do_unlink=True)
black=bpy.data.materials['Crow_Obsidian'];cream=bpy.data.materials['Crow_Warm_Cream'];brown=bpy.data.materials['Crow_Underbelly'];white=bpy.data.materials['Crow_Porcelain_Eyes'];beakmat=bpy.data.materials['Crow_Beak'];feetmat=bpy.data.materials['Crow_Feet']
for m,c,r in [(black,(.022,.025,.031),.45),(cream,(.66,.50,.405),.57),(brown,(.20,.143,.10),.62),(beakmat,(.58,.435,.34),.48),(feetmat,(.017,.022,.026),.53)]:
    m.diffuse_color=(*c,1);p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=r

def mesh(name,v,f,mat):
    d=bpy.data.meshes.new(name);d.from_pydata(v,[],f);d.update()
    bm=bmesh.new();bm.from_mesh(d);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(d);bm.free()
    o=bpy.data.objects.new(name,d);col.objects.link(o);d.materials.append(mat)
    for p in d.polygons:p.use_smooth=True
    return o

def skin(o,weights):
    o.parent=rig;gs={n:o.vertex_groups.new(name=n) for n in weights}
    for v in o.data.vertices:
        ww={n:max(0,float(fn(v.co) if callable(fn) else fn)) for n,fn in weights.items()};total=sum(ww.values())
        for n,w in ww.items():
            if w>0:gs[n].add([v.index],w/total,'REPLACE')
    m=o.modifiers.new('Crow skin','ARMATURE');m.object=rig

def smoothstep(a,b,v):
    t=max(0,min(1,(v-a)/(b-a)));return t*t*(3-2*t)
def interp(knots,x):
    for j in range(len(knots)-1):
        a,va=knots[j];b,vb=knots[j+1]
        if x<=b:
            t=max(0,(x-a)/(b-a));v0=knots[max(0,j-1)][1];v3=knots[min(len(knots)-1,j+2)][1]
            return .5*((2*va)+(-v0+vb)*t+(2*v0-5*va+4*vb-v3)*t*t+(-v0+3*va-3*vb+v3)*t*t*t)
    return knots[-1][1]
def spline(points,n=6):
    out=[]
    for i in range(len(points)):
        p0=Vector(points[(i-1)%len(points)]);p1=Vector(points[i]);p2=Vector(points[(i+1)%len(points)]);p3=Vector(points[(i+2)%len(points)])
        for k in range(n):
            t=k/n;out.append(.5*(2*p1+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
    return out

# Main black body: one continuous trunk, shoulder, long neck and low crown.
px=[(.14,.008),(.15,.074),(.17,.145),(.23,.215),(.32,.255),(.43,.267),(.54,.238),(.64,.194),(.73,.160),(.82,.139),(.95,.137),(1.075,.143),(1.163,.141),(1.186,.121),(1.199,.059),(1.201,.001)]
py=[(.14,.008),(.15,.069),(.17,.135),(.23,.185),(.32,.235),(.43,.257),(.54,.229),(.64,.184),(.73,.148),(.82,.135),(.95,.131),(1.075,.139),(1.163,.135),(1.186,.114),(1.199,.055),(1.201,.001)]
def bodypos(z,a,offset=0):
    rx=interp(px,z);ry=interp(py,z)
    x=(rx+offset)*sin(a);y=(ry+offset)*cos(a)
    # The slight backward peak belongs to the crown silhouette, not added spheres.
    peak=math.exp(-((z-1.112)/.026)**2)*max(0,-cos(a))**9*.054
    y-=peak
    y+=.014*math.exp(-((z-.4)/.20)**2)
    return (x,y,z)
N=80;NZ=140;v=[];f=[]
for j in range(NZ+1):
    z=.14+(1.201-.14)*j/NZ
    for i in range(N):v.append(bodypos(z,2*pi*i/N))
for j in range(NZ):
    for i in range(N):a=j*N+i;b=j*N+(i+1)%N;f.append((a,a+N,b+N,b))
f.extend([tuple(reversed(range(N))),tuple(NZ*N+i for i in range(N))])
body=mesh('Crow_Body',v,f,black);body.data.materials.append(brown)
for p in body.data.polygons:
    if p.center.z < .304 and p.center.y > -.09:p.material_index=1
weights={'pelvis':lambda p:1-smoothstep(.31,.57,p.z),'torso':lambda p:smoothstep(.31,.57,p.z)*(1-smoothstep(.73,.94,p.z)),'neck':lambda p:smoothstep(.73,.94,p.z)*(1-smoothstep(1.005,1.09,p.z)),'head':lambda p:smoothstep(1.005,1.09,p.z)}
skin(body,weights)
# Cream breast has two upper shoulders, black point in middle, rounded scallops.
v=[];f=[];cols=72;rows=30
for j in range(rows+1):
    t=j/rows
    for i in range(cols+1):
        u=-1+2*i/cols
        lower=.286+.0105*cos(u*pi*5.5)
        upper=.594+.040*sin(abs(u)*pi)-.055*abs(u)**5
        z=lower+(upper-lower)*t
        a=u*(.985-.13*t+.04*sin(pi*t))
        v.append(bodypos(z,a,.0016))
for j in range(rows):
    for i in range(cols):a=j*(cols+1)+i;f.append((a,a+1,a+cols+2,a+cols+1))
o=mesh('Cream_Breast_Feathers',v,f,cream);skin(o,weights)
# Side neck feathers: broad, swept triangular cream marking with inward point.
front=[(.585,-.176),(.64,-.099),(.70,-.003),(.76,.098),(.80,.126),(.84,.080),(.91,.018),(.97,-.027),(1.018,-.064),(1.027,-.095)]
back=[(.585,-.178),(.64,-.165),(.70,-.149),(.76,-.140),(.80,-.135),(.84,-.132),(.91,-.127),(.97,-.127),(1.018,-.121),(1.027,-.105)]
for side in [-1,1]:
    v=[];f=[]
    for j in range(65):
        z=.585+(1.027-.585)*j/64;ry=interp(py,z);cy=.014*math.exp(-((z-.4)/.20)**2)
        ya=interp(back,z);yb=interp(front,z)
        for i in range(25):
            y=ya+(yb-ya)*i/24;a=side*math.acos(max(-.996,min(.996,(y-cy)/ry)))
            pos=list(bodypos(z,a,.0027))
            if y < cy:
                pos[0]=side*(interp(px,z)+.003+ .008*sin((z-.585)/.442*pi))
                pos[1]=y
            v.append(pos)
    for j in range(64):
        for i in range(24):a=j*25+i;f.append((a,a+1,a+26,a+25))
    o=mesh('Cream_Neck_'+str(side),v,f,cream);skin(o,weights)

# A volume from a closed 2D outline. Two gently domed surfaces meet at the rim.
def cushion(name,outline,center,thickness,fn,mat):
    pts=spline(outline,5);n=len(pts);v=[];f=[];rings=14
    for side in [-1,1]:
        for j in range(rings+1):
            r=.001+.999*j/rings
            for p in pts:
                q=Vector(center).lerp(p,r)
                d=side*thickness*sqrt(max(0,1-r*r))
                v.append(fn(q,d))
    block=(rings+1)*n
    for half in range(2):
        for j in range(rings):
            for i in range(n):a=half*block+j*n+i;b=half*block+j*n+(i+1)%n;f.append((a,b,b+n,a+n))
        f.append(tuple(half*block+i for i in range(n)))
    for i in range(n):a=rings*n+i;b=rings*n+(i+1)%n;f.append((a,b,block+b,block+a))
    return mesh(name,v,f,mat)
# Wing side silhouette traced from the left panel, in metres.
wing=[(-.055,.717),(-.035,.684),(.052,.616),(.075,.538),(.057,.395),(.030,.255),(-.024,.132),(-.080,.078),(-.127,.073),(-.171,.093),(-.202,.143),(-.242,.081),(-.288,.065),(-.333,.086),(-.360,.143),(-.371,.229),(-.366,.287),(-.404,.203),(-.434,.175),(-.454,.196),(-.458,.241),(-.419,.333),(-.466,.302),(-.483,.327),(-.436,.395),(-.355,.478),(-.256,.568),(-.143,.641)]
for side,suf in [(-1,'L'),(1,'R')]:
    def wingfn(q,d,s=side):
        y,z=q
        x=interp([(.065,.418),(.12,.443),(.24,.455),(.40,.350),(.55,.249),(.64,.188),(.725,.168)],z)+.26*y
        # broad leading edge rounds continuously into the long lowest primary.
        x+=.012*sin((z-.07)/.65*pi)
        return (s*(x+d),y,z)
    o=cushion('Wing_'+suf+'_Skinned',wing,(-.205,.390),.037,wingfn,black)
    skin(o,{'wing_'+suf:lambda p:smoothstep(.35,.59,p.z),'wing_tip_'+suf:lambda p:1-smoothstep(.35,.59,p.z)})

# Beak: a closed diamond-shaped upper and lower mandible with a narrow seam.
# It tapers to one tip; no protruding circular lip.
for upper in [True,False]:
    v=[];f=[];sections=28;around=48
    for j in range(sections+1):
        t=j/sections;y=.104+.196*t
        width=.077*(1-t)**.63+.001
        height=(.057*(1-smoothstep(.04,1,t))**.75 if upper else .047*(1-t)**1.3)
        for i in range(around):
            a=2*pi*i/around;x=width*cos(a)
            seam=1.055+.005*cos(a)**2+.003*t-.004*(1-abs(cos(a)))
            # Half-ellipse mandible with a flatter seam side.
            vertical=(max(0,sin(a))**.8*height if upper else -max(0,sin(a))**.8*height)
            if sin(a)<0:vertical=(-.001*sin(a) if upper else .001*sin(a))
            z=seam+vertical+(.0015 if upper else -.0015)
            v.append((x,y,z))
    for j in range(sections):
        for i in range(around):a=j*around+i;b=j*around+(i+1)%around;f.append((a,b,b+around,a+around))
    f.extend([tuple(reversed(range(around))),tuple(sections*around+i for i in range(around))])
    o=mesh('Beak_Upper' if upper else 'Beak_Lower',v,f,beakmat);skin(o,{'head':1})

def ellipsoid(name,loc,scale,mat,bone):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=loc)
    o=bpy.context.object;o.name=name
    for c in list(o.users_collection):c.objects.unlink(o)
    col.objects.link(o);o.scale=scale
    bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    o.data.materials.append(mat)
    for p in o.data.polygons:p.use_smooth=True
    skin(o,{bone:1});return o
for side in [-1,1]:ellipsoid('White_Eye_'+str(side),(side*.139,.034,1.107),(.023,.038,.047),white,'head')
# Three tapered rear feather petals, central feather overlaps the two side feathers.
for i in [-1,1,0]:
    x=i*.084;top=.437 if i==0 else .414;bottom=.143 if i==0 else .154;w=.071 if i==0 else .06
    outline=[(x-.018,top),(x+.037,top-.055),(x+w,.285),(x+w*.74,.216),(x+.010,bottom),(x-.018,bottom+.01),(x-w*.85,.206),(x-w,.286),(x-.040,top-.040)]
    o=cushion('Tail_Feather_'+str(i),outline,(x,.29),.030,lambda q,d,j=i:(q.x,-.252-(.021 if j==0 else 0)-d,q.y),black)
    skin(o,{'tail':1})

# Short tapered feathered shanks and grounded crow toes. No swollen drumsticks.
def tube(name,points,radii,mat,bone,segments=12):
    v=[];f=[]
    for j,p in enumerate(points):
        p=Vector(p);tangent=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(j-1,0)])
        tangent.normalize();ref=Vector((1,0,0))
        if abs(tangent.dot(ref))>.9:ref=Vector((0,1,0))
        u=tangent.cross(ref).normalized();w=tangent.cross(u).normalized()
        for k in range(segments):a=k/segments*2*pi;v.append(p+radii[j]*(u*cos(a)+w*sin(a)))
    for j in range(len(points)-1):
        for k in range(segments):a=j*segments+k;b=j*segments+(k+1)%segments;f.append((a,b,b+segments,a+segments))
    f.extend([tuple(reversed(range(segments))),tuple((len(points)-1)*segments+k for k in range(segments))])
    o=mesh(name,v,f,mat);skin(o,{bone:1});return o
for side,suf in [(-1,'L'),(1,'R')]:
    x=side*.17
    tube('Leg_Feathers_'+suf,[(x,0,.25),(x,0,.21),(x,.004,.168),(x,.009,.133),(x,.012,.104),(x,.01,.080)],[.038,.042,.039,.031,.028,.023],brown,'leg_'+suf,24)
    tube('Ankle_'+suf,[(x,.009,.086),(x,.006,.061),(x,.014,.033)],[.018,.015,.022],feetmat,'foot_'+suf,18)
    ellipsoid('Foot_Pad_'+suf,(x,.019,.022),(.031,.036,.020),feetmat,'foot_'+suf)
    for k in [-1,0,1]:
        # Toes splay in X; tips rest on Z=0.005 and bend into the floor contact.
        length=.103 if k==0 else .073
        pts=[(x+k*.012,.025,.025),(x+k*.028,.049,.016),(x+k*.040,length,.014),(x+k*.056,length+.012,.009)]
        tube('Toe_'+suf+str(k),pts,[.013,.013,.011,.005],feetmat,'foot_'+suf)
    tube('Back_Toe_'+suf,[(x,.005,.025),(x-side*.018,-.021,.015),(x-side*.034,-.035,.008)],[.013,.011,.004],feetmat,'foot_'+suf)
# Match hip/ankle bone centres to the reference stance; deform bones remain named.
bpy.context.view_layer.objects.active=rig;bpy.ops.object.select_all(action='DESELECT');rig.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for side,suf in [(-1,'L'),(1,'R')]:
    for n in ['leg_'+suf,'foot_'+suf]:
        b=rig.data.edit_bones[n];b.head.x=side*.17;b.tail.x=side*.17
bpy.ops.object.mode_set(mode='OBJECT')
rig.animation_data.action=bpy.data.actions['idle'];scene.frame_set(0)
for o in bpy.data.objects:o.select_set(False)
for o in col.objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/characters/crow/model.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='NONE',export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_skins=True,export_def_bones=False,export_rest_position_armature=True)
# Review lighting and floor; excluded from character exports.
scene.render.engine='BLENDER_EEVEE';scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.30,.285,1)
scene.world.node_tree.nodes['Background'].inputs[1].default_value=.55
scene.camera.data.ortho_scale=1.46
scene.view_settings.view_transform='AgX'
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/source.blend')
result={'reconstructed_meshes':len([o for o in col.objects if o.type=='MESH']),'saved':bpy.data.filepath}
