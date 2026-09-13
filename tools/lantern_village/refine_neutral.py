"""Corrections from front/side/back review: embedded ears, clean cape, continuous tail bands."""
import bpy,sys,math
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import *
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character']
bpy.data.libraries.write(str(ROOT/'assets/characters/red_panda/checkpoints/before_neutral_refinement.blend'),{s},fake_user=True)
for side in ['L','R']:
 o=c.objects['Ear_'+side]
 for v in o.data.vertices:
  sign=-1 if v.co.x<0 else 1
  v.co.x=sign*(.32+(abs(v.co.x)-.317)*1.20);v.co.z=1.046+(v.co.z-1.084)*.8
# Tiny oval eyes remain flush, remove the toy-button reflection bulge.
for side in ['L','R']:
 o=c.objects['Eye_'+side]
 for v in o.data.vertices:v.co.y=.289+(v.co.y-.289)*.65
 o.data.materials[0].node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.42
# A closed shoulder mantle, with a high front point and longer back.
bpy.data.objects.remove(c.objects['Teal_Cape'],do_unlink=True)
verts=[];faces=[];N=128;R=17
for j in range(R):
 t=j/(R-1)
 for i in range(N):
  a=i*math.tau/N;front=max(0,math.cos(a));back=max(0,-math.cos(a))
  radius=.168+(.12+.015*math.sin(a)**2)*math.sin(t*math.pi/2)
  hem=.395-.22*back**.8+.105*front**10
  verts.append((math.sin(a)*radius,math.cos(a)*radius*.79-.055*t*t*back,.515*(1-t)+hem*t))
for j in range(R-1):
 for i in range(N):a=j*N+i;b=j*N+(i+1)%N;faces.append((a,b,b+N,a+N))
cape=mesh_object('Teal_Cape',verts,faces,c,bpy.data.materials['LanternPanda_Cape']);cape['skin_region']='cape'
activate(cape);mod=cape.modifiers.new('Cloth thickness','SOLIDIFY');mod.thickness=.012;mod.offset=0;bpy.ops.object.modifier_apply(modifier=mod.name)
mod=cape.modifiers.new('Soft hem','BEVEL');mod.width=.005;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
# Keep a clean connected body, polish the leg transition without changing the hand layout.
body=c.objects['Connected_Body'];activate(body)
mod=body.modifiers.new('Polished limb junctions','SMOOTH');mod.factor=.65;mod.iterations=8;bpy.ops.object.modifier_apply(modifier=mod.name)
# Tail bands follow cross sections, never coarse polygon-centre color thresholds.
bpy.data.objects.remove(c.objects['Ringed_Tail'],do_unlink=True)
tail=tube('Ringed_Tail',[(0,-.135,.25,.084),(-.02,-.26,.24,.145),(-.06,-.43,.265,.165),(-.09,-.59,.335,.17),(-.09,-.71,.365,.12),(-.09,-.763,.365,.001)],c,bpy.data.materials['LanternPanda_Coat'],64,12)
tail.data.materials.append(bpy.data.materials['LanternPanda_Cream']);tail['skin_region']='tail'
for p in tail.data.polygons:
 band=p.index//64
 p.material_index=1 if 12<=band<23 or 34<=band<44 else 0
# Pointed broad feet rather than a separate flat sole.
for v in body.data.vertices:
 if v.co.z<.065:
  v.co.y=.015+(v.co.y-.015)*.87
# Refine the back tail tip with smooth normals. All these are editable mesh changes.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'source':bpy.data.filepath}
