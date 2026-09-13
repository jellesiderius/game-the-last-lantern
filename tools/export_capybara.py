"""Export the current edited capybara through the shared Blender exporter."""
import bpy, sys
from pathlib import Path
ROOT = next(parent for parent in Path(bpy.data.filepath).parents if (parent / 'project.godot').is_file())
if str(ROOT / 'tools') not in sys.path:
    sys.path.insert(0, str(ROOT / 'tools'))
from asset_export import export_character
bpy.context.window.scene = bpy.data.scenes['Capybara_Production']
result = export_character('capybara', 'Capybara_Rig', 'Capybara_Character')
