# Active work — 10 September 2026

## Latest user direction (supersedes earlier appearance)

ONE playable red panda. Latest main-character reference is `assets/references/lantern_village/ranger_panda.png` (11:10:35 source image): stern smaller head, cream brow and cheek patches, teal short-sleeved jacket and collar, ochre shirt, brown belt/pouch/gloves/leg wraps, amber crystal sword and lantern. **Cape removed by this new reference.** Prior cape panda checkpointed in `assets/characters/red_panda/checkpoints/before_ranger_design/`. Do not deliver earlier design as finished.

The 16×16m miniature room uses the supplied kit/reference composition. User explicitly changed the frontal camera back to Death’s Door-style **50° down / 45° yaw**, currently saved in room scene. Keep that angle and arrange the room for visibility. User insists exact reference-matched assets, current-source multi-angle checks and no pixelated color boundaries / floating facial parts.

User reported too-slow movement / frantic legs; active panda profile now max 4.5m/s (like crow), animation rate capped1.2; this needs real runtime review after the new ranger anatomy. Earlier limb IK caused severe deformation. Last action before new reference repaired weights and replaced unreachable short-leg IK with connected FK, but **not yet reviewed/imported**. Do not claim solved animation.

## Existing actual work

- New environment kit built via Blender MCP: 13 assets under `assets/environment/{grass_tile,plaza_tile,garden_path,grass_cliff,stone_stairs,timber_bridge,autumn_tree,cottage,smithy,timber_fence,rock_cluster,flower_patch,barrel}` with source.blend/model.glb and visual wrappers.
- `scenes/levels/PrototypeBlockout.tscn` was started and viewed. `PrototypeRoom.tscn` has saved geometry, real GLB asset instances, continuous bank colliders, 4×.25m stair ramp, 2m channel and3m bridge. root script extends arena. Main scene now PrototypeRoom. Latest blockout camera superseded by diagonal camera.
- Last room visual review still hard shadows, flat grass/water, roof/gable intersections and stair coplanarity. `tools/lantern_village/refine_environment.py` fixed roof profile / raised roof / lowered stair core; reimported but new visual review pending. Room needs nicer lighting, water and composed details, still reference controlled.
- Source environment models live in Blender scenes Asset_<id>. Source file currently saved as red_panda/source.blend contains these scenes as well. `assets/environment/lantern_kit.blend` earlier whole kit, not latest individual roof edits.
- New sunblade (short straight amber) and hand_lantern sources/GLBs created; wrappers `scenes/weapons/sunblade/Weapon.tscn`, `scenes/assets/props/hand_lantern/Visual.tscn`. Shared palette gives amber bow/arrow/effects.
- New cape panda `LanternPanda_Production`, `LanternPanda_Character`, rig `LanternPanda_Rig`,30bones,22clips. Current source has repair_skin.py changes + new FK animations not yet reexported. CurrentGLB last export predates those repairs.
- Eye/brow floating positions fixed by BVH projection; nose fitted to muzzle. Tail rings changed from coarse world-Y polygon material thresholds to exact continuous cross-section loops (no jagged color edges). Body now orange at user request, ears innerorange; new ranger reference supersedes leather areas.
- Art review script `tools/lantern_village/review_blender.py`: **now copies source.frame_current into review scene**; earlier reviews accidentally sampled defaultframe1. Latest true run frame14 revealed deformations. Evidence captures/panda_run_frame14. Repair evidence generated at panda_run_skin_repaired but not yet viewed.
- CharacterVisual optional exported `upright_accessory_paths` keeps held props upright and hides during bow/roll/death. Latest wrapper points lantern to own socket. stow_at_rest=false. Needs runtime testing.
- GameSession.characters has only panda; explicit CLI --character=crow/capybara can load historical profiles for regressions. Pause ChooseCharacter hidden when only1. Old CharacterSelect scene remains historical. Update README/AGENTS/ARCHITECTURE stale old selection descriptions later.
- Scene author initially generated invalid subresource IDs with '-' sign. `author_room.py` now sanitizes subresource IDs. Regenerated final scene, validation pending.

## Application state / tools

Blender5.2.1LTS, Godot4.7.2stable Forward+ Metal M4Pro. Blender MCP works, code must `import bpy` per call; tool scopes fresh. No subagents authorized. Blender currently Production scene; last repair sets pose_position='POSE', sourceframe run14 in review. Need leave neutral/rest on next user-visible stage. Check processes before killing anything user-owned. GodotMCP run_project can succeed but nextcall says no active process; CLI started game also later quit, may be user closing. Actual first blockout + firstfinal room screenshot succeeded live. No successful new-panda Godot visual check yet.

Explicit Godot `--headless --editor --path . --import` after every final GLB change. NEVER edit .godot/imported. Latest exec import session79469 may still be running or finished; no check after user interruption. CLI game session11978 exited by last log. Inspect actual processes.

## Scripts (authoring history, don't casually rerun destructively)

`tools/lantern_village/build_environment.py`, `refine_environment.py`, `author_room.py` offline scene author, `build_character.py`, `refine_neutral.py`, `attach_face.py`, `rig_character.py`, `animate_character.py`, `refine_cape.py`, `fit_cape_shoulders.py`, `repair_skin.py`, `build_equipment.py`, `export_character.py`, `review_blender.py`.

Some focused edits (ears/bodycolor/nose) were applied via MCP code and saved in authoritative source, not fully represented by regeneration scripts. Source.blend is authoritative. Export_character.py selects currentProduction scene and shared asset_export ACTIONS/NONE restskin. Current armature30bones incl 3 cape bones; new design can retain unused cape bones for animation contract, no visual cape.

## Required remaining work

1. Model new ranger reference from current checkpointed anatomy, useful geometry reused. Neutral review before rig/animation. Fix deformation root causes, not more cosmetic cape tweaks.
2. Final saved room, compare individual assets and diagonal camera; ensure smooth bridge/stair traversal and contained banks, no sky gaps. Keep middle free for combat.
3. Add/retain usable training targets and actual combat demo, update source assembly in Blender too.
4. Explicit import, actual rendered game checks and screenshots/motion video. Test movement at4.5 with nonfrantic cadence and all clips/attachments.
5. Targeted newroom replay plus shared melee/bow/enemy/controller/crowd at30/60/120 (historicalcrow/cap tests perAGENTS too aftersharedvisual changes). Prior9Sept results are not current ranger validation.
6. Update docs and manifests with actual evidence and limitations. Asset skill was expanded peruser: all sides, anatomy joins (nose/brows/eyes/ears/limbs/cape), color and pixelation checks mandatory. quick_validate passed. Add discovered pose-review clock lesson and skin leakage if useful.

Latest additional refs: `lantern_detail.png` and `sword_detail.png` (11:13:22). User explicitly requests exact separate assets. New lantern square brass cage with X braces front/back, rounded rectangular handle, glowing central crystal; sword short broad crystal, upper shoulders before sharp point, curved U gold guard, wrapped brown grip and octagonal gold pommel. Existing sunblade/hand_lantern draft exports MUST be refined to these references.

`build_ranger.py` has now executed once on the checkpointed cape source. New clothes/body with region-specific skin, 30bone existing rig repositioned; all old Actions removed intentionally and rig in REST. **No ranger animations yet. CurrentGLB still old cape panda.** Current Blender file includes new ranger neutral geometry; renders `captures/lantern_village/ranger_neutral/` produced, need inspect. Body/garments now separate fitting meshes with bounded weights to avoid limb-weight spill into chest. Needs clothing contact refinement and own grip targets in animation authoring. Do not rerun build_ranger.py (it transforms face again).

## Latest correction after ranger build

User clarified twice: keep the ORIGINAL round chibi panda shape/proportions/head, **only clothing changes**. No taller or broad ranger anatomy, no stern-face change. Restore checkpoint `before_ranger_design/source.blend`, fit new clothing to that small body. This restore has JUST EXECUTED via Blender MCP. Current filepath is checkpoint path; save final authoritative source.blend only after fitting. New garment meshes were separately saved to `checkpoints/ranger_clothes_library.blend`, collection `Ranger_Clothes_Transfer` (includes clothing+shirt+gloves/boots, excludes head/tail/skin Arm_). Append clothing, map garment vertices to original bone/shape landmarks, fit surfaces and avoid hidden-body poke-through. Reuse original reviewed head/ears/face attachments. Original orange body user preference remains under clothes; dark gloves/boots come from clothing ref. Latest separate lantern/sworddetail refs still apply.
