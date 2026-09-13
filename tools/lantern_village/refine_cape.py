"""Tail-clearance cutout and a three-bone cape hem, following the reference shoulder mantle."""
import bpy,sys,math
from mathutils import Vector
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');sys.path.insert(0,str(ROOT/'tools'))
from asset_geometry import activate,mesh_object
s=bpy.data.scenes['LanternPanda_Production'];bpy.context.window.scene=s;c=bpy.data.collections['LanternPanda_Character'];rig=c.objects['LanternPanda_Rig']
bpy.data.libraries.write(str(ROOT/'assets/characters/red_panda/checkpoints/before_cape_tail_clearance.blend'),{s},fake_user=True)
activate(rig);rig.animation_data.action=bpy.data.actions['neutral'];s.frame_set(0)
bpy.ops.object.mode_set(mode='EDIT')
for side,x in [('L',-.20),('R',.20),('back',0.)]:
 b=rig.data.edit_bones.new('cape_'+side);b.head=(x,-.05 if side!='back' else -.18,.45);b.tail=(x,-.23 if side!='back' else -.26,.245 if side!='back' else .425);b.parent=rig.data.edit_bones['torso']
bpy.ops.object.mode_set(mode='OBJECT')
for b in rig.pose.bones:b.rotation_mode='QUATERNION'
bpy.data.objects.remove(c.objects['Teal_Cape'],do_unlink=True)
verts=[];faces=[];N=128;R=21
for j in range(R):
 t=j/(R-1)
 for i in range(N):
  a=i*math.tau/N;front=max(0,math.cos(a));back=max(0,-math.cos(a))
  radius=.193+(.115+.01*math.sin(a)**2)*math.sin(t*math.pi/2)
  hem=.388-.20*back**.75+.252*back**12+.112*front**10
  x=math.sin(a)*radius;y=math.cos(a)*radius*.80-.022*t*t*back
  # Broad, subtle fabric folds. No noisy surface wrinkles.
  fold=.004*math.sin(a*6)*t*t
  verts.append((x*(1+fold),y,.52*(1-t)+hem*t))
for j in range(R-1):
 for i in range(N):a=j*N+i;b=j*N+(i+1)%N;faces.append((a,b,b+N,a+N))
cape=mesh_object('Teal_Cape',verts,faces,c,bpy.data.materials['LanternPanda_Cape']);cape['skin_region']='cape'
activate(cape);mod=cape.modifiers.new('Cloth thickness','SOLIDIFY');mod.thickness=.01;mod.offset=0;bpy.ops.object.modifier_apply(modifier=mod.name)
mod=cape.modifiers.new('Rounded hem','BEVEL');mod.width=.004;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
cape.parent=rig;groups={n:cape.vertex_groups.new(name=n) for n in ['torso','cape_L','cape_R','cape_back']}
for v in cape.data.vertices:
 x,y,z=v.co;t=max(0,min(1,(.50-z)/.19));side='L' if x<0 else 'R';back=max(0,1-abs(x)/.13) if y<0 else 0.;strength=.8*t
 groups['torso'].add([v.index],1-strength,'REPLACE');groups['cape_'+side].add([v.index],strength*(1-back),'REPLACE');groups['cape_back'].add([v.index],strength*back,'REPLACE')
mod=cape.modifiers.new('Cape skin','ARMATURE');mod.object=rig
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/red_panda/source.blend'))
result={'cape_bones':3,'tail_cutout':True}
