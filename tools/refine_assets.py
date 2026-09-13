# HISTORICAL GENERATOR: see README; do not run over the reviewed character sources.
import bpy,bmesh,math
from mathutils import Vector
ROOT='/Users/jelle/Godot-Projects/crow-test'
s=bpy.context.scene
body=bpy.data.objects['Crow_Body'];rig=bpy.data.objects['Crow_Rig']
# Patches are feather colour surfaces; snap onto the actual body profile.
def surface(z,a):
    ray=Vector((math.sin(a),math.cos(a),0));hit,loc,no,idx=body.ray_cast(Vector((0,0,z)),ray)
    return loc+ray*.003 if hit else Vector((.14*ray.x,.14*ray.y,z))
for o in [bpy.data.objects['Cream_Neck_-1'],bpy.data.objects['Cream_Neck_1']]:
    side=-1 if o.name.endswith('-1') else 1
    for v in o.data.vertices:
        j=v.index//13;i=v.index%13;t=j/20;u=-1+2*i/12
        # pointed lower sweep, broad centre and narrowed top along either side.
        z=.64+.405*t
        center=side*(.70+.76*t)
        width=.59*math.sin(math.pi*t)**.6+.013
        v.co=surface(z,center+u*width)
for v in bpy.data.objects['Cream_Breast_Feathers'].data.vertices:
    j=v.index//29;i=v.index%29;t=j/16;u=-1+2*i/28
    z=.29+.345*t+.012*math.cos(u*math.pi*6)*(1-t)**8-.055*abs(u)**3*t**5
    a=u*(.95-.12*t)
    v.co=surface(z,a)
# Flatten beak subtly; remove the disconnected spherical crown sweeps.
for o in list(s.objects):
    if o.name.startswith('Crown_Sweep'):bpy.data.objects.remove(o,do_unlink=True)
for suf in ['L','R']:
    objs=[o for o in s.objects if o.name.startswith('Wing_') and (o.name.endswith(suf) or any(o.name.endswith(suf+str(i)) for i in range(3)))]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        for m in list(o.modifiers):o.modifiers.remove(m)
        o.parent=None;o.select_set(True)
    bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();o=bpy.context.object;o.name='Wing_'+suf+'_Skinned'
    mod=o.modifiers.new('Continuous feather forms','REMESH');mod.mode='VOXEL';mod.voxel_size=.008
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=o.modifiers.new('Feather smoothing','SMOOTH');mod.factor=.65;mod.iterations=4;bpy.ops.object.modifier_apply(modifier=mod.name)
    o.vertex_groups.clear();g1=o.vertex_groups.new(name='wing_'+suf);g2=o.vertex_groups.new(name='wing_tip_'+suf)
    for v in o.data.vertices:
        w=max(0,min(1,(v.co.z-.36)/.19));g1.add([v.index],w,'REPLACE');g2.add([v.index],1-w,'REPLACE')
    for p in o.data.polygons:p.use_smooth=True
    o.parent=rig;mod=o.modifiers.new('Crow skin','ARMATURE');mod.object=rig
bpy.data.materials['Crow_Obsidian'].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.48
for o in s.objects:
    if o.type=='MESH':
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
# Fix wall exact overall height, translating bottom to zero.
for o in bpy.data.collections['LowWall_Export'].objects:
    if o.type=='MESH':
        for v in o.data.vertices:v.co.z=(v.co.z+.0035)*(.7/.671)
for o in bpy.data.objects:o.select_set(False)
for col,file,anim in [('Crow_Character','crow.glb',True),('Sword_Export','sword.glb',False),('Ground_Export','ground_tile.glb',False),('LowWall_Export','low_wall.glb',False)]:
    c=bpy.data.collections[col];c.hide_viewport=False
    for o in s.objects:o.select_set(False)
    for o in c.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/exports/'+file,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=anim,export_animation_mode='ACTIONS',export_merge_animation='NONE',export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_skins=True,export_def_bones=False,export_rest_position_armature=True)
    if not anim:c.hide_viewport=True
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/source.blend')
s.render.engine='BLENDER_EEVEE';bpy.ops.render.render(write_still=True)
result={'refined':True}
