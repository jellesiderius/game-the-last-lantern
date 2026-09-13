"""Shared Blender export implementation for authored character sources.
Load from a saved source inside the project. Meshes, weights and existing Actions are preserved.
"""
from pathlib import Path
import bpy


def project_root():
    candidates = [Path(__file__).resolve(), Path(bpy.data.filepath).resolve()]
    for candidate in candidates:
        for parent in candidate.parents:
            if (parent / 'project.godot').is_file():
                return parent
    raise RuntimeError('Open a saved source inside the Godot project before exporting.')


def export_character(character_id, rig_name, collection_name):
    root = project_root()
    rig = bpy.data.objects[rig_name]
    collection = bpy.data.collections[collection_name]
    assert rig in list(collection.all_objects), 'Rig must belong to the export collection.'
    assert rig.type == 'ARMATURE' and rig.animation_data, 'Expected an authored animated rig.'
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    rig.animation_data.action = bpy.data.actions['idle']
    bpy.context.scene.frame_set(0)
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in collection.all_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    destination = root / 'assets/characters' / character_id
    assert destination.is_dir(), 'Create and review the character folder before exporting.'
    bpy.ops.wm.save_as_mainfile(filepath=str(destination / 'source.blend'))
    bpy.ops.export_scene.gltf(
        filepath=str(destination / 'model.glb'), export_format='GLB',
        use_selection=True, use_active_scene=True, export_yup=True,
        export_animations=True, export_animation_mode='ACTIONS',
        export_merge_animation='NONE', export_frame_range=False,
        export_force_sampling=True, export_anim_slide_to_zero=True,
        export_skins=True, export_def_bones=False, export_rest_position_armature=True,
    )
    return {'source':str(destination / 'source.blend'), 'model':str(destination / 'model.glb'),
            'actions':[action.name for action in bpy.data.actions]}
