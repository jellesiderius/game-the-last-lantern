"""Offline scene authoring for the reusable threshold and its small example dungeon."""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parents[2]


def write(path, text):
    destination = ROOT / path
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text.strip() + "\n")


write("settings/transitions/dungeon.tres", '''
[gd_resource type="Resource" script_class="SceneTravelSettings" format=3]
[ext_resource type="Script" path="res://scripts/components/scene_travel_settings.gd" id="Script"]
[resource]
script = ExtResource("Script")
exit_walk_distance = 0.85
entry_walk_distance = 0.45
walk_speed = 2.6
fade_duration = 0.28
black_hold = 0.0
departure_fade_delay = 0.24
''')
write("settings/dungeons/forgotten_sanctum.tres", '''
[gd_resource type="Resource" script_class="DungeonDefinition" format=3]
[ext_resource type="Script" path="res://scripts/dungeons/dungeon_definition.gd" id="Script"]
[resource]
script = ExtResource("Script")
id = &"forgotten_sanctum"
display_name = "Vergeten heiligdom"
scene_path = "res://scenes/levels/ForgottenSanctum.tscn"
entrance = &"DungeonEntrance"
completion_loot = Dictionary[String, int]({"lantern_shard": 1})
''')
write("settings/areas/forgotten_sanctum.tres", '''
[gd_resource type="Resource" script_class="WorldArea" format=3]
[ext_resource type="Script" path="res://scripts/world/world_area.gd" id="Script"]
[resource]
script = ExtResource("Script")
code = &"dungeon.forgotten_sanctum"
display_name = "Vergeten heiligdom"
scene_path = "res://scenes/levels/ForgottenSanctum.tscn"
''')
write("scenes/assets/environment/threshold_gate/Visual.tscn", '''
[gd_scene format=3]
[ext_resource type="PackedScene" path="res://assets/environment/threshold_gate/model.glb" id="Model"]
[ext_resource type="Script" path="res://scripts/dungeons/threshold_visual.gd" id="Script"]
[ext_resource type="Shader" path="res://shaders/threshold_veil.gdshader" id="Veil"]
[sub_resource type="ShaderMaterial" id="VeilMaterial"]
resource_local_to_scene = true
shader = ExtResource("Veil")
[sub_resource type="QuadMesh" id="VeilMesh"]
size = Vector2(1.6, 2.47)
[sub_resource type="StandardMaterial3D" id="MoteMaterial"]
shading_mode = 0
transparency = 1
vertex_color_use_as_albedo = true
albedo_color = Color(1, 0.85, 0.38, 1)
emission_enabled = true
emission = Color(1, 0.58, 0.08, 1)
emission_energy_multiplier = 4.0
[sub_resource type="SphereMesh" id="MoteMesh"]
radius = 0.022
height = 0.044
radial_segments = 6
rings = 3
material = SubResource("MoteMaterial")
[sub_resource type="Gradient" id="MoteFade"]
offsets = PackedFloat32Array(0, 0.2, 0.8, 1)
colors = PackedColorArray(1,1,1,0, 1,1,1,1, 1,1,1,0.8, 1,1,1,0)
[node name="Visual" type="Node3D"]
script = ExtResource("Script")
[node name="Model" parent="." instance=ExtResource("Model")]
[node name="Veil" type="MeshInstance3D" parent="."]
position = Vector3(0,1.475,0)
cast_shadow = 0
mesh = SubResource("VeilMesh")
material_override = SubResource("VeilMaterial")
[node name="WarmLight" type="OmniLight3D" parent="."]
visible = false
position = Vector3(0,1.15,0.45)
light_color = Color(1,0.57,0.12,1)
light_energy = 1.35
omni_range = 3.4
shadow_enabled = true
[node name="CrownLight" type="OmniLight3D" parent="."]
visible = false
position = Vector3(0,3.10,0)
light_color = Color(1,0.62,0.16,1)
light_energy = 0.75
omni_range = 1.7
[node name="Motes" type="CPUParticles3D" parent="."]
visible = false
position = Vector3(0,1.15,0)
emitting = false
amount = 9
lifetime = 3.2
preprocess = 2.0
mesh = SubResource("MoteMesh")
emission_shape = 3
emission_box_extents = Vector3(0.61,0.85,0.05)
direction = Vector3(0,1,0)
spread = 7.0
gravity = Vector3(0,0.01,0)
initial_velocity_min = 0.15
initial_velocity_max = 0.32
scale_amount_min = 0.65
scale_amount_max = 1.2
color_ramp = SubResource("MoteFade")
''')

# Convex colliders cover only individual stones; never a convex hull of the whole arch.
shapes = []
shape_nodes = []


def convex(name, profile, depth):
    xyz = [(x, y, z) for z in [-depth/2, depth/2] for x, y in profile]
    values = ", ".join(f"{v:.6f}" for point in xyz for v in point)
    name = name.replace('-', 'Minus')
    shapes.append(f'[sub_resource type="ConvexPolygonShape3D" id="{name}"]\npoints = PackedVector3Array({values})')
    shape_nodes.append(f'[node name="{name}" type="CollisionShape3D" parent="StoneCollision"]\nshape = SubResource("{name}")')


for side in [-1, 1]:
    convex(f"Leg{side}", [(side*.82, .025), (side*1.47, .025), (side*1.34, 1.68), (side*.82, 1.68)], .57)
    for i in range(7):
        a, b = i*math.radians(84)/7, (i+1)*math.radians(84)/7
        profile = [(side*.82*math.cos(a), 1.71+1.02*math.sin(a)),
                   (side*1.34*math.cos(a), 1.71+1.43*math.sin(a)),
                   (side*1.34*math.cos(b), 1.71+1.43*math.sin(b)),
                   (side*.82*math.cos(b), 1.71+1.02*math.sin(b))]
        convex(f"Arch{side}_{i}", profile, .54)
# Ramp in local Z, with the same .23 m top as the visible step. Both approaches are smooth.
ramp_points = [(x, y, z) for x in [-1.10, 1.10] for y, z in [(0,-.94),(0,.94),(.23,.53),(.23,-.53)]]
values = ", ".join(str(v) for point in ramp_points for v in point)
shapes.append('[sub_resource type="ConvexPolygonShape3D" id="Ramp"]\npoints = PackedVector3Array(' + values + ')')
shape_nodes.append('[node name="Ramp" type="CollisionShape3D" parent="StoneCollision"]\nshape = SubResource("Ramp")')
collision_scene = '''[gd_scene format=3]
'''+"\n".join(shapes)+'''
[node name="StoneCollision" type="StaticBody3D"]
collision_layer = 1
collision_mask = 0
'''+"\n".join(s.replace('parent="StoneCollision"', 'parent="."') for s in shape_nodes)
write("scenes/assets/environment/threshold_gate/Collision.tscn", collision_scene)
write("scenes/world/dungeons/Drempelpoort.tscn", '''
[gd_scene format=3]
[ext_resource type="PackedScene" path="res://scenes/components/ScenePortal.tscn" id="Portal"]
[ext_resource type="PackedScene" path="res://scenes/assets/environment/threshold_gate/Visual.tscn" id="Visual"]
[ext_resource type="PackedScene" path="res://scenes/assets/environment/threshold_gate/Collision.tscn" id="Collision"]
[ext_resource type="Script" path="res://scripts/dungeons/threshold_gate.gd" id="Gate"]
[ext_resource type="Script" path="res://scripts/dungeons/gate_return_point.gd" id="Return"]
[ext_resource type="Resource" path="res://settings/transitions/dungeon.tres" id="Travel"]
[node name="Drempelpoort" instance=ExtResource("Portal")]
script = ExtResource("Gate")
trigger_size = Vector3(1.5,2.65,0.55)
settings = ExtResource("Travel")
allow_loading_screen = false
[node name="Visual" parent="." instance=ExtResource("Visual")]
[node name="StoneCollision" parent="." instance=ExtResource("Collision")]
[node name="ReturnPoint" type="Marker3D" parent="."]
position = Vector3(0,0,2.0)
rotation_degrees = Vector3(0,180,0)
script = ExtResource("Return")
''')
write("scenes/world/dungeons/DungeonExit.tscn", '''
[gd_scene format=3]
[ext_resource type="PackedScene" path="res://scenes/components/ScenePortal.tscn" id="Portal"]
[ext_resource type="PackedScene" path="res://scenes/assets/environment/threshold_gate/Visual.tscn" id="Visual"]
[ext_resource type="PackedScene" path="res://scenes/assets/environment/threshold_gate/Collision.tscn" id="Collision"]
[ext_resource type="Script" path="res://scripts/dungeons/dungeon_exit.gd" id="Exit"]
[ext_resource type="Resource" path="res://settings/transitions/dungeon.tres" id="Travel"]
[node name="DungeonExit" instance=ExtResource("Portal")]
script = ExtResource("Exit")
trigger_size = Vector3(1.5,2.65,0.55)
settings = ExtResource("Travel")
allow_loading_screen = false
[node name="Visual" parent="." instance=ExtResource("Visual")]
[node name="StoneCollision" parent="." instance=ExtResource("Collision")]
''')


def level(name, gallery=False):
    ext = '''[gd_scene format=3]
[ext_resource type="Script" path="res://scripts/dungeons/dungeon_room.gd" id="World"]
[ext_resource type="PackedScene" path="res://scenes/actors/player/Player.tscn" id="Player"]
[ext_resource type="PackedScene" path="res://scenes/ui/HUD.tscn" id="HUD"]
[ext_resource type="PackedScene" path="res://scenes/effects/ImpactSpark.tscn" id="Spark"]
[ext_resource type="AudioStream" path="res://assets/audio/impact.wav" id="Sound"]
[ext_resource type="PackedScene" path="res://scenes/world/dungeons/DungeonExit.tscn" id="Exit"]
[ext_resource type="PackedScene" path="res://scenes/world/dungeons/Drempelpoort.tscn" id="Gate"]
[ext_resource type="Script" path="res://scripts/world/scene_spawn_point.gd" id="Spawn"]
[ext_resource type="Resource" path="res://settings/dungeons/forgotten_sanctum.tres" id="Dungeon"]
[ext_resource type="PackedScene" path="res://scenes/actors/npcs/enemy/AcornGuard.tscn" id="Enemy"]
[sub_resource type="Environment" id="Environment"]
background_mode = 1
background_color = Color(0.045,0.066,0.068,1)
ambient_light_source = 2
ambient_light_color = Color(0.58,0.67,0.72,1)
ambient_light_energy = 0.65
tonemap_mode = 2
ssao_enabled = true
glow_enabled = true
glow_intensity = 0.75
reflected_light_source = 2
[sub_resource type="StandardMaterial3D" id="FloorMaterial"]
albedo_color = Color(0.28,0.32,0.32,1)
roughness = 0.91
[sub_resource type="StandardMaterial3D" id="WallMaterial"]
albedo_color = Color(0.22,0.28,0.30,1)
roughness = 0.88
[sub_resource type="BoxMesh" id="Foundation"]
size = Vector3(14,0.5,18)
[sub_resource type="BoxShape3D" id="FloorShape"]
size = Vector3(14,0.5,18)
[sub_resource type="BoxMesh" id="SideWall"]
size = Vector3(0.65,2.5,18)
[sub_resource type="BoxShape3D" id="SideShape"]
size = Vector3(0.65,2.5,18)
[sub_resource type="BoxMesh" id="EndWall"]
size = Vector3(14,2.5,0.65)
[sub_resource type="BoxShape3D" id="EndShape"]
size = Vector3(14,2.5,0.65)
[sub_resource type="BoxMesh" id="CutawayWall"]
size = Vector3(14,0.55,0.65)
[sub_resource type="CylinderMesh" id="Column"]
top_radius = 0.43
bottom_radius = 0.5
height = 2.25
radial_segments = 8
[sub_resource type="CylinderShape3D" id="ColumnShape"]
radius = 0.47
height = 2.25
'''
    nodes = f'''[node name="{name}" type="Node3D"]
script = ExtResource("World")
spawn_position = Vector3(0,0,4.7)
camera_min = Vector2(-2.5,-4.2)
camera_max = Vector2(2.5,4.3)
'''
    if not gallery:
        nodes += 'dungeon = ExtResource("Dungeon")\nrequired_enemies = Array[NodePath]([NodePath("Wachter1"),NodePath("Wachter2")])\n'
    nodes += '''[node name="Player" parent="." instance=ExtResource("Player")]
position = Vector3(0,0,4.7)
[node name="CameraRig" type="Node3D" parent="."]
transform = Transform3D(0.7071069,-0.54167527,0.4545192,0,0.64278734,0.7660447,-0.70710665,-0.54167545,0.45451936,0,0.65,4)
[node name="Camera3D" type="Camera3D" parent="CameraRig"]
position = Vector3(0,0,30)
projection = 1
current = true
size = 13.0
far = 120.0
[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-55,-32,0)
light_color = Color(1,0.88,0.7,1)
light_energy = 0.75
shadow_enabled = true
shadow_blur = 2.0
directional_shadow_max_distance = 70.0
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment")
[node name="HUD" parent="." instance=ExtResource("HUD")]
[node name="DebugVolumes" type="MeshInstance3D" parent="."]
[node name="ImpactPool" type="Node3D" parent="."]
'''
    for i in range(4):
        nodes += f'[node name="Spark{i}" parent="ImpactPool" instance=ExtResource("Spark")]\n'
    nodes += '''[node name="ImpactSound" type="AudioStreamPlayer3D" parent="."]
stream = ExtResource("Sound")
volume_db = -8.0
max_distance = 30.0
[node name="DungeonEntrance" type="Marker3D" parent="."]
position = Vector3(0,0,4.7)
script = ExtResource("Spawn")
spawn_id = &"DungeonEntrance"
'''
    for label, position, mesh_id, shape_id in [
        ("Floor", (0,-.25,0), "Foundation", "FloorShape"),
        ("WestWall", (-7,1.25,0), "SideWall", "SideShape"),
        ("EastWall", (7,1.25,0), "SideWall", "SideShape"),
        ("NorthWall", (0,1.25,-9), "EndWall", "EndShape"),
        ("SouthWall", (0,.275,9), "CutawayWall", "EndShape")]:
        vector = ','.join(map(str,position))
        nodes += f'''[node name="{label}" type="StaticBody3D" parent="."]
position = Vector3({vector})
[node name="Mesh" type="MeshInstance3D" parent="{label}"]
mesh = SubResource("{mesh_id}")
material_override = SubResource("{'FloorMaterial' if label == 'Floor' else 'WallMaterial'}")
[node name="Shape" type="CollisionShape3D" parent="{label}"]
shape = SubResource("{shape_id}")
'''
    if gallery:
        for i, x in enumerate([-3, 3]):
            nodes += f'''[node name="Poort{i+1}" parent="." instance=ExtResource("Gate")]
position = Vector3({x},0,-1)
dungeon = ExtResource("Dungeon")
gate_id = &"gate.gallery.{i+1}"
identity_scene = "res://scenes/levels/{name}.tscn"
'''
    else:
        nodes += '''[node name="Uitgang" parent="." instance=ExtResource("Exit")]
position = Vector3(0,0,6.5)
rotation_degrees = Vector3(0,180,0)
dungeon = ExtResource("Dungeon")
'''
        for i, (x,z) in enumerate([(-1.8,-1), (1.8,-3.0)]):
            nodes += f'''[node name="Wachter{i+1}" parent="." instance=ExtResource("Enemy")]
position = Vector3({x},0,{z})
respawn_rule = 1
persistent_id = &"dungeon.forgotten_sanctum.guard{i+1}"
'''
        for i,(x,z) in enumerate([(-5,-6),(5,-6),(-5,2),(5,2)]):
            nodes += f'''[node name="Column{i}" type="StaticBody3D" parent="."]
position = Vector3({x},1.125,{z})
[node name="Mesh" type="MeshInstance3D" parent="Column{i}"]
mesh = SubResource("Column")
material_override = SubResource("WallMaterial")
[node name="Shape" type="CollisionShape3D" parent="Column{i}"]
shape = SubResource("ColumnShape")
[node name="Lamp" type="OmniLight3D" parent="Column{i}"]
position = Vector3(0,1.2,0)
light_color = Color(1,0.65,0.25,1)
light_energy = 0.8
omni_range = 4.0
'''
    write(f"scenes/levels/{name}.tscn", ext + nodes)


level("ForgottenSanctum")
level("DrempelpoortGallery", True)
# A second independent example dungeon. Never write ForestOpening or ForestPassage here.
for path in ["settings/dungeons/forgotten_sanctum.tres", "settings/areas/forgotten_sanctum.tres", "scenes/levels/ForgottenSanctum.tscn"]:
    text = (ROOT / path).read_text().replace("forgotten_sanctum", "root_cellar").replace("ForgottenSanctum", "RootCellar").replace("Vergeten heiligdom", "Wortelkelder")
    text = text.replace("Color(0.28,0.32,0.32,1)", "Color(0.31,0.30,0.23,1)").replace("Color(0.22,0.28,0.30,1)", "Color(0.27,0.28,0.20,1)")
    write(path.replace("forgotten_sanctum", "root_cellar").replace("ForgottenSanctum", "RootCellar"), text)
print("THRESHOLD_SCENES_AUTHORED")
