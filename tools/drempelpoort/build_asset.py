"""Author the editable stone threshold. Review source renders before --export.
Blender --background --python tools/drempelpoort/build_asset.py [-- --export]
"""
import bpy
import math
import shutil
import sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "assets/environment/threshold_gate"
CAP = ROOT / "captures/drempelpoort/source"
DEST.mkdir(parents=True, exist_ok=True)
CAP.mkdir(parents=True, exist_ok=True)
if "--export" in sys.argv:
    bpy.ops.wm.open_mainfile(filepath=str(DEST / "source.blend"))
    for obj in bpy.data.objects:
        obj.select_set(False)
    for obj in bpy.data.collections["ThresholdGate"].all_objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(DEST / "model.glb"), export_format="GLB",
                              use_selection=True, use_active_scene=True,
                              export_animations=False, export_yup=True)
    print("THRESHOLD_GATE_EXPORTED")
    sys.exit()
if (DEST / "source.blend").exists():
    backup = DEST / "checkpoints/before_rebuild.blend"
    backup.parent.mkdir(exist_ok=True)
    if not backup.exists():
        shutil.copy2(DEST / "source.blend", backup)
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.name = "ThresholdGate_Production"
asset = bpy.data.collections.new("ThresholdGate")
review = bpy.data.collections.new("Review")
scene.collection.children.link(asset)
scene.collection.children.link(review)


def rgb(h):
    values = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return [v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in values]


def material(name, color, roughness=.78, metal=.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*rgb(color), 1)
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = mat.diffuse_color
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metal
    return mat


stone = material("GateStone", "626b71")
bevel = material("GateBevel", "758087")
rim = material("GateInnerRim", "899192", .42, .15)
crystal = material("GateCrystal", "929a9e", .28, .12)


def move_to(ob, collection):
    for c in list(ob.users_collection):
        c.objects.unlink(ob)
    collection.objects.link(ob)


def mesh(name, verts, faces, mat, bevel_width=.04):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    ob = bpy.data.objects.new(name, data)
    asset.objects.link(ob)
    data.materials.append(mat)
    if bevel_width:
        data.materials.append(bevel)
        mod = ob.modifiers.new("Carved soft edges", "BEVEL")
        mod.width = bevel_width
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = .38
        mod.material = 1
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        ob.select_set(False)
    return ob


def extrude(name, profile, depth, mat, bevel_width=.04):
    n = len(profile)
    verts = [(x, y, z) for y in [-depth/2, depth/2] for x, z in profile]
    faces = [tuple(reversed(range(n))), tuple(n+i for i in range(n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    return mesh(name, verts, faces, mat, bevel_width)


for side in [-1, 1]:
    # Broad lower feet taper up to the separate curved arch stones.
    profile = [(side*.82, .025), (side*1.47, .025), (side*1.34, 1.68), (side*.82, 1.68)]
    if side < 0:
        profile.reverse()
    extrude("StoneLeg" + ("Left" if side < 0 else "Right"), profile, .57, stone, .048)
    inner = [(side*.82*math.cos(t), 1.71+1.02*math.sin(t)) for t in [i*math.radians(84)/14 for i in range(15)]]
    outer = [(side*1.34*math.cos(t), 1.71+1.43*math.sin(t)) for t in [i*math.radians(84)/14 for i in range(15)]]
    profile = inner + list(reversed(outer))
    if side < 0:
        profile.reverse()
    extrude("StoneArch" + ("Left" if side < 0 else "Right"), profile, .54, stone, .042)

extrude("StoneThreshold", [(-1.15, 0), (1.15, 0), (1.12, .23), (-1.12, .23)], 1.13, stone, .045)
# Five-sided diamond, visibly faceted on both sides and separated from the arch.
n = 4
verts = [(0, 0, 2.78), (0, 0, 3.43)]
verts += [(.205*math.cos(i*math.tau/n+math.pi/4), .205*math.sin(i*math.tau/n+math.pi/4), 3.105) for i in range(n)]
faces = []
for i in range(n):
    faces += [(0, 2+(i+1)%n, 2+i), (1, 2+i, 2+(i+1)%n)]
mesh("CrownCrystal", verts, faces, crystal, 0)


def glow_line(name, points):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 1
    curve.bevel_depth = .014
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points)-1)
    for p, coordinate in zip(spline.points, points):
        p.co = (*coordinate, 1)
    ob = bpy.data.objects.new(name, curve)
    asset.objects.link(ob)
    curve.materials.append(rim)
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob.select_set(False)


for front in [-1, 1]:
    for side in [-1, 1]:
        points = [(side*.808, front*.277, .24), (side*.808, front*.277, 1.71)]
        points += [(side*.808*math.cos(t), front*.277, 1.71+1.02*math.sin(t))
                   for t in [i*math.radians(84)/24 for i in range(1, 25)]]
        glow_line("InnerLight_%d_%d" % (front, side), points)
    glow_line("ThresholdLight_%d" % front, [(-.808, front*.277, .241), (.808, front*.277, .241)])

# Review-only stage is excluded from export. Source opens in its dormant state.
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.007))
floor = bpy.context.object
move_to(floor, review)
floor.data.materials.append(material("ReviewIvory", "ddd6ca", .9))
world = bpy.data.worlds.new("ReviewWorld")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (.45, .47, .50, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = .55
for name, pos, power, size in [("Key", (-3, -4, 6), 650, 4), ("Fill", (4, -2, 4), 240, 4), ("Rim", (1, 3, 5), 450, 3)]:
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.size = power, size
    ob = bpy.data.objects.new(name, data)
    review.objects.link(ob)
    ob.location = pos
    ob.rotation_euler = (Vector((0, 0, 1.5))-ob.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.object.camera_add()
camera = bpy.context.object
move_to(camera, review)
scene.camera = camera
camera.data.type = "ORTHO"
camera.data.ortho_scale = 4.4
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 640
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
views = {"front": (0, -7, 3.4), "left": (-7, 0, 3.4), "right": (7, 0, 3.4), "back": (0, 7, 3.4), "game": (5, -5, 8)}
camera.location = views["game"]
camera.rotation_euler = (Vector((0, 0, 1.6))-camera.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(DEST / "source.blend"))
for state in ["unfinished", "completed"]:
    if state == "completed":
        for mat in [rim, crystal]:
            node = mat.node_tree.nodes.get("Principled BSDF")
            node.inputs["Base Color"].default_value = (*rgb("ffb631"), 1)
            node.inputs["Emission Color"].default_value = (*rgb("ffb631"), 1)
            node.inputs["Emission Strength"].default_value = 3
    for name, pos in views.items():
        camera.location = pos
        camera.rotation_euler = (Vector((0, 0, 1.6))-camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(CAP / (state + "_" + name + ".png"))
        bpy.ops.render.render(write_still=True)
print("THRESHOLD_SOURCE_REVIEW_READY")
