"""Export the current reviewed source, never regenerate character geometry."""
import sys, bpy
from pathlib import Path
root=Path(bpy.data.filepath).resolve().parents[3]
sys.path.insert(0,str(root/'tools'))
from asset_export import export_character
result=export_character('red_panda','RedPanda_Rig','RedPanda_Character')
