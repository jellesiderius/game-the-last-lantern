"""Blender authoring: extend the approved four-step design without scaling its treads.

Run in the current kit source through Blender MCP. Creates a new asset only.
Review first; export is deliberately separate. Local +Y is the low end, Z is up.
"""
import bpy
import sys
from pathlib import Path

ROOT = Path('/Users/jelle/Godot-Projects/crow-test')
sys.path.insert(0, str(ROOT / 'tools'))
from asset_geometry import activate, mesh_object

ASSET = 'long_stairs'
assert not bpy.data.collections.get('Village_' + ASSET), 'Inspect existing source before rebuilding.'
source = bpy.data.scenes['Asset_stone_stairs']
scene = bpy.data.scenes.new('Asset_' + ASSET)
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
collection = bpy.data.collections.new('Village_' + ASSET)
scene.collection.children.link(collection)

# Preserve the exact tread/riser profiles, bevels and materials of the approved short stair.
for i in range(16):
    for prefix in ['Tread', 'Riser']:
        template = source.objects[prefix + '_0']
        obj = template.copy()
        obj.data = template.data.copy()
        obj.name = f'Long_{prefix}_{i + 1:02d}'
        obj.location.y += 3.0 - i * .5
        obj.location.z += i * .25
        collection.objects.link(obj)

# A single opaque staircase core: no stacked blocks, internal faces or grass poking through.
outline = [(4.0, -.03)]
for i in range(16):
    y = 4.0 - i * .5
    h = (i + 1) * .25 - .09
    outline.extend([(y, h), (y - .5, h)])
outline.append((-4.0, -.03))
n = len(outline)
vertices = [(x, y, z) for x in [-.99, .99] for y, z in outline]
faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
faces += [(i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n)]
core = mesh_object('Long_Continuous_Core', vertices, faces, collection, bpy.data.materials['Village_Rock'])
activate(core)
for face in core.data.polygons:
    face.use_smooth = False
bevel = core.modifiers.new('Crafted edges', 'BEVEL')
bevel.width = .012
bevel.segments = 2
bpy.ops.object.modifier_apply(modifier=bevel.name)
normal = core.modifiers.new('Weighted normals', 'WEIGHTED_NORMAL')
normal.keep_sharp = True
bpy.ops.object.modifier_apply(modifier=normal.name)

destination = ROOT / 'assets/environment' / ASSET
destination.mkdir(parents=True, exist_ok=True)
bpy.context.view_layer.update()
bpy.data.libraries.write(str(destination / 'source.blend'), {scene}, fake_user=True)
result = {'asset': ASSET, 'steps': 16, 'rise': 4.0, 'run': 8.0, 'width': 2.0,
          'source': str(destination / 'source.blend'), 'objects': len(collection.objects)}
