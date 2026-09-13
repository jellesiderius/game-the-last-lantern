"""Cascadeur: import the inspected original character plus socket-skinned props."""
import csc
from pathlib import Path

OUT = Path('/Users/jelle/Godot-Projects/crow-test/assets/characters/red_panda/cascadeur')
app = csc.app.get_application()
sm = app.get_scene_manager()
view = sm.create_application_scene()
sm.set_current_scene(view)
loader = app.get_tools_manager().get_tool('FbxSceneLoader').get_fbx_loader(view)
loader.import_scene(str(OUT / 'red_panda_equipped_rest.fbx'))
view.save(str(OUT / 'red_panda_combat_base.casc'))
print('Equipped rest scene saved; ready for 120-FPS authoring.')
