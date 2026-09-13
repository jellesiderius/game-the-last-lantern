# Actuele controle — 9 september 2026

De controllerindeling is grafisch getest in Godot 4.7.2 Forward+ Metal met dezelfde 120 Hz physics. De reeks op rendercap60 bevatte 59 melee-, 69 boog-, 19 vijand- en 42 controllerchecks: alle189 geslaagd. De resultaten staan in `captures/{runtime,bow,enemy,controller}_checks_60.json`. De controllerreplay stuurt echte Godot InputEvents door de opgeslagen InputMap en de native GUI. Een fysieke PlayStation-controller is nog niet handmatig getest; trilling en apparaatdetectie bij fysiek aansluiten zijn dus niet visueel/haptisch bevestigd.

Gecontroleerd: kruisje rollen, vierkantcombo, R2 laden/vroeg loslaten/automatische volle slag, kruisje→R2 rolaanval, L2+rondje spannen/loslaten, één automatische volle pijl zonder herhalen, leegte zonder snelheidsverlies, neutrale stick/muis, rechterstick-camera met vaste basis, driehoekinteractie, vergrendelde D-pad-slots, menu-focus/tabs/instellingen, bevestigen/terug zonder gameplaylek, gesimuleerde disconnect tijdens laden en controllerherstart na dood.

De beelden `controller_controls.png`, `controller_bow_draw.png` en `controller_arrow_flight.png` komen uit een draaiende grafische showcase. `enemy_warning_000/025/050/092/100.png` samplet de echte shader/presenter op die windupfracties (100 is de actieve fase). Deze samples controleren uiterlijk; de vijandreplay controleert de daadwerkelijke voorbereidingstijd en tokenlimiet. De waarschuwing vult van de voorrand terug, blijft tijdens laden amber en heeft vlak voor de slag een korte lichtpuls.

De versies/cijfers hieronder zijn oudere meetpunten. Hun oude LT/RT- en charge-holdregels zijn vervangen door de bovenstaande bediening; ze bewijzen niet dat latere wijzigingen op alle eerdere rendercaps zijn gemeten.

---

# Uitgevoerde controles

Getest op Apple M4 Pro met **Godot 4.7.2.stable.official.ed1daf0bf**, **Forward+ / Metal 4.0** en **Blender 5.2.1 LTS**. Het project is daadwerkelijk grafisch gestart, via Godot MCP bestuurd en met echte physicsreplays getest. De runtime-screenshots en Movie Maker-opnamen komen uit de game.

## Geautomatiseerde checks

`runtime_replay.gd` heeft 59 checks; `bow_replay.gd` heeft 44 checks. De JSON-bestanden in `captures` bevatten elke assert en meetwaarde. De physicsfrequentie blijft 120 Hz; rendercaps worden afzonderlijk ingesteld. `observed_render_fps` onderscheidt de ingestelde cap van werkelijk getekende frames.

Laatste grafische regressierun: **alle 309 assertions geslaagd** (103 per ingestelde rendercap).

| Rendercap | Werkelijk melee / boog | Physics | Melee | Boog |
|---|---|---|---|---|
| 30 | 29.63 / 29.98 fps | 120 Hz | 59/59 | 44/44 |
| 60 | 59.81 / 59.74 fps | 120 Hz | 59/59 | 44/44 |
| 120 | 59.39 / 59.86 fps | 120 Hz | 59/59 | 44/44 |

**Beperking bij 120 renderfps:** de Metal/macOS-uitvoer bleef ook met uitgeschakelde VSync ongeveer 60 frames/s tekenen. De 120-caprun slaagt, maar bewijst geen echte 120-fps-rendercontrole. Werkelijke 30 en 60 renderfps zijn wel gemeten. De physicsfrequentie was steeds 120 Hz.

Recht en diagonaal is ongeveer 4,2937 m in één seconde afgelegd vanuit stilstand; beide bereiken maximaal 4,5 m/s. Een vrije rol legt ongeveer 3,3600 m af in 0,425 s. Actieduren zijn gelijk over de drie runs, binnen één physicsstap: lichte slagen 0,3667 / 0,3833 / 0,4833 s, zware release 0,6500 s en roll-attack 0,4500 s. De ingestelde windows worden uitsluitend op de gedeelde physicsklok gesampled.

Getest: rechte/diagonale snelheid, analoge invoer, camerabasis, afremmen, lopen/rollen/lunge tegen muren, alle meleeclips, afzonderlijke combo-input, vroeg en volledig zwaar laden, cancelprioriteit, roll-attack, actieve hitvensters, meerdere doelen, deduplicatie over twee hurtboxes, muren, rol-onkwetsbaarheid, hurt/death/respawn, vijandschade, pauze/hitstop en één correct opgeborgen zwaard.

Boog: zes geïmporteerde clips, vier schoten en geblokkeerd vijfde schot, geen regeneratie met tijd, vroege release, hold zonder autofire, cancel/dodge/hurt/death zonder kosten, directe Q- en RMB-events via de echte InputMap, controller LT/RT, neutrale stick en stilstaande muis, horizontaal schieten, normale/opgeladen schade, eerste doel, twee hurtboxes, muren en geblokkeerde muzzle, één magiepunt per multihit-meleezwaai, maximumvoorraad, missen, projectielpauze/hitstop en opruimen bij restart.

De afvuurmelding wordt op 0,03333 s van de releaseactie waargenomen: het ingestelde moment 0,03 s, afgerond naar de eerstvolgende 120 Hz physicsstap. De held-arrow is dan verborgen; bij een vrij afvuurpunt is de positieafwijking tussen zichtbare punt en projectiel 0 m. Een geblokkeerd afvuurpunt eindigt bij de blokkade en kan dus afwijken.

De GLB-audit controleert 19 afzonderlijke clips, een vaste root en genormaliseerde skinweights. `final_animation_floor_audit.json` bevat zeven gesamplede poses per clip. Dat is een gerichte controle, geen wiskundig bewijs voor alle mogelijke blendposes.

## Visuele controle

- Blender: voor-, achter- en zijaanzicht gecontroleerd op silhouet, borstband, achtervlakken, verbonden poten, tenen en gladde shading. De bronbeelden staan naast de opgeslagen eigen renders.
- Godot: lopen/rennen, rollen, lichte combo, zwaar laden/loslaten en boog bekeken vanuit de spelcamera. De romp helt bij rennen verder voorover; de benen bewegen afzonderlijk. Een vrije renpose is gebruikt voor de opname, omdat een stilstaande kraai tegen een muur geen bewijs van de renanimatie is.
- Het ene zwaard zit centraal op de rug, met de punt ongeveer 0,10 m boven de vloer in rust. Tijdens melee gaat hetzelfde wapen naar de vleugel. Tijdens booggebruik is het verborgen en wordt hitdetectie uitgeschakeld.
- De grote rode melee-sikkel is naar voren begrensd. De boog heeft dezelfde rood-roze kleurstelling, een grotere heldere pijl en een korte richtlijn van maximaal 2,2 m. Glow is gecontroleerd in Forward+ Metal.
- De boogdemo bevat vier schoten, een lege voorraad, een meleehit die één punt herstelt en opnieuw schieten. Bij het herstel is de runtimewaarde `magic=1, shots=4` gelogd.

Laatste opnamen: `bow_showcase.mp4` bevat 571 frames op 60 fps (9,52 s); `showcase.mp4` 551 frames (9,18 s). De nieuwe `bow_aim.png`, `arrow_flight.png`, `combat_active.png` en `running_game.png` zijn uit deze grafische runs vernieuwd. Daarnaast is Q via Godot MCP bij de normale camerasize 14 vastgehouden en losgelaten: tijdens spannen 4 magie/0 schoten, daarna 3 magie/1 schot, locomotion en zichtbaar zwaard.

## Grenzen van het bewijs

De crow is een zelf gemodelleerde benadering van het referentieblad. De snavelcontour, enkele veerovergangen en fijne achterhoofd-/vleugelvormen zijn nog geen letterlijke 1:1-reconstructie. Er is geen visuele perfectieclaim. De bestaande karaktermeshes zijn bij de booguitbreiding behouden.

Keyboard/muis en gamepad zijn met echte Godot-invoerevents gecontroleerd; een fysieke Xbox-controller is niet handmatig gebruikt. De eenvoudige vijand, dummies en kleine arena zijn een prototype, geen duurtest van een groot level of een volledige game.

De gebruikte Godot-build meldt bij afsluiten één niet-vrijgegeven `ParticlesShaderRD`/shader-RID (headless: `DummyShader`). Deze melding verschijnt bij engine shutdown; tijdens de geslaagde gameplayreplays zijn geen GDScript-fouten opgetreden. De MCP-hulpautoload geeft daarnaast enkele eigen type-/naamwaarschuwingen. Een tweede gelijktijdig draaiende game kan diens lokale poort 9090 bezetten; voor interactieve MCP-controle is één game gebruikt.

Een eerste Movie Maker-poging verloor renderframes doordat het venster bedekt was. Die is vervangen door een opname met zichtbaar reviewvenster en gecontroleerd frameaantal. De beschikbare screenshots/video moeten samen met de JSON-resultaten worden beoordeeld.
