"""Exclusive grass/path/terrace footprints with precise polygon-clipped banks."""
import bpy,sys,math,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(Path(__file__).parent))
from layout import path_mask,pond_distance,TERRACES,GROUND_BOUNDS
passage = '--passage' in sys.argv
ground_id = 'forest_passage_ground' if passage else 'forest_ground'
if passage:
 from layout import segment_distance
 GROUND_BOUNDS=(-19,19,-19,25)
 TERRACES=[]
 def pond_distance(x,z):return 1000000.
 def path_mask(x,z):
  d=min(segment_distance(x,z,(0,-5),(0,25))-1.2,math.hypot(x,z+5)-3.)
  d+=.035*math.sin(x*5+z*3)+.025*math.sin(z*7-x*4)
  return max(0,min(1,.5-d/.25))

(ROOT/'captures/forest').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
s=bpy.context.scene;s.name='ForestGround_Production'
# Half-plane clipping keeps the raised grass edge exact rather than staircase sampled.
def cut(poly,a,b,keep_inside):
 def field(p):return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
 result=[]
 for p,q in zip(poly,poly[1:]+poly[:1]):
  fp=field(p);fq=field(q);pin=(fp>=-1e-8) if keep_inside else (fp<=1e-8);qin=(fq>=-1e-8) if keep_inside else (fq<=1e-8)
  if pin:result.append(p)
  if pin!=qin:
   t=fp/(fp-fq);result.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])))
 return result
regions=[]
for t in TERRACES:
 poly=t['polygon'];area=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))
 if area<0:poly=list(reversed(poly))
 regions.append((t,poly))
region_bounds=[(min(p[0] for p in poly),max(p[0] for p in poly),min(p[1] for p in poly),max(p[1] for p in poly)) for _,poly in regions]
verts=[];faces=[];masks=[];area_total=0.;area_expected=0.
def emit(poly,h):
 global area_total
 if len(poly)<3:return
 area=abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))*.5
 if area<1e-9:return
 area_total+=area;start=len(verts)
 for x,z in poly:verts.append((x,-z,h));masks.append(path_mask(x,z) if h<.1 else 0.)
 faces.append(tuple(reversed(range(start,len(verts)))))
step=.25
xmin,xmax,zmin,zmax=GROUND_BOUNDS
for j in range(round((zmax-zmin)/step)):
 for i in range(round((xmax-xmin)/step)):
  x=xmin+i*step;z=zmin+j*step
  if pond_distance(x+step*.5,z+step*.5)<2.43:continue
  area_expected+=step*step
  pieces=[[(x,z),(x+step,z),(x+step,z+step),(x,z+step)]]
  for (terrace,region),bounds in zip(regions,region_bounds):
   if x+step<bounds[0] or x>bounds[1] or z+step<bounds[2] or z>bounds[3]:continue
   next_pieces=[]
   for polygon in pieces:
    inner=polygon
    for a,b in zip(region,region[1:]+region[:1]):
     if len(inner)<3:break
     outer=cut(inner,a,b,False)
     if len(outer)>=3:next_pieces.append(outer)
     inner=cut(inner,a,b,True)
    emit(inner,terrace['height'])
   pieces=next_pieces
  for polygon in pieces:emit(polygon,0.)
assert abs(area_total-area_expected)<1e-5,(area_total,area_expected)
mesh=bpy.data.meshes.new('Exclusive_grass_path');mesh.from_pydata(verts,[],faces);mesh.update()
o=bpy.data.objects.new('Ground',mesh);s.collection.objects.link(o)
uv=mesh.uv_layers.new(name='UVMap');color=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
for p in mesh.polygons:
 for li in p.loop_indices:
  vi=mesh.loops[li].vertex_index;x,y,z=verts[vi];uv.data[li].uv=(x/3,y/3);t=masks[vi];color.data[li].color=(t,t,t,1)
mat=bpy.data.materials.new('ForestGround');mat.diffuse_color=(.32,.41,.16,1);mat.use_nodes=True
# Blender authoring preview reads the same region mask and atlas as the Godot wrapper.
nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.94
texcoord=nodes.new('ShaderNodeTexCoord');fract=nodes.new('ShaderNodeVectorMath');fract.operation='FRACTION';links.new(texcoord.outputs['UV'],fract.inputs[0])
sample=[]
for offset in [(0.,0.,0.),(.5,0.,0.)]:
 scale=nodes.new('ShaderNodeVectorMath');scale.operation='MULTIPLY_ADD';scale.inputs[1].default_value=(.468,.468,1);scale.inputs[2].default_value=(.016+offset[0],.016,0);links.new(fract.outputs[0],scale.inputs[0])
 tex=nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(ROOT/'assets/environment/forest_materials/atlas.png'),check_existing=True);links.new(scale.outputs[0],tex.inputs['Vector']);sample.append(tex)
mask=nodes.new('ShaderNodeVertexColor');mask.layer_name='Color';mix=nodes.new('ShaderNodeMixRGB');links.new(mask.outputs['Color'],mix.inputs[0]);links.new(sample[0].outputs['Color'],mix.inputs[1]);links.new(sample[1].outputs['Color'],mix.inputs[2]);links.new(mix.outputs[0],bs.inputs['Base Color']);mesh.materials.append(mat)
for im in bpy.data.images:
 if im.filepath:im.pack()
out=ROOT/'assets/environment'/ground_id;out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'model.glb'),export_format='GLB',export_animations=False,export_vertex_color='NAME',export_vertex_color_name='Color',export_all_vertex_colors=True)
report={'faces':len(faces),'exclusive_surface':True,'area_m2':area_total,'expected_area_m2':area_expected,'exact_terrace_boundaries':bool(regions),'pond_cutout':not passage}
(ROOT/'captures/forest'/('passage_ground_audit.json' if passage else 'ground_audit.json')).write_text(json.dumps(report,indent=2));print('GROUND_OVERLAP_CHECK_PASS',report)
if passage:sys.exit(0)
# Continuous walls share the exact grass boundary; cap material drapes down irregularly.
bpy.ops.wm.read_factory_settings(use_empty=True);s=bpy.context.scene;s.name='ForestTerraces_Production'
materials=[]
for name,c in [('Slate',(.19,.175,.265)),('Slate_light',(.23,.22,.31)),('Slate_dark',(.16,.17,.235)),('Moss_edge',(.26,.33,.12))]:
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(*c,1);m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.96;materials.append(m)
for terrace,poly in regions:
 boundary=[];h=terrace['height']
 for a,b in zip(poly,poly[1:]+poly[:1]):
  dx=b[0]-a[0];dz=b[1]-a[1];length=math.hypot(dx,dz);n=max(1,round(length/.75));normal=(dz/length,-dx/length)
  for i in range(n):
   t=i/n;boundary.append((a[0]+dx*t,a[1]+dz*t,normal))
 n=len(boundary);v=[];f=[];owners=[]
 for j in range(5):
  for i,(x,z,normal) in enumerate(boundary):
   irregular=.13*math.sin(i*1.71);outset=[.12,.45,.26,.01,0.][j]*(.55+.45*math.sin(i*1.27)**2)
   y=[-.08,h*.31+irregular,h*.75+irregular,h-.055-.075*(.5+.5*math.sin(i*1.7)),h][j]
   v.append((x+normal[0]*outset,-z-normal[1]*outset,y))
 for j in range(4):
  for i in range(n):
   # The waterfall replaces this section of the pond bank.
   x,z,normal=boundary[i];xx,zz,_=boundary[(i+1)%n]
   from layout import height_at
   if abs(height_at((x+xx)/2+normal[0]*.01,(z+zz)/2+normal[1]*.01)-h)<.001:continue
   if terrace['name']=='PondBank' and -9.05<(x+xx)/2<-7.95 and (z+zz)/2>-7:continue
   f.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i));owners.append(3 if j==3 else (1 if i%7==0 else 2 if i%9==0 else 0))
 me=bpy.data.meshes.new(terrace['name']);me.from_pydata(v,[],f);me.update();ob=bpy.data.objects.new(terrace['name'],me);s.collection.objects.link(ob)
 for mat in materials:me.materials.append(mat)
 for face,owner in zip(me.polygons,owners):face.material_index=min(owner,3)
 import bmesh
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(me);bm.free()
out=ROOT/'assets/environment/forest_terraces';out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'source.blend'))
# Export is separate, after current-source visual review.
