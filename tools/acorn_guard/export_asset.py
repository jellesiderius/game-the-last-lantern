"""Export only the reviewed acorn source and its separate wooden club."""
import bpy
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'tools'))
from asset_export import export_character
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/characters/acorn_guard/source.blend'))
bpy.context.window.scene = bpy.data.scenes['AcornGuard_Production']
print(export_character('acorn_guard','AcornGuard_Rig','AcornGuard_Character'))
bpy.context.window.scene = bpy.data.scenes['WoodenClub_Production']
for obj in bpy.context.view_layer.objects:obj.select_set(False)
for obj in bpy.data.collections['WoodenClub_Asset'].all_objects:obj.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/weapons/wooden_club/model.glb'),
    export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False)
