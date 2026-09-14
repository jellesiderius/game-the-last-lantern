# Game foundation

## Shared game foundation

- Multiple playable character types share `PlayerCharacter`, `CharacterVisual` and `MovementSettings`; gameplay must not assume a crow, specific sword, palette or imported skeleton path.
- Shared code is in `scripts/{characters,components,combat,ui,core,world,ai}`. Assets use `assets/characters/<id>/{source.blend,model.glb,checkpoints}`, `assets/weapons/<id>/model.glb` and `assets/environment/<id>/model.glb`. Character wrappers: `scenes/assets/characters/<id>/Visual.tscn`.
- Scene layout: `scenes/levels/` for levels; `scenes/actors/player/` for playable actors; `scenes/actors/npcs/{friendly,enemy}/` for NPC prefabs; `scenes/assets/` for visual/environment wrappers. Keep the player outside `npcs`. Passive training dummies are under `friendly`.
- Read `docs/WORK_IN_PROGRESS.md` for unfinished work. Current-source renders are required before visual claims.

## Current input and action requirements

- Q/RMB directly draws; release after minimum draw can shoot. Full charge auto-fires once; holding never starts another shot. Controller: L2 aims; circle draws/releases. R2 is heavy; cross dodges; cross then R2 queues roll attack.
- Empty bow attempts preserve normal movement speed. Refusal affects only the upper body; no held arrow, aiming line or charge effect.
- Heavy/bow charge allow reduced-speed movement. Full heavy charge auto-releases. Dodge/hurt/death retain priority. These override historical standing-still/hold-at-full rules.
- Compact HUD: five slanted green health segments with opposite pointed end caps, teal outlines, and four yellow circular magic pips below. No flame icons or large diamond weapon slots (latest user correction). Controls in pause; meters read components.


Read `README.md` and `docs/ARCHITECTURE.md` before gameplay changes. Apply the project skill `.agents/skills/reference-3d-assets/SKILL.md` for asset work.

- Preserve the user's crow design and the editable `assets/characters/crow/source.blend`. Earlier generators are historical checkpoints; do not rerun them over the refined model casually.
- Keep level, character, weapon and effect meshes in saved Godot scenes. Runtime spawning is appropriate for projectiles and transient instances of saved scenes. Never edit `.godot/imported`.
- Gameplay state and action time belong to `PlayerCharacter`; `GameClock` coordinates physics, animations, projectiles and hitstop. Avoid a second gameplay state machine inside AnimationTree or timer-driven damage callbacks.
- Put adjustable attack data in Resources. Keep health and magic components independent of input/UI. Emit gameplay events instead of making weapons update HUD directly.
- PC controls: WASD; LMB/V/J melee; MMB/B/K heavy; Q or RMB hold to draw, release to fire; Space dodge. PlayStation: LS move/aim, RS bounded camera look, square melee, R2 heavy, cross dodge, triangle interact, L2 aim + circle draw/release, D-pad ranged slot, Options/touchpad menu. Menu: cross confirm, circle back, L1/R1 tabs.
- Format GDScript consistently with `gdformat scripts tests`. Use checks scoped to the changed behaviour. Visual adjustments need a focused native visual check; do not automatically run broad combat/controller suites.
- Verify visuals in a running Forward+ Metal game. A successful import/headless test does not prove good animation. On macOS, an occluded window can skip drawing; inspect actual render-frame counts before relying on a screenshot or movie.
- Describe remaining visual differences honestly. Reference footage supports observations, not claims about Acid Nerve's internal implementation.

## Reuse and input boundaries

- Prefer a shared controller plus components/Resources for playable characters. Use inheritance when a subtype actually specializes behaviour: `training_interaction.gd` extends `Interactable`; `Bruiser.tscn` inherits the enemy scene and supplies different settings. Avoid empty base classes or a forced player/enemy inheritance tree.
- `project.godot` contains the editable Input Map. `tools/configure_input.gd` explicitly authors the current defaults; it is not run at game startup. `InputRouter` owns device prompts, disconnect handling, vibration and the GUI-to-gameplay transition fence.
- Handled GUI events still affect Godot's global Input state. Block gameplay polling on menu open/close/restart and cancel pending charge input. Never let cross-confirm become a dodge or circle-back become a shot.
- The right stick pans within camera bounds; it does not rotate the camera or change character aim. Left stick retains aim at neutral. Only real input changes active device.
- One ranged ability is currently unlocked: bow in the upper D-pad slot. Empty slots show a locked response without changing the selected ability. New abilities must supply actual gameplay before becoming selectable.

## Character and weapon contracts

- Startup is `scenes/ui/TitleScreen.tscn`. New Game opens ForestOpening with one playable red panda; Testscene opens the exported `test_scene` path, currently TestArena. ForestOpening, PrototypeRoom and TestArena remain directly launchable. Title fades/rises gently; menu arrival follows the title with matching easing. Keep lettering solid, menu above lantern, sparse sparks and quiet moving flame. The room remains 32 × 32 m, fixed 50° downward / 45° yaw camera, orthographic size13 and smooth bounded following. The three-character selector is historical. `GameSession._init()` must supply a non-null CharacterDefinition before Player enters the tree. Test both launch paths and title/menu input fences.
- Visual wrappers provide the same named clips and socket attachments with their own rig. The red panda keeps the original chibi anatomy and wears the new ranger clothing. It holds the sunblade in the right hand at rest; the broad faces point sideways (saved roll on WeaponModel). The back-stow request was explicitly reverted. Crow stows its rose sword centrally on the back; capybara holds its amber sword in the right hand at rest. `stow_at_rest` and cycle-speed settings belong to CharacterVisual.
- `MeleeWeapon.tscn` is a real inherited base for rose/amber weapon scenes. WeaponDefinition supplies palette/material settings; avoid a second controller for a different character.
- `AttackDefinition.charged_clip` changes presentation without changing the shared action clock. CombatFeedback reads that clock; its ground wake is cosmetic and cannot expand damage reach.
- Per the latest user correction, crow and capybara tests are not required. Only expand beyond focused red-panda checks when a concrete regression justifies it or the user requests it.

## Current miniature assets

- Authoritative panda body/head reference: `assets/references/lantern_village/lantern_panda.png`. `ranger_panda.png` supplies clothing only. Never broaden or lengthen the accepted anatomy when changing clothing.
- Separate prop references: `lantern_detail.png`, `sword_detail.png`; sources in `assets/props/hand_lantern/` and `assets/weapons/sunblade/`. `Equipment_Preview` in the character source is excluded from character export.
- Terrain surfaces have exclusive footprints. Sand replaces grass with half-width border modules; do not overlay a path with millimeter Y offsets. Run the overlap assertion in `tools/lantern_village/author_room.py --final` and visually inspect in Godot.
- Room instances are saved in `PrototypeRoom.tscn`; Blender assembly: `assets/environment/prototype_room.blend`. Authoring scripts run offline, never at game startup.
- Re-run `--room-replay --fps=60` after room/camera changes; compare caps30/60/120 for traversal. Do not run screenshot control against an unrelated headless process on port9090.

- PrototypeRoom camera uses camera_follow_half_life=0.12 s and camera_height_half_life=0.08 s. Preserve size13 and fixed angle. The long test stair is west of the plaza: 16×0.25 m rise over8 m, 4 m landing. Test ascent/descent, camera settling and HUD state in --room-replay.

## Current sunblade combat

- Latest correction: light directions alternate continuously, but there is NO light follow-up queue. Early clicks are discarded; a fresh click in the last0.10 s recovery can start the next attack immediately. Randomly choose level/rising/falling authored bone paths, no consecutive same style. Light slope stays shallow (20°). Heavy charge is0.45 s with normalized clip sampling.
- Sunblade energy radius is1.9 m, charged2.4 m. MeleeWeapon owns its visible 3D leading-edge sweep and shared target deduplication. Shader reads the same basis/height/angle. Ground wake is still cosmetic. Other WeaponDefinitions default to physical-blade-only.
- Panda has29 Actions including six light styles, attack_3_reverse and separately revised heavy clips. Its editable GLB import uses animation/fps=120; lower sampling distorted one short swing. Keep the original chibi meshes. Read docs/COMBAT_SWINGS.md; run --energy-replay after swing changes.

## First forest area

- User forest references are authoritative: `assets/references/forest/`. Preserve their quiet low-poly palette and silhouettes. Do not claim 1:1 from an import or headless check.
- Forest source assets: `assets/environment/forest_*/source.blend`; level assembly `assets/environment/forest_opening.blend`; saved level `scenes/levels/ForestOpening.tscn`; gallery `ForestAssetGallery.tscn`. Author offline with `tools/forest/`; never rebuild meshes at startup.
- Panda has 32 Actions including the new seated/rise/hop `entrance`; accepted anatomy and existing clips stay preserved. `PlayerCharacter` owns entrance timing/real physics; `settings/forest_entrance.tres` configures takeoff and handoff.
- Forest ground uses exact exclusive grass/path/terrace footprints, with the area assertion in `author_ground.py`. The forest Environment uses `AMBIENT_SOURCE_COLOR` (2), not SKY (3) with an empty sky.
- After forest changes, run native `--forest-replay --fps=60`, with caps30/120 after camera/traversal changes. `--forest-overview` and `--forest-asset-review` provide visual evidence; `--forest-movie` records a clean entrance/approach. Overview camera changes are test-only; gameplay retains size13 and fixed50°/45°.
