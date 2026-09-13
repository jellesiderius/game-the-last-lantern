"""Keep ankle roots on the shanks while the toes plant independently."""
import bpy
r=bpy.data.objects['Crow_Rig']
for suffix in ['L','R']:
 o=bpy.data.objects['Ankle_'+suffix];o.vertex_groups.clear()
 leg=o.vertex_groups.new(name='leg_'+suffix);foot=o.vertex_groups.new(name='foot_'+suffix)
 for v in o.data.vertices:
  t=max(0,min(1,(v.co.z-.035)/(.081-.035)));w=t*t*(3-2*t)
  if w>0:leg.add([v.index],w,'REPLACE')
  if w<1:foot.add([v.index],1-w,'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath='/Users/jelle/Godot-Projects/crow-test/assets/characters/crow/source.blend')
result={'ankles':'gradient leg-to-foot weights; toe meshes remain rigid'}
