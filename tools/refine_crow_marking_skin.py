"""Transfer the underlying body's barycentric skin weights to thin cream patches.

The old independent height formula disagreed with the body's authored weights when
the torso leaned. Preserve the body, patch outlines, rig and Actions; align only
the patch skin with its actual supporting triangles. Run on the saved crow source.
"""
import bpy
from pathlib import Path
from mathutils.bvhtree import BVHTree

ROOT = next(p for p in Path(bpy.data.filepath).parents if (p / 'project.godot').is_file())
rig = bpy.data.objects['Crow_Rig']
body = bpy.data.objects['Crow_Body']
patches = [bpy.data.objects[n] for n in ('Cream_Breast_Feathers', 'Cream_Neck_-1', 'Cream_Neck_1')]
checkpoint = ROOT / 'assets/characters/crow/checkpoints/before_marking_skin_transfer.blend'
if not checkpoint.exists():
    bpy.ops.wm.save_as_mainfile(filepath=str(checkpoint), copy=True)
body.data.calc_loop_triangles()
triangles = [t.vertices[:] for t in body.data.loop_triangles]
tree = BVHTree.FromPolygons([v.co for v in body.data.vertices], triangles, all_triangles=True)


def barycentric(p, a, b, c):
    u, v, q = b-a, c-a, p-a
    uu, uv, vv = u.dot(u), u.dot(v), v.dot(v)
    qu, qv = q.dot(u), q.dot(v)
    denominator = uu*vv-uv*uv
    if abs(denominator) < 1e-18:
        return (1., 0., 0.)
    y = (vv*qu-uv*qv)/denominator
    z = (uu*qv-uv*qu)/denominator
    values = [max(0., 1-y-z), max(0., y), max(0., z)]
    return [w/sum(values) for w in values]


result = {}
for patch in patches:
    assert max(abs(v) for row in (patch.matrix_world - body.matrix_world) for v in row) < 1e-6, 'Expected shared mesh coordinates.'
    patch.vertex_groups.clear()
    groups = {g.name: patch.vertex_groups.new(name=g.name) for g in body.vertex_groups}
    greatest_shift = 0.
    for vertex in patch.data.vertices:
        point, normal, face, distance = tree.find_nearest(vertex.co)
        assert distance < .012, 'Patch no longer lies near the intended body.'
        ids = triangles[face]
        coefficients = barycentric(point, *(body.data.vertices[i].co for i in ids))
        weights = {}
        for index, coefficient in zip(ids, coefficients):
            for group in body.data.vertices[index].groups:
                name = body.vertex_groups[group.group].name
                weights[name] = weights.get(name, 0.) + coefficient * group.weight
        chosen = sorted(weights.items(), key=lambda item: -item[1])[:4]
        total = sum(w for _, w in chosen)
        for name, weight in chosen:
            if weight > 1e-7:
                groups[name].add([vertex.index], weight/total, 'REPLACE')
        # A sub-millimetre margin beyond the old offset avoids raster overlap.
        destination = point + normal * .003
        greatest_shift = max(greatest_shift, (destination-vertex.co).length)
        vertex.co = destination
    patch.data.update()
    patch['skin_contract'] = 'Body triangle barycentric weights; 3 mm surface separation.'
    result[patch.name] = {'max_surface_adjustment_m': greatest_shift}
rig.animation_data.action = bpy.data.actions['idle']
bpy.context.scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'assets/characters/crow/source.blend'))
