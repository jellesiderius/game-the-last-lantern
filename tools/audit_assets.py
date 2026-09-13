"""Read actual GLB exports into the versioned asset manifest; no Blender mutation."""
import importlib.util, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('glb_inspector', ROOT/'.agents/skills/reference-3d-assets/scripts/inspect_glb.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
manifest={'blender':'5.2.1 LTS','forward':'Blender +Y/Z-up to Godot -Z/Y-up','characters':{},'weapons':{},'environment':{}}
for category in ['characters','weapons','environment']:
 for path in sorted((ROOT/'assets'/category).glob('*/model.glb')):
  audit=module.inspect(path)
  if audit['errors']:raise ValueError(audit['errors'])
  entry={'model':str(path.relative_to(ROOT)),'meshes':audit['meshes'],'triangles':audit['triangles']}
  source=path.with_name('source.blend')
  if source.exists():entry['source']=str(source.relative_to(ROOT))
  if category=='characters':
   entry.update({'animations':audit['animations'],'root_static':all(a['root_static'] for a in audit['animations']),'maximum_weight_sum_error':audit['max_weight_error']})
   dest=ROOT/'captures'/path.parent.name/'glb_audit.json'
   dest.parent.mkdir(parents=True,exist_ok=True)
   dest.write_text(json.dumps(audit,indent=2)+'\n')
  manifest[category][path.parent.name]=entry
(ROOT/'assets/manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Audited', {kind:len(manifest[kind]) for kind in ['characters','weapons','environment']})
