"""Add separate bow/arrow meshes and six in-place Actions to the current crow.
Preserves the character meshes and all existing sword/locomotion Actions.
"""
import bpy, math, os
from mathutils import Vector, Matrix, Quaternion
ROOT='/Users/jelle/Godot-Projects/crow-test'
s=bpy.context.scene; r=bpy.data.objects['Crow_Rig']
if not os.path.exists(ROOT+'/assets/characters/crow/checkpoints/crow_before_bow.blend'): bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/checkpoints/crow_before_bow.blend',copy=True)
assert bpy.context.scene.name=='Crow_Production'
bpy.context.view_layer.objects.active=r
bpy.ops.object.select_all(action='DESELECT');r.select_set(True)
bpy.ops.object.mode_set(mode='EDIT')
for name,parent,x in [('bow_socket','wing_tip_L',-.365),('bow_draw_socket','wing_tip_R',.365)]:
    b=r.data.edit_bones.get(name) or r.data.edit_bones.new(name)
    b.head=(x,0,.34);b.tail=(x,.10,.34);b.parent=r.data.edit_bones[parent]
    b.align_roll(Vector((0,0,1)))
bpy.ops.object.mode_set(mode='OBJECT')
def collection(name):
    c=bpy.data.collections.get(name)
    if c:
        for o in list(c.objects): bpy.data.objects.remove(o,do_unlink=True)
    else:
        c=bpy.data.collections.new(name);s.collection.children.link(c)
    c.hide_viewport=False;c.hide_render=False
    return c
bow=collection('Bow_Export');arrow=collection('Arrow_Export')
def mat(name,color,emission=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=.4
    p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
    return m
dark=mat('Bow_Obsidian',(.035,.045,.054));rose=mat('Bow_Rose',(.85,.009,.10),2.0)
shaft=mat('Arrow_Dark',(.065,.035,.06));pink=mat('Arrow_Rose_Emission',(1,.012,.15),4)
def link(o,c,m):
    for old in list(o.users_collection):old.objects.unlink(o)
    c.objects.link(o);o.data.materials.append(m)
    return o
def tube(name,points,radius,c,m):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=4
    poly=curve.splines.new('POLY');poly.points.add(len(points)-1)
    for p,v in zip(poly.points,points):p.co=(*v,1)
    o=bpy.data.objects.new(name,curve);c.objects.link(o);curve.materials.append(m)
    bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.convert(target='MESH');o=bpy.context.object;o.select_set(False)
    for p in o.data.polygons:p.use_smooth=True
    return o
for side in [-1,1]:
    pts=[]
    for i in range(41):
        t=i/40
        pts.append((0,-.13*t*t,side*(.04+.38*t)))
    tube('Bow_Limb_'+str(side),pts,.027,bow,dark)
    tube('Bow_Rose_Inlay_'+str(side),[(.022,y,z) for x,y,z in pts[10:35]],.007,bow,rose)
    tube('Bow_Tip_'+str(side),pts[-5:],.032,bow,rose)
tube('Bow_Grip',[(0,0,-.07),(0,0,.07)],.035,bow,dark)
# Arrow's local +Y is forward in Blender / -Z in Godot. Origin at the nock.
tube('Arrow_Shaft',[(0,0,0),(0,.46,0)],.009,arrow,shaft)
verts=[(-.035,.44,0),(.035,.44,0),(0,.44,.016),(0,.44,-.016),(0,.57,0)]
faces=[(0,2,4),(2,1,4),(1,3,4),(3,0,4),(0,3,1,2)]
mesh=bpy.data.meshes.new('Arrowhead');mesh.from_pydata(verts,[],faces);mesh.materials.append(pink)
o=bpy.data.objects.new('Arrow_Rose_Tip',mesh);arrow.objects.link(o)
for side in [-1,1]:
    tube('Arrow_Fletch_'+str(side),[(side*.025,.01,0),(side*.009,.10,0)],.010,arrow,pink)
def reset():
    for b in r.pose.bones:
        b.rotation_mode='QUATERNION';b.location=(0,0,0);b.rotation_quaternion=(1,0,0,0);b.scale=(1,1,1)
def smooth(u):
    u=max(0,min(1,u));return u*u*(3-2*u)
def pose(equip,draw,recoil=0):
    # Target both grips explicitly, with the pull hand ahead of the chest surface.
    torso=r.pose.bones['torso'];basis=torso.bone.matrix_local.to_quaternion()
    torso.rotation_quaternion=basis.inverted()@Quaternion((1,0,0),-.10*equip)@basis
    bpy.context.view_layer.update()
    for side,desired in [('L',Vector((-.20,.50-recoil*.025,.66))),('R',Vector((-.20,.37-.18*draw-recoil*.04,.66)))]:
        wing=r.pose.bones['wing_'+side];socket=r.pose.bones['bow_socket' if side=='L' else 'bow_draw_socket']
        neutral=wing.parent.matrix @ wing.parent.bone.matrix_local.inverted() @ wing.bone.matrix_local
        shoulder=neutral.translation
        base_socket=wing.parent.matrix @ wing.parent.bone.matrix_local.inverted() @ socket.bone.matrix_local
        palm=base_socket.translation
        target=palm.lerp(desired,equip)
        rest_vector=palm-shoulder;aim=target-shoulder
        q=rest_vector.rotation_difference(aim)
        factor=aim.length/rest_vector.length
        m=Matrix.Translation(shoulder)@q.to_matrix().to_4x4()@Matrix.Scale(factor,4)@Matrix.Translation(-shoulder)@neutral
        wing.matrix=m
        bpy.context.view_layer.update()
        # Socket orientation is authored in the character's fixed forward frame.
        parent=socket.parent
        actual=parent.matrix@parent.bone.matrix_local.inverted()@socket.bone.matrix_local
        m=Matrix.Identity(4);m.translation=actual.translation;socket.matrix=m
    bpy.context.view_layer.update()
clips={'bow_equip':.18,'bow_aim':.60,'bow_draw':.25,'bow_hold':.50,'bow_release':.20,'bow_unequip':.14}
for name,duration in clips.items():
    r.animation_data.action=None
    old=bpy.data.actions.get(name)
    if old:bpy.data.actions.remove(old)
    a=bpy.data.actions.new(name);a.use_fake_user=True;r.animation_data.action=a
    for f in range(round(duration*100)+1):
        reset();t=f/100;u=t/duration
        equip=smooth(u) if name=='bow_equip' else (1-smooth(u) if name=='bow_unequip' else 1)
        draw=smooth(u) if name=='bow_draw' else (1 if name=='bow_hold' else (1-smooth(t/.03) if name=='bow_release' else 0))
        recoil=math.sin(math.pi*min(1,t/.12)) if name=='bow_release' else 0
        pose(equip,draw,recoil)
        for b in r.pose.bones:
            for key in ['location','rotation_quaternion','scale']:b.keyframe_insert(key,frame=f,group=b.name)
    a['duration_seconds']=duration;a['in_place']=True
r.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
def export(c,path):
    for o in bpy.data.objects:o.select_set(False)
    for o in c.objects:o.select_set(True)
    bpy.context.view_layer.objects.active=list(c.objects)[0]
    bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/weapons/'+({'bow.glb':'arc_bow','arrow.glb':'magic_arrow'}[path])+'/model.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False)
export(bow,'bow.glb');export(arrow,'arrow.glb')
for c in [bow,arrow]:c.hide_viewport=True;c.hide_render=True
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/source.blend')
result={'new_clips':clips,'new_assets':['bow.glb','arrow.glb'],'character_meshes':'preserved'}
