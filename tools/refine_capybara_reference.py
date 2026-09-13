"""Reference revision: compact muzzle, lateral inset eyes and integrated eyelids.

Run once on the reviewed, rigged source. The checkpoint is immutable; retry by
opening it explicitly. Existing limb topology, weights, bones and Actions remain.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = next(p for p in Path(bpy.data.filepath).parents if (p/'project.godot').is_file())
s=bpy.data.scenes['Capybara_Production']; bpy.context.window.scene=s
rig=bpy.data.objects['Capybara_Rig']; collection=bpy.data.collections['Capybara_Character']
body=bpy.data.objects['Capybara_Body']
assert not body.get('reference_face_revision'), 'Open the pre-revision checkpoint before retrying.'
rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
rig.data.pose_position='REST'
checkpoint=ROOT/'assets/characters/capybara/checkpoints/before_reference_face_coat.blend'
if not checkpoint.exists():bpy.ops.wm.save_as_mainfile(filepath=str(checkpoint),copy=True)


def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)


def coat(p):
    x,y,z=p
    belly=math.exp(-((x/.245)**4+((z-.74)/.405)**4))*smooth(.04,.19,y)
    under=(1-smooth(1.16,1.315,z))*smooth(.215,.35,y)*smooth(1.045,1.13,z)
    base=Vector((.32,.121,.037)).lerp(Vector((.57,.337,.161)),belly*.76)
    base=base.lerp(Vector((.46,.294,.16)),under*.80)
    paws=max(smooth(.43,.53,abs(x))*(1-smooth(.57,.68,z)),(1-smooth(.10,.25,z))*smooth(.09,.17,abs(x)))
    base=base.lerp(Vector((.10,.055,.03)),paws)
    for sign in [-1,1]:
        nostril=math.exp(-(((x-sign*.052)/.020)**2+((z-1.291-sign*.28*(x-sign*.052))/.010)**2)*1.7)
        base=base.lerp(Vector((.005,.003,.002)),smooth(.15,.7,nostril)*smooth(.30,.38,y))
    return (*base,1)


# Narrow the blunt muzzle across its forward half; keep the skull and cheek breadth.
for vertex in body.data.vertices:
    x,y,z=vertex.co
    snout=smooth(.21,.36,y)*smooth(1.03,1.13,z)*(1-smooth(1.32,1.40,z))
    vertex.co.x*=1-.22*snout
    vertex.co.z-=.010*snout*(1-smooth(1.19,1.27,z))
    # A modest central bridge joins forehead to the blunt nose, with paired soft lip pads.
    vertex.co.y+=.025*math.exp(-((x/.14)**2+((z-1.368)/.066)**2))*smooth(.06,.15,y)
    vertex.co.y+=.006*math.exp(-(((abs(x)-.054)/.047)**2+((z-1.205)/.075)**2))*smooth(.28,.37,y)
    hood=math.exp(-(((abs(x)-.165)/.057)**2+((z-1.391)/.022)**2))*smooth(.05,.12,y)
    vertex.co.y+=.014*hood;vertex.co.x+=math.copysign(.005*hood,x)
body.data.update()


def mesh(name,vertices,faces,material):
    old=bpy.data.objects.get(name)
    if old:bpy.data.objects.remove(old,do_unlink=True)
    data=bpy.data.meshes.new(name+'_Reference');data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);collection.objects.link(obj);data.materials.append(material)
    for poly in data.polygons:poly.use_smooth=True
    group=obj.vertex_groups.new(name='head');group.add(list(range(len(vertices))),1.,'REPLACE')
    modifier=obj.modifiers.new('Armature','ARMATURE');modifier.object=rig
    obj.parent=rig
    obj['skin_region']='head'
    return obj


def ellipsoid(name,center,radii,material,basis=Matrix.Identity(3),power=1.):
    vertices=[];faces=[];rows=24;cols=48
    def sp(v):return math.copysign(abs(v)**power,v)
    for j in range(rows+1):
        theta=math.pi*j/rows
        for i in range(cols):
            phi=math.tau*i/cols
            q=Vector((radii[0]*sp(math.sin(theta))*sp(math.cos(phi)),radii[1]*sp(math.sin(theta))*sp(math.sin(phi)),radii[2]*sp(math.cos(theta))))
            vertices.append(Vector(center)+basis@q)
    for j in range(rows):
        for i in range(cols):
            a=j*cols+i;b=j*cols+(i+1)%cols;faces.append((a,b,b+cols,a+cols))
    return mesh(name,vertices,faces,material)


def surface_tree():
    return BVHTree.FromPolygons([v.co for v in body.data.vertices],[p.vertices[:] for p in body.data.polygons])


eye_mat=bpy.data.materials['Capybara_Dark_Eyes']
eye_bsdf=eye_mat.node_tree.nodes.get('Principled BSDF')
eye_bsdf.inputs['Roughness'].default_value=.26
eye_bsdf.inputs['Specular IOR Level'].default_value=.28
eye_bsdf.inputs['Base Color'].default_value=(.024,.012,.005,1)
skin=bpy.data.materials['Capybara_Caramel_Details']
skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.32,.121,.037,1)
rim_mat=bpy.data.materials['Capybara_Eyelids']
rim_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.19,.086,.029,1)
sclera=bpy.data.materials.get('Capybara_Eye_Sclera') or eye_mat.copy();sclera.name='Capybara_Eye_Sclera'
sclera.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.62,.52,.35,1)
pupil_mat=bpy.data.materials.get('Capybara_Eye_Pupil') or eye_mat.copy();pupil_mat.name='Capybara_Eye_Pupil'
pupil_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.003,.002,.001,1)

# The eye plane follows the side of the skull, rather than looking straight out of its front.
for sign,side in [(-1,'L'),(1,'R')]:
    normal=Vector((sign*.70,.714,0)).normalized();u=Vector((normal.y,-normal.x,0));up=Vector((0,0,1))
    basis=Matrix((u,normal,up)).transposed()
    center=Vector((sign*.168,.140,1.363))
    for name in ['Eye_Socket_'+side,'Eye_'+side,'Eye_Glint_'+side,'Eye_Iris_'+side,'Eye_Pupil_'+side,'Brow_'+side]:
        obj=bpy.data.objects.get(name)
        if obj:bpy.data.objects.remove(obj,do_unlink=True)
    uncut=surface_tree()
    # Open the cavity in the same oblique plane, with a broad skin lip around it.
    cutter=ellipsoid('Temporary_Eye_Cutter',center+normal*.010,(.039,.043,.026),skin,basis)
    for modifier in list(cutter.modifiers):cutter.modifiers.remove(modifier)
    modifier=body.modifiers.new('Reference eye cavity '+side,'BOOLEAN')
    modifier.operation='DIFFERENCE';modifier.object=cutter
    bpy.context.view_layer.objects.active=body
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.data.objects.remove(cutter,do_unlink=True)
    ellipsoid('Eye_'+side,center-normal*.017,(.030,.018,.025),sclera,basis)
    # Iris and pupil lie on the eye surface; a small outer sclera wedge remains visible.
    for name,radius,material in [('Eye_Iris_',.022,eye_mat),('Eye_Pupil_',.012,pupil_mat)]:
        points=[];polygons=[];ring_count=12;count=64
        for ring in range(ring_count+1):
            radius_now=radius*ring/ring_count
            for index in range(count):
                angle=math.tau*index/count;x=-sign*.006+radius_now*math.cos(angle);z=radius_now*math.sin(angle)
                depth=.018*math.sqrt(max(0,1-(x/.031)**2-(z/.026)**2))-.017
                points.append(center+u*x+up*z+normal*(depth+(.0004 if name=='Eye_Iris_' else .0008)))
        for ring in range(ring_count):
            for index in range(count):
                a=ring*count+index;b=ring*count+(index+1)%count;polygons.append((a,b,b+count,a+count))
        mesh(name+side,points,polygons,material)
    # One rolled eyelid surface. Outer edge sinks into the cheek; top edge forms the hood.
    vertices=[];faces=[];rings=9;segments=80
    for j in range(rings):
        t=j/(rings-1)
        for i in range(segments):
            angle=math.tau*i/segments;cs=math.cos(angle);sn=math.sin(angle)
            inner_x=.026*cs
            inner_z=(.010 if sn>0 else .019)*sn + sign*.28*inner_x
            outer_x=.052*cs
            outer_z=(.038 if sn>0 else .034)*sn + sign*.20*outer_x
            x=inner_x*(1-t)+outer_x*t;z=inner_z*(1-t)+outer_z*t
            outer_point=center+u*outer_x+up*outer_z
            hit=uncut.ray_cast(outer_point+normal*.12,-normal,.3)[0]
            outer_depth=(hit-outer_point).dot(normal)-.0003 if hit else -.025
            depth=.004*(1-t)+outer_depth*t + .014*math.sin(math.pi*t)*max(0,sn)
            vertices.append(center+u*x+up*z+normal*depth)
    for j in range(rings-1):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    socket=mesh('Eye_Socket_'+side,vertices,faces,skin)
    # Orient the rim outwards (the ring ordering is opposite on its inner side).
    import bmesh
    bm=bmesh.new();bm.from_mesh(socket.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(socket.data);bm.free()

# A broad nose saddle tapers into the central cleft, fitted to the blunt muzzle.
nose_mat=bpy.data.materials['Capybara_Nose']
nose_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.078,.049,.031,1)
nose_mat.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.60
tree=surface_tree()
vertices=[];faces=[];colors=[];rows=64;cols=96
for j in range(rows+1):
    radius=j/rows
    for i in range(cols):
        theta=math.tau*i/cols;z=1.282+.064*math.sin(theta)*radius
        x=.090*math.cos(theta)*radius*(.20+.80*smooth(1.218,1.297,z))
        hit=tree.ray_cast(Vector((x,2,z)),Vector((0,-1,0)))[0]
        rim=1-radius*radius
        y=hit.y-.0004+.025*rim
        nostril=0.
        for sign in [-1,1]:
            dx=(x-sign*.052)/.019;dz=(z-1.291-sign*.28*(x-sign*.052))/.008
            nostril=max(nostril,math.exp(-(dx*dx+dz*dz)*1.7))
        y-=.009*nostril
        vertices.append((x,y,z))
        edge=smooth(0,.14,rim)
        color=Vector(coat((x,y,z))[:3]).lerp(Vector((.082,.052,.035)),edge)
        color=color.lerp(Vector((.005,.003,.002)),smooth(.2,.8,nostril))
        colors.append((*color,1))
for j in range(rows):
    for i in range(cols):
        a=j*cols+i;b=j*cols+(i+1)%cols;faces.append((a,b,b+cols,a+cols))
nose=mesh('Broad_Dark_Nose',vertices,faces,nose_mat)
attribute=nose.data.color_attributes.new(name='CoatColours',type='FLOAT_COLOR',domain='POINT')
for value,color in zip(attribute.data,colors):value.color=color
color_node=nose_mat.node_tree.nodes.new('ShaderNodeVertexColor');color_node.layer_name='CoatColours'
nose_mat.node_tree.links.new(color_node.outputs['Color'],nose_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
for sign in [-1,1]:
    old=bpy.data.objects.get('Nostril_'+str(sign))
    if old:bpy.data.objects.remove(old,do_unlink=True)


def seam(name,coordinates,radius=.0015):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=radius;curve.bevel_resolution=3
    samples=[]
    for a,b in zip(coordinates,coordinates[1:]):
        for k in range(40):
            t=k/40;samples.append((a[0]*(1-t)+b[0]*t,a[1]*(1-t)+b[1]*t))
    samples.append(coordinates[-1])
    spline=curve.splines.new('POLY');spline.points.add(len(samples)-1)
    for point,(x,z) in zip(spline.points,samples):
        hit=tree.ray_cast(Vector((x,2,z)),Vector((0,-1,0)))[0]
        point.co=(x,hit.y+.001,z,1)
    obj=bpy.data.objects.new(name+'_Curve',curve);collection.objects.link(obj)
    for other in bpy.context.selected_objects:other.select_set(False)
    bpy.context.view_layer.objects.active=obj;obj.select_set(True);bpy.ops.object.convert(target='MESH')
    data=obj.data
    replacement=mesh(name,[v.co.copy() for v in data.vertices],[p.vertices[:] for p in data.polygons],eye_mat)
    bpy.data.objects.remove(obj,do_unlink=True)
    return replacement


seam('Closed_Mouth_Center',[(0,1.225),(0,1.175),(0,1.123)])
for sign,side in [(-1,'Left'),(1,'Right')]:
    seam('Closed_Mouth_'+side,[(0,1.123),(sign*.040,1.111),(sign*.082,1.098)])

# Boolean output receives the same authored coat and a rigid head influence.
body.data.materials.clear();body.data.materials.append(bpy.data.materials['Capybara_Caramel_Fur'])
attribute=body.data.color_attributes.get('CoatColours')
if not attribute:attribute=body.data.color_attributes.new(name='CoatColours',type='FLOAT_COLOR',domain='POINT')
for vertex in body.data.vertices:
    attribute.data[vertex.index].color=coat(vertex.co)
    if vertex.co.z>1.30:
        for group_id in [g.group for g in vertex.groups]:body.vertex_groups[group_id].remove([vertex.index])
        body.vertex_groups['head'].add([vertex.index],1.,'REPLACE')
for poly in body.data.polygons:poly.material_index=0;poly.use_smooth=True
body['reference_face_revision']=1
rig.data.pose_position='POSE';rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/capybara/source.blend'))
result={'face_revision':1,'body_vertices':len(body.data.vertices),'bone_count':len(rig.data.bones),'actions':len(bpy.data.actions)}
