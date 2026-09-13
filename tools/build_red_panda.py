"""Initial red panda source authoring. Refuses to overwrite an existing character.
Run through Blender MCP in a fresh scene. Subsequent refinements edit source.blend.
"""
import bpy, sys, math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
assert not bpy.data.collections.get('RedPanda_Character'),'Existing model: inspect and refine, do not rebuild.'
s=bpy.data.scenes.new('RedPanda_Production');bpy.context.window.scene=s
s.unit_settings.system='METRIC';s.unit_settings.scale_length=1.
c=bpy.data.collections.new('RedPanda_Character');s.collection.children.link(c)
orange=material('Panda_Caramel_Rust',(.70,.32,.17))
cream=material('Panda_Warm_Cream',(.96,.84,.69))
dark=material('Panda_Chocolate',(.245,.19,.17))
inner=material('Panda_Ear_Interior',(.33,.155,.09))
black=material('Panda_Nose_Mouth',(.09,.066,.057),.40)
eyes=material('Panda_Eye_Onyx',(.055,.047,.039),.19)
glint=material('Panda_Eye_Catchlight',(.98,.98,.92),.24)

# Continuous torso, arms, wrists, hands and short planted legs. Palms face inward at rest.
parts=[loft('Torso',[(.175,.055,.065,0),(.21,.14,.13,-.005),(.30,.205,.165,-.018),(.43,.233,.175,-.015),(.56,.205,.15,-.008),(.66,.167,.125,0),(.73,.128,.103,0),(.79,.115,.10,0)],c,orange,64,6)]
for sign,side in [(-1,'L'),(1,'R')]:
    arm=tube('Arm_'+side,[(sign*.135,0,.691,.09),(sign*.213,0,.655,.087),(sign*.276,.002,.557,.079),(sign*.326,.016,.465,.070),(sign*.340,.028,.378,.061)],c,orange,32,7);parts.append(arm)
    parts.append(ellipsoid('Palm_'+side,(sign*.344,.027,.343),(.064,.072,.083),c,dark))
    # Three descending digits spread along the palm depth, curling inward rather than forward.
    for i,(y,end) in enumerate([(-.020,.274),(.023,.257),(.064,.276)]):
        parts.append(tube('Digit_'+side+str(i),[(sign*.355,y,.345,.027),(sign*.359,y+.002,.303,.025),(sign*.344,y+.004,end,.023),(sign*.326,y+.006,end+.010,.009)],c,dark,20,5))
    parts.append(tube('Thumb_'+side,[(sign*.302,.060,.362,.031),(sign*.286,.084,.340,.027),(sign*.290,.092,.313,.023),(sign*.304,.087,.307,.011)],c,dark,24,6))
    parts.append(tube('Leg_'+side,[(sign*.113,-.02,.27,.104),(sign*.15,-.012,.192,.092),(sign*.179,.002,.105,.064),(sign*.190,.017,.052,.057)],c,dark,32,6))
    foot=ellipsoid('Foot_'+side,(sign*.187,.051,.039),(.082,.115,.041),c,dark);parts.append(foot)
    for i in range(3):
        toe=ellipsoid('Toe_'+side+str(i),(sign*.187+(i-1)*.050,.137-(abs(i-1)*.008),.032),(.027,.049,.030),c,dark,32,20);parts.append(toe)
body=fuse(parts,'RedPanda_Body',.0032,4,.47)
for v in body.data.vertices:
    if v.co.z<.009:v.co.z=.004
body.data.materials.clear();bodymat=material('Panda_Body_Coat',(.7,.32,.17));body.data.materials.append(bodymat)
attribute=body.data.color_attributes.new(name='CoatColours',type='FLOAT_COLOR',domain='POINT')
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
rust=Vector(linear_color((.70,.32,.17)));choc=Vector(linear_color((.245,.19,.17)))
for v in body.data.vertices:
    x,y,z=v.co
    belly_width=.198*(1-((z-.46)/.39)**2)**.5 if abs(z-.46)<.39 else 0
    belly=(1-smooth(belly_width-.015,belly_width+.010,abs(x)))*smooth(.016,.058,y)
    arm=smooth(.23,.285,abs(x))*(1-smooth(.525,.550,z))
    legs=(1-smooth(.24,.30,z))
    amount=max(belly,arm,legs);attribute.data[v.index].color=(*(rust.lerp(choc,amount)),1)
node=bodymat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='CoatColours'
bodymat.node_tree.links.new(node.outputs['Color'],bodymat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
body['skin_region']='body'

# Broad skull, rather than a spherical head with separate ball cheeks.
head=loft('RedPanda_Head',[(.704,.07,.08,0),(.725,.195,.153,-.007),(.777,.274,.19,-.014),(.858,.295,.216,-.021),(.960,.276,.211,-.028),(1.055,.235,.175,-.035),(1.115,.15,.118,-.039),(1.142,.012,.012,-.04)],c,orange,96,7,2.25)
head['skin_region']='head'
def head_y(x,z):
    # Ray onto actual skull: patches remain close to the curved surface at every contour point.
    ok,point,normal,index=head.ray_cast(Vector((x,.8,z)),Vector((0,-1,0)))
    return point.y if ok else .035

def patch(name,outline,mat,depth=.015,plane=None):
    outline=smooth_curve([(x,z) for x,z in outline],5,True)
    center=sum(outline,Vector((0,0)))/len(outline);verts=[];faces=[];N=len(outline)
    for radius in [0.0,.18,.36,.55,.73,.89,1.]:
        for p in outline:
            q=center+(p-center)*radius;x,z=q
            y=head_y(x,z) if plane is None else plane(x,z,radius)
            verts.append((x,y+depth*(1-radius*radius)+.0025,z))
    for ring in range(6):
        for i in range(N):
            a=ring*N+i;b=ring*N+(i+1)%N;faces.append((a,b,b+N,a+N))
    o=mesh_object(name,verts,faces,c,mat);o['skin_region']='head';return o

for sign,side in [(-1,'L'),(1,'R')]:
    # Orange silhouette tufts; cream marking lies across their forward surface.
    tuft_outline=[(.210,.922),(.264,.936),(.299,.895),(.336,.878),(.305,.854),(.337,.813),(.309,.805),(.323,.773),(.273,.768),(.249,.748),(.218,.773)]
    patch('Outer_Cheek_'+side,[(sign*x,z) for x,z in tuft_outline],orange,.025,lambda x,z,r: .023+.08*(1-r*r))
    cheek=[(.191,.946),(.223,.939),(.249,.903),(.287,.872),(.264,.852),(.286,.818),(.263,.815),(.266,.771),(.247,.746),(.206,.741),(.183,.761),(.195,.802),(.171,.843)]
    patch('Cream_Cheek_'+side,[(sign*x,z) for x,z in cheek],cream,.015)
    # Ear shell and cream rounded rim: one surface with a recessed dark inner cup.
    outline=smooth_curve([(sign*x,z) for x,z in [(.11,1.082),(.163,1.134),(.279,1.188),(.300,1.166),(.304,1.073),(.271,1.005),(.203,1.027)]],7,True)
    center=sum(outline,Vector((0,0)))/len(outline);vertices=[];faces=[];N=len(outline)
    rs=[0,.23,.47,.65,.73,.82,.91,1.]
    for r in rs:
        for p in outline:
            x,z=center+(p-center)*r
            y=.002 + .056*math.exp(-((r-.84)/.17)**2)-.02*(z-1.08)
            vertices.append((x,y,z))
    for j in range(len(rs)-1):
        for i in range(N):faces.append((j*N+i,j*N+(i+1)%N,(j+1)*N+(i+1)%N,(j+1)*N+i))
    for i in range(N):vertices.append((outline[i].x,-.04,outline[i].y))
    for i in range(N):faces.append(((len(rs)-1)*N+i,(len(rs)-1)*N+(i+1)%N,len(rs)*N+(i+1)%N,len(rs)*N+i))
    faces.append(tuple(len(rs)*N+i for i in range(N)))
    ear=mesh_object('Ear_'+side,vertices,faces,c,inner);ear.data.materials.append(cream);ear.data.materials.append(orange)
    for p in ear.data.polygons:
        j=p.index//N;p.material_index=0 if j<4 else (1 if j<8 else 2)
    ear['skin_region']='head'
    x=sign*.112;z=.919;y=head_y(x,z)
    eye_rim=ellipsoid('Eye_Rim_'+side,(x,y+.011,z),(.037,.020,.047),c,cream)
    eye=ellipsoid('Eye_'+side,(x-sign*.002,y+.026,z),(.030,.019,.040),c,eyes)
    highlight=ellipsoid('Eye_Glint_'+side,(x-sign*.008,y+.043,z+.017),(.009,.0035,.012),c,glint,24,16)
    for o in [eye_rim,eye,highlight]:o['skin_region']='head'
    brow=[(.052,.963),(.074,.957),(.114,.969),(.153,.990),(.151,1.017),(.126,1.027),(.098,1.013),(.070,.988)]
    patch('Brow_'+side,[(sign*a,b) for a,b in brow],cream,.021)

muzzle=loft('Cream_Muzzle',[(.735,.015,.02,.205),(.745,.073,.035,.223),(.770,.111,.052,.232),(.810,.114,.064,.231),(.845,.080,.054,.227),(.860,.025,.021,.222)],c,cream,64,6,2.2);muzzle['skin_region']='head'
# Small soft triangular nose, not a large dog nose.
nose=patch('Nose',[(-.031,.856),(-.034,.867),(-.018,.877),(.018,.877),(.034,.867),(.024,.850),(0,.836)],black,.012,lambda x,z,r:.286)
for name,points in [('Philtrum',[(0,.297,.840),(0,.297,.812)]),('Mouth_L',[(0,.297,.812),(-.020,.292,.802),(-.042,.279,.793)]),('Mouth_R',[(0,.297,.812),(.020,.292,.802),(.042,.279,.793)])]:
    o=tube(name,[(*p,.0020) for p in points],c,black,10,5);o['skin_region']='head'

# One fully volumetric tail, smoothly attached and ringed without polygon-index stair steps.
tail_controls=[(0,-.133,.32,.076),(-.014,-.250,.33,.131),(-.065,-.408,.324,.157),(-.14,-.590,.345,.174),(-.214,-.755,.400,.178),(-.255,-.891,.491,.163),(-.264,-.974,.566,.124),(-.26,-1.020,.602,.066),(-.251,-1.037,.616,.002)]
tail=tube('Ringed_Tail',tail_controls,c,orange,64,12);tail['skin_region']='tail'
tailmat=material('Panda_Tail_Rings',(.7,.32,.17));tail.data.materials.clear();tail.data.materials.append(tailmat)
attr=tail.data.color_attributes.new(name='CoatColours',type='FLOAT_COLOR',domain='POINT')
crem=Vector(linear_color((.96,.84,.69)))
for v in tail.data.vertices:
    ring=v.index//64;u=ring/(len(smooth_curve(tail_controls,12))-1)
    # Broad evenly readable bands; cream root stripe and alternating rust/cream to rust tip.
    amount=0.
    for a,b in [(.115,.205),(.335,.46),(.595,.73)]:
        amount=max(amount,smooth(a-.004,a+.004,u)*(1-smooth(b-.004,b+.004,u)))
    attr.data[v.index].color=(*rust.lerp(crem,amount),1)
node=tailmat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='CoatColours'
tailmat.node_tree.links.new(node.outputs['Color'],tailmat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
s.render.fps=100;s.frame_start=0;s.frame_end=200
for obj in c.objects:
    if obj.type=='MESH':obj['reference_asset']='red_panda_turnaround'
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'source':bpy.data.filepath,'meshes':len(c.objects),'vertices':sum(len(o.data.vertices) for o in c.objects if o.type=='MESH')}
