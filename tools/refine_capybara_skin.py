"""Replace provisional distance weights with Blender bone-heat skinning of connected anatomy.
Rigid face/fingers/toes retain their explicit assignments. Check authored bend poses afterward.
"""
import bpy
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
rig=bpy.data.objects['Capybara_Rig'];body=bpy.data.objects['Capybara_Body']
bpy.data.libraries.write(str(ROOT/'assets/characters/capybara/checkpoints/before_heat_skin.blend'),{s},fake_user=True)
rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
for o in bpy.context.selected_objects:o.select_set(False)
body.parent=None
for modifier in list(body.modifiers):
 if modifier.type=='ARMATURE':body.modifiers.remove(modifier)
body.vertex_groups.clear()
flags={b.name:b.use_deform for b in rig.data.bones}
for bone in rig.data.bones:
 bone.use_deform=bone.name not in ['root','sword_socket','back_sword_socket','bow_socket','bow_draw_socket','fingers_L','fingers_R']
body.select_set(True);rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.parent_set(type='ARMATURE_AUTO')
for b in rig.data.bones:b.use_deform=flags[b.name]
# Anchor muzzle/eyes to the head. Normalize to glTF's four-influence contract.
head=body.vertex_groups.get('head')
missing=0
for v in body.data.vertices:
 weights=[(g.group,g.weight) for g in v.groups if g.weight>.001]
 if v.co.z>1.235:weights=[(head.index,1.)]
 if not weights:
  missing+=1;weights=[(body.vertex_groups['torso'].index,1.)]
 weights=sorted(weights,key=lambda g:-g[1])[:4];total=sum(w for _,w in weights)
 for group_id in [g.group for g in v.groups]:body.vertex_groups[group_id].remove([v.index])
 for idx,w in weights:body.vertex_groups[idx].add([v.index],w/total,'REPLACE')
for modifier in body.modifiers:
 if modifier.type=='ARMATURE':modifier.use_deform_preserve_volume=False
body['rig_review']='Bone heat on connected body; rigid head details, four normalized influences.'
rig.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/capybara/source.blend'))
result={'heat_unweighted_vertices':missing,'source':bpy.data.filepath}
