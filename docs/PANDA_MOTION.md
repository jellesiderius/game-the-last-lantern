# Panda-beweging — 13 september 2026

De bestaande chibi-panda heeft nieuwe idle-, walk- en run-clips. De rechterarm draagt het zwaard laag en schuin naar voren, met een beperkte tegengestelde zwaai tijdens bewegen. Beide benen hebben een expliciete steun- en terughaalperiode; romp, hoofd en drie staartsegmenten leveren secundaire beweging. De korte benen en ronde lichaamsvorm zijn behouden.

## Bron en instellingen

- Bewerkbare bron: `assets/characters/red_panda/source.blend`; volledig origineel checkpoint: `assets/characters/red_panda/checkpoints/before_motion_20260913.blend`.
- Offline authoring: `tools/lantern_village/refine_panda_motion.py` vervangt alleen drie locomotion-Actions. `blend_panda_carry.py` leest het checkpoint en verbindt begin/herstel van 19 bestaande Actions aan de nieuwe rusthouding. Deze scripts zijn gerichte revisies, geen algemene generators om over latere handmatige bewerkingen te draaien.
- Idle 2,4 s, walk 0,8 s, run 0,56 s; afspelen volgt werkelijke bewegingssnelheid. De laatste gebruikerscorrectie verhoogde de eerste vertraging van 3,2 naar **3,8 m/s**.
- De volledige loopfase wordt gedeeld tussen walk en run. Snelheidsblending duurt visueel enkele frames; botsingen stoppen de voetklok wanneer de speler werkelijk stilstaat. Pauze/hitstop blijven onder GameClock.
- Bron/export bevatten 31 Actions; actieve aanvalbanen, charge-duur en schadebereik zijn behouden. GLB-import blijft 120 samples/s.

## Controle en bewijs

`captures/panda_motion/source_audit.json` bevestigt ongewijzigde meshvertices en skinweights. `contact_audit.json` meet elk bronframe: voetzolen blijven boven de vloer, verbonden beengewrichten hebben minder dan 0,000001 m afstand. De korte zweeffase bij run is onderdeel van de cyclus. Dit bewijst geen perfecte voetplaatsing op trappen: runtime voet-IK blijft afwezig.

De actuele Blender-bron is van voren, beide zijkanten, achteren en vanuit de spelcamera gerenderd in `captures/lantern_village/panda_motion_run/`. De posevergelijking haalde 8,1/10 bij de onafhankelijke tweede visuele controle; dat cijfer beoordeelt stills, niet op zichzelf het bewegingsgevoel.

Native Godot-replays:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/PandaLocomotionReplay.tscn -- --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/PandaMotionReview.tscn -- --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/OcclusionReview.tscn -- --fps=60
```

De locomotion-replay meet verplaatsing, pasfrequentie, zwaardpuntvrijheid, stoppen, pauze, actieterugkeer en daadwerkelijk getekende frames. Alle acht basiscontroles slagen in Forward+ Metal bij caps30/60/120; gemeten rendering is respectievelijk 29,97 / 59,99 / 120,03 FPS. Snelheid is 3,800 m/s, pasfrequentie 5,793 stappen/s en de laagste zwaardpunt 0,0432 m boven de vloer. Een aanvullende negende controle bij cap60 meet gemiddeld 0,020 m/s resterende voetbeweging tijdens het vlakke steundeel, tegenover 3,8 m/s lichaamsbeweging. Dit betreft de vlakke testbaan.

De reviewmovie gebruikt Godots vaste 60-FPS movieklok; frames achteraf simpelweg op 60 FPS zetten zou vertraagde screenshotopname onterecht versnellen. Opname: `captures/panda_motion/panda_motion.mp4`. De 80 energy-replaycontroles slagen na de definitieve carry-export.

Melee, bow, controller en crowd slagen bij cap60 voor alle drie karakterprofielen. De legacy replayfixture selecteert benoemde oefendoelen en gebruikt vrije bewegingsbanen om nieuw geplaatste decoratie/NPCs te vermijden. De enemy-suite heeft nog een open toelatingstest: een vijand bereikt zijn aanvalspost bij de gewijzigde TestArena-muur niet binnen de testdeadline. Dit is geen geslaagde volledige regressiematrix. De gebruikersscene en AI-besturing zijn hiervoor niet teruggedraaid.

## Occlusie

`settings/occlusion_silhouette.tres` stelt **#414342** in. De helper `OcclusionSilhouette` gebruikt het ingebouwde [XRAY-stencilmateriaal](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#stencil), met eigen materiaalkopieën per actor. Hij ondersteunt de BaseMaterial3D-oppervlakken van de huidige spelers/NPCs en meegenomen socketprops. Hij maakt geen duplicaat-skelet of runtime mesh.

`captures/occlusion/` bevat volledige occlusie, gedeeltelijke occlusie, vrij zicht, schadefeedback en een verborgen rolpose. `render.json` registreert renderer, renderframes en de daadwerkelijk geladen hexkleur. Tonemapping kan de uiteindelijke schermpixel iets veranderen; de bronkleur is exact de gevraagde hexwaarde. Zichtbare lichaamsdelen houden hun gewone materiaal, verborgen delen vullen het silhouet aan.
