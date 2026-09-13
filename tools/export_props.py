"""Export source prop collections from the active scene, excluding other scenes."""
import bpy, os
from pathlib import Path
ROOT=str(next(parent for parent in Path(bpy.data.filepath).parents if (parent / 'project.godot').is_file()))
exports={'Sword_Export':'weapons/rose_sword/model.glb','Ground_Export':'environment/stone_floor/model.glb','LowWall_Export':'environment/low_wall/model.glb','Bow_Export':'weapons/arc_bow/model.glb','Arrow_Export':'weapons/magic_arrow/model.glb'}
done=[]
for name,filename in exports.items():
    c=bpy.data.collections.get(name)
    if not c:continue
    hidden=c.hide_viewport;c.hide_viewport=False
    for o in bpy.data.objects:o.select_set(False)
    for o in c.objects:o.select_set(True)
    bpy.context.view_layer.objects.active=list(c.objects)[0]
    bpy.ops.export_scene.gltf(filepath=ROOT+'/assets/'+filename,export_format='GLB',use_selection=True,use_active_scene=True,export_yup=True,export_animations=False)
    c.hide_viewport=hidden;done.append(filename)
result={'exports':done}
