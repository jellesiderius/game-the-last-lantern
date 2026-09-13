"""Bake reviewed dense vertex colour onto an existing skinned game mesh.
Keeps UV/filtering smooth after topology reduction. Character source must be in neutral pose.
"""
import bpy,sys
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate
asset=globals().get('COAT_CHARACTER','red_panda');name=globals().get('COAT_BODY','RedPanda_Body')
folder=ROOT/'assets/characters'/asset;texture_dir=folder/'textures';texture_dir.mkdir(exist_ok=True)
body=bpy.data.objects[name];rig=body.parent;rig.animation_data.action=bpy.data.actions['neutral'];bpy.context.scene.frame_set(0)
with bpy.data.libraries.load(str(folder/'checkpoints/high_density_skin.blend'),link=False) as (src,dst):dst.objects=[name]
high=dst.objects[0];bpy.context.scene.collection.objects.link(high);high.parent=None
for modifier in list(high.modifiers):high.modifiers.remove(modifier)
activate(body);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=1.15,island_margin=.008);bpy.ops.object.mode_set(mode='OBJECT')
image=bpy.data.images.new('Body_Coat_Albedo',width=2048,height=2048,alpha=False)
material=body.data.materials[0].copy();material.name='Panda_Body_Coat';body.data.materials[0]=material
target=material.node_tree.nodes.new('ShaderNodeTexImage');target.image=image;material.node_tree.nodes.active=target
source=high.data.materials[0].copy();high.data.materials[0]=source
tree=source.node_tree;vertex=next(n for n in tree.nodes if n.type=='VERTEX_COLOR');emission=tree.nodes.new('ShaderNodeEmission');tree.links.new(vertex.outputs['Color'],emission.inputs['Color']);tree.links.new(emission.outputs[0],tree.nodes['Material Output'].inputs['Surface'])
activate(body);high.select_set(True)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
scene.render.bake.use_selected_to_active=True;scene.render.bake.cage_extrusion=.014;scene.render.bake.max_ray_distance=.04;scene.render.bake.margin=24
bpy.ops.object.bake(type='EMIT')
image.filepath_raw=str(texture_dir/'body_albedo.png');image.file_format='PNG';image.save();image.pack()
material.node_tree.links.new(target.outputs['Color'],material.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
bpy.data.objects.remove(high,do_unlink=True)
scene.render.bake.use_selected_to_active=False
# Topology reduction can introduce tiny fifth weights. Commit the same normalized four as GLB.
for v in body.data.vertices:
 weights=sorted([(g.group,g.weight) for g in v.groups if g.weight>.0001],key=lambda item:-item[1])[:4]
 group_ids=[int(g.group) for g in v.groups]
 for group in group_ids:body.vertex_groups[group].remove([v.index])
 total=sum(w for _,w in weights)
 for group,w in weights:body.vertex_groups[group].add([v.index],w/total,'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath=str(folder/'source.blend'))
result={'texture':str(texture_dir/'body_albedo.png'),'source':bpy.data.filepath}
