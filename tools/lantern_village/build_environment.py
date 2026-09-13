"""Author the lantern-village kit in Blender. Saved 3D sources and GLBs, never runtime meshes.
Only creates new named asset scenes; refuses an already-authored collection.
"""
import bpy,sys,math,random,json
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate,mesh_object,material,ellipsoid,tube,smooth_curve
random.seed(1042)
colors={'Grass':(.68,.73,.31),'Grass_Light':(.72,.76,.35),'Earth':(.49,.37,.26),'Sand':(.88,.73,.53),'Sand_Light':(.93,.80,.61),'Paver':(.72,.64,.53),'Rock':(.46,.44,.54),'Rock_Light':(.53,.50,.60),'Rock_Shadow':(.40,.40,.49),'Plaster':(.87,.80,.64),'Roof':(.19,.33,.37),'Roof_Light':(.23,.37,.40),'Timber':(.40,.27,.18),'Plank':(.64,.41,.22),'Plank_Light':(.72,.48,.27),'Gold_Leaves':(1,.65,.15),'Amber_Leaves':(.83,.53,.15),'Coral_Leaves':(.92,.36,.20),'Leaf_Green':(.39,.47,.22),'Glass':(1,.69,.22),'Iron':(.27,.29,.29),'Fire':(1,.31,.035),'Dark':(.13,.105,.085),'Petal':(.99,.93,.73)}
mats={name:material('Village_'+name,color,.72,.25 if name=='Iron' else 0) for name,color in colors.items()}
for name,power in [('Glass',.65),('Fire',3.)]:
 bsdf=mats[name].node_tree.nodes['Principled BSDF'];bsdf.inputs['Emission Color'].default_value=(*colors[name],1);bsdf.inputs['Emission Strength'].default_value=power

def begin(asset):
 global s,c
 assert not bpy.data.collections.get('Village_'+asset),'Existing authored kit: refine source instead of rebuilding.'
 s=bpy.data.scenes.new('Asset_'+asset);bpy.context.window.scene=s;s.unit_settings.system='METRIC'
 c=bpy.data.collections.new('Village_'+asset);s.collection.children.link(c)

def bevel(o,width=.035,segments=2):
 activate(o);mod=o.modifiers.new('Soft crafted edges','BEVEL');mod.width=width;mod.segments=segments
 bpy.ops.object.modifier_apply(modifier=mod.name)
 mod=o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
 bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def box(name,pos,size,mat='Timber',rounding=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for old in list(o.users_collection):old.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(mats[mat])
 if rounding:bevel(o,rounding)
 return o

def beam(name,a,b,width,depth=None,mat='Timber'):
 a=Vector(a);b=Vector(b);o=box(name,(a+b)*.5,(width,depth or width,(b-a).length),mat,min(width*.1,.025))
 o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();return o

def prism(name,outline,depth,axis='Y',mat='Rock',rounding=.025):
 verts=[];faces=[];n=len(outline)
 for d in [-depth*.5,depth*.5]:
  for x,z in outline:verts.append((x,d,z) if axis=='Y' else (d,x,z))
 faces.extend([tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))])
 for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
 o=mesh_object(name,verts,faces,c,mats[mat])
 for f in o.data.polygons:f.use_smooth=False
 if rounding:bevel(o,rounding)
 return o

def ico(name,pos,scale,mat,sub=1):
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=pos);o=bpy.context.object;o.name=name;o.scale=scale
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 for old in list(o.users_collection):old.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(mats[mat]);return o

def cylinder(name,pos,radius,depth,mat,vertices=12):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=pos);o=bpy.context.object;o.name=name
 for old in list(o.users_collection):old.objects.unlink(o)
 c.objects.link(o);o.data.materials.append(mats[mat]);bevel(o,.012,1);return o

def finish(asset):
 destination=ROOT/'assets/environment'/asset;destination.mkdir(parents=True,exist_ok=True)
 for o in bpy.data.objects:o.select_set(False)
 for o in c.objects:o.select_set(True);o.data.name=o.name+'_Mesh'
 bpy.data.libraries.write(str(destination/'source.blend'),{s},fake_user=True)
 bpy.ops.export_scene.gltf(filepath=str(destination/'model.glb'),export_format='GLB',use_selection=True,use_active_scene=True,export_animations=False,export_yup=True)
 return {'asset':asset,'meshes':len(c.objects),'triangles':sum(len(p.vertices)-2 for o in c.objects if o.type=='MESH' for p in o.data.polygons)}

reports=[]
begin('grass_tile')
box('Earth_Base',(0,0,-.19),(2,2,.22),'Earth',0)
box('Grass_Surface',(0,0,-.045),(2,2,.09),'Grass',0)
reports.append(finish('grass_tile'))

begin('plaza_tile')
box('Sand_Block',(0,0,-.13),(2,2,.26),'Sand',0)
reports.append(finish('plaza_tile'))

begin('garden_path')
box('Earth_Base',(0,0,-.21),(2,2,.18),'Earth',0)
box('Path',(0,0,-.06),(.84,2,.12),'Sand',0)
for sign in [-1,1]:
 # Authored subtly scalloped grass margins; straight outer boundaries stay on the 2 m grid.
 points=[(sign*.415,-1),(sign*1,-1),(sign*1,1),(sign*.415,1)]
 verts=[];faces=[];outline=[]
 for j in range(21):outline.append((sign*(.415+.007*math.sin(j*2.1)),-1+j*.1))
 outline.extend([(sign*1,1),(sign*1,-1)])
 for z in [-.12,0]:
  verts.extend([(x,y,z) for x,y in outline])
 n=len(outline);faces=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]
 for i in range(n):faces.append((i,(i+1)%n,(i+1)%n+n,i+n))
 o=mesh_object('Grass_Margin_'+str(sign),verts,faces,c,mats['Grass'])
 for p in o.data.polygons:p.use_smooth=False
for i,(x,y,r) in enumerate([(-.06,.62,.17),(.035,-.02,.23),(-.045,-.67,.125)]):
 o=cylinder('Inset_Paver_'+str(i),(x,y,.002),r,.009,'Paver',8);o.scale.y=1.07
for i,(x,y) in enumerate([(.26,.39),(-.27,.12),(.26,-.52)]):cylinder('Path_Pebble_'+str(i),(x,y,.001),.037,.006,'Sand_Light',7)
reports.append(finish('garden_path'))

begin('grass_cliff')
perimeter=[(-1,-1),(-.52,-1),(-.08,-.99),(.38,-1),(1,-1),(1,-.48),(1,.05),(1,.52),(1,1),(.51,1),(.03,1),(-.51,1),(-1,1),(-1,.51),(-1,.02),(-1,-.5)]
verts=[];faces=[];N=len(perimeter)
for j,z in enumerate([-1.0,-.52,-.14]):
 for i,(x,y) in enumerate(perimeter):
  inset=(.035*(1+math.sin(i*5.7+j*2.1))) if j==1 else 0
  verts.append((x*(1-inset),y*(1-inset),z+(.055*math.sin(i*2.7) if j==1 else 0)))
for j in range(2):
 for i in range(N):
  a=j*N+i;b=j*N+(i+1)%N
  if (i+j)%3==0:faces.extend([(a,b,b+N),(a,b+N,a+N)])
  else:faces.append((a,b,b+N,a+N))
faces.extend([tuple(range(N-1,-1,-1)),tuple(2*N+i for i in range(N))])
cliff=mesh_object('Faceted_Stone',verts,faces,c,mats['Rock']);cliff.data.materials.append(mats['Rock_Light']);cliff.data.materials.append(mats['Rock_Shadow'])
for p in cliff.data.polygons:p.use_smooth=False;p.material_index=[0,0,1,0,2][p.index%5]
box('Grass_Cap',(0,0,-.065),(2,2,.13),'Grass',0)
for i,(x,y) in enumerate([(-.67,1),(.1,1),(.75,1),(1,-.35),(-1,.25)]):
 o=ico('Grass_Lip_'+str(i),(x*.83,y*.9,-.13),(.16,.10,.10),'Grass',1)
reports.append(finish('grass_cliff'))

begin('stone_stairs')
outline=[(1,0),(1,.25),(.5,.25),(.5,.5),(0,.5),(0,.75),(-.5,.75),(-.5,1.0),(-1,1.0),(-1,0)]
prism('Continuous_Stair_Core',outline,1.98,'X','Rock',.015)
for i in range(4):
 y=.75-i*.5;h=(i+1)*.25
 box('Tread_'+str(i),(0,y,h-.040),(2,.50,.08),'Sand_Light',.025)
 box('Riser_'+str(i),(0,y+.22,h-.15),(2,.08,.20),'Sand',.023)
reports.append(finish('stone_stairs'))

begin('timber_bridge')
def arch(y):return .14*max(0,1-(y/1.5)**2)
for i in range(18):
 y=-1.5+(i+.5)*3/18;box('Deck_Plank_%02d'%i,(0,y,arch(y)-.065),(1.72,3/18-.009,.13),'Plank' if i%3 else 'Plank_Light',.021)
for side in [-1,1]:
 for j,y in enumerate([-1.39,-.46,.46,1.39]):
  box('Post_%s_%s'%(side,j),(side*.875,y,.34),(.22,.23,.87),'Timber',.025)
  box('Post_Cap_%s_%s'%(side,j),(side*.875,y,.80),(.25,.25,.14),'Timber',.025)
 for name,z,width,height in [('Handrail',.67,.12,.12),('Underbeam',-.15,.12,.18)]:
  vertices=[];faces=[]
  for j in range(33):
   y=-1.5+j*3/32;h=arch(y)+z
   vertices.extend([(side*.875-width/2,y,h-height/2),(side*.875+width/2,y,h-height/2),(side*.875+width/2,y,h+height/2),(side*.875-width/2,y,h+height/2)])
  for j in range(32):
   for k in range(4):faces.append((j*4+k,j*4+(k+1)%4,(j+1)*4+(k+1)%4,(j+1)*4+k))
  faces.extend([(3,2,1,0),(128,129,130,131)])
  o=mesh_object(name+str(side),vertices,faces,c,mats['Plank' if name=='Handrail' else 'Timber']);bevel(o,.014,2)
reports.append(finish('timber_bridge'))

begin('autumn_tree')
trunk=tube('Forked_Trunk',[(0,0,.02,.29),(.04,0,.6,.20),(-.025,.015,1.35,.19),(-.12,.03,2.1,.13)],c,mats['Timber'],7,1)
for a,b,r in [((0,0,.75),(-.75,.015,1.85),.11),((0,0,1.03),(.72,-.045,2.12),.13)]:
 tube('Branch',[(*a,r),(*b,r*.55)],c,mats['Timber'],7,1)
for i in range(5):
 a=i*math.tau/5;tube('Root_'+str(i),[(0,0,.26,.16),(.43*math.cos(a),.43*math.sin(a),.02,.04)],c,mats['Timber'],5,1)
for name,pos,scale,mat in [('Crown',(-.10,.01,2.42),(.83,.71,.84),'Gold_Leaves'),('Left_Cluster',(-.78,.07,1.86),(.53,.50,.53),'Amber_Leaves'),('Right_Cluster',(.67,-.02,2.04),(.60,.56,.60),'Coral_Leaves')]:
 o=ico(name,pos,scale,mat,2);activate(o);mod=o.modifiers.new('Broad foliage facets','DECIMATE');mod.ratio=.55;bpy.ops.object.modifier_apply(modifier=mod.name)
for o in c.objects:
 if o.type=='MESH':
  for p in o.data.polygons:p.use_smooth=False
reports.append(finish('autumn_tree'))

def roof(width=3.5,depth=2.95,eave=1.93,ridge=2.94):
 for side in [-1,1]:
  profile=[(0,ridge),(.32*width/2,ridge-.17),(.75*width/2,eave+.13),(width/2,eave)]
  profile=smooth_curve(profile,5)
  outline=[(side*p.x,p.y+.065) for p in profile]+[(side*p.x,p.y-.085) for p in reversed(profile)]
  for panel in range(4):
   o=prism('Roof_Panel_%s_%s'%(side,panel),outline,depth/4-.007,'Y','Roof' if panel%3 else 'Roof_Light',.043)
   o.location.y=-depth/2+(panel+.5)*depth/4

def window(name,center,rotation=0,lit=True):
 parts=[]
 parts.append(box(name+'_Recess',(0,0,0),(.53,.072,.56),'Timber',.018))
 for x in [-.112,.112]:
  for z in [-.12,.12]:parts.append(box(name+'_Pane',(x,.043,z),(.17,.012,.18),'Glass' if lit else 'Dark',.007))
 # Apply placement to each little pane and frame; saved meshes stay editable.
 from mathutils import Matrix
 rotation_matrix=Matrix.Rotation(rotation,3,'Z')
 for o in parts:o.location=Vector(center)+rotation_matrix@o.location;o.rotation_euler.z=rotation

def door(name,y):
 outline=[(-.39,.035),(.39,.035),(.39,1.08)]
 for i in range(17):
  a=i*math.pi/16;outline.append((.39*math.cos(a),1.08+.39*math.sin(a)))
 o=prism(name,outline,.06,'Y','Timber',.018);o.location.y=y
 for x in [-.2,0,.2]:box('Door_Plank_Join',(x,y+.038,.60),(.012,.009,1.03),'Dark',.003)
 arch_points=[(-.46,y+.015,.04),(-.46,y+.015,1.08)]
 arch_points += [(-.46*math.cos(i*math.pi/20),y+.015,1.08+.46*math.sin(i*math.pi/20)) for i in range(21)]
 arch_points +=[(.46,y+.015,.04)]
 tube('Door_Stone_Frame',[(*p,.068) for p in arch_points],c,mats['Plaster'],12,1)
 ellipsoid('Door_Knob',(-.23,y+.09,.64),(.045,.035,.045),c,mats['Iron'],20,12)
 box('Doorstep',(0,y+.22,.065),(1.0,.47,.13),'Paver',.035)

begin('cottage')
prism('Plaster_House',[(-1.52,0),(1.52,0),(1.52,1.88),(0,2.86),(-1.52,1.88)],2.45,'Y','Plaster',.035)
roof();door('Arched_Oak_Door',1.258)
for x in [-1.01,1.01]:window('Front_Window',(x,1.25,1.03))
window('Right_Window',(1.55,0,1.03),-math.pi/2);window('Left_Window',(-1.55,0,1.03),math.pi/2)
for x in [-.81,.81]:window('Rear_Window',(x,-1.25,1.03),math.pi)
for x in [-1.48,1.48]:
 for y in [-1.21,1.21]:box('Corner_Timber',(x,y,.93),(.13,.13,1.86),'Timber',.021)
box('Chimney',(1.00,-.60,2.91),(.40,.42,.98),'Plaster',.03)
box('Chimney_Cap',(1.00,-.60,3.43),(.50,.52,.14),'Sand_Light',.028)
reports.append(finish('cottage'))

begin('smithy')
box('Rear_Plaster_Wall',(0,-1.10,.97),(2.85,.17,1.94),'Plaster',.035)
prism('Rear_Gable',[(-1.43,1.9),(1.43,1.9),(0,2.87)],.17,'Y','Plaster',.025).location.y=-1.10
for x in [-1.35,1.35]:
 box('Side_Plaster_Wall',(x,-.14,.97),(.16,2.10,1.94),'Plaster',.035)
 box('Porch_Post',(x,1.10,1.02),(.21,.23,2.04),'Timber',.026)
 box('Post_Foot',(x,1.10,.135),(.31,.33,.27),'Timber',.03)
box('Porch_Header',(0,1.10,2.06),(2.95,.21,.20),'Timber',.028)
beam('Gable_King_Post',(0,1.10,2.06),(0,1.10,2.80),.17,mat='Timber')
for side in [-1,1]:beam('Roof_Brace',(side*1.30,1.10,1.82),(side*.88,1.10,2.16),.12,mat='Timber')
roof(3.42,2.94,1.98,2.95)
box('Forge_Floor',(0,0,.035),(2.72,2.44,.07),'Paver',.025)
box('Forge_Chimney',(0,-.91,2.10),(.55,.52,1.65),'Rock',.03)
box('Roof_Chimney',(1.03,-.55,2.98),(.40,.42,.91),'Paver',.025);box('Roof_Chimney_Cap',(1.03,-.55,3.45),(.49,.51,.15),'Iron',.025)
box('Hearth_Dark',(0,-.918,.64),(.83,.04,.80),'Dark',.02)
for sign in [-1,1]:
 for z in [.26,.51,.76]:box('Hearth_Pier',(sign*.51,-.80,z),(.25,.30,.24),'Paver',.025)
for i in range(9):
 a=i*math.pi/8;o=box('Arch_Stone_'+str(i),(.50*math.cos(a),-.80,.76+.50*math.sin(a)),(.25,.31,.25),'Paver',.028);o.rotation_euler.y=math.pi/2-a
ellipsoid('Fire_Glow',(0,-.805,.40),(.28,.028,.18),c,mats['Fire'],24,16)
box('Hearth_Ledge',(0,-.55,.14),(1.28,.56,.14),'Rock',.025)
cylinder('Anvil_Stump',(0,1.32,.23),.33,.46,'Plank',12)
box('Anvil_Foot',(0,1.32,.51),(.48,.32,.10),'Iron',.025)
prism('Anvil', [(-.27,.55),(.23,.55),(.17,.67),(.27,.73),(.51,.78),(.53,.85),(-.36,.85),(-.54,.83),(-.68,.79),(-.47,.71),(-.23,.70)],.30,'Y','Iron',.018).location.y=1.32
window('Smithy_Side_Window',(1.45,-.28,1.03),-math.pi/2,False)
reports.append(finish('smithy'))

# Small kit companions used in the supplied village composition.
begin('timber_fence')
for x in [-.94,.94]:box('Fence_Post',(x,0,.37),(.16,.18,.82),'Timber',.015)
box('Fence_Rail',(0,0,.48),(1.93,.10,.12),'Plank',.013)
reports.append(finish('timber_fence'))
begin('rock_cluster')
for i,(pos,scale) in enumerate([((0,0,.24),(.32,.27,.42)),((.27,.08,.13),(.22,.20,.22)),((-.26,.08,.07),(.16,.18,.12))]):ico('Stone_'+str(i),pos,scale,'Rock_Light',1)
reports.append(finish('rock_cluster'))
begin('flower_patch')
for i in range(8):
 x=random.uniform(-.35,.35);y=random.uniform(-.25,.25);z=random.uniform(.14,.25)
 tube('Stem_'+str(i),[(x,y,0,.012),(x,y,z,.009)],c,mats['Leaf_Green'],5,1)
 ico('Leaves_'+str(i),(x,y,.05),(.09,.06,.10),'Leaf_Green',1)
 for j in range(5):
  a=j*math.tau/5;ellipsoid('Petal',(x+.037*math.cos(a),y+.037*math.sin(a),z),(.035,.025,.012),c,mats['Petal'],12,8)
reports.append(finish('flower_patch'))
begin('barrel')
cylinder('Oak_Barrel',(0,0,.27),.23,.54,'Plank',12)
for z in [.12,.43]:cylinder('Iron_Hoop',(0,0,z),.239,.045,'Iron',12)
cylinder('Barrel_Lid',(0,0,.548),.215,.026,'Timber',12)
reports.append(finish('barrel'))

(ROOT/'captures/lantern_village/environment_build.json').write_text(json.dumps(reports,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/environment/lantern_kit.blend'))
result={'assets':reports,'source':bpy.data.filepath}
