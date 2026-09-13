"""Set only the native .casc scene FPS, retaining all other archive entries.

Cascadeur's exposed Scene API has no FPS setter. Use on an offline exchange scene,
then reload it in Cascadeur before authoring. Does not retime existing keys.
Requires the system Python with ZIP_ZSTANDARD support (Python 3.14 on this Mac).
"""
import argparse
import json
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('scene', type=Path)
parser.add_argument('fps', type=float)
args = parser.parse_args()
assert args.fps > 0
temporary = args.scene.with_suffix('.fps-tmp.casc')
with zipfile.ZipFile(args.scene) as source, zipfile.ZipFile(temporary, 'w') as target:
    for entry in source.infolist():
        data = source.read(entry.filename)
        if entry.filename == 'scene/scene_settings.json':
            settings = json.loads(data)
            settings['Data']['FPS'] = args.fps
            data = json.dumps(settings, indent=2).encode()
        target.writestr(entry, data)
temporary.replace(args.scene)
print('Scene FPS set:', args.scene, args.fps)
