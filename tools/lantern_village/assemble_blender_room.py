"""Save the same authored module placement as an editable Blender miniature set."""
import bpy, json, math
from mathutils import Vector
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
scene=bpy.data.scenes.get('PrototypeRoom_Assembly') or bpy.data.scenes.new('PrototypeRoom_Assembly')
bpy.context.window.scene=scene;scene.unit_settings.system='METRIC'
assert not scene.objects, 'Existing assembly: inspect before replacing.'
for item in json.loads((ROOT/'assets/environment/room_layout.json').read_text()):
    obj=bpy.data.objects.new(item['name'],None);obj.instance_type='COLLECTION';obj.instance_collection=bpy.data.collections['Village_'+item['asset']]
    scene.collection.objects.link(obj);x,y,z=item['position'];obj.location=(x,-z,y);obj.rotation_euler.z=item['yaw'];sx,sy,sz=item['scale'];obj.scale=(sx,sz,sy)
for name,pos,size,mat in [('Canal',(0,-3,-.30),(32,2,.04),'Village_Water'),('Backdrop',(0,0,-1.26),(100,100,.1),'Village_Backdrop')]:
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);obj=bpy.context.object;obj.name=name;obj.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    material=bpy.data.materials.get(mat) or bpy.data.materials.new(mat)
    material.diffuse_color=(.045,.62,.73,1) if name=='Canal' else (.9,.865,.79,1)
    obj.data.materials.append(material)
for name,col in [('Player','LanternPanda_Character'),('Held_Props','Equipment_Preview')]:
    obj=bpy.data.objects.new(name,None);obj.instance_type='COLLECTION';obj.instance_collection=bpy.data.collections[col];scene.collection.objects.link(obj);obj.location=(0,3,0)
data=bpy.data.cameras.new('GameplayAngle');cam=bpy.data.objects.new('GameplayAngle',data);scene.collection.objects.link(cam);data.type='ORTHO';data.ortho_scale=43
cam.location=(22,-22,37);cam.rotation_euler=(Vector((0,0,.5))-cam.location).to_track_quat('-Z','Y').to_euler();scene.camera=cam
for name,pos,power,size in [('WarmDay',(2,-8,20),2200,15),('SoftFill',(-10,-2,12),1500,20)]:
    light=bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size
    o=bpy.data.objects.new(name,light);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(-o.location).to_track_quat('-Z','Y').to_euler()
scene.world=bpy.data.worlds.new('MiniatureAmbient');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True;scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
bpy.context.view_layer.update()
bpy.data.libraries.write(str(ROOT/'assets/environment/prototype_room.blend'),{scene},fake_user=True)
bpy.context.window.scene=bpy.data.scenes['LanternPanda_Production']
result={'assembly':str(ROOT/'assets/environment/prototype_room.blend'),'instances':len(scene.objects)}
