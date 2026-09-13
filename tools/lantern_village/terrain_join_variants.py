"""Saved half-width terrain modules; path replaces grass instead of covering it."""
import bpy, sys
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate
reports=[]
for source,key in [('grass_tile','grass_tile_half'),('grass_cliff','grass_cliff_half'),('plaza_tile','plaza_cliff')]:
    assert not bpy.data.collections.get('Village_'+key), 'Existing variant: edit, do not blindly regenerate.'
    src=bpy.data.scenes['Asset_'+source];bpy.context.window.scene=src;bpy.context.view_layer.update()
    scene=bpy.data.scenes.new('Asset_'+key);c=bpy.data.collections.new('Village_'+key);scene.collection.children.link(c)
    for old in bpy.data.collections['Village_'+source].objects:
        if old.type!='MESH':continue
        o=old.copy();o.data=old.data.copy();o.name=key+'_'+old.name;c.objects.link(o)
        matrix=old.matrix_world.copy()
        for v in o.data.vertices:
            v.co=matrix@v.co
            if key.endswith('_half'):v.co.x*=.5
        o.matrix_world.identity()
    bpy.context.window.scene=scene;scene.unit_settings.system='METRIC'
    if key=='plaza_cliff':
        bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,-.63));o=bpy.context.object;o.name='Path_Earth_Foundation';o.scale=(2,2,.74)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
        for col in list(o.users_collection):col.objects.unlink(o)
        c.objects.link(o);o.data.materials.append(bpy.data.materials['Village_Earth'])
    bpy.context.view_layer.update()
    d=ROOT/'assets/environment'/key;d.mkdir(parents=True,exist_ok=True)
    bpy.data.libraries.write(str(d/'source.blend'),{scene},fake_user=True)
    for o in bpy.data.objects:o.select_set(False)
    for o in c.objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(d/'model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False)
    wrapper=ROOT/'scenes/assets/environment'/key/'Visual.tscn';wrapper.parent.mkdir(parents=True,exist_ok=True)
    wrapper.write_text('[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://assets/environment/'+key+'/model.glb" id="Model"]\n[node name="Visual" type="Node3D"]\n[node name="Model" parent="." instance=ExtResource("Model")]\n')
    reports.append(key)
result={'terrain_variants':reports}
