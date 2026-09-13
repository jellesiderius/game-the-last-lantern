"""Offline saved continuation and cottage interior, reusing the current asset kit."""
from pathlib import Path
import math, random, re
ROOT=Path(__file__).resolve().parents[2]
class Scene:
 def __init__(self,name,spawn,indoor=False):
  self.exts={};self.res=[];self.nodes=[];self.count=0
  for k,t,path in [('World','Script','scripts/world/forest_passage.gd'),('Player','PackedScene','scenes/actors/player/Player.tscn'),('HUD','PackedScene','scenes/ui/HUD.tscn'),('Spark','PackedScene','scenes/effects/ImpactSpark.tscn'),('Sound','AudioStream','assets/audio/impact.wav'),('Portal','PackedScene','scenes/components/ScenePortal.tscn'),('Spawn','Script','scripts/world/scene_spawn_point.gd')]:self.ext(k,t,path)
  self.node(name,'Node3D',parent=None,props='script = ExtResource("World")\nspawn_position = '+self.xyz(spawn)+'\ncamera_min = Vector2('+('-1,-1' if indoor else '-5,-8')+')\ncamera_max = Vector2('+('1,1' if indoor else '5,11')+')')
  self.node('Assets','Node3D');self.node('Collision','Node3D')
  self.node('Player',instance='Player',props='position = '+self.xyz(spawn))
  self.node('CameraRig','Node3D',props='transform = Transform3D(0.7071069,-0.54167527,0.4545192,0,0.64278734,0.7660447,-0.70710665,-0.54167545,0.45451936,0,1.8,0)')
  self.node('Camera3D','Camera3D','CameraRig',props='position = Vector3(0,0,30)\nprojection = 1\ncurrent = true\nsize = 13.0\nfar = 120.0')
  self.node('Sun','DirectionalLight3D',props='rotation_degrees = Vector3(-55,-32,0)\nlight_color = Color(1,.88,.68,1)\nlight_energy = '+('.6' if indoor else '1.05')+'\nshadow_enabled = true\nshadow_blur = 3.0\nshadow_bias = .03\ndirectional_shadow_max_distance = 70.0')
  env=self.sub('Environment','Environment','background_mode = 1\nbackground_color = Color(.025,.055,.05,1)\nambient_light_source = 2\nambient_light_color = Color(.56,.69,.63,1)\nambient_light_energy = .55\ntonemap_mode = 4\ntonemap_exposure = 1.3\nssao_enabled = true\nssao_radius = .4\nssao_intensity = .7\nglow_enabled = true\nglow_intensity = .35')
  self.node('WorldEnvironment','WorldEnvironment',props='environment = '+env)
  self.node('HUD',instance='HUD');self.node('DebugVolumes','MeshInstance3D');self.node('ImpactPool','Node3D')
  for i in range(4):self.node('Spark'+str(i),parent='ImpactPool',instance='Spark')
  self.node('ImpactSound','AudioStreamPlayer3D',props='stream = ExtResource("Sound")\nvolume_db = -8.0\nmax_distance = 30.0')
 def xyz(self,v):return 'Vector3('+','.join(str(x) for x in v)+')'
 def ext(self,k,t,p):self.exts[k]=(t,p)
 def sub(self,k,t,props):
  k=re.sub(r"[^a-zA-Z0-9_]","_",k)
  self.res.append(f'[sub_resource type="{t}" id="{k}"]\n{props}\n');return f'SubResource("{k}")'
 def node(self,name,typ=None,parent='.',props='',instance=None):
  attrs=f'name="{name}"'+(f' type="{typ}"' if typ else '')+(f' parent="{parent}"' if parent else '')+(f' instance=ExtResource("{instance}")' if instance else '')
  self.nodes.append(f'[node {attrs}]\n{props}\n')
 def asset(self,asset,pos,scale=1,yaw=0,name=None):
  self.ext(asset,'PackedScene',f'scenes/assets/environment/{asset}/Visual.tscn');self.count+=1
  name=name or asset+str(self.count)
  self.node(name,parent='Assets',instance=asset,props='position = '+self.xyz(pos)+'\nscale = '+self.xyz((scale,)*3)+'\nrotation_degrees = '+self.xyz((0,yaw,0)))
 def box(self,name,pos,size,color=None,collision=True,parent='Assets'):
  if color:
   material=self.sub(name+'Material','StandardMaterial3D','albedo_color = Color('+','.join(str(c) for c in color)+',1)\nroughness = .92')
   mesh=self.sub(name+'Mesh','BoxMesh','size = '+self.xyz(size))
   self.node(name,'MeshInstance3D',parent,props='position = '+self.xyz(pos)+'\nmesh = '+mesh+'\nmaterial_override = '+material)
  if collision:
   shape=self.sub(name+'Shape','BoxShape3D','size = '+self.xyz(size))
   self.node(name+'Body','StaticBody3D','Collision',props='position = '+self.xyz(pos));self.node('Shape','CollisionShape3D','Collision/'+name+'Body',props='shape = '+shape)
 def spawn(self,name,pos,yaw=0):
  self.node('Spawn'+name,'Marker3D',props='position = '+self.xyz(pos)+'\nrotation_degrees = '+self.xyz((0,yaw,0))+'\nscript = ExtResource("Spawn")\nspawn_id = &"'+name+'"')
 def portal(self,name,pos,target,spawn,yaw=0,size=(6,3,2),door=False):
  if door:self.ext("DoorTravel","Resource","settings/transitions/door.tres")
  self.node(name,instance='Portal',props='position = '+self.xyz(pos)+'\nrotation_degrees = '+self.xyz((0,yaw,0))+'\ntarget_scene = "res://scenes/levels/'+target+'.tscn"\ntarget_spawn = &"'+spawn+'"\ntrigger_size = '+self.xyz(size))
  if door:self.nodes[-1]+='settings = ExtResource("DoorTravel")\nallow_loading_screen = false\n'
 def save(self,name):
  text='[gd_scene format=3]\n'+''.join(f'[ext_resource type="{t}" path="res://{p}" id="{k}"]\n' for k,(t,p) in self.exts.items())+'\n'+''.join(self.res)+''.join(self.nodes)
  text=re.sub(r'(?<![0-9])\.(?=[0-9])','0.',text)
  (ROOT/'scenes/levels'/name).write_text(text)

s=Scene('ForestPassage',(0,0,8.3));rng=random.Random(14)
s.asset('forest_passage_ground',(0,0,0))
s.box('Floor',(0,-.6,0),(26,1.2,28))
for sign in [-1,1]:
 s.box('Side'+str(sign),(sign*8.8,1,0),(.7,3,28))
 for z in range(-12,14,3):
  s.asset('forest_cliff',(sign*9.3,0,z),1.2,90 if sign<0 else -90)
  s.asset(rng.choice(['forest_pine','forest_pine_b','forest_pine_c']),(sign*rng.uniform(8.5,10.5),1.0,z+.3),rng.uniform(.9,1.1))
for x in [-6,-3,0,3,6]:s.asset('forest_pine_b',(x,0,-12.5),1.15)
s.box('Back',(0,1,-13),(18,3,.7))
for sign in [-1,1]:s.box('South'+str(sign),(sign*5.8,1,13),(6.3,3,.7))
for x in [-12,-9,-6,-3,3,6,9,12]:
 s.asset('forest_pine_c',(x,0,16.2+abs(x)*.12),1.15)
 if abs(x)>3:s.asset('forest_cliff',(x,0,14.5),1.1)
s.asset('forest_gate',(0,0,10.4),1,0)
s.ext('Lantern','PackedScene','scenes/assets/props/hand_lantern/Visual.tscn')
s.node('GateLantern',parent='Assets',instance='Lantern',props='position = Vector3(0,1.92,10.4)\nscale = Vector3(1.3,1.3,1.3)')
s.asset('cottage',(0,0,-7),1.35,180,name='Cottage')
# Door faces south. Its transition starts before the doorstep and main house collision.
s.box('Cottage',(0,1.2,-7.15),(4.1,2.4,2.8))
s.portal('HouseDoor',(0,0,-4.5),'ForestHouse','Door',size=(2.8,3,1.2),door=True)
s.spawn('HouseDoor',(0,0,-3.65),180)
s.portal('SouthGate',(0,0,11.0),'ForestOpening','NorthGate',180)
s.spawn('SouthGate',(0,0,9.6))
for x,z,asset in [(-3.4,-4.9,'barrel'),(3.8,-7,'forest_shrub'),(-4,-8,'forest_oak'),(5,0,'forest_hollow_log'),(-3,3,'forest_fern'),(3,5,'forest_flowers_blue'),(-5,6,'forest_oak'),(4,-3,'forest_flowers_cream')]:s.asset(asset,(x,0,z),1)
s.save('ForestPassage.tscn')

s=Scene('ForestHouse',(0,0,1.5),True)
wood=(.35,.22,.12);dark=(.14,.09,.05);plaster=(.64,.57,.41)
s.box('Foundation',(0,-.35,0),(9.4,.5,9.4),dark,False)
s.box('Floor',(0,-.6,0),(9.4,1.2,9.4))
for i in range(18):s.box('Floorboard%02d'%i,(-4.25+i*.5,-.045,0),(.488,.09,9.0),(.39+(i%3)*.018,.27+(i%3)*.014,.15),False)
s.box('NorthWall',(0,1.3,-4.5),(9.4,2.6,.28),plaster)
s.box('WestWall',(-4.5,1.3,0),(.28,2.6,9),plaster)
s.box('EastCutaway',(4.5,.25,0),(.28,.5,9),wood,False);s.box('EastBarrier',(4.5,1.3,0),(.28,2.6,9))
for sign in [-1,1]:
 s.box('SouthWall'+str(sign),(sign*2.85,.25,4.5),(3.3,.5,.28),wood,False)
 s.box('SouthBarrier'+str(sign),(sign*2.85,1.3,4.5),(3.3,2.6,.28))
 s.box('DoorPost'+str(sign),(sign*1.23,1.2,4.4),(.18,2.4,.22),dark)
s.box('EntryFloor',(0,-.25,5.5),(2.4,.5,2),wood)
for x in [-4.45,-2.2,0,2.2,4.45]:s.box('Timber'+str(x),(x,1.3,-4.3),(.13,2.6,.12),dark,False)
s.box('WallBeam',(0,2.35,-4.3),(9,.15,.15),dark,False)
s.box('Rug',(0,.012,.2),(3.2,.02,4.2),(.20,.31,.27),False)
s.box('RugBorder',(0,.025,.2),(2.95,.008,3.95),(.34,.39,.28),False)
s.box('RugCentre',(0,.03,.2),(2.75,.005,3.75),(.24,.34,.29),False)
s.box('TableTop',(2.6,.88,-2.3),(2,.16,1.2),wood)
for i,(x,z) in enumerate([(1.8,-2.7),(3.4,-2.7),(1.8,-1.9),(3.4,-1.9)]):s.box('TableLeg'+str(i),(x,.4,z),(.14,.8,.14),dark)
s.box('BedFrame',(-3.1,.28,-2.4),(1.7,.56,2.7),wood)
s.box('Mattress',(-3.1,.60,-2.4),(1.6,.16,2.55),(.83,.76,.56),False)
s.box('Blanket',(-3.1,.71,-2.0),(1.63,.07,1.7),(.22,.39,.35),False)
s.box('Pillow',(-3.1,.75,-3.23),(1.25,.15,.6),(.93,.86,.65),False)
s.asset('barrel',(3.7,0,3.4),1.1)
s.asset('barrel',(-3.7,0,2.6),1)
s.ext('Lantern','PackedScene','scenes/assets/props/hand_lantern/Visual.tscn')
s.node('TableLantern',parent='Assets',instance='Lantern',props='position = Vector3(2.6,1.29,-2.3)\nscale = Vector3(1.3,1.3,1.3)')
s.node('WarmLight','OmniLight3D',props='position = Vector3(1.6,2.6,-1.5)\nlight_color = Color(1,.72,.40,1)\nlight_energy = 1.0\nomni_range = 7.0\nshadow_enabled = true')
s.ext('Keeper','PackedScene','scenes/actors/npcs/friendly/forest_keeper/Keeper.tscn');s.ext('Conversation','Resource','settings/dialogue/house_keeper.tres')
s.node('Linde',instance='Keeper',props='position = Vector3(-.5,0,-1.1)\nrotation_degrees = Vector3(0,180,0)')
s.nodes.append('[node name="Conversation" parent="Linde" index="2"]\nconversation = ExtResource("Conversation")\n')
s.spawn('Door',(0,0,3.0))
s.portal('Door',(0,0,4.7),'ForestPassage','HouseDoor',180,size=(2.7,3,1.2),door=True)
s.nodes.append('[editable path="Linde"]\n')
s.save('ForestHouse.tscn')
print('AUTHORED_CONNECTED_FOREST_AND_HOUSE')
