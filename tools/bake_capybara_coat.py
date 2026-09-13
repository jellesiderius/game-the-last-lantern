"""Bake the edited coat into UV-bound colour and tangent normals for Blender/Godot parity.
Fine short anisotropic grain changes direction over the cheeks; no silhouette hairs.
Run on the current reviewed source, never an old geometry generator.
"""
import bpy, math
from pathlib import Path
root=next(p for p in Path(bpy.data.filepath).parents if (p/'project.godot').is_file())
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
r=bpy.data.objects['Capybara_Rig'];o=bpy.data.objects['Capybara_Body']
r.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0);r.data.pose_position='REST'
checkpoint=root/'assets/characters/capybara/checkpoints/before_coat_bake.blend'
if not checkpoint.exists():bpy.ops.wm.save_as_mainfile(filepath=str(checkpoint),copy=True)
for other in bpy.context.selected_objects:other.select_set(False)
o.select_set(True);bpy.context.view_layer.objects.active=o
if not o.get('coat_uv_authored'):
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
 bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.012,area_weight=.2)
 bpy.ops.object.mode_set(mode='OBJECT');o['coat_uv_authored']=True
mat=bpy.data.materials['Capybara_Caramel_Fur'];nodes=mat.node_tree.nodes;links=mat.node_tree.links
nodes.clear()
def node(kind,name):
 n=nodes.new(kind);n.label=name;n.name=name;return n
def mathnode(op,a,b):
 n=node('ShaderNodeMath',op);n.operation=op
 for index,value in enumerate([a,b]):
  if isinstance(value,(int,float)):n.inputs[index].default_value=value
  else:links.new(value,n.inputs[index])
 return n.outputs[0]
geo=node('ShaderNodeNewGeometry','Rest surface position');sep=node('ShaderNodeSeparateXYZ','Anatomical coordinates');links.new(geo.outputs['Position'],sep.inputs[0]);x,y,z=sep.outputs
body=node('ShaderNodeCombineXYZ','Body fibre flow');head=node('ShaderNodeCombineXYZ','Cheek fibre flow')
for i,out in enumerate([mathnode('MULTIPLY',x,720),mathnode('MULTIPLY',y,720),mathnode('MULTIPLY',z,95)]):links.new(out,body.inputs[i])
for i,out in enumerate([mathnode('ADD',mathnode('MULTIPLY',mathnode('ABSOLUTE',x,0),720),mathnode('MULTIPLY',z,300)),mathnode('ADD',mathnode('MULTIPLY',y,650),mathnode('MULTIPLY',z,220)),mathnode('ADD',mathnode('MULTIPLY',z,110),mathnode('MULTIPLY',y,60))]):links.new(out,head.inputs[i])
mask=node('ShaderNodeMapRange','Head transition');links.new(z,mask.inputs['Value']);mask.inputs['From Min'].default_value=1.04;mask.inputs['From Max'].default_value=1.27
mix=node('ShaderNodeMixRGB','Regional fur direction');links.new(mask.outputs[0],mix.inputs[0]);links.new(body.outputs[0],mix.inputs[1]);links.new(head.outputs[0],mix.inputs[2])
noise=node('ShaderNodeTexNoise','Short fine coat fibres');noise.inputs['Scale'].default_value=1;noise.inputs['Detail'].default_value=1.3;noise.inputs['Roughness'].default_value=.58;links.new(mix.outputs[0],noise.inputs['Vector'])
ramp=node('ShaderNodeValToRGB','Subtle fibre variation');ramp.color_ramp.elements[0].position=.28;ramp.color_ramp.elements[0].color=(.72,.72,.72,1);ramp.color_ramp.elements[1].position=.72;ramp.color_ramp.elements[1].color=(1.06,1.06,1.06,1);links.new(noise.outputs['Fac'],ramp.inputs[0])
coat=node('ShaderNodeVertexColor','Authored warm coat');coat.layer_name='CoatColours'
colour=node('ShaderNodeMixRGB','Coat with fibre variation');colour.blend_type='MULTIPLY';colour.inputs[0].default_value=1;links.new(coat.outputs['Color'],colour.inputs[1]);links.new(ramp.outputs[0],colour.inputs[2])
bump=node('ShaderNodeBump','Fine surface relief');bump.inputs['Strength'].default_value=.36;bump.inputs['Distance'].default_value=.0007;links.new(noise.outputs['Fac'],bump.inputs['Height'])
bs=node('ShaderNodeBsdfPrincipled','Principled BSDF');bs.inputs['Roughness'].default_value=.83;bs.inputs['Specular IOR Level'].default_value=.20;links.new(colour.outputs[0],bs.inputs['Base Color']);links.new(bump.outputs[0],bs.inputs['Normal'])
output=node('ShaderNodeOutputMaterial','Material Output');links.new(bs.outputs[0],output.inputs[0])
destination=root/'assets/characters/capybara/textures';destination.mkdir(exist_ok=True)
s.render.engine='CYCLES';s.cycles.samples=8;s.render.bake.margin=16;s.render.bake.use_selected_to_active=False
images={}
for name,kind in [('coat_albedo','DIFFUSE'),('coat_normal','NORMAL')]:
 image=bpy.data.images.new('Capybara_'+name,width=4096,height=4096,alpha=False)
 if kind=='NORMAL':image.colorspace_settings.name='Non-Color'
 texture=node('ShaderNodeTexImage','Baked '+name);texture.image=image;nodes.active=texture
 if kind=='DIFFUSE':bpy.ops.object.bake(type=kind,pass_filter={'COLOR'})
 else:bpy.ops.object.bake(type=kind)
 image.filepath_raw=str(destination/(name+'.png'));image.file_format='PNG';image.save();image.pack();images[name]=texture
# Keep the editable authoring graph, but render the same sampled textures as the engine.
links.new(images['coat_albedo'].outputs['Color'],bs.inputs['Base Color'])
normal=node('ShaderNodeNormalMap','Baked tangent normal');links.new(images['coat_normal'].outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bs.inputs['Normal'])
o['coat_bake']='4096px UV colour and tangent normal; short regional grain, no object-space swimming'
r.data.pose_position='POSE';r.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'assets/characters/capybara/source.blend'))
result={'textures':str(destination),'resolution':4096,'source':bpy.data.filepath}
