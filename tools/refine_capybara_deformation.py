"""Isolate the soft torso from limb weights after heat binding; preserve outer joint blends."""
import bpy
from pathlib import Path
ROOT=Path('/Users/jelle/Godot-Projects/crow-test');o=bpy.data.objects['Capybara_Body'];r=bpy.data.objects['Capybara_Rig']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/capybara/checkpoints/before_core_weight_refine.blend'),copy=True)
def smooth(a,b,x):
 u=max(0,min(1,(x-a)/(b-a)));return u*u*(3-2*u)
for bone in r.data.bones:
 if 'socket' in bone.name or bone.name=='root':bone.use_deform=False
for v in o.data.vertices:
 x,y,z=v.co
 weights={o.vertex_groups[g.group].name:g.weight for g in v.groups}
 for name in list(weights):
  if 'socket' in name or name=='root':
   parent='pelvis' if name=='root' else r.data.bones[name].parent.name
   weights[parent]=weights.get(parent,0)+weights.pop(name)
 core=(1-smooth(.19,.34,abs(x)))*smooth(.40,.58,z)*(1-smooth(1.,1.13,z))
 if core>0:
  spine=smooth(.48,.85,z)
  weights={n:w*(1-core) for n,w in weights.items()}
  weights['torso']=weights.get('torso',0)+core*spine
  weights['pelvis']=weights.get('pelvis',0)+core*(1-spine)
 head=max(smooth(1.14,1.23,z),smooth(1.05,1.13,z)*smooth(.13,.20,y))
 if head>0:
  weights={n:w*(1-head) for n,w in weights.items()};weights['head']=weights.get('head',0)+head
 chosen=sorted(((n,w) for n,w in weights.items() if w>1e-6),key=lambda x:-x[1])[:4];total=sum(w for n,w in chosen)
 # Never retain mutable VertexGroupElement RNA references across remove() calls.
 for group_id in [g.group for g in v.groups]:o.vertex_groups[group_id].remove([v.index])
 for name,weight in chosen:o.vertex_groups[name].add([v.index],weight/total,'REPLACE')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/characters/capybara/source.blend'))
result={'max_influences':max(len(v.groups) for v in o.data.vertices),'weight_error':max(abs(sum(g.weight for g in v.groups)-1) for v in o.data.vertices)}
