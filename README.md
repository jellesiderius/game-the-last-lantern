# The Last Lantern

Speelbaar lokaal Godot-prototype met één rode panda, een amberkleurig zwaard, een magische boog en een lantaarn. Het oorspronkelijke ronde pandalichaam en hoofd zijn behouden; het nieuwe jack, shirt, riem, tasje, handschoenen en beenwikkels zijn daarop passend gemaakt.

Op het plein staan twee eikelwachters met skeletanimaties, eigen rust-/patrouilleschema's en verschillende bewegingsritmes. Ze kiezen een korte slag of uitval op basis van de situatie, lopen om obstakels en elkaar heen, volgen over de brug en beide trappen en draaien voordat ze weglopen. Nieuwe levels gebruiken automatisch hun wereldcolliders voor navigatie; vaste AI-levelgrenzen of handmatige routes zijn niet nodig. Bronnen, prefab, instellingen en previews: [ACORN_GUARD.md](docs/ACORN_GUARD.md). Onderzoek en herbruikbare enemyprofielen: [ENEMY_AI_DESIGN.md](docs/ENEMY_AI_DESIGN.md). De aparte Cascadeur-werkbestanden voor de panda en de geblokkeerde export staan in [CASCADEUR_PANDA.md](docs/CASCADEUR_PANDA.md).

## Starten

De bewerkbare 3D-bronnen en grote beeldbestanden gebruiken **Git LFS**. Na installatie van Git LFS:

```sh
git lfs install
git clone git@github.com:jellesiderius/game-the-last-lantern.git
cd game-the-last-lantern
git lfs pull
```

Open `project.godot` in **Godot 4.7.2** en druk **F5**. De hoofdscene is `scenes/ui/TitleScreen.tscn`: het introscherm met geanimeerde titel, rustig vlamlicht en enkele opstijgende vonkjes. **New Game** opent de drie save slots; een leeg slot begint in `ForestOpening`; **Testscene** opent standaard `TestArena`. Selecteer de root van TitleScreen en wijzig **Test Scene** in de Inspector om een andere testscene in te stellen. Via **Main menu** in het pauzemenu kom je terug. Zie [INTRO_SCREEN.md](docs/INTRO_SCREEN.md).

De eerste area begint in het bos: de panda zit op een grote stronk, springt eraf en krijgt de besturing terug terwijl vlinders voorbijvliegen. Het pad leidt langs begroeiing, een vijver en rotsterrassen naar de Eikelwachter. Aan het einde opent de poort een tweede bos met een huis. De voordeur brengt je naar het interieur, waar je met Linde kunt praten; beide routes werken ook terug. Bewerkbare assets en bouwinstructies: [FOREST_OPENING.md](docs/FOREST_OPENING.md).

De afzonderlijke prototypekamer is **32 × 32 meter**, met een 2 meter breed waterkanaal, brug en een terras op 1 meter hoogte. De camera behoudt 50° neerwaartse hoek en 45° draaiing, heeft een orthografische grootte van **13 meter** en volgt de speler soepel binnen grenzen. Alle levels blijven rechtstreeks met F6 te starten.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Deze Mac gebruikt **Forward+ via Metal**, met MSAA/TAA, omgevingslicht, schaduwen en beperkte glow. Bewerkbare bronnen gebruiken **Blender 5.2.1 LTS**.

Rustpunten, drie onafhankelijke spellen en bewerkbare checkpointinstellingen: [VUURLELIE.md](docs/VUURLELIE.md). Continue verschijnt pas zodra een save bestaat. Alleen **Rusten** herstelt meters, vernieuwt vijanden en slaat op; plaatsnemen opent uitsluitend het menu. Een klein lantaarnicoon bevestigt een geslaagde save.

## Zelf levels maken

Open **Level Builder** boven de 3D-weergave. Onderaan kies je assets met kleine modelpreviews; rechts staan **Bouwen**, **Bewerken** en **Level**. Via Level → Nieuw level kies je een areaset en eigen breedte/diepte. Paden blijven glad bij elke grondresolutie; ramps hebben versleepbare hoogtepunten en kunnen met één knop een aansluitend plateau krijgen. Assets nemen hun opgeslagen collision mee.

Volledige uitleg: [LEVEL_BUILDER.md](docs/LEVEL_BUILDER.md). Voorbeelden: `BuilderForest.tscn`, `BuilderCave.tscn`, `BuilderCity.tscn`. Grot en stad zijn uitbreidbare startsets met bestaande assets.

## Besturing

| Actie | PlayStation | PC |
|---|---|---|
| Bewegen / richting | Linker stick | WASD / pijltjes |
| Camera-look | Rechter stick | — |
| Lock-on aan/uit | R3 | F |
| Ander doel kiezen (links/rechts op scherm) | Rechter stick flick | Z / X of muiswiel |
| Lichte combo | Vierkant, losse drukken | LMB / V / J |
| Zwaar laden / loslaten | R2 | MMB / B / K |
| Rollen | Kruisje | Spatie |
| Rolaanval | Kruisje gevolgd door R2 | Spatie gevolgd door zwaar |
| Boog richten / spannen | L2 + rondje vasthouden | Q of RMB vasthouden; muis richt |
| Schieten | Rondje loslaten | Q of RMB loslaten |
| Interactie | Driehoek | E |
| Afstandsvaardigheid | D-pad boven: boog | 1–4; overige slots vergrendeld |
| Pauze | Options / touchpad | Escape |
| Menu bevestigen / terug | Kruisje / rondje | Enter of Spatie / Q of RMB |
| Menutab | L1 / R1 | Z / X |
| Herstart | Pauzemenu | R / pauzemenu |
| Debug / cameratrilling | Instellingen | F3 / F4 |

Volle boog- en zware charge vuren één keer automatisch. Vasthouden begint geen volgende aanval. Tijdens laden kan de speler vertraagd lopen; een lege boog behoudt normale loopsnelheid. De HUD gebruikt vijf schuine groene levensblokken met tegengestelde puntige uiteinden, en vier gele magiebolletjes eronder. Eén punt per afgevuurde pijl; een geldige meleezwaai herstelt maximaal één punt. Dummies tellen mee. Er staan drie trainingsdoelen oostelijk van het plein. Links/west staat een lange testtrap: 16 treden, 8 m lengte, 2 m breedte en 4 m stijging naar een bordes. De korte trap naar het dorpshuis blijft beschikbaar.

Lock-on (`TargetLock` op de speler) kiest het dichtstbijzijnde zichtbare doel vóór de speler. Wisselen gaat naar het eerstvolgende doel met de klok mee (rechts) of tegen de klok in (links) zoals op het scherm gezien, en loopt rond. Een verslagen doel geeft de lock door aan het dichtstbijzijnde doel; buiten 12 m of 0,8 s zonder zicht vervalt de lock. Tijdens lock blijft het lichaam naar het doel gericht: de stick verplaatst alleen (strafen, op `MovementSettings.lock_on_speed_multiplier` = 80% snelheid). Melee, heavy en boog richten op het doel en de camera leunt ernaartoe. Rollen gaat in de stickrichting. Er zijn nog geen zijwaartse/achterwaartse loopclips; de gewone loopcyclus speelt tijdens strafen. Zie `tests/lock_on_replay.gd` (`--lock-on-replay` in PrototypeRoom).

Het zwaard blijft in rust in de **rechterhand**, met de brede zijden naar links/rechts. De tijdelijke rugsocketvariant is op verzoek teruggedraaid. Er is precies één zwaardinstance. Booggebruik verbergt het zwaard en de lantaarn; daarna komen ze terug.

## Bestanden

- `assets/characters/red_panda/source.blend` en `model.glb`: huidige panda, eigen skelet en 34 Actions.
- `assets/weapons/sunblade/`: los bewerkbaar kristalzwaard en GLB.
- `assets/props/hand_lantern/`: losse messing lantaarn met glazen panelen, X-spijlen en lichtgevend kristal.
- `assets/environment/<id>/`: herbruikbare grond, pad, klif, trap, brug, gebouwen, bomen en props.
- `assets/environment/prototype_room.blend`: samengestelde Blender-ruimte met bewerkbare module-instances.
- `scenes/levels/ForestOpening.tscn`: eerste speelbare bosarea.
- `scenes/levels/ForestAssetGallery.tscn`: afzonderlijke bosassetgalerij.
- `scenes/levels/PrototypeRoom.tscn`: aparte prototypekamer. Alle zichtbare assets en plaatsing zijn opgeslagen nodes.
- `scenes/levels/TestArena.tscn`: afzonderlijke uitgebreide combatregressie-arena; rechtstreeks starten met F6.
- `scenes/assets/`: visuele wrappers. `scenes/actors/player/` en `scenes/actors/npcs/{friendly,enemy}/`: gameplayactors.
- `scripts/{characters,components,combat,ui,core,world,ai}`: gedeelde gameplay. `settings/`: instelbare Resources.
- `assets/references/lantern_village/`: gebruikte ontwerpbladen. `lantern_panda.png` bepaalt anatomie; `ranger_panda.png` alleen kleding.
- `.agents/skills/reference-3d-assets/`: asset- en Godot-controleworkflow, inclusief aansluitende grondvlakken.

De kraai- en capibarabronnen blijven behouden als historische assets en regressieprofielen. Ze verschijnen niet meer als drie keuzes bij opstarten.

## Instellingen

`settings/characters/red_panda_movement.tres` bepaalt onder andere 3,8 m/s snelheid en de eigen loopcyclusinstellingen. De vernieuwde panda heeft gesynchroniseerde voetfasen, een ontspannen lage zwaardhouding en meebewegende armen, romp en staart. Zie [PANDA_MOTION.md](docs/PANDA_MOTION.md) voor bron, replay en beperkingen. Aanvalvensters/schade staan in `settings/default_melee.tres`; boogregels in `settings/bow_settings.tres`. `settings/weapons/sunblade.tres` levert de amberkleur aan zwaard, boog, pijl en effecten.

Speler en NPCs blijven achter ondoorzichtige meshes leesbaar als een volledig donkergrijs silhouet. De centrale kleur staat op `#414342` in `settings/occlusion_silhouette.tres`; ook gedragen wapens en accessoires doen mee.

De sunblade heeft een energieradius van 1,9 m, volledig geladen 2,4 m. Lichte slagen wisselen links/rechts door; zes echte botclips leveren rechte, stijgende en dalende banen (maximaal20°). Er is geen klik-wachtrij: alleen een verse klik in het laatste herstel kan meteen een nieuwe slag starten. De zware aanval laadt in0,45 s met een eigen hoge laadpose en lage follow-through. Zie `docs/COMBAT_SWINGS.md` voor instellingen, synchronisatie en controles.

Camera-afstand: `PrototypeRoom/CameraRig/Camera3D.size` (13 m). In de Inspector van `PrototypeRoom` bepaalt `camera_follow_half_life` de volgvertraging: standaard 0,12 s om de resterende horizontale afstand te halveren. Een hogere waarde volgt zachter; een lagere waarde volgt strakker. `camera_height_half_life` is 0,08 s voor trappen. De camera blijft bij rennen ongeveer 0,8 m achter en haalt na stoppen geleidelijk in. Doelhoogte en grenzen staan op dezelfde node; herstart reset de framing onmiddellijk. De camera draait niet mee met de speler. Zie `docs/CAMERA_FOLLOW.md` voor onderzoek en controles.

`PlayerCharacter` bezit state en actietijd. `GameClock` synchroniseert physics, animatie, projectielen, pauze en optionele hitstop. Damageable, Health en Magic zijn herbruikbare componenten; de HUD leest hun signalen. Zie `docs/ARCHITECTURE.md`.

## Assetexport en zelfcontrole

Open de actuele panda-bron en voer `tools/lantern_village/export_character.py` in Blender uit. Exporteer niet de previewcollectie met de karaktermesh: `Equipment_Preview` toont de losse props alleen voor controle. Godot gebruikt hun afzonderlijke wrappers. Behouw bone-, socket- en materiaalnamen.

`tools/lantern_village/author_room.py --final` schrijft de opgeslagen levelscene en weigert overlappende grondvoetafdrukken. Het zandpad vervangt gras; halve randmodules sluiten exact aan. Er liggen geen millimeters verhoogde padvlakken over gras. De collisionvloeren zijn doorlopend; de trap gebruikt een onzichtbare helling.

De overige Blender-scripts in die map documenteren afzonderlijke bouw- en herstelstappen. **Niet blind opnieuw uitvoeren:** sommige vervangen geometrie of Actions en verwachten een specifiek checkpoint. `source.blend` is leidend. `build_ranger.py` hoort bij de verworpen bredere lichaamsvariant. De huidige vorm komt uit het oorspronkelijke chibi-checkpoint met passend gemaakte kleding.

Na export expliciet herimporteren en in de echte renderer controleren:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 .agents/skills/reference-3d-assets/scripts/inspect_glb.py assets/characters/red_panda/model.glb
```

Wijzig nooit `.godot/imported`. De projectskill vereist front, beide zijkanten, achterkant, spelcamera en bewegingsposes; inspecteer ook kleurgrenzen, huid-/kledingaansluiting en coplanaire oppervlakken.

## Controles en demonstratie

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --room-replay --fps=60
python3 tools/run_checks.py --character red_panda --caps 30 60 120
```

`--headless` bij de Python-runner controleert logica en is geen bewijs voor renderprestaties. De roomreplay controleert brug/trap, gelijke diagonale snelheid, cameralag/grenzen en het zwaard. Hij schrijft screenshots en `captures/lantern_village/room_checks_<cap>.json`.

`captures/` bevat lokale, gegenereerde controles en opnamen. Deze bestanden worden niet meegecommit; de replaycommando's maken ze opnieuw. Godot bouwt zijn `.godot/`-importcache bij het openen van het project.

Zie `docs/VALIDATION_LANTERN.md` voor actuele resultaten, screenshots en beperkingen. De miniatuurstijl is een eigen interpretatie van de referenties; de gameplayarchitectuur en waarden zijn geen gereconstrueerde Death’s Door-broncode.

Gesprekken en configureerbare Praten/Lezen-labels beheren: [docs/DIALOGUE.md](docs/DIALOGUE.md).

Herbruikbare poorten, deuren en aankomstpunten instellen: [docs/SCENE_TRANSITIONS.md](docs/SCENE_TRANSITIONS.md).

Laadscherm bij New Game en snelle gebouwdoorgangen met voorladen: [docs/LOADING_SCREEN.md](docs/LOADING_SCREEN.md).

Herbruikbare dungeonpoorten, onafhankelijke dungeons en terugkeerpunten: [docs/DREMPELPOORT.md](docs/DREMPELPOORT.md).
