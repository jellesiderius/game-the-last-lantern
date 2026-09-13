"""Author wrappers and saved level instances. No environment mesh creation at game startup."""
import json,math,re
from pathlib import Path
from layout import placements,STUMP,POND,TERRACES,EXIT,PATH,PLAY_BOUNDS
ROOT=Path(__file__).resolve().parents[2]
assets=sorted(p.name for p in (ROOT/'assets/environment').glob('forest_*/source.blend') for p in [p.parent] if not p.name.endswith('_ground'))
for name in assets:
 folder=ROOT/'scenes/assets/environment'/name;folder.mkdir(parents=True,exist_ok=True)
 text=f'[gd_scene format=3]\n[ext_resource type="PackedScene" path="res://assets/environment/{name}/model.glb" id="Model"]\n'
 if name=='forest_butterfly':text+='[ext_resource type="Script" path="res://scripts/world/forest_butterfly.gd" id="Flight"]\n'
 text+=f'[node name="{name}" type="Node3D"]\n'
 if name=='forest_butterfly':text+='script = ExtResource("Flight")\n'
 text+='[node name="Model" parent="." instance=ExtResource("Model")]\n'
 folder.joinpath('Visual.tscn').write_text(text)
# Ground material override is authored into the wrapper, not a startup material swap.
ground=ROOT/'scenes/assets/environment/forest_ground';ground.mkdir(parents=True,exist_ok=True)
ground.joinpath('Visual.tscn').write_text('''[gd_scene format=3]
[ext_resource type="PackedScene" path="res://assets/environment/forest_ground/model.glb" id="Model"]
[ext_resource type="Shader" path="res://shaders/forest_ground.gdshader" id="Shader"]
[ext_resource type="Texture2D" path="res://assets/environment/forest_materials/atlas.png" id="Atlas"]
[sub_resource type="ShaderMaterial" id="Surface"]
shader = ExtResource("Shader")
shader_parameter/atlas = ExtResource("Atlas")
[node name="ForestGround" type="Node3D"]
[node name="Model" parent="." instance=ExtResource("Model")]
[node name="Ground" parent="Model" index="0"]
material_override = SubResource("Surface")
[editable path="Model"]
''')
exts={};res=[];nodes=[]
def ext(k,t,p):exts[k]=(t,p)
def sub(k,t,props):res.append(f'[sub_resource type="{t}" id="{k}"]\n{props}\n');return f'SubResource("{k}")'
def node(name,typ=None,parent='.',props='',instance=None):
 attrs=f'name="{name}"'+(f' type="{typ}"' if typ else '')+(f' parent="{parent}"' if parent else '')+(f' instance=ExtResource("{instance}")' if instance else '')
 nodes.append(f'[node {attrs}]\n{props}\n')
def xyz(v):return 'Vector3('+','.join(f'{x:.5f}' for x in v)+')'
def box(name,at,size,yaw=0):
 shape=sub(name+'Shape','BoxShape3D','size = '+xyz(size));node(name,'StaticBody3D','Collision',props='position = '+xyz(at)+'\nrotation_degrees = '+xyz((0,yaw,0)));node('Shape','CollisionShape3D','Collision/'+name,props='shape = '+shape)
def cylinder(name,at,radius,height):
 shape=sub(name+'Shape','CylinderShape3D',f'radius = {radius}\nheight = {height}');node(name,'StaticBody3D','Collision',props='position = '+xyz(at));node('Shape','CollisionShape3D','Collision/'+name,props='shape = '+shape)
for name in assets+['forest_ground']:ext(name,'PackedScene',f'scenes/assets/environment/{name}/Visual.tscn')
for k,t,p in [('World','Script','scripts/world/forest_opening.gd'),('Entrance','Resource','settings/forest_entrance.tres'),('Player','PackedScene','scenes/actors/player/Player.tscn'),('HUD','PackedScene','scenes/ui/HUD.tscn'),('Acorn','PackedScene','scenes/actors/npcs/enemy/AcornGuard.tscn'),('Spark','PackedScene','scenes/effects/ImpactSpark.tscn'),('Sound','AudioStream','assets/audio/impact.wav'),('Water','Shader','shaders/forest_water.gdshader'),('Lantern','PackedScene','scenes/assets/props/hand_lantern/Visual.tscn')]:ext(k,t,p)
ext('Portal','PackedScene','scenes/components/ScenePortal.tscn')
ext('Spawn','Script','scripts/world/scene_spawn_point.gd')
ext('Keeper','PackedScene','scenes/actors/npcs/friendly/forest_keeper/Keeper.tscn')
ext('Waymarker','PackedScene','scenes/assets/environment/ForestWaymarker.tscn')
node('ForestOpening','Node3D',parent=None,props='script = ExtResource("World")\nentrance_sequence = ExtResource("Entrance")\nspawn_position = Vector3(-3,0,7.4)\ncamera_min = Vector2(-10,-73)\ncamera_max = Vector2(12,7)')
node('Ground',instance='forest_ground');node('Assets','Node3D');node('Collision','Node3D')
xmin,xmax,zmin,zmax=PLAY_BOUNDS
box('Floor',((xmin+xmax)/2,-.6,(zmin+zmax)/2),(xmax-xmin,1.2,zmax-zmin))
items=placements()
for i,p in enumerate(items):
 name=p['asset']+'_'+str(i);s=p['scale']
 node(name,parent='Assets',instance=p['asset'],props='position = '+xyz((p['x'],p['y'],p['z']))+'\nrotation = '+xyz((0,math.radians(p['yaw']),0))+'\nscale = '+xyz((s,s,s)))
 if p['asset']=='forest_stump':cylinder('Stump',(p['x'],.60*s,p['z']),1.31*s,1.2*s)
 elif p['asset'] in ['forest_pine','forest_pine_b','forest_pine_c','forest_oak']:cylinder('Trunk'+str(i),(p['x'],p['y']+s*.85,p['z']),s*.28,s*1.7)
 # Cliff modules are covered by the connected terrace collision below.
 elif p['asset']=='forest_rocks':cylinder('Rock'+str(i),(p['x'],p['y']+s*.32,p['z']),s*.4,s*.64)
 elif p['asset']=='forest_hollow_log':box('Log'+str(i),(p['x'],p['y']+s*.34,p['z']),(s*2.2,s*.75,s*.72),p['yaw'])
 elif p['asset']=='forest_fence':box('Fence'+str(i),(p['x'],p['y']+s*.4,p['z']),(s*1.38,s*.80,s*.15),p['yaw'])
 elif p['asset']=='forest_gate':
  for sign in [-1,1]:cylinder('Gate'+('Left' if sign<0 else 'Right'),(p['x']+sign*1.4,1.3,p['z']),.17,2.6)
for terrace in TERRACES:
 points=[(x,y,z) for y in [-.10,terrace['height']] for x,z in terrace['polygon']]
 shape=sub(terrace['name']+'Shape','ConvexPolygonShape3D','points = PackedVector3Array('+','.join(str(c) for point in points for c in point)+')')
 node(terrace['name'],'StaticBody3D','Collision');node('Shape','CollisionShape3D','Collision/'+terrace['name'],props='shape = '+shape)
# A submerged world blocker keeps the opening pond decorative and nav routes on shore.
cylinder('PondBasin',(POND[0],.25,POND[1]),2.50,1.1)
node('Water','Node3D')
mat=sub('PondMaterial','ShaderMaterial','resource_local_to_scene = true\nshader = ExtResource("Water")')
fallmat=sub('FallMaterial','ShaderMaterial','resource_local_to_scene = true\nshader = ExtResource("Water")\nshader_parameter/waterfall = true')
watermesh=sub('PondMesh','CylinderMesh','top_radius = 2.85\nbottom_radius = 2.85\nheight = 0.03\nradial_segments = 48')
node('Pond','MeshInstance3D','Water',props=f'position = {xyz((POND[0],-.21,POND[1]))}\nscale = Vector3(1.12,1,1)\nmesh = {watermesh}\nmaterial_override = {mat}')
fallmesh=sub('WaterfallMesh','BoxMesh','size = Vector3(1.05, 1.02, .16)')
node('Waterfall','MeshInstance3D','Water',props=f'position = Vector3(-8.5,.30,-5.60)\nmesh = {fallmesh}\nmaterial_override = {fallmat}')
node('UpperCascade','MeshInstance3D','Water',props=f'position = Vector3(-8.5,1.31,-6.10)\nmesh = {fallmesh}\nmaterial_override = {fallmat}')
midmesh=sub('CascadePoolMesh','BoxMesh','size = Vector3(1.05,.035,.75)')
node('CascadePool','MeshInstance3D','Water',props=f'position = Vector3(-8.5,.815,-5.97)\nmesh = {midmesh}\nmaterial_override = {mat}')
foammat=sub('WaterFoam','StandardMaterial3D','transparency = 1\nalbedo_color = Color(.56,.78,.73,.45)\nroughness = .8\ncull_mode = 2')
foammesh=sub('FoamRing','TorusMesh','inner_radius = .46\nouter_radius = .49\nrings = 40\nring_segments = 6')
for i in range(3):
 node('Ripple'+str(i),'MeshInstance3D','Water',props=f'position = Vector3(-8.5,-.178,-5.4)\nscale = Vector3({.6+i*.38},.05,{.4+i*.24})\nmesh = {foammesh}\nmaterial_override = {foammat}\ncast_shadow = 0')
node('Butterflies','Node3D')
for i,(x,y,z) in enumerate([(-1.9,1.0,5.3),(-.8,1.25,4.7),(-1.0,.85,2.8)]):node('Butterfly'+str(i),parent='Butterflies',instance='forest_butterfly',props=f'position = {xyz((x,y,z))}\nphase = {i*1.63}\nflight_radius = 1.25')
node('GateLantern',parent='Assets',instance='Lantern',props='position = '+xyz((EXIT[0],1.92,EXIT[1]))+'\nscale = Vector3(1.3,1.3,1.3)')
node('LanternLight','OmniLight3D','Assets/GateLantern',props='light_color = Color(1,.58,.18,1)\nlight_energy = .5\nomni_range = 2.5')
node('ForestKeeper',instance='Keeper',props='position = Vector3(1,-0.0,-20.5)\nrotation_degrees = Vector3(0,-90,0)')
node('Waymarker',instance='Waymarker',props='position = Vector3(5.5,0,-22.5)')
node('Route','Node3D')
for i,(x,z) in enumerate(PATH[1:]):node('Point%02d'%i,'Marker3D','Route',props='position = '+xyz((x,0,z)))
node('ForestExit',instance='Portal',props='position = '+xyz((EXIT[0],0,EXIT[1]-1.8))+'\ntarget_scene = "res://scenes/levels/ForestPassage.tscn"\ntarget_spawn = &"SouthGate"\ntrigger_size = Vector3(6,3,2.6)')
node('SpawnNorthGate','Marker3D',props='position = '+xyz((EXIT[0],0,EXIT[1]-.6))+'\nrotation_degrees = Vector3(0,180,0)\nscript = ExtResource("Spawn")\nspawn_id = &"NorthGate"')
node('Player',instance='Player',props='position = Vector3(-3,1.565,4.72)')
node('AcornGuard',instance='Acorn',props='position = Vector3(4,0,-12)')
node('CameraRig','Node3D',props='transform = Transform3D(0.7071069,-0.54167527,0.4545192,0,0.64278734,0.7660447,-0.70710665,-0.54167545,0.45451936,-3,1.8,4.12)')
node('Camera3D','Camera3D','CameraRig',props='position = Vector3(0,0,30)\nprojection = 1\ncurrent = true\nsize = 13.0\nfar = 120.0')
node('Sun','DirectionalLight3D',props='rotation_degrees = Vector3(-55,-32,0)\nlight_color = Color(1,.88,.68,1)\nlight_energy = 1.05\nlight_angular_distance = 0.0\nshadow_blur = 3.0\nshadow_opacity = .85\nshadow_enabled = true\nshadow_bias = .03\ndirectional_shadow_max_distance = 70.0')
node('Fill','DirectionalLight3D',props='rotation_degrees = Vector3(-42,145,0)\nlight_color = Color(.65,.81,1,1)\nlight_energy = .18')
env=sub('Environment','Environment','background_mode = 1\nbackground_color = Color(.11,.19,.18,1)\nambient_light_source = 2\nambient_light_color = Color(.56,.69,.63,1)\nambient_light_energy = .55\nreflected_light_source = 2\ntonemap_mode = 4\ntonemap_exposure = 1.3\nssao_enabled = true\nssao_radius = .4\nssao_intensity = 0.7\nssil_enabled = false\nssil_intensity = .45\nglow_enabled = true\nglow_intensity = .35\nglow_bloom = 0.0\nfog_enabled = true\nfog_light_color = Color(.22,.32,.29,1)\nfog_density = .0018')
node('WorldEnvironment','WorldEnvironment',props='environment = '+env)
node('HUD',instance='HUD');node('DebugVolumes','MeshInstance3D');node('ImpactPool','Node3D')
for i in range(4):node('Spark'+str(i),parent='ImpactPool',instance='Spark')
node('ImpactSound','AudioStreamPlayer3D',props='stream = ExtResource("Sound")\nvolume_db = -8.0\nmax_distance = 30.0')
text='[gd_scene format=3]\n'+''.join(f'[ext_resource type="{t}" path="res://{p}" id="{k}"]\n' for k,(t,p) in exts.items())+'\n'+'\n'.join(res)+'\n'.join(nodes)
text=re.sub(r'(?<![0-9])\.(?=[0-9])','0.',text)
# Preserve the user's editor-added butterfly group and second guard.
text += '\n'+(ROOT/'tools/forest/authored_details.tscn.inc').read_text()
(ROOT/'scenes/levels/ForestOpening.tscn').write_text(text)
(ROOT/'assets/environment/forest_layout.json').write_text(json.dumps(items,indent=2))
print('FOREST_LEVEL_AUTHORED',len(items),'saved asset instances')
