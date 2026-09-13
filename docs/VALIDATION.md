# Gecontroleerd op 9 september 2026

Werkelijk gestart en bestuurd met Godot MCP en grafische replays op **Godot 4.7.2.stable.official.ed1daf0bf**, **Forward+ / Metal 4.0**, Apple M4 Pro. Blenderbron en exports: **Blender 5.2.1 LTS**.

## Huidige regressiematrix

Alle onderstaande controles zijn grafisch uitgevoerd met **120 Hz physics**. De gemeten renderfrequentie komt uit `Engine.get_frames_drawn()` gedeeld door verstreken kloktijd, niet uit alleen de ingestelde cap.

| Personage | Rendercap | Werkelijk getekende fps, bereik over suites | Geslaagd |
|---|---:|---:|---:|
| crow | 30 | 29.33–29.96 | 195/195 |
| crow | 60 | 59.61–59.82 | 196/196 |
| crow | 120 | 118.93–119.27 | 195/195 |
| capybara | 30 | 29.87–29.93 | 195/195 |
| capybara | 60 | 59.60–59.82 | 196/196 |
| capybara | 120 | 119.00–119.47 | 195/195 |

Dit zijn 1172 uitgevoerde assertions over beide personages en drie caps, plus 21 geslaagde controles van de opstartkeuze. De melee-suite heeft op 30/120 caps 63 checks; bij de laatste 60-caprun is een extra praktijktest toegevoegd voor werkelijk drie schade en één magieherstel bij een volledig geladen treffer. Boog: 69, vijanden: 21, controller: 42 per run. `captures/final_validation_matrix.json` verwijst naar alle onderliggende rapporten.

De nieuwste 120-capruns tekenden daadwerkelijk ongeveer 119 frames/s. Oudere runs kwamen op deze Mac slechts rond 60 uit; die oudere beperking geldt niet voor de hierboven gemeten runs.

## Gemeten gedrag

- Vanuit stilstand circa 4,2937 m in één seconde; recht en diagonaal verschillen minder dan 0,00001 m. Maximale snelheid 4,5 m/s. Resultaten zijn gelijk over rendercaps en personages.
- Vrije rol 3,3600 m in 0,425 s gemeten; ingestelde clip 0,42 s, afronding op 120 Hz. Collider blijft rechtop. Muren blokkeren lopen, rollen en lunge; vloer heeft één doorlopende collider.
- Heavy release 0,6500 s, gemeten actief 0,15833 s bij een ontwerpvenster van 0,16 s. Overige actie-/hitvensters blijven binnen één physicsstap. Richting, buffers, combo, i-frames en onderbrekingen zijn getest.
- Vol laden vuurt boog en heavy één keer automatisch af. Vroeg loslaten, dodge, hurt, death, hitstop, pauze en herstart blijven gecontroleerd. Langzamer bewegen tijdens laden; volle beweging tijdens lege-boogweigering.
- Vier pijlen verbruiken vier magiepunten. Vijfde schot wordt geweigerd. Melee herstelt maximaal één punt per swing, ook met twee doelen/hurtboxes; missen en pijlen herstellen niets. Normale en dubbele pijlschade, eerste raakpunt en muur-/muzzleblokkering slagen voor beide rigs.
- De pijl verschijnt op 0,03333 s van de releaseclip, de eerste physicsstap na het ingestelde 0,03 s. Bij een vrije muzzle is de afwijking tussen zichtbare punt en projectielpositie 0 m. De capibara-release ligt rond 0,666 m hoogte, onder de 0,7 m muur. Een blokkade beëindigt het schot vóór de muzzle.
- Vijanden delen maximaal twee tokens. Scoring, vrijgeven bij hit/death/reset, aankondiging, vaste slaghoek, muurpad, pauze en een gecommitteerde terugkeer na de leash zijn gecontroleerd.
- Controllerreplay: LS/RS, vierkant, kruisje, R2, kruisje→R2, L2+rondje, driehoek, D-pad, Options/touchpad, tabs, focus, bevestigen/terug zonder gameplaylek, gesimuleerde disconnect en herstart na dood. Native GUI-tests wachten op deferred focus/layout; gameplayduurtests blijven op physics.

## Visueel bekeken

`captures/character_select.png` toont de werkelijke keuzescene. De selector-replay kiest beide typen via controller-events, controleert hun echte visual/capsule, één zwaard, rollen, respawn en terugkeer naar de selector.

`captures/pose_review/<id>/` bevat alle 21 kraaiclips en 22 capibaraclips van voren, achteren, beide zijkanten en met de exacte cameraoriëntatie uit TestArena. Contactbladen plus afzonderlijke beelden zijn bekeken. Dit zijn vaste poses van de echte import; de bewegende demonstraties leveren aanvullend bewijs voor overgangen, stappen, rollen en aanvallen. Blender-neutraalbeelden staan onder `captures/capybara/neutral_*.png`; de bewerkbare bron is opnieuw gebruikt voor de laatste vier aanzichten.

De laatste frontale posecontrole vond zwarte strepen door het kraaiborstvlak bij lopen en boogspannen. De cream-vlakken volgen nu barycentrisch dezelfde gewichten als de onderliggende romp, met 3 mm afstand. Hun oppervlakte verschoof minder dan 1,4 mm; de rompgeometrie, botten en Actions zijn behouden. De kraai is opnieuw geëxporteerd en in de game bekeken; de ongewenste banden zijn verdwenen. De posebeelden en kraaidemo zijn daarna vernieuwd.

`captures/capybara_showcase.mp4` en `captures/crow_showcase.mp4` zijn respectievelijk 10,27 en 10,28 s daadwerkelijke Movie Maker-opname: lopen, rollen, vier schoten, lege-boogweigering tijdens beweging, meleeherstel, opnieuw schieten en een volledig geladen slag. De demo logt vier schoten/magie 0 en vervolgens meleeherstel naar 1. Screenshots `*_bow_draw`, `*_arrow_flight`, `*_melee_refill`, `*_heavy_charge` en `*_charged_cleave` komen uit die opname.

`captures/controller_showcase.mp4` en `controller_controls.png` tonen de controllerprompts. `enemy_warning_000/025/050/092/100.png` toont de echte aankondigingsshader: voorwaarts vullen, amber tijdens laden, korte voorflits en actieve fase. Deze statische samples bewijzen uiterlijk; de vijandreplay bewaakt de echte timing.

## Assetcontrole en grenzen

GLB-audits vinden 21/22 afzonderlijke clips, vaste roots en genormaliseerde skinweights. De capibara heeft 23 botten, 35 meshes en 80.888 driehoeken; de kraai 25 meshes en 75.816 driehoeken. De losse zwaarden staan buiten de karakter-GLB's. `assets/manifest.json` wordt uit de bestanden gelezen.

De capibara is een gestileerde volumetrische interpretatie van het referentieblad. Hoofd/snuit, kleine ogen, verbonden ledematen, warme kleuren en afwezigheid van kleding/staart zijn overgenomen. De snuit-/oogovergangen en fijne vacht zijn nog niet exact gelijk aan het referentiebeeld. De posecontrole is geen bewijs van een volledige 1:1 gelijkenis of afwezigheid van iedere mogelijke penetratie in alle blends.

Een fysieke PlayStation-controller was niet aangesloten. De bindings, stickevents en native GUI zijn getest met echte Godot InputEvents; fysieke herkenning, drivergedrag en trilling zijn nog niet met hardware gevoeld/gecontroleerd.

Bij afsluiten meldt deze Godot-run nog `ParticlesShaderRD`/`ShaderE` resources die niet waren vrijgegeven. Deze melding is niet opgelost; de regressies bevatten geen gameplay-scriptfouten. Godot MCP kan daarnaast waarschuwingen uit zijn eigen interactiescript loggen. Er is geen engine-upgrade uitgevoerd.

Historische meetpunten staan in `docs/archive/validation_previous.md`; oude input-/chargeclaims daarin beschrijven eerdere versies.
