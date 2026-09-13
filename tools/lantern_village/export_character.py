import bpy,sys
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_export import export_character
bpy.context.window.scene=bpy.data.scenes['LanternPanda_Production']
result=export_character('red_panda','LanternPanda_Rig','LanternPanda_Character')
