"""Offline scene authoring. Every visible node is saved before the game runs."""
from pathlib import Path
import math,sys,re,json
ROOT=Path(__file__).resolve().parents[2]
FINAL='--final' in sys.argv
CHECK_ONLY='--check-only' in sys.argv
HALF=16 if FINAL else 8
BACK_EDGE=-HALF+4
STAIR_CENTER=BACK_EDGE+1
HOUSE_Z=-HALF+2
HOUSE_X=5.5 if FINAL else 4.1
TREE=(-7,0,-4) if FINAL else (-4.9,0,-.4)
ROCK=(9,0,-2) if FINAL else (5.3,0,-.2)
res=[];nodes=[];terrain=[];asset_placements=[]
def v(a):return 'Vector3('+', '.join(str(round(x,6)) for x in a)+')'
def sub(kind,name,props):
 name=re.sub(r'[^a-zA-Z0-9_]','_',name)
 res.append(f'[sub_resource type="{kind}" id="{name}"]\n{props}\n');return f'SubResource("{name}")'
def node(name,kind='Node3D',parent='.',props='',instance=None,groups=None):
 nodes.append(f'[node name="{name}" '+(f'type="{kind}" ' if not instance else '')+(f'parent="{parent}" ' if parent is not None else '')+(f'instance=ExtResource("{instance}")' if instance else '')+(f' groups={groups}' if groups else '')+f']\n{props}\n')
def mat(name,color):return sub('StandardMaterial3D',name,f'albedo_color = Color({color}, 1)\nroughness = 0.85')
palette={n:mat(n,c) for n,c in {'Grass':'0.68,0.73,0.31','Stone':'0.48,0.46,0.56','Sand':'0.90,0.75,0.55','Wood':'0.55,0.34,0.18','Wall':'0.87,0.80,0.64','Roof':'0.19,0.33,0.37','Leaves':'0.95,0.62,0.16','Water':'0.10,0.65,0.74','Backdrop':'0.90,0.865,0.79'}.items()}
def box(name,pos,size,color=None,collision=False,parent='Geometry'):
 if color:
  mesh=sub('BoxMesh',name+'Mesh','size = '+v(size))
  node(name,'MeshInstance3D',parent,'position = '+v(pos)+'\nmesh = '+mesh+'\nmaterial_override = '+palette[color])
 if collision:
  shape=sub('BoxShape3D',name+'Shape','size = '+v(size))
  node(name+'Body','StaticBody3D','Collision','position = '+v(pos)+'\ncollision_layer = 1\ncollision_mask = 0',groups='["walls"]' if name.startswith('Tree') or name=='RockBody' else None)
  node('Collision','CollisionShape3D','Collision/'+name+'Body','shape = '+shape)
def asset(name,key,pos,rotation=0,scale=(1,1,1)):
 asset_placements.append({'name':name,'asset':key,'position':pos,'yaw':rotation,'scale':scale})
 node(name,parent='Geometry',props='position = '+v(pos)+'\nrotation = '+v((0,rotation,0))+'\nscale = '+v(scale),instance=key)
 if key in ['grass_tile','grass_tile_half','grass_cliff','grass_cliff_half','plaza_tile','plaza_cliff']:
  terrain.append({'name':name,'kind':key,'x':pos[0],'z':pos[2],'height':pos[1],'width':1 if key.endswith('_half') else 2,'depth':2})
exts={'Player':('PackedScene','scenes/actors/player/Player.tscn'),'Room':('Script','scripts/world/prototype_room.gd'),'HUD':('PackedScene','scenes/ui/HUD.tscn'),'Spark':('PackedScene','scenes/effects/ImpactSpark.tscn'),'Sound':('AudioStream','assets/audio/impact.wav')}
if FINAL:
 exts['Acorn']=('PackedScene','scenes/actors/npcs/enemy/AcornGuard.tscn')
 exts['Dummy']=('PackedScene','scenes/actors/npcs/friendly/TrainingDummy.tscn')
 for k in ['grass_tile','grass_tile_half','grass_cliff_half','plaza_cliff','plaza_tile','garden_path','grass_cliff','stone_stairs','long_stairs','timber_bridge','cottage','smithy','autumn_tree','rock_cluster','timber_fence','flower_patch','barrel']:
  exts[k]=('PackedScene',f'scenes/assets/environment/{k}/Visual.tscn')
node('PrototypeRoom',parent=None,props='script = ExtResource("Room")')
node('Geometry');node('Collision')
# Three continuous banks; no collision seams at module boundaries.
for name,pos,size in [('Entrance',(0,-.5,(HALF+4)/2),(HALF*2,1,HALF-4)),('Square',(0,-.5,(BACK_EDGE+2)/2),(HALF*2,1,2-BACK_EDGE)),('Terrace',(0,.0,HOUSE_Z),(HALF*2,2,4))]:
 box(name,pos,size,None if FINAL else 'Grass',True)
box('Water',(0,-.28,3),(HALF*2,.04,2),'Water')
box('Backdrop',(0,-1.26,0),(200,.1,200),'Backdrop')
if FINAL:
 for x in range(-HALF+1,HALF,2):
  for z in range(-HALF+1,HALF,2):
   if z==3:continue
   top=1 if z<BACK_EDGE else 0
   key='grass_cliff' if z in [-HALF+1,BACK_EDGE-1,HALF-1] or abs(x)==HALF-1 else 'grass_tile'
   # Surface ownership is exclusive. Sand occupies real openings in the grass.
   path_half_width=1 if z>=5 or BACK_EDGE+2<z<-6 else (5 if z in [-5,-3,-1,1] else 0)
   if path_half_width and abs(x)<path_half_width:continue
   center=x
   if path_half_width and abs(x)==path_half_width:
    key+='_half';center=x+(.5 if x>0 else -.5)
   asset(f'Ground_{x+HALF-1}_{z+HALF-1}',key,(center,top,z))
 # Full-width sand ribbon at the bridge, narrower paths and broad quiet square.
 for z in list(range(5,HALF,2))+list(range(BACK_EDGE+3,2,2)):
  asset('Path_'+str(z+HALF),'plaza_cliff' if z==HALF-1 else 'plaza_tile',(0,0,z))
 for x in [-4,-2,2,4]:
  for z in [-5,-3,-1,1]:asset('Square_%s_%s'%(x+4,z+5),'plaza_tile',(x,0,z))
 asset('Stairs','stone_stairs',(0,0,STAIR_CENTER),math.pi)
 # Sixteen unscaled 25 cm steps: sustained ascent for camera-height testing.
 asset('LongTestStairs','long_stairs',(-11,0,-4),math.pi)
 for x in [-12,-10]:
  for z in [-11,-9]:asset('TestLanding_%s_%s'%(x,z),'grass_cliff',(x,4,z),scale=(1,4,1))
 box('TestLanding',(-11,1.98,-10),(4,4.04,4),None,True)
 for x in [-12,-10]:
  asset('LandingBackFence_'+str(x),'timber_fence',(x,4,-11.85))
 for side in [-1,1]:
  for z in [-11,-9]:asset('LandingSideFence_%s_%s'%(side,z),'timber_fence',(-11+side*1.85,4,z),math.pi/2)
  box('LandingSideRail_'+str(side),(-11+side*1.91,4.5,-10),(.18,1.0,4),None,True)
  asset('LandingFrontFence_'+str(side),'timber_fence',(-11+side*1.5,4,-8.08),scale=(.5,1,1))
  box('LandingFrontRail_'+str(side),(-11+side*1.5,4.5,-8.08),(1,1,.16),None,True)
 box('LandingBackRail',(-11,4.5,-11.91),(4,1,.18),None,True)
 points=[(x,y,z) for x in [-12,-10] for y,z in [(-.03,0),(-.03,-8),(0,0),(4,-8)]]
 long_ramp=sub('ConvexPolygonShape3D','LongStairRamp','points = PackedVector3Array('+', '.join(str(f) for p in points for f in p)+')')
 node('LongStairRamp','StaticBody3D','Collision','collision_layer = 1\ncollision_mask = 0')
 node('Collision','CollisionShape3D','Collision/LongStairRamp','shape = '+long_ramp)
 asset('Bridge','timber_bridge',(0,0,3))
 asset('Cottage','cottage',(-HOUSE_X,1,HOUSE_Z),math.pi)
 asset('Smithy','smithy',(HOUSE_X,1,HOUSE_Z),math.pi)
 asset('AutumnTree','autumn_tree',TREE)
 asset('Rock','rock_cluster',ROCK,.5,(1.65,1.65,1.65))
 for i,p in enumerate([(-7.6,1,HOUSE_Z+1.25),(7,1,HOUSE_Z+1.2),(-7.8,0,-2.6)]):asset('Flowers_'+str(i),'flower_patch',p)
 for i,p in enumerate([(-11,0,10),(11,0,9),(-14.1,0,-5),(11,0,-8)]):
  asset('BoundaryTree_'+str(i),'autumn_tree',p,.7*i,(.9,.9,.9))
  box('TreeBlocker_'+str(i),(p[0],.65,p[2]),(.48,1.3,.48),None,True)
 for i,p in enumerate([(6,0,-2),(6.65,0,-2),(9,0,-6)]):node('TrainingTarget_'+str(i),props='position = '+v(p),instance='Dummy')
 for name,p in [('West',(-3.6,0,-4.4)),('East',(3.4,0,-4.4))]:node('AcornGuard'+name,props='position = '+v(p),instance='Acorn')
 for side in [-1,1]:
  for z in range(-13,16,2):
   if z==3:continue
   asset('SideFence_%s_%s'%(side,z),'timber_fence',(side*(HALF-.35),1 if z<BACK_EDGE else 0,z),math.pi/2)
else:
 box('Path',(0,.008,4),(2,.016,8),'Sand');box('Plaza',(0,.008,0),(6,.016,2),'Sand')
 box('Bridge',(0,.03,3),(2,.10,3),'Wood')
 for i in range(4):box('Step'+str(i),(0,(i+1)*.125,-2.25-i*.5),(2,(i+1)*.25,.5),'Sand')
 for name,x in [('Cottage',-4.1),('Smithy',4.1)]:
  box(name,(x,2,-6),(3,2,2.5),'Wall');box(name+'Roof',(x,3.2,-6),(3.5,.4,3),'Roof')
 box('Tree',(-4.9,1.1,-.4),(.4,2.2,.4),'Wood');box('Crown',(-4.9,2.5,-.4),(2,1.7,1.6),'Leaves')
# Stair ramp fits the four 25 cm treads, only physics is sloped.
pts=[(x,y,z) for x in [-1,1] for y,z in [(-.05,BACK_EDGE+2),(-.05,BACK_EDGE),(0,BACK_EDGE+2),(1,BACK_EDGE)]]
ramp=sub('ConvexPolygonShape3D','StairRamp','points = PackedVector3Array('+', '.join(str(f) for p in pts for f in p)+')')
node('StairRamp','StaticBody3D','Collision','collision_layer = 1\ncollision_mask = 0')
node('Collision','CollisionShape3D','Collision/StairRamp','shape = '+ramp)
# Continuous gentle arch collider, 6 segments with shared end points.
for i in range(6):
 z0=1.5+i*.5;z1=z0+.5
 y0=.14*(1-((z0-3)/1.5)**2);y1=.14*(1-((z1-3)/1.5)**2)
 points=[(x,y,z) for x in [-.86,.86] for y,z in [(y0,z0),(y1,z1),(-.15,z0),(-.15,z1)]]
 shape=sub('ConvexPolygonShape3D','BridgeRamp'+str(i),'points = PackedVector3Array('+', '.join(str(round(f,6)) for p in points for f in p)+')')
 node('BridgeRamp'+str(i),'StaticBody3D','Collision','collision_layer = 1\ncollision_mask = 0')
 node('Collision','CollisionShape3D','Collision/BridgeRamp'+str(i),'shape = '+shape)
for side in [-1,1]:
 box('BridgeRail'+str(side),(side*.91,.4,3),(.18,1.1,3),None,True)
 for z in [2,4]:box('CanalBank%s_%s'%(side,z),(side*(HALF+1)/2,.45,z),(HALF-1,1,.12),None,True)
 box('RoomSide'+str(side),(side*(HALF-.08),1,0),(.16,4,HALF*2),None,True)
 box('House'+str(side),(side*HOUSE_X,2,HOUSE_Z),(3.05,2.1,2.48),None,True)
box('BackBoundary',(0,2,-HALF+.08),(HALF*2,3,.16),None,True)
box('FrontBoundary',(0,.8,HALF-.02),(HALF*2,3,.12),None,True)
box('TreeTrunk',(TREE[0],.7,TREE[2]),(.48,1.4,.48),None,True)
box('RockBody',(ROCK[0],.28,ROCK[2]),(.9,.6,.75),None,True)
# Hide the artificial diorama edge with a thin grass rim, leave entrance visually open.
for side in [-1,1]:
 box('SideRim'+str(side),(side*(HALF-.15),.05,0),(.30,.10,HALF*2),'Grass')
box('BackRim',(0,1.05,-HALF+.15),(HALF*2,.1,.30),'Grass')
node('Player',props='position = Vector3(0,0,0.3)',instance='Player')
node('CameraRig',props='position = Vector3(0,0.65,0.3)\nrotation = Vector3(-0.872665,0.785398,0)')
node('Camera3D','Camera3D','CameraRig','position = Vector3(0,0,24)\nprojection = 1\nsize = 13.0\ncurrent = true\nfar = 100.0')
node('Sun','DirectionalLight3D',props='rotation = Vector3(-0.95,-0.5,-0.2)\nlight_color = Color(1,0.91,0.78,1)\nlight_energy = 0.95\nlight_angular_distance = 1.0\nshadow_enabled = true\nshadow_bias = 0.03\ndirectional_shadow_max_distance = 45.0')
node('Fill','DirectionalLight3D',props='rotation = Vector3(-0.6,2.5,0)\nlight_color = Color(0.75,0.82,1,1)\nlight_energy = 0.18')
env=sub('Environment','World','background_mode = 1\nbackground_color = Color(0.90,0.865,0.79,1)\nambient_light_source = 2\nambient_light_color = Color(0.84,0.87,0.95,1)\nambient_light_energy = 0.48\nreflected_light_source = 2\ntonemap_mode = 2\nssao_enabled = true\nssao_radius = 0.35\nssao_intensity = 0.55\nglow_enabled = true\nglow_intensity = 0.55\nglow_strength = 0.8\nglow_bloom = 0.0\nglow_hdr_threshold = 1.4')
node('WorldEnvironment','WorldEnvironment',props='environment = '+env)
node('HUD',instance='HUD');node('DebugVolumes','MeshInstance3D',props='material_override = '+mat('Debug','0.8,1,0.5'))
node('ImpactPool')
for i in range(4):node('Spark'+str(i),parent='ImpactPool',instance='Spark')
node('ImpactSound','AudioStreamPlayer3D',props='stream = ExtResource("Sound")\nvolume_db = -8.0\nmax_distance = 30.0')
header='[gd_scene format=3]\n\n'+''.join(f'[ext_resource type="{t}" path="res://{p}" id="{k}"]\n' for k,(t,p) in exts.items())+'\n'
path=ROOT/'scenes/levels'/('PrototypeRoom.tscn' if FINAL else 'PrototypeBlockout.tscn')
if FINAL:
 # Reject any positive-area overlap at the same walk-surface height.
 for i,a in enumerate(terrain):
  for b in terrain[i+1:]:
   dx=(a['width']+b['width'])/2-abs(a['x']-b['x']);dz=(a['depth']+b['depth'])/2-abs(a['z']-b['z'])
   assert not(abs(a['height']-b['height'])<.001 and dx>1e-6 and dz>1e-6),f'Overlapping terrain: {a["name"]}, {b["name"]}'
 if CHECK_ONLY:
  print('TERRAIN_OVERLAP_CHECK_PASS',len(terrain),'surfaces');sys.exit(0)
 (ROOT/'captures/lantern_village/terrain_layout.json').write_text(json.dumps(terrain,indent=2))
 (ROOT/'assets/environment/room_layout.json').write_text(json.dumps(asset_placements,indent=2))

if not CHECK_ONLY:path.write_text(header+'\n'.join(res)+'\n'.join(nodes));print(path)
