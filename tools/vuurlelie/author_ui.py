"""Offline authoring of saved shared menu scenes; no runtime layout/mesh generation."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
def save(path,txt):
 p=ROOT/path;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(txt)
full='anchors_preset = 15\nanchor_right = 1.0\nanchor_bottom = 1.0\ngrow_horizontal = 2\ngrow_vertical = 2\n'
font='[ext_resource type="FontFile" path="res://assets/ui/fonts/EBGaramond.ttf" id="Font"]\n'
save('settings/ui/lantern_menu.tres','''[gd_resource type="Theme" format=3]
'''+font+'''
[sub_resource type="StyleBoxFlat" id="Normal"]
bg_color = Color(0.025, 0.105, 0.12, 0.96)
border_width_bottom = 1
border_color = Color(0.33,0.41,0.36,0.4)
content_margin_left = 22.0
content_margin_right = 22.0
content_margin_top = 12.0
content_margin_bottom = 12.0
corner_radius_top_left = 5
corner_radius_top_right = 5
corner_radius_bottom_left = 5
corner_radius_bottom_right = 5
[sub_resource type="StyleBoxFlat" id="Focus"]
bg_color = Color(0.075,0.20,0.21,1)
border_width_left = 3
border_width_top = 1
border_width_right = 1
border_width_bottom = 1
border_color = Color(0.82,0.62,0.30,0.85)
content_margin_left = 22.0
content_margin_right = 22.0
content_margin_top = 12.0
content_margin_bottom = 12.0
corner_radius_top_left = 5
corner_radius_top_right = 5
corner_radius_bottom_left = 5
corner_radius_bottom_right = 5
[sub_resource type="StyleBoxFlat" id="Panel"]
bg_color = Color(0.012,0.075,0.087,0.96)
border_width_left = 1
border_width_right = 1
border_width_top = 1
border_width_bottom = 1
border_color = Color(0.53,0.43,0.25,0.45)
corner_radius_top_left = 9
corner_radius_top_right = 9
corner_radius_bottom_left = 9
corner_radius_bottom_right = 9
shadow_color = Color(0,0,0,0.24)
shadow_size = 18
[resource]
default_font = ExtResource("Font")
default_font_size = 28
Button/colors/font_color = Color(0.90,0.85,0.73,1)
Button/colors/font_hover_color = Color(1,0.87,0.6,1)
Button/colors/font_focus_color = Color(1,0.87,0.6,1)
Button/colors/font_pressed_color = Color(1,0.77,0.35,1)
Button/styles/normal = SubResource("Normal")
Button/styles/disabled = SubResource("Normal")
Button/colors/font_disabled_color = Color(0.90,0.85,0.73,1)
Button/styles/focus = SubResource("Focus")
Button/styles/hover = SubResource("Focus")
Button/styles/pressed = SubResource("Focus")
PanelContainer/styles/panel = SubResource("Panel")
Label/colors/font_color = Color(0.94,0.88,0.73,1)
''')
theme='[ext_resource type="Theme" path="res://settings/ui/lantern_menu.tres" id="Theme"]\n'
save('scenes/ui/RestMenuButton.tscn','''[gd_scene format=3]
[node name="Option" type="Button"]
custom_minimum_size = Vector2(0,62)
alignment = 0
mouse_default_cursor_shape = 2
''')
for id,label in [('rest','Rusten'),('continue','Verdergaan')]:
 save('settings/rest/'+id+'.tres',f'''[gd_resource type="Resource" script_class="RestMenuOption" format=3]
[ext_resource type="Script" path="res://scripts/ui/rest_menu_option.gd" id="Script"]
[resource]
script = ExtResource("Script")
id = &"{id}"
label = "{label}"
''')
save('scenes/ui/RestMenu.tscn','''[gd_scene format=3]
'''+theme+'''[ext_resource type="Script" path="res://scripts/ui/rest_menu.gd" id="Script"]
[ext_resource type="Script" path="res://scripts/ui/rest_menu_option.gd" id="Option"]
[ext_resource type="Resource" path="res://settings/rest/rest.tres" id="Rest"]
[ext_resource type="Resource" path="res://settings/rest/continue.tres" id="Continue"]
[node name="RestMenu" type="Control"]
'''+full+'''theme = ExtResource("Theme")
script = ExtResource("Script")
options = Array[ExtResource("Option")]([ExtResource("Rest"),ExtResource("Continue")])
[node name="Dim" type="ColorRect" parent="."]
'''+full+'''color = Color(0.004,0.025,0.026,0.3)
[node name="Panel" type="PanelContainer" parent="."]
offset_right = 430.0
offset_bottom = 470.0
[node name="Margin" type="MarginContainer" parent="Panel"]
theme_override_constants/margin_left = 34
theme_override_constants/margin_right = 34
theme_override_constants/margin_top = 32
theme_override_constants/margin_bottom = 26
[node name="Column" type="VBoxContainer" parent="Panel/Margin"]
theme_override_constants/separation = 12
[node name="Title" type="Label" parent="Panel/Margin/Column"]
theme_override_font_sizes/font_size = 47
text = "Vuurlelie"
[node name="Location" type="Label" parent="Panel/Margin/Column"]
theme_override_font_sizes/font_size = 22
modulate = Color(0.76,0.83,0.77,1)
text = "Onbekende locatie"
autowrap_mode = 2
[node name="Rule" type="ColorRect" parent="Panel/Margin/Column"]
custom_minimum_size = Vector2(0,1)
color = Color(0.79,0.61,0.30,0.55)
[node name="Space" type="Control" parent="Panel/Margin/Column"]
custom_minimum_size = Vector2(0,12)
[node name="Options" type="VBoxContainer" parent="Panel/Margin/Column"]
theme_override_constants/separation = 9
[node name="Status" type="Label" parent="Panel/Margin/Column"]
custom_minimum_size = Vector2(350,78)
max_lines_visible = 3
text_overrun_behavior = 3
theme_override_font_sizes/font_size = 21
autowrap_mode = 2
text = ""
''')
save('scenes/world/checkpoints/CheckpointService.tscn','''[gd_scene format=3]
[ext_resource type="Script" path="res://scripts/core/checkpoints.gd" id="Script"]
[ext_resource type="PackedScene" path="res://scenes/ui/RestMenu.tscn" id="Menu"]
[node name="Checkpoints" type="Node"]
script = ExtResource("Script")
[node name="UI" type="CanvasLayer" parent="."]
layer = 40
[node name="RestMenu" parent="UI" instance=ExtResource("Menu")]
''')
text='''[gd_scene format=3]
'''+theme+'''[ext_resource type="Script" path="res://scripts/ui/save_slot_menu.gd" id="Script"]
[node name="SaveSlots" type="Control"]
'''+full+'''theme = ExtResource("Theme")
script = ExtResource("Script")
[node name="Backdrop" type="ColorRect" parent="."]
'''+full+'''color = Color(0.006,0.037,0.045,0.96)
[node name="Composition" type="Control" parent="."]
offset_right = 1280.0
offset_bottom = 800.0
mouse_filter = 2
[node name="Brand" type="Label" parent="Composition"]
offset_left = 180.0
offset_top = 52.0
offset_right = 1100.0
offset_bottom = 87.0
text = "T H E   L A S T   L A N T E R N"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 22
modulate = Color(0.85,0.73,0.49,1)
[node name="Title" type="Label" parent="Composition"]
offset_left = 180.0
offset_top = 98.0
offset_right = 1100.0
offset_bottom = 160.0
text = "Jouw avontuur"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 50
[node name="Rule" type="ColorRect" parent="Composition"]
offset_left = 460.0
offset_top = 182.0
offset_right = 820.0
offset_bottom = 183.0
color = Color(0.78,0.61,0.31,0.65)
[node name="Slots" type="VBoxContainer" parent="Composition"]
offset_left = 180.0
offset_top = 215.0
offset_right = 1100.0
offset_bottom = 605.0
theme_override_constants/separation = 15
'''
for i in range(3):
 parent=f'Composition/Slots/Slot{i+1}'
 text+=f'''[node name="Slot{i+1}" type="Control" parent="Composition/Slots"]
custom_minimum_size = Vector2(920,116)
mouse_filter = 2
[node name="Select" type="Button" parent="{parent}"]
offset_right = 780.0
offset_bottom = 116.0
mouse_default_cursor_shape = 2
'''
 for name,x,y,w,h,size,content in [('Slot',24,8,340,35,28,f'Spel {i+1}'),('Location',24,42,530,33,26,'Nieuw spel'),('Details',24,80,640,28,20,'Een nieuw avontuur begint hier'),('State',540,15,218,25,18,'Leeg slot')]:
  text+=f'''[node name="{name}" type="Label" parent="{parent}/Select"]
offset_left = {float(x)}
offset_top = {float(y)}
offset_right = {float(x+w)}
offset_bottom = {float(y+h)}
theme_override_font_sizes/font_size = {size}
text = "{content}"
mouse_filter = 2
clip_text = true
'''
  if name in ('Details','State'):text+='modulate = Color(0.69,0.78,0.71,1)\n'
 text+=f'''[node name="Delete" type="Button" parent="{parent}"]
offset_left = 795.0
offset_top = 33.0
offset_right = 920.0
offset_bottom = 83.0
text = "Verwijderen"
theme_override_font_sizes/font_size = 20
mouse_default_cursor_shape = 2
'''
text+='''[node name="Status" type="Label" parent="Composition"]
offset_left = 180.0
offset_top = 624.0
offset_right = 1100.0
offset_bottom = 673.0
theme_override_font_sizes/font_size = 22
horizontal_alignment = 1
autowrap_mode = 2
[node name="Back" type="Button" parent="Composition"]
offset_left = 540.0
offset_top = 704.0
offset_right = 740.0
offset_bottom = 754.0
text = "Terug"
[node name="Confirm" type="Control" parent="."]
visible = false
'''+full+'''[node name="Dim" type="ColorRect" parent="Confirm"]
'''+full+'''color = Color(0.0,0.012,0.016,0.86)
[node name="Panel" type="PanelContainer" parent="Confirm"]
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -310.0
offset_top = -150.0
offset_right = 310.0
offset_bottom = 150.0
[node name="Column" type="VBoxContainer" parent="Confirm/Panel"]
theme_override_constants/separation = 14
[node name="Message" type="Label" parent="Confirm/Panel/Column"]
custom_minimum_size = Vector2(620,120)
horizontal_alignment = 1
vertical_alignment = 1
autowrap_mode = 2
theme_override_font_sizes/font_size = 29
[node name="Cancel" type="Button" parent="Confirm/Panel/Column"]
text = "Behouden"
[node name="Delete" type="Button" parent="Confirm/Panel/Column"]
text = "Spel definitief verwijderen"
'''
save('scenes/ui/SaveSlotMenu.tscn',text)
