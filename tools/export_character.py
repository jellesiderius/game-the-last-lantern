"""Export the current edited crow through the shared Blender exporter."""
import bpy, sys
from pathlib import Path
ROOT = next(parent for parent in Path(bpy.data.filepath).parents if (parent / 'project.godot').is_file())
if str(ROOT / 'tools') not in sys.path:
    sys.path.insert(0, str(ROOT / 'tools'))
from asset_export import export_character
bpy.context.window.scene = bpy.data.scenes['Crow_Production']
result = export_character('crow', 'Crow_Rig', 'Crow_Character')
