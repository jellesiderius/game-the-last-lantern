Historical documentation — superseded by README.md

# Combat Courtyard

Lokaal 3D combatprototype met een kiesbare kraai of capibara, roze/oranje zwaarden, een magische boog en een modulaire stenen trainingsarena. Gemaakt met Blender MCP en Godot; alle zichtbare assets en hun plaatsing staan als echte meshes/scenenodes in het project.

## Starten

Open `project.godot` in **Godot 4.7.2** en druk **F6** bij `TestArena.tscn`, of **F5** voor het ingestelde hoofdproject. De hoofdscene is `scenes/ui/CharacterSelect.tscn`: kies met stick/D-pad en bevestig met kruisje, of gebruik muis/Enter. Via het pauzemenu kun je terug naar de karakterkeuze. Op deze Mac werkt **Forward+ via Metal** met glow, MSAA en TAA. Blenderbron: **Blender 5.2.1 LTS**.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path /Users/jelle/Godot-Projects/crow-test
```

## Besturing

| Actie | PlayStation | Toetsenbord / muis |
|---|---|---|
| Bewegen / richten | Linker stick | WASD / pijltjes; muis voor boog |
| Rondkijken | Rechter stick | — |
| Lichte combo | □ Vierkant, afzonderlijke drukken | LMB / V / J |
| Zwaar laden / loslaten | R2 | MMB / B / K |
| Rolaanval | ✕ gevolgd door R2 tijdens de rol | Spatie gevolgd door zwaar |
| Boog richten | L2 vasthouden | Q / RMB begint direct spannen |
| Boog spannen / schieten | L2 + ○ vasthouden, ○ loslaten | Q / RMB vasthouden en loslaten |
| Rollen | ✕ Kruisje | Spatie |
| Interactie | △ Driehoek | E |
| Afstandsvaardigheid | D-pad; boven = boog | 1–4 |
| Pauzemenu | Options / touchpad | Escape |
| Menutab | L1 / R1 | Z / X |
| Bevestigen / terug | ✕ / ○ | Enter of Spatie / Q of RMB |
| Herstarten | Pauzemenu | R / pauzemenu |
| Debug / cameratrilling | Instellingen voor trilling | F3 / F4 |

Xbox gebruikt dezelfde posities: A rollen, X melee, RT zwaar, Y interactie, LT + B boog en LB/RB voor tabs. Prompts volgen het laatst gebruikte apparaat. Volle bow/heavy charge vuurt één keer automatisch; eerder loslaten blijft mogelijk. Vasthouden start geen volgende aanval.

Een lichte klik in de laatste 0,12 s van de rol zet een roll-attack klaar. Dodge breekt laden af; tijdens een slag kan dodge pas aan het einde van herstel. Je start met 5 HP. Dummies resetten na vernietiging. Drie oefenvijanden delen maximaal twee aanvalstokens. Hun voorwaartse aankondiging vult van voren naar achteren, blijft tijdens laden amber/oranje en pulseert kort vóór de rode actieve slag.

De boog richt tijdens het vasthouden naar de muis, zonder extra linkermuisklik. De korte richtlijn toont de richting en stopt bij obstakels; pijlen vliegen horizontaal. Muisaanvallen richten via een ray naar het grondvlak. Toetsenbord-melee en controller gebruiken de bewegingsrichting of laatste kijkrichting. Een stilstaande muis neemt de controller niet over.

## Opbouw

- `assets/characters/crow/source.blend`: bewerkbaar karakter, armature en 21 benoemde Actions; ook broncollecties voor zwaard en modules. Checkpointbestanden blijven beschikbaar.
- `assets/characters/capybara/`: bewerkbare bron, 23 botten en 22 Actions, inclusief neutrale pose en eigen geladen slag.
- `assets/characters/<id>/`: bron, model.glb, materialen en checkpoints per personage.
- `settings/characters/` en `settings/weapons/`: karakter- en wapendefinities; beide personages delen dezelfde controller.
- `assets/weapons/<id>/` en `assets/environment/<id>/`: afzonderlijke wapen- en omgevingsexports.
- `scenes/levels/`: de bewerkbare arena met 36 opgeslagen grondmodules en muren.
- `scenes/actors/player/`: gedeelde speler; `scenes/actors/npcs/friendly/`: trainingsdoelen; `scenes/actors/npcs/enemy/`: vijanden.
- `scenes/assets/`: wrappers voor visuele personages en omgeving. Wapens, projectielen, effecten en UI hebben eigen mappen. Zie `scenes/README.md`.
- `scripts/`: controller, klok, animatiekoppeling, zwaardqueries, doelen, HUD en navigatie.
- `settings/`: instelbare movement-, combat- en boogresources plus materiaaloverrides.
- `shaders/`: voorwaartse rode sikkel, pijlenergie, boogpuls, korte richtlijn en witte/rode contactflits.
- `tests/`: herhaalbare gameplaycontrole en showcase. `captures/` bevat beelden, video en testrapporten.
- `.agents/skills/reference-3d-assets/`: uitgebreide projectskill over referentieconsistentie, anatomie, shading, rigging en zelfcontrole.

## Instellingen voor spelgevoel

Open `settings/player_movement.tres` in de Inspector. De exportvelden komen uit `scripts/characters/movement_settings.gd`: snelheid 4,5 m/s, versnelling 45, afremmen 60, draaien 1080°/s, deadzone 0,18, rol 0,42 s bij 8 m/s, rol-onkwetsbaarheid 0,05–0,27 s, buffer 0,12 s, laadduur 0,6 s en hitstop 0,04 s.

Aanvalvensters en schade staan in `settings/default_melee.tres`, als benoemde `AttackDefinition`-resources. De kleine lunge wordt door `move_and_slide()` geblokkeerd. De lopende aanval vergrendelt de richting. De zwaardquery gebruikt gesweepte lemmetvolumes en deduplicatie per attack-id/doel. Een world-ray voorkomt schade door muren.

`GameClock` pauzeert actie, botanimatie en hitvenster gezamenlijk; `Engine.time_scale` blijft 1. AnimationTree visualiseert de gameplaytoestand en blendt idle/walk/run op echte horizontale snelheid. De nominale walk/run-clips worden sneller afgespeeld om de korte stappen bij de werkelijke snelheid te laten aansluiten. De renpose helt duidelijk verder voorover dan lopen.

Bij de kraai rust het zwaard centraal op de rug. De capibara houdt zijn oranje zwaard in de rechterhand schuin omlaag en naar buiten. Tijdens laden/slagen gaat hetzelfde wapen naar de dragende hand of vleugel; er staat geen tweede statisch zwaard op de rug. De grote sikkel volgt de lemmetrichting binnen een voorwaartse sector. Volledig laden kiest een aparte botclip, een bredere sikkel, korte grondenergie, een zwaarder geluid, 4,5 knockback en 0,075 s hitstop bij contact. De extra grondenergie doet zelf geen schade. Deze waarden en de optionele clip staan op `AttackDefinition`.

## Boog en magie

Je start met vier magiepunten. Een pijl kost één punt bij het werkelijk afvuren. Een geldige meleezwaai herstelt één punt, maximaal één per zwaai, ook bij meerdere geraakte dummies. Missen, muren, pijlen en tijd herstellen niets.

Q/RMB indrukken begint direct het spannen; loslaten na minimaal 0,25 s vuurt precies één pijl. Te vroeg loslaten en dodge/hurt/death vóór het schot kosten niets. Links blijft melee en kan een nog gespannen pijl annuleren. De zware aanval zit op MMB/B/K. Vol laden vuurt automatisch bij 0,6 s (0,8 s voor de ontgrendelde sterkere pijl). Na een schot geldt 0,20 s herstel. Zwaar laden laat 35% loopsnelheid toe, boogladen 30%; lege-boogfeedback behoudt normale snelheid. Tijdens pauze blijft alles staan; hervatten annuleert een aangehouden laadactie zodat een tijdens pauze losgelaten knop geen vastzittende houding geeft.

`Player/BowCombat` gebruikt `settings/bow_settings.tres`: snelheid 18 m/s, bereik 16 m, korte richtlijn 2,2 m. `charged_arrow_unlocked` staat standaard uit. Inschakelen maakt minimaal 0,8 s laden twee keer zo sterk voor dezelfde kosten, met een lichtpuls. Normale pijlschade volgt de eerste lichte slag.

De boog gebruikt `bow_equip`, `bow_aim`, `bow_draw`, `bow_hold`, `bow_release` en `bow_unequip` uit hetzelfde skelet. Het zwaard wordt tijdelijk verborgen; er blijft precies één zwaardinstance. De pijl heeft een heldere roze punt en rood-roze shadertrail in de kleurstelling van de melee-slash.

## Assetexport

Bewerk de huidige `assets/characters/crow/source.blend`. Open deze in Blender en voer `tools/export_character.py` uit via de Python-console/MCP om de huidige rig, skin en afzonderlijke Actions te exporteren. `tools/export_props.py` exporteert de losse broncollecties, inclusief boog en pijl. `tools/build_bow.py` herbouwt die twee assets en de boogclips; maak eerst een checkpoint. Godot importeert het GLB opnieuw. Controleer daarna de spelcamera en een actieve aanval.

Voor de capibara: open `assets/characters/capybara/source.blend` en voer `tools/export_capybara.py` uit. Het losse zwaard staat in `assets/weapons/amber_sword/source.blend`. `rig_capybara.py`, `animate_capybara.py` en de gerichte `refine_capybara_*` scripts documenteren de opbouw; opnieuw riggen is geen exportstap. `author_charged_melee.py` voegt uitsluitend de geladen kraaiclip toe en weigert die zonder inspectie te overschrijven.

De oudere `build_assets.py`, `refine_assets.py`, `rebuild_character.py` en `connect_anatomy.py` documenteren de eerste iteraties. **Voer deze niet over het huidige verfijnde model uit**: ze bouwen delen opnieuw op. Recentere scripts hebben een smallere taak: `author_combat.py`, `author_steps.py`, `skin_ankles.py`, `refine_markings.py` en `ground_animation.py`. Controleer hun bron en toepassingsvolgorde voordat je ze herhaalt. Het opgeslagen `source.blend` is de gezaghebbende bewerkbare bron.

Behoud bone-, socket- en materiaalnamen. Blender Z-up/+Y-forward wordt eenmaal via glTF naar Godot Y-up/-Z-forward geconverteerd. Wijzig geen `.godot/imported`-bestanden. De opgeslagen bodymateriaaloverride activeert vertexkleuren als albedo.

## Controle opnieuw uitvoeren

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/TestArena.tscn -- --replay --fps=60
python3 .agents/skills/reference-3d-assets/scripts/inspect_glb.py assets/characters/crow/model.glb
```

De replay sluit af met een resultaatcode en schrijft `captures/runtime_checks_60.json`. Testinput sluit handmatige gameplay-invoer uit tijdens de replay. Gebruik 30, 60 en 120 als rendercap met dezelfde 120 Hz physics.

Showcase opnemen:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/TestArena.tscn --write-movie /tmp/crow-showcase.avi --fixed-fps 60 --disable-vsync -- --showcase
ffmpeg -i /tmp/crow-showcase.avi -c:v libx264 -crf 19 -pix_fmt yuv420p -c:a aac captures/showcase.mp4
```

Boogdemo opnemen: vervang `--showcase` door `--bow-showcase`. `captures/bow_showcase.mp4` demonstreert vier schoten, leegte, meleeherstel en opnieuw schieten.

Alle regressies draaien: `python3 tools/run_checks.py --caps 30 60 120`. Voeg `--character capybara` toe om dezelfde suites op de capibara te draaien. Karakterkeuze: `Godot --path . -- --selection-replay`. Actuele karakterdemo: `--character-showcase --character=capybara` bij rechtstreeks starten van TestArena met Movie Maker; gebruik `crow` voor de kraai. Gericht: `--suite bow`, `--suite enemy` of `--suite controller`. `--headless` controleert logica, geen visuele kwaliteit. De code is met gdformat geformatteerd; dit is ontwikkeltooling en geen runtime-afhankelijkheid. Zie `docs/ARCHITECTURE.md` voor de componentgrenzen en uitbreiding.

Zie `docs/VALIDATION.md` voor de daadwerkelijk uitgevoerde controles en beperkingen, en `docs/REFERENCE_NOTES.md` voor observaties uit de video's. De game is een eigen prototype; architectuur, camera, combo en getallen zijn geen gereconstrueerde Death’s Door-broncode.

De actuele exportwrappers gebruiken `tools/asset_export.py` samen. Die ontdekt de projectroot vanuit de opgeslagen Blenderbron, selecteert uitsluitend de karaktercollectie en exporteert afzonderlijke Actions. Rechtstreekse `.blend`-import staat uit; de game gebruikt de gecontroleerde GLB-exports. Het assetoverzicht `assets/manifest.json` wordt uit de echte GLB's opgebouwd met `python3 tools/audit_assets.py`. `refine_crow_marking_skin.py` documenteert de overdracht van rompgewichten naar de cream-vlakken, zodat die tijdens buigen blijven aansluiten.
