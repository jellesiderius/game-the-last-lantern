"""Refine the existing neutral capybara face, preserving the approved continuous body."""
import bpy, math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
c=bpy.data.collections['Capybara_Character'];body=c.objects['Capybara_Body']
assert not body.get('face_refined'), 'Already applied: do not stack the correction.'
bpy.data.libraries.write(str(ROOT/'assets/characters/capybara/checkpoints/before_face.blend'),{s},fake_user=True)

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)

# Warm fur with a lighter lower snout and long, extremely shallow surface grain.
for v in body.data.vertices:
    x,y,z=v.co
    belly=math.exp(-((x/.25)**4+((z-.76)/.43)**4))*smooth(.04,.19,y)
    underside=(1-smooth(1.18,1.33,z))*smooth(.21,.38,y)*smooth(1.05,1.12,z)
    base=Vector((.34,.12,.032)).lerp(Vector((.60,.36,.175)),max(belly,underside)*.84)
    shade=max(smooth(.43,.53,abs(x))*(1-smooth(.57,.68,z)),(1-smooth(.10,.25,z))*smooth(.09,.17,abs(x)))
    body.data.color_attributes['CoatColours'].data[v.index].color=(*base.lerp(Vector((.10,.055,.03)),shade),1)
for material in [bpy.data.materials['Capybara_Caramel_Fur'],bpy.data.materials['Capybara_Caramel_Details']]:
    nodes=material.node_tree.nodes;links=material.node_tree.links
    noise=next(n for n in nodes if n.type=='TEX_NOISE')
    mapping=nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(1,1,.13)
    coords=nodes.new('ShaderNodeTexCoord');links.new(coords.outputs['Object'],mapping.inputs[0]);links.new(mapping.outputs[0],noise.inputs['Vector'])
    bump=next(n for n in nodes if n.type=='BUMP');bump.inputs['Strength'].default_value=.17;bump.inputs['Distance'].default_value=.002

# Recess the eyeballs into actual sockets instead of resting beads on the skin.
bvh=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
for sign in [-1,1]:
    side='L' if sign<0 else 'R'
    surface=bvh.ray_cast(Vector((sign*.163,2,1.36)),Vector((0,-1,0)))[0].y
    for name in ['Eye_Socket_'+side,'Eye_'+side,'Eye_Glint_'+side]:
        o=c.objects[name]
        for v in o.data.vertices:v.co.y-=.014
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32,ring_count=20,location=(sign*.163,surface+.008,1.362))
    cutter=bpy.context.object;cutter.scale=(.033,.034,.026)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bpy.context.view_layer.objects.active=body
    modifier=body.modifiers.new('Inset eye socket '+side,'BOOLEAN');modifier.operation='DIFFERENCE';modifier.object=cutter
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    brow=c.objects['Brow_'+side]
    for v in brow.data.vertices:
        v.co.y-=.006
        v.co.z-=.004*(1-smooth(.14,.19,abs(v.co.x)))

# The neutral mouth slopes slightly down at the corners; it must not smile.
bvh=BVHTree.FromPolygons([v.co for v in body.data.vertices],[list(p.vertices) for p in body.data.polygons])
for name in ['Closed_Mouth_Left','Closed_Mouth_Right']:
    o=c.objects[name]
    for v in o.data.vertices:
        v.co.z-=.022*smooth(0,.12,abs(v.co.x))
        hit=bvh.ray_cast(Vector((v.co.x,2,v.co.z)),Vector((0,-1,0)))[0]
        if hit:v.co.y=hit.y+.0012
for poly in body.data.polygons:poly.use_smooth=True
body['face_refined']=True
bpy.data.libraries.write(str(ROOT/'assets/characters/capybara/source.blend'),{s},fake_user=True)
result={'face':'recessed eyes, lower serious mouth, sand muzzle, shallow directional fur','source':str(ROOT/'assets/characters/capybara/source.blend')}
