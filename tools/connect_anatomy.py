"""Unite feathered legs with the body and widen the black breast mantle.
Run after rebuild_character.py; retain a single skin with smooth hip weights.
"""
import bpy,bmesh,math
ROOT='/Users/jelle/Godot-Projects/crow-test'
s=bpy.context.scene;rig=bpy.data.objects['Crow_Rig'];body=bpy.data.objects['Crow_Body']
rig.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
# Lower and flatten the two cream shoulder lobes: wider continuous black mantle.
o=bpy.data.objects['Cream_Breast_Feathers']
for v in o.data.vertices:
    i=v.index%73;j=v.index//73;u=-1+2*i/72;t=j/30
    lower=.286+.0105*math.cos(u*math.pi*5.5)
    upper=.568+.022*math.sin(abs(u)*math.pi)-.028*abs(u)**5
    z=lower+(upper-lower)*t
    a=u*(.985-.13*t+.04*math.sin(math.pi*t))
    # same profile function as the reconstruction, available in this script's scope
    v.co=bodypos(z,a,.002)
# Fuse the leg roots into the belly with a closed boolean union.
for m in list(body.modifiers):body.modifiers.remove(m)
for suf in ['L','R']:
    leg=bpy.data.objects.get('Leg_Feathers_'+suf)
    if not leg:continue
    for m in list(leg.modifiers):leg.modifiers.remove(m)
    bpy.context.view_layer.objects.active=body
    mod=body.modifiers.new('Anatomical hip union '+suf,'BOOLEAN');mod.operation='UNION';mod.solver='EXACT';mod.object=leg
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(leg,do_unlink=True)
# Smooth only the junction rings; preserve the traced body and feet elsewhere.
bm=bmesh.new();bm.from_mesh(body.data)
junction=[v for v in bm.verts if .142 < v.co.z < .233 and abs(v.co.x)>.09]
for _ in range(9):bmesh.ops.smooth_vert(bm,verts=junction,factor=.42,use_axis_x=True,use_axis_y=True,use_axis_z=True)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
# Reassign all body weights, with a smooth pelvis-to-leg transition.
body.vertex_groups.clear()
weights2={'pelvis':lambda p:(1-smoothstep(.31,.57,p.z))*smoothstep(.115,.233,p.z),'torso':lambda p:smoothstep(.31,.57,p.z)*(1-smoothstep(.73,.94,p.z)),'neck':lambda p:smoothstep(.73,.94,p.z)*(1-smoothstep(1.005,1.09,p.z)),'head':lambda p:smoothstep(1.005,1.09,p.z),'leg_L':lambda p:(1-smoothstep(.115,.233,p.z)) if p.x<0 else 0,'leg_R':lambda p:(1-smoothstep(.115,.233,p.z)) if p.x>=0 else 0}
skin(body,weights2)
for p in body.data.polygons:
    p.use_smooth=True
    if p.center.z<.225:p.material_index=1 if p.center.y>-.10 else 0
# Shoulder colours are continuous curved feather sheets, without a crease in X.
for side in [-1,1]:
    o=bpy.data.objects['Cream_Neck_'+str(side)]
    for v in o.data.vertices:
        j=v.index//25;i=v.index%25;z=.585+.442*j/64;ry=interp(py,z);cy=.014*math.exp(-((z-.4)/.20)**2)
        y=interp(back,z)+(interp(front,z)-interp(back,z))*i/24
        ratio=max(-.996,min(.996,(y-cy)/ry))
        factor=(1-ratio*ratio)**(.20 if ratio<0 else .50)
        v.co=(side*(interp(px,z)+.0027)*factor,y,z)
    mod=o.modifiers.new('Feather edge thickness','SOLIDIFY');mod.thickness=.002;mod.offset=0
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
for m in [bpy.data.materials['Crow_Obsidian'],bpy.data.materials['Crow_Feet']]:
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Specular IOR Level'].default_value=.26
for o in bpy.data.objects:o.select_set(False)
for o in bpy.data.collections['Crow_Character'].objects:o.select_set(True)
bpy.context.view_layer.objects.active=rig
bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/characters/crow/model.glb',export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=True,export_animation_mode='ACTIONS',export_merge_animation='NONE',export_frame_range=False,export_force_sampling=True,export_anim_slide_to_zero=True,export_skins=True,export_def_bones=False,export_rest_position_armature=True)
bpy.ops.wm.save_as_mainfile(filepath=ROOT+'/assets/characters/crow/source.blend')
result={'hip_mesh':'joined to body','black_mantle':'widened'}
