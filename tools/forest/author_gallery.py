"""Saved, independently startable forest asset gallery and native close-up review scene."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
assets=sorted(p.parent.name for p in (ROOT/'scenes/assets/environment').glob('forest_*/Visual.tscn') if p.parent.name not in ['forest_ground','forest_terraces'])
lines=['[gd_scene format=3]','[ext_resource type="Script" path="res://tests/forest_asset_review.gd" id="Review"]']
for name in assets:lines.append(f'[ext_resource type="PackedScene" path="res://scenes/assets/environment/{name}/Visual.tscn" id="{name}"]')
lines+=['''[sub_resource type="StandardMaterial3D" id="FloorMaterial"]
albedo_color = Color(0.78,0.74,0.65,1)
roughness = 0.9
[sub_resource type="PlaneMesh" id="FloorMesh"]
size = Vector2(60,60)
material = SubResource("FloorMaterial")
[sub_resource type="Environment" id="Environment"]
background_mode = 1
background_color = Color(0.78,0.74,0.65,1)
ambient_light_source = 2
ambient_light_color = Color(0.75,0.79,0.77,1)
ambient_light_energy = 0.75
tonemap_mode = 4
ssao_enabled = true
ssao_radius = 0.3
ssao_intensity = 0.7
[node name="ForestAssetGallery" type="Node3D"]
script = ExtResource("Review")
[node name="Assets" type="Node3D" parent="."]''']
for i,name in enumerate(assets):lines.append(f'[node name="{name}" parent="Assets" instance=ExtResource("{name}")]\nposition = Vector3({(i%5)*5-10},{0.2 if 'tile_' in name else 0},{(i//5)*5-10})')
lines+=['''[node name="Floor" type="MeshInstance3D" parent="."]
position = Vector3(0,-0.005,0)
mesh = SubResource("FloorMesh")
[node name="Camera3D" type="Camera3D" parent="."]
position = Vector3(19,29,24)
rotation_degrees = Vector3(-50,38,0)
projection = 1
current = true
size = 31.0
[node name="Sun" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-48,-35,0)
light_color = Color(1,0.93,0.81,1)
light_energy = 0.8
shadow_enabled = true
light_angular_distance = 0.8
[node name="Fill" type="DirectionalLight3D" parent="."]
rotation_degrees = Vector3(-30,140,0)
light_color = Color(0.77,0.83,1,1)
light_energy = 0.22
[node name="WorldEnvironment" type="WorldEnvironment" parent="."]
environment = SubResource("Environment")''']
(ROOT/'scenes/levels/ForestAssetGallery.tscn').write_text('\n\n'.join(lines)+'\n')
