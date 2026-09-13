# Uitgevoerde controles — 10 september 2026

Godot 4.7.2 stable (ed1daf0bf), Forward+ via Metal op Apple M4 Pro. Blender 5.2.1 LTS via Blender MCP. Alle replays gebruiken 120 Hz physics.

## Actuele combat

`tests/energy_replay.gd`: **80 controles geslaagd**, in zichtbaar draaiende Metal-games bij renderlimieten 30, 60 en 120. Getekende frames: respectievelijk **549, 1099 en 1753**; wandkloktijden 18,542 / 16,698 / 18,565 s. De laatste 60-run is opgenomen. De movie heeft 18,33 s vaste frametijd; movie-opname is geen realtime prestatietest. Dit zijn echte tekenframes, geen headless screenshots.

Gecontroleerd: normale treffers op 0,85 / 1,25 / 1,65 / 1,85 m; meerdere doelen per slag; geen dubbele schade door echte blade plus energie of meerdere hurtboxes; één magieherstel; geen schade vóór het actieve venster of achter de speler; geen treffer door de trap-/muurcore; geladen bereik en 3 schade; dezelfde 3D-basis/radius voor effect en query; hurt-/respawn-opruiming. 24 willekeurige stijlen raken hun voorwaartse doel één keer en gebruiken alle zes botclips. Een reeks van zes geldige late kliks wisselt exact links/rechts door zonder idle-gap. Vroege spamklikken tijdens een slag worden weggegooid. Een verse klik in de laatste 0,10 s herstel begint direct de volgende slag; er is geen wachtrij. Vasthouden maakt geen extra slag. Hurt onderbreekt; zonder volgende klik stopt de reeks.

De normale/geladen radius blijft **1,9/2,4 m**. Dit is de energieradius vanaf de bewegende speler; lunge en doelomvang beïnvloeden de afstand tussen objectmiddens waarop een treffer mogelijk is. Slagrichting is vast afwisselend; de stijl wordt willekeurig gekozen zonder directe herhaling. Lichte slagen zijn horizontaal of maximaal 20 graden schuin. De geladen zichtbare energiebaan is verlaagd naar 0,75 m en 16 graden; effect en schade volgen dezelfde baan. De groepstest raakt daarmee opnieuw alle zes nabije vijanden.

`tests/swing_style_replay.gd`: **54 controles geslaagd**, zes afzonderlijke stijlen/richtingen, met 264 getekende frames. Voor iedere clip zijn de werkelijk geïmporteerde zwaardpuntbeweging, slagrichting, grondvrijheid, horizontale straal over de boog, een treffer op 1,85 m en twee gelijktijdige doelen gecontroleerd. Gemeten verticale verplaatsing van de zwaardpunt tijdens de actieve fase: horizontaal −0,021 / +0,0004 m; stijgend +0,408 / +0,408 m; dalend −0,412 / −0,405 m.

Heavy-charge is **0,45 s** in plaats van 0,60 s. De gehele bronclip wordt over die kortere tijd afgespeeld. De melee-suite controleert de automatische vrijgave tegen deze instelling; de zichtbare energy-replay controleert de geheven laadpose en de eigen zware impactclip.

## Gedeelde regressies

Na de controller-, clipselectie- en wapenwijzigingen: alle onderstaande suites geslaagd voor **red_panda, crow én capybara**, cap60, headless. Na het corrigeren van de geladen Sunblade-energiebaan is de panda-groepstest opnieuw uitgevoerd en geslaagd. De actuele energy-runs bevatten deze correctie ook.

| Suite | Controles per profiel |
|---|---:|
| Melee/beweging/actietijd | 76 |
| Boog/magie/onderbreken | 69 |
| Vijand/aanvalstokens | 46 |
| Controller/menu | 42 |
| Groepen vijanden | 33 |

Headless resultaat bewijst gameplaylogica; het bewijst geen FPS of animatiekwaliteit. Rapporten: `captures/suite_summary_<character>.json` en de daarin genoemde losse JSON-bestanden.

## Camera, kamer en HUD

`room_replay.gd`: **34 controles geslaagd** bij caps30/60/120. Camera/looproute zijn gelijk gebleven; cap60 is na de laatste combat/HUD-aanpassing opnieuw zichtbaar uitgevoerd: **1153 tekenframes in 19,692 s**. De eerdere 30/120-runs hadden 586 / 1681 frames en bevatten de toenmalige vlamicons; alleen de laatste HUD-screenshots tonen de gevraagde gele bolletjes. Een cap120-run is geen bewijs dat de machine stabiel120 fps levert.

Gemeten horizontale cameralag: circa0,798 m bij4,5 m/s; na loslaten en0,6 s uitlopen nog circa0,030 m. De lange trap bereikt4,000 m; de camera volgt in hoogte met maximaal circa0,211 m achterstand. Omkeren, uitlopen, begrenzen, pauze, hitstop, respawn, brug, korte/lange trap, diagonale snelheid en HUD-consumptie/herstel zijn gecontroleerd.

## Bron en visueel bewijs

- Nieuwe zware Actions en reverse-finisher zijn in Blender van voren, links, rechts, achteren en vanuit een hoge camera bekeken: `captures/lantern_village/heavy_source_windup`, `heavy_source_impact`, `reverse_finisher_source`.
- Zes nieuwe lichte Actions zijn op het bestaande model gemaakt. Elke clip is bij begin en einde van de actieve fase van voren, links, rechts, achteren en vanuit de spelcamera gerenderd en bekeken: **60 actuele bronbeelden** in `light_<style>_<direction>_<start|end>/`.
- Exportinspectie: **29 clips**, root in alle clips vast, geen gevonden export-/skincontrolefouten. Bron: `assets/characters/red_panda/source.blend`. De eerdere `--pose-review` van 23 poses is historisch; de zes nieuwe clips zijn afzonderlijk in de actuele zichtbare style-replay gecontroleerd.
- De standaard import op 30 samples/s gaf de korte stijgende rechterzwaai een verkeerde tussenpose. De bewerkbare GLB-import gebruikt nu **120 samples/s**, gelijk aan physics. Vergelijking van socketposities in Blender en Godot bevestigt de correctie. De importcache is niet handmatig aangepast.
- Actuele gameplaybeelden: [geladen slag](../captures/lantern_village/room_energy_charged.png), [schuine lichte slag](../captures/lantern_village/room_energy_random_1.png), [lange trap](../captures/lantern_village/room_long_stair_ascent.png), [HUD](../captures/lantern_village/room_hud_four_health.png).
- [Combatdemonstratie](../captures/lantern_village/combat_variation_demo.mp4), 18,33 s: bereikproeven, snellere geladen slag, varianten, een doorlopende reeks met verse klikken en controle dat spam geen vervolgaanvallen opslaat. Testteleports en doelresets tussen losse proeven zijn bewust zichtbaar.
- [Zes slaganimaties van dichtbij](../captures/lantern_village/light_swing_styles_demo.mp4), 4,42 s: horizontaal, stijgend en dalend in beide richtingen. Alleen deze test gebruikt een dichter camerastandpunt; normale gameplay blijft op 13 m.
- `camera_stairs_hud_demo.mp4` is de eerdere trap-/cameraopname en bevat nog de vlamicons. Gebruik de actuele screenshots om de uiteindelijke HUD te beoordelen.

## Grenzen van deze oplevering

Het karakter behoudt het bestaande chibi-model en heeft nieuwe zware botposes; dit is geen claim van perfecte1:1 gelijkenis. Het grote hoofd kan hand en lemmet uit sommige achteraanzichten gedeeltelijk bedekken. De kleding blijft eenvoudige skinned geometrie; geen cloth-simulatie. Trappen gebruiken een gladde hellingcollider, zonder afzonderlijke voet-IK per trede. De kamer blijft een open prototype met eenvoudig water.

Sommige Godot-sluitingen melden één niet-vrijgegeven shader/RID. Bij gelijktijdige games kan de debugconnector bovendien port9090 bezet melden; de zelfsturende replays gebruiken die verbinding niet. Er waren geen scriptfouten of mislukte assertions in de genoemde eindruns. De vastgelegde bronbeelden, screenshots en getekende frames zijn de visuele onderbouwing; een export alleen is dat niet.

Machineleesbare samenvatting: `captures/lantern_village/final_validation.json`. Instellingen en onderhoud: `COMBAT_SWINGS.md`, `CAMERA_FOLLOW.md`, `ARCHITECTURE.md` en de bijgewerkte projectskill.
