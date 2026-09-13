"""Repair garment construction on the restored chibi. Does not touch head or body landmarks."""
import bpy, sys, math
from pathlib import Path
ROOT = Path('/Users/jelle/Godot-Projects/crow-test')
sys.path.insert(0, str(ROOT/'tools'))
from asset_geometry import tube, mesh_object, activate
s = bpy.data.scenes['LanternPanda_Production']; bpy.context.window.scene = s
c = bpy.data.collections['LanternPanda_Character']; rig = c.objects['LanternPanda_Rig']
rig.data.pose_position = 'REST'
checkpoint = ROOT/'assets/characters/red_panda/checkpoints/before_outfit_seams.blend'
if not checkpoint.exists(): bpy.data.libraries.write(str(checkpoint), {s}, fake_user=True)
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a))); return t*t*(3-2*t)
def skin(o, side=None, mode='torso'):
    o.parent=rig; o['skin_region']=mode
    for g in list(o.vertex_groups): o.vertex_groups.remove(g)
    groups={n:o.vertex_groups.new(name=n) for n in rig.data.bones.keys()}
    for v in o.data.vertices:
        z=v.co.z
        if mode=='torso':
            t=smooth(.28,.43,z); weights={'pelvis':1-t,'torso':t}
        elif mode=='pelvis': weights={'pelvis':1}
        else:
            shoulder=smooth(.405,.46,z); elbow=smooth(.33,.39,z)
            weights={'torso':shoulder,'arm_upper_'+side:(1-shoulder)*elbow,'forearm_'+side:(1-shoulder)*(1-elbow)}
        for n,w in weights.items():
            if w>0: groups[n].add([v.index],w,'REPLACE')
    mod=o.modifiers.new('Outfit skin','ARMATURE'); mod.object=rig
def remove(name):
    if c.objects.get(name): bpy.data.objects.remove(c.objects[name],do_unlink=True)
def radius(z,a):
    q=max(.12,math.sqrt(max(0,1-((z-.3)/.23)**2))); rx=.224*q; ry=.171*q
    if z>.405:
        neck=math.sqrt(max(0,1-((z-.49)/.125)**2)); rx=max(rx,.165*neck);ry=max(ry,.135*neck)
    return 1/math.sqrt((math.sin(a)/rx)**2+(math.cos(a)/ry)**2)
# Regenerate the outer surface BEFORE thickness. Projecting both sides of a solid
# garment onto one radius had collapsed the shell and caused the striped belt.
remove('Teal_Jacket'); verts=[];faces=[];N=96;R=30
for j in range(R):
    t=j/(R-1); z=.19+.33*t
    for i in range(N+1):
        a=.42+i*(math.tau-.84)/N; h=z+.007*math.cos(a*2)*(1-t)**5
        r=radius(h,a)+.012;verts.append((r*math.sin(a),r*math.cos(a),h))
for j in range(R-1):
    for i in range(N):
        a=j*(N+1)+i;faces.append((a,a+1,a+N+2,a+N+1))
o=mesh_object('Teal_Jacket',verts,faces,c,bpy.data.materials['Ranger_Jacket']);activate(o)
mod=o.modifiers.new('Tailored thickness','SOLIDIFY');mod.thickness=.009;mod.offset=1;bpy.ops.object.modifier_apply(modifier=mod.name)
mod=o.modifiers.new('Soft hem','BEVEL');mod.width=.003;mod.segments=3;bpy.ops.object.modifier_apply(modifier=mod.name);skin(o)
remove('Leather_Belt');verts=[];faces=[];N=96
for r_offset,z in [(0,.266),(0,.305),(.009,.266),(.009,.305)]:
    for i in range(N):
        a=math.tau*i/N;r=radius(z,a)+.028+r_offset;verts.append((r*math.sin(a),r*math.cos(a),z))
for i in range(N):
    n=(i+1)%N
    faces.extend([(i,n,n+N,i+N),(i+2*N,i+3*N,n+3*N,n+2*N),(i,n,n+2*N,i+2*N),(i+N,i+3*N,n+3*N,n+N)])
o=mesh_object('Leather_Belt',verts,faces,c,bpy.data.materials['Ranger_Leather']);skin(o,mode='pelvis')
for o in c.objects:
    if o.name.startswith('Buckle'):
        for v in o.data.vertices: v.co.y+=.029
# Replace clipped body vertices with closed forearm volumes, embedded in sleeve/glove.
remove('Exposed_Forearms')
for sign,side in [(-1,'L'),(1,'R')]:
    for name in ['Sleeve_'+side,'Sleeve_Cuff_'+side,'Exposed_Arm_'+side]: remove(name)
    o=tube('Sleeve_'+side,[(sign*.164,0,.442,.060),(sign*.200,.003,.422,.067),(sign*.238,.016,.378,.059)],c,bpy.data.materials['Ranger_Jacket'],48,8);skin(o,side,'arm')
    o=tube('Sleeve_Cuff_'+side,[(sign*.233,.014,.385,.062),(sign*.244,.019,.370,.061)],c,bpy.data.materials['Ranger_Jacket'],48,3);skin(o,side,'arm')
    o=tube('Exposed_Arm_'+side,[(sign*.224,.009,.391,.052),(sign*.252,.025,.345,.054),(sign*.275,.042,.295,.047)],c,bpy.data.materials['LanternPanda_Coat'],48,8);skin(o,side,'arm')
    # Wrists must cover the orange arm end all around, not cut into its surface.
    for i in range(2):
        name='Glove_Cuff_'+side+str(i);remove(name)
        z=.309+i*.019;x=sign*(.269-i*.009)
        o=tube(name,[(x,.036,z,.056),(x-sign*.005,.033,z+.013,.056)],c,bpy.data.materials['Ranger_LeatherEdge'],40,3);skin(o,side,'arm')
rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'fixed':'closed arms, tailored sleeve fit, noncollapsed jacket and belt thickness'}
