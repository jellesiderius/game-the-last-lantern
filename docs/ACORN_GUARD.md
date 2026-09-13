# Eikelwacht — 12 september 2026

De eerste bosarea bevat één Eikelwachter bij de noordelijke doorgang. Twee extra eikelwachters staan als opgeslagen instances in `PrototypeRoom.tscn`, op (-3.6, 0, -4.4) en (3.4, 0, -4.4). Loop vanaf de start het plein op om ze te activeren. De drie bestaande trainingsdoelen blijven beschikbaar.

## Ontwerp en bestanden

Referentie: `assets/references/acorn_guard/turnaround.png`, de aangeleverde front/zij/achter/driekwart-afbeelding. Herkenningspunten: brede olijfbruine eikeldop, gouden huls, zwart oogmasker met strenge ivoren ogen, korte houten ledematen, gebogen steel met goudkleurig blad en knots in de rechterhand. Het blad zit tegenover de knots. De gewrichtsconstructie en animaties zijn eigen interpretaties.

- Bewerkbaar personage: `assets/characters/acorn_guard/source.blend`, scene `AcornGuard_Production`, collectie `AcornGuard_Character`, rig `AcornGuard_Rig`.
- Export: `assets/characters/acorn_guard/model.glb`; 19 bones, 30 meshes, 14.768 driehoeken en één skin. Godot importeert op 120 samples/s. Controlepunt: `checkpoints/reviewed_20260912.*`.
- Knots: `assets/weapons/wooden_club/source.blend`, actieve scene `WoodenClub_Production`, plus aparte GLB en wrapper. De `Equipment_Preview` in het karakterbestand wordt niet mee geëxporteerd.
- Visuele wrapper: `scenes/assets/characters/acorn_guard/Visual.tscn`; de knots zit aan `club_socket` via een opgeslagen BoneAttachment3D.
- Enemy prefab: `scenes/actors/npcs/enemy/AcornGuard.tscn`; instellingen: `settings/enemies/acorn_guard.tres`.

## Gedrag en animatie

De prefab gebruikt de bestaande Damageable-, Health-, EnemyBrain- en AttackTokenManager-componenten. Zichtcontrole, achtervolgen, spreiding, vastgelegde aanval, geraakt worden, leashing en terugkeren gebruiken dezelfde gedeelde klok. `skinned_enemy_visual.gd` samplet de bones uit EnemyBrain-state en actietijd en beslist geen gameplay. Onderzoek, algoritmekeuze en uitbreiden met nieuwe enemytypes: [ENEMY_AI_DESIGN.md](ENEMY_AI_DESIGN.md).

| Clip | Duur | Gebruik |
|---|---:|---|
| idle | 2,00 s | Ademhaling en gewichtsverplaatsing; eigen fase/tempo per instance |
| look_around | 2,40 s | Rondkijken tijdens wisselende rustmomenten |
| walk | 0,40 s | Korte passen; tempo volgt werkelijke loopsnelheid |
| run | 0,342 s | Snelle passen; natuurlijke snelheid circa 2,24 m/s |
| turn | 0,317 s | Voeten verplaatsen tijdens draaien op de plaats |
| windup | 0,683 s | Duidelijk heffen naast de dop; 0,68 s gameplay |
| strike | 0,20 s | Eén stevige klap; 0,20 s gameplay |
| recover | 0,80 s | Voorover uit balans, korte vangstap en kwetsbaar herstel |
| lunge_windup | 0,758 s | Afzonderlijke voorbereiding op de uitval; 0,76 s gameplay |
| lunge_strike | 0,217 s | Voorwaartse uitval; 0,22 s gameplay |
| lunge_recover | 0,90 s | Langere zichtbare herstelruimte na de uitval |
| hurt | 0,30 s | Terugslag bij onderbreekbare toestand |
| death | 0,65 s | Voorover neervallen; verdwijnen na 1,1 s |

De eikel heeft 6 HP, rent met een individuele snelheid van 2,025–2,475 m/s, merkt de speler binnen 5,5 m op en heeft een leash van 24 m. Na zichtverlies onthoudt hij de laatst waargenomen positie maximaal 6 s. Tijdens rust wisselt hij ademhaling, rondkijken en een kleine patrouille af. Elke instance krijgt eigen reactietijd, rustduur, looptempo, routeoriëntatie en kleine aanvalsvoorkeuren; gedeelde Resources blijven ongewijzigd.

Een aanval veroorzaakt één HP schade binnen 0,98 m. Contact mag vanaf 45% van de korte zwaai of 40% van de uitval plaatsvinden (`AttackDefinition.enemy_contact_fraction`). De korte slag begint binnen 0,83 m en verplaatst 0,24 m; de uitval begint binnen 1,35 m en verplaatst 0,65 m. Afstand en zichtbaar spelergebruik van heavy/boog bepalen de tactische keuze. Willekeur varieert het ritme en vergelijkbare keuzes, niet het contactmoment van een al ingezette slag. In deze oefenkamer respawnt de vijand na 2,5 s.

Damageable past hitflash recursief toe op de visuele meshes, met een eigen materiaal per actor. Een presenter kan optioneel `present_death(time)` aanbieden; bestaande primitieve trainingsdoelen behouden hun onmiddellijke verdwijning.

NavigationWorld berekent automatisch een 3D-navmesh uit de wereldcolliders. Er zijn geen vaste levelgrenzen of brug-/trapcoördinaten in de AI. Bomen, rotsen en muren bepalen de omweg; brug, beide traphellingen en bordessen worden beloopbare oppervlakken. Alle enemyprofielen gebruiken deze gedeelde navigatie, ook in TestArena. EnemyLocomotion cachet routes, voorspelt ontmoetingen met nabije vijanden, remt af en draait lopend door gewone bochten. Lopen volgt de neus en de pasfrequentie volgt de werkelijke snelheid. Een hoogteverschil boven 0,45 m voorkomt dat de wacht al vanaf de vloer een aanval op de speler op het terras begint. Collision blijft de fysieke grens bewaken.

## Correctie van hoeken en bochten

De screenshots van 13:02 en 13:03 toonden twee ontbrekende situaties: de lage zijkant van een trap kon door de navmesh worden afgesneden terwijl de capsule daar een wand raakte, en passieve trainingsdoelen ontbraken in de voorspellende burenlijst. De nieuwe bewegingsprobe controleert echte colliders, inclusief die doelen. Een kleine herstelrichting wordt genormaliseerd vóór het draaien; de oude afstandsdrempel kon het laatste stukje correctie blokkeren.

De routeplanning kiest nu waar mogelijk meer ruimte rond obstakels. `preferred_path_clearance` (0,20 m), `path_look_ahead_time` (0,55 s) en `obstacle_clearance` (0,10 m) staan in EnemyMovementSettings. Gewone bochten worden eerder ingezet en lopend genomen; de bewegingsrichting blijft bij de lichaamsrichting. Een aparte 0,80 m doorgang verifieert de terugval op de fysieke lichaamsmaat.

De volledige hoekreplay heeft 54 checks, inclusief 40 startposities bij traphoeken en vier controles op afstand tot passieve doelen. De gerichte opname slaagt met 14 checks en 720 werkelijk getekende frames in Forward+ Metal. Preview: `captures/acorn_guard/corner_preview.mp4`; de ruimere aanloop staat apart in `corner_wide_approach.mp4`. Hoeken en doorgangen hebben geen speciale logica in productiecode: coördinaten staan uitsluitend in de regressiescenario's.

## Export en controle

Wijzig de opgeslagen bron. `refine_mobility.py` bewerkt uitsluitend de betreffende Actions op het bestaande skelet en controleert dat de vertexhash gelijk blijft. Voor deze revisie staat een bron/exportcontrolepunt in `checkpoints/before_tempo_20260912.*`. De oorspronkelijke generator is uitsluitend voor gerichte herbouw van dit nieuwe personage en weigert standaard een bestaande bron. Geen generator op de panda- of kraaibron toepassen.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/acorn_guard/review_poses.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/acorn_guard/export_asset.py
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --path . --import
python3 .agents/skills/reference-3d-assets/scripts/inspect_glb.py assets/characters/acorn_guard/model.glb
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --acorn-replay --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --enemy-movement-replay --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --enemy-surface-replay --fps=60
python3 tools/lantern_village/author_room.py --final --check-only
```

Bronrenders van voor, beide zijkanten, achter en spelcamera staan in `captures/lantern_village/acorn_guard_neutral/`; vervormde rust-, loop-, ren-, draai-, aanval- en doodposes in de naastliggende acorn_guard-mappen. Na import zijn de aanzichten en bewegende poses bekeken in Godot 4.7.2, Forward+ Metal op Apple M4 Pro. De laatste acornreplay heeft 50 geslaagde assertions en 938 werkelijk getekende frames. Zie `captures/acorn_guard/runtime_checks.json`. Dit omvat echte Sunblade-/pijltreffers, contextuele aanvalskeuze, zichtcontrole, rust/patrouille en volledig stilstaande terugdraaiing vóór vertrek.

De nieuwe bewegingsreplay slaagt met 18 checks bij caps 30/60/120. Cap60 is Forward+ Metal met 986 getekende frames; 30 en 120 zijn headless logicacontroles. Twee tegenliggers houden minstens 0,637 m centrumafstand, vier kruisende vijanden minstens 0,591 m (lichaamsdiameter 0,50 m). De boomroute bereikt de bestemming met zes padberekeningen. Tijdens gemeten teruglopen is de dotproduct-overeenkomst tussen lichaamsrichting en echte snelheid 1,0. Dit zijn resultaten van deze scenario's, geen garantie voor iedere mogelijke menigte.

De oppervlaktereplay slaagt met 23 checks in Forward+ Metal en 1041 renderframes: brug, korte trap en lange trap omhoog/omlaag, plus echte achtervolging vanaf de zijkant. De afzonderlijke 256 × 256 m testwereld slaagt met 7 checks zonder Arena-script of opgeslagen navigatiecache. Een route over 200 m gaat om de muur; het losse eiland blijft onbereikbaar. De eerste automatische bake duurde 1,28 s op deze Mac. Dit meet een eenvoudige wereld, geen dichtbevolkt gestreamd level.

- `captures/acorn_guard/pursuit_preview.mp4`: achtervolging vanaf de zijkant bij brug en beide trappen.
- `captures/acorn_guard/stairs_preview.mp4`: lange trap omhoog en omlaag.
- `captures/acorn_guard/variety_preview.mp4`: tien seconden van twee onafhankelijke rust-/patrouilleschema's in de echte renderer.
- `captures/acorn_guard/return_preview.mp4`: eerst draaien, vervolgens naar huis lopen.
- `captures/acorn_guard/idle_preview.mp4`: rust en een korte patrouille.
- `captures/acorn_guard/animation_preview.mp4`: gesamplede loop- en gevechtsclips in de renderer.
- `gameplay.png`: gewone camera op 13 m.

De vijf bestaande regressiesuites voor panda, kraai én capybara slagen bij cap60: 266 checks per type, 798 totaal, headless. De opnieuw gedraaide roomreplay slaagt bij cap60 met 34 checks en 1149 renderframes; de bestaande cap30/120-baselines hebben 585/2263 renderframes. Camera-instellingen en kameroppervlakken zijn in deze AI-revisie niet aangepast. De offline overlapcontrole slaagt op 256 oppervlakken. De Godot-processen melden bij afsluiten nog een shader/RID-opruimmelding; er zijn geen GDScript-fouten tijdens deze geslaagde replays.

De doprand en huls zijn hoekiger en regelmatiger dan de geschilderde referentie; voeten en vuisten zijn eenvoudiger. Van bovenaf bedekt de grote dop een deel van de ogen. Close-ups tonen de bestaande beperkte resolutie van de kamerschaduwen. Geen claim van een exacte 1:1-reconstructie of voet-IK op trappen.

## Herziening voor de bosintroductie

Zes voorbereidings-, slag- en herstelclips zijn opnieuw geanimeerd op het bestaande skelet. De knots wordt ongeveer 1,02 m boven de rusthoogte getild; de slag eindigt laag. Het lichaam kantelt, één voet maakt een kleine vangstap en dop/blad lopen iets na. Geometrie en skinweights zijn gecontroleerd gelijk gebleven; het broncheckpoint staat onder `checkpoints/before_readable_attack_20260913.blend`. `EnemyAttackDefinition` houdt alle gameplayvensters instelbaar en EnemyBrain houdt één schadecontact per slag.

De gerichte replay bevat nu 51 controles, waaronder stilstaand herstel zonder tweede schadecontact. De bronreview gebruikt de huidige geïmporteerde clipduren en de Resource-timing, geen verouderde hardgecodeerde fasegrenzen.
