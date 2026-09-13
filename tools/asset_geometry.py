"""Small Blender mesh-authoring helpers. No scene deletion or implicit export."""
import bpy, bmesh, math
from mathutils import Vector

def activate(obj):
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    for item in bpy.context.selected_objects: item.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj

def mesh_object(name, vertices, faces, collection, material=None):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
    bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
    obj=bpy.data.objects.new(name,mesh);collection.objects.link(obj)
    if material: mesh.materials.append(material)
    for face in mesh.polygons: face.use_smooth=True
    return obj

def smooth_curve(points, steps=6, closed=False):
    points=[Vector(p) for p in points];out=[];n=len(points)
    for i in range(n if closed else n-1):
        a=points[(i-1)%n] if closed or i else points[0]
        b=points[i];c=points[(i+1)%n]
        d=points[(i+2)%n] if closed or i+2<n else points[-1]
        for j in range(steps):
            t=j/steps
            out.append((b*2+(-a+c)*t+(a*2-b*5+c*4-d)*t*t+(-a+b*3-c*3+d)*t**3)*.5)
    if not closed:out.append(points[-1])
    return out

def loft(name, profiles, collection, material, segments=64, steps=5, exponent=2.):
    # Profiles: z, x radius, y radius, y centre. Dense curved rings, continuous normals.
    rings=smooth_curve(profiles,steps);verts=[];faces=[]
    power=2/exponent
    for z,rx,ry,cy in rings:
        for i in range(segments):
            a=i*math.tau/segments;s=math.sin(a);c=math.cos(a)
            verts.append((rx*math.copysign(abs(s)**power,s),cy+ry*math.copysign(abs(c)**power,c),z))
    for j in range(len(rings)-1):
        for i in range(segments):
            k=j*segments+i;n=j*segments+(i+1)%segments
            faces.append((k,n,n+segments,k+segments))
    faces.append(tuple(range(segments-1,-1,-1)))
    faces.append(tuple((len(rings)-1)*segments+i for i in range(segments)))
    return mesh_object(name,verts,faces,collection,material)

def tube(name, controls, collection, material, segments=24, steps=6):
    # Controls x,y,z,radius; a stable transported circular section along a smooth spine.
    rings=smooth_curve(controls,steps);verts=[];faces=[]
    for j,v in enumerate(rings):
        center=Vector(v[:3]);axis=Vector(rings[min(j+1,len(rings)-1)][:3])-Vector(rings[max(0,j-1)][:3])
        axis.normalize();normal=axis.cross(Vector((1,0,0)))
        if normal.length<.1:normal=axis.cross(Vector((0,1,0)))
        normal.normalize();other=axis.cross(normal).normalized()
        for i in range(segments):
            a=math.tau*i/segments;verts.append(center+(normal*math.cos(a)+other*math.sin(a))*max(.001,v[3]))
    for j in range(len(rings)-1):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments
            faces.append((a,b,b+segments,a+segments))
    faces.extend([tuple(range(segments-1,-1,-1)),tuple((len(rings)-1)*segments+i for i in range(segments))])
    return mesh_object(name,verts,faces,collection,material)

def ellipsoid(name, position, scale, collection, material, segments=48, rings=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=position)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    for coll in list(obj.users_collection):coll.objects.unlink(obj)
    collection.objects.link(obj)
    if material:obj.data.materials.append(material)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def fuse(objects, name, voxel=.004, smoothing=3, reduction=.5):
    activate(objects[0])
    for obj in objects:obj.select_set(True)
    bpy.ops.object.join();obj=objects[0];obj.name=name
    mod=obj.modifiers.new('Continuous anatomy','REMESH');mod.mode='VOXEL';mod.voxel_size=voxel;mod.use_smooth_shade=True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    mod=obj.modifiers.new('Surface polish','SMOOTH');mod.factor=.8;mod.iterations=smoothing
    bpy.ops.object.modifier_apply(modifier=mod.name)
    if reduction<1:
        mod=obj.modifiers.new('Game surface','DECIMATE');mod.ratio=reduction
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for p in obj.data.polygons:p.use_smooth=True
    return obj

def linear_color(rgb):
    return tuple(c/12.92 if c<=.04045 else ((c+.055)/1.055)**2.4 for c in rgb)

def material(name, rgb, roughness=.65, metallic=0.):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    color=(*linear_color(rgb),1);mat.diffuse_color=color
    bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=color
    bsdf.inputs['Roughness'].default_value=roughness;bsdf.inputs['Metallic'].default_value=metallic
    return mat
