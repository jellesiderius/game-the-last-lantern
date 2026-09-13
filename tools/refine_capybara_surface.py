"""Fourth neutral review: embedded brows, restrained ears, matte directional fur.
Run once on the existing study; keep an editable pre-rig checkpoint.
"""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path('/Users/jelle/Godot-Projects/crow-test')
s=bpy.data.scenes['Capybara_Production'];bpy.context.window.scene=s
c=bpy.data.collections['Capybara_Character'];body=c.objects['Capybara_Body']
assert not body.get('surface_refined')
bpy.data.libraries.write(str(ROOT/'assets/characters/capybara/checkpoints/before_surface.blend'),{s},fake_user=True)
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
for v in body.data.vertices:
 x,y,z=v.co
 shoulder=math.exp(-(((abs(x)-.345)/.093)**2+((z-.94)/.12)**2))
 v.co.y*=1-.16*shoulder
 v.co.z+=.023*math.exp(-((x/.18)**2+((z-1.445)/.04)**2))
 # The lower face joins a short stout neck; avoid an angular teddy-bear cheek.
 v.co.x*=1-.045*math.exp(-((z-1.20)/.09)**2)
for side,sign in [('L',-1),('R',1)]:
 for name in ['Ear_'+side,'Ear_Inside_'+side]:
  o=c.objects[name];center=Vector((sign*.188,-.013,1.421))
  for v in o.data.vertices:v.co=center+(v.co-center)*.83
 # Broader hood, sunk into the forehead, so it reads as anatomy rather than a stuck-on eyebrow.
 o=c.objects['Brow_'+side];center=sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
 for v in o.data.vertices:
  v.co.y=center.y+(v.co.y-center.y)*1.2-.008
  v.co.z=center.z+(v.co.z-center.z)*.7-.003
  v.co.x=center.x+(v.co.x-center.x)*1.13
for m in bpy.data.materials:
 if not m.name.startswith('Capybara_') or not m.use_nodes:continue
 p=m.node_tree.nodes.get('Principled BSDF')
 if p and any(x in m.name for x in ['Fur','Details','Muzzle','Paws']):
  p.inputs['Roughness'].default_value=.84;p.inputs['Specular IOR Level'].default_value=.22
  bumps=[n for n in m.node_tree.nodes if n.type=='BUMP']
  for n in bumps:n.inputs['Strength'].default_value=.27;n.inputs['Distance'].default_value=.012
body['surface_refined']=True
bpy.data.libraries.write(str(ROOT/'assets/characters/capybara/source.blend'),{s},fake_user=True)
result={'saved':str(ROOT/'assets/characters/capybara/source.blend')}
