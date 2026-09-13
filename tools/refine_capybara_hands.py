"""Replace bead-like digits with connected palms, curled fingers and opposed thumbs.
Local hand topology is rebuilt; torso UVs, bones and gameplay socket names survive.
"""
import bpy, bmesh, math
from pathlib import Path
from mathutils import Vector
root=next(p for p in Path(bpy.data.filepath).parents if (p/'project.godot').is_file())
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
rig=bpy.data.objects['Capybara_Rig'];body=bpy.data.objects['Capybara_Body'];collection=bpy.data.collections['Capybara_Character']
assert not body.get('connected_hands_revision'), 'Already applied; reopen the checkpoint to revise topology.'
checkpoint=root/'assets/characters/capybara/checkpoints/before_hand_topology.blend'
if not checkpoint.exists():bpy.ops.wm.save_as_mainfile(filepath=str(checkpoint),copy=True)
rig.data.pose_position='REST'
V=Vector

def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)

def mesh(name,vertices,faces):
 data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
 obj=bpy.data.objects.new(name,data);collection.objects.link(obj)
 return obj

def tube(name,controls,radii):
 vertices=[];faces=[];count=40;segments=16
 def point(t):
  a,b,c,d=map(V,controls);return a*(1-t)**3+b*3*t*(1-t)**2+c*3*t*t*(1-t)+d*t**3
 for j in range(count+1):
  t=j/count;p=point(t);tangent=(point(min(1,t+.002))-point(max(0,t-.002))).normalized()
  axis=V((1,0,0));axis=(axis-tangent*axis.dot(tangent)).normalized();other=tangent.cross(axis)
  radius=radii[0]*(1-t)+radii[1]*t
  if t>.90:radius*=math.sqrt(max(.025,1-((t-.90)/.10)**2))
  for i in range(segments):
   angle=math.tau*i/segments;vertices.append(p+radius*(axis*math.cos(angle)+other*math.sin(angle)))
 for j in range(count):
  for i in range(segments):
   a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
 faces.extend([tuple(reversed(range(segments))),tuple(count*segments+i for i in range(segments))])
 return mesh(name,vertices,faces)

mat=bpy.data.materials.get('Capybara_Hands') or bpy.data.materials.new('Capybara_Hands');mat.use_nodes=True
bs=mat.node_tree.nodes.get('Principled BSDF');bs.inputs['Roughness'].default_value=.78;bs.inputs['Specular IOR Level'].default_value=.22
colour=mat.node_tree.nodes.new('ShaderNodeVertexColor');colour.layer_name='CoatColours';mat.node_tree.links.new(colour.outputs['Color'],bs.inputs['Base Color'])
# Remove only the old palm ends. The new wrist extends under the retained forearm.
bm=bmesh.new();bm.from_mesh(body.data)
remove=[v for v in bm.verts if abs(v.co.x)>.44 and v.co.z<.605 and v.co.z>.35]
bmesh.ops.delete(bm,geom=remove,context='VERTS');bm.to_mesh(body.data);bm.free()
for obj in list(collection.objects):
 if obj.name.startswith('Finger_') or obj.name.startswith('Thumb_'):bpy.data.objects.remove(obj,do_unlink=True)
for sign,side in [(-1,'L'),(1,'R')]:
 vertices=[];faces=[];rings=24;segments=40
 # A flattened palm with a tapered wrist and knuckle shelf, not a spherical mitten.
 profiles=[(.676,.510,.032,.046,.046),(.635,.528,.035,.050,.045),(.586,.551,.036,.061,.044),(.537,.556,.040,.060,.043),(.503,.558,.044,.054,.040),(.478,.558,.045,.040,.032)]
 for j in range(rings+1):
  u=j/rings*(len(profiles)-1);k=min(len(profiles)-2,int(u));t=smooth(0,1,u-k)
  z,x,y,rx,ry=[a*(1-t)+b*t for a,b in zip(profiles[k],profiles[k+1])]
  for i in range(segments):
   a=math.tau*i/segments;vertices.append((sign*x+rx*math.cos(a),y+ry*math.sin(a),z))
 for j in range(rings):
  for i in range(segments):
   a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,b,b+segments,a+segments))
 faces.extend([tuple(reversed(range(segments))),tuple(rings*segments+i for i in range(segments))])
 parts=[mesh('Hand_Palm_'+side,vertices,faces)]
 for i in range(3):
  x=sign*(.558+(i-1)*.038);bottom=.420+(.010 if i==0 else (.005 if i==2 else 0))
  parts.append(tube('Hand_Finger_'+side+str(i),[(x,.034,.527),(x,.020,.477),(x,.045,bottom+.018),(x,.070,bottom+.008)],(.0205,.0145)))
 parts.append(tube('Hand_Thumb_'+side,[(sign*.511,.043,.579),(sign*.489,.060,.554),(sign*.490,.098,.523),(sign*.508,.100,.512)],(.024,.016)))
 for obj in bpy.context.selected_objects:obj.select_set(False)
 for obj in parts:obj.select_set(True)
 bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();hand=bpy.context.object;hand.name='Hand_'+side
 hand.data.remesh_voxel_size=.0025;bpy.ops.object.voxel_remesh()
 modifier=hand.modifiers.new('Hand surface relaxation','SMOOTH');modifier.factor=.7;modifier.iterations=5;bpy.ops.object.modifier_apply(modifier=modifier.name)
 modifier=hand.modifiers.new('Hand contour resolution','SUBSURF');modifier.levels=1;bpy.ops.object.modifier_apply(modifier=modifier.name)
 modifier=hand.modifiers.new('Game hand topology','DECIMATE');modifier.ratio=.06;bpy.ops.object.modifier_apply(modifier=modifier.name)
 hand.data.materials.clear();hand.data.materials.append(mat)
 colours=hand.data.color_attributes.new(name='CoatColours',type='FLOAT_COLOR',domain='POINT')
 groups={n:hand.vertex_groups.new(name=n) for n in ['forearm_'+side,'hand_'+side,'fingers_'+side]}
 for vertex in hand.data.vertices:
  x,y,z=vertex.co
  proximal=smooth(.58,.667,z)
  digit=(1-smooth(.465,.522,z))*(1-proximal)
  thumb=(1-smooth(.515,.540,abs(x)))*smooth(.055,.09,y)
  digit*=1-thumb
  weights={'forearm_'+side:proximal,'hand_'+side:1-proximal-digit,'fingers_'+side:digit}
  for name,value in weights.items():
   if value>1e-5:groups[name].add([vertex.index],value,'REPLACE')
  # Match the existing warm wrist, then darken to the reference's brown palms/digits.
  shade=V((.065,.032,.018)).lerp(V((.21,.083,.026)),smooth(.57,.675,z))
  colours.data[vertex.index].color=(*shade,1)
 for poly in hand.data.polygons:poly.use_smooth=True
 hand.parent=rig;modifier=hand.modifiers.new('Armature','ARMATURE');modifier.object=rig
 hand['skin_region']='hand_'+side
# Stitch each wrist to the body's open forearm ring. No overlapping sleeves or floating cuffs.
for sign,side in [(-1,'L'),(1,'R')]:
 hand=bpy.data.objects['Hand_'+side]
 bm=bmesh.new();bm.from_mesh(hand.data)
 bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,plane_co=(0,0,.590),plane_no=(0,0,1),clear_outer=True,clear_inner=False)
 bm.to_mesh(hand.data);bm.free()
 for obj in bpy.context.selected_objects:obj.select_set(False)
 body.select_set(True);hand.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
 bm=bmesh.new();bm.from_mesh(body.data)
 boundary={v for edge in bm.edges if edge.is_boundary for v in edge.verts if sign*v.co.x>.44 and .57<v.co.z<.64}
 upper=[v for v in boundary if v.co.z>.599];lower=[v for v in boundary if v.co.z<.599]
 assert upper and lower, (side,len(upper),len(lower))
 for v in upper:v.co.z=.610
 center=sum((v.co for v in upper),V())/len(upper)
 angle=lambda v:(math.atan2(v.co.y-center.y,v.co.x-center.x)+math.tau)%math.tau
 upper.sort(key=angle);lower.sort(key=angle)
 i=j=0;n=len(upper);m=len(lower)
 material_index=list(body.data.materials).index(mat)
 while i<n or j<m:
  next_a=angle(upper[(i+1)%n])+(math.tau if i+1>=n else 0) if i<n else 1e10
  next_b=angle(lower[(j+1)%m])+(math.tau if j+1>=m else 0) if j<m else 1e10
  if next_a<next_b:
   face=bm.faces.new((upper[i%n],upper[(i+1)%n],lower[j%m]));i+=1
  else:
   face=bm.faces.new((upper[i%n],lower[(j+1)%m],lower[j%m]));j+=1
  face.material_index=material_index;face.smooth=True
 bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
body['connected_hands_revision']=2
rig.data.pose_position='POSE';rig.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(root/'assets/characters/capybara/source.blend'))
result={'connected_hand_revision':2,'body_vertices':len(body.data.vertices),'materials':[m.name for m in body.data.materials]}
