"""Blender: export the current, unchanged character in rest pose for Cascadeur."""
import json
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/characters/red_panda/cascadeur"
scene = bpy.data.scenes["LanternPanda_Production"]
bpy.context.window.scene = scene
rig = bpy.data.objects["LanternPanda_Rig"]
collection = bpy.data.collections["LanternPanda_Character"]
assert bpy.data.filepath == str(ROOT / "assets/characters/red_panda/source.blend")
OUT.mkdir(parents=True, exist_ok=True)
rest = {b.name: {"matrix": [list(row) for row in b.matrix_local],
                 "parent": b.parent.name if b.parent else None,
                 "length": b.length} for b in rig.data.bones}
(OUT / "skeleton.json").write_text(json.dumps(rest, indent=2))
rig.animation_data.action = None
rig.data.pose_position = "REST"
for obj in bpy.data.objects:
    obj.select_set(False)
for obj in collection.all_objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=str(OUT / "red_panda_rest.fbx"), use_selection=True,
    object_types={"ARMATURE", "MESH"}, add_leaf_bones=False,
    bake_anim=False, axis_forward="-Z", axis_up="Y",
    use_armature_deform_only=False, mesh_smooth_type="FACE",
)
# Render the actual saved source, without saving any exchange/review changes to it.
rig.data.pose_position = "POSE"
rig.animation_data.action = bpy.data.actions["walk"]
rig.animation_data.action_slot = rig.animation_data.action.slots[0]
scene.frame_set(20)
REVIEW_LABEL = "cascadeur_walk_before"
exec((ROOT / "tools/lantern_village/review_blender.py").read_text())
