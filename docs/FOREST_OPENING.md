# Eerste bosarea

F5 opent het bestaande titelscherm. **New Game** gaat naar `scenes/levels/ForestOpening.tscn`; Testscene blijft instelbaar en opent standaard TestArena. ForestOpening en de afzonderlijke `ForestAssetGallery.tscn` zijn ook direct met F6 te starten.

De panda zit op de grote stronk, staat op, springt met echte physics naar de grond en krijgt daarna de besturing terug. Drie vlinders vliegen langs het begin. Het kronkelende pad loopt om een grasplateau, langs een vijver met twee watervalstappen, naar de Eikelwachter bij de doorgang. Restart begint op veilige grond en herhaalt de introductie niet.

## Bewerkbare assets

De zeven aangeleverde referenties staan ongewijzigd in `assets/references/forest/`. Ze bepalen vorm, kleur en verhoudingen; de overzichtsafbeelding is de visuele richtlijn, geen platte achtergrond in de game.

Elke losse asset heeft een `source.blend`, `model.glb` en een opgeslagen wrapper in `scenes/assets/environment/<id>/Visual.tscn`:

- Grote stronk met brede wortels, gouden zaagvlak, jaarringen, zijtak en mos.
- Loofboom en drie dennenvarianten, holle boomstam, rotsen, kiezelgroep en rotsmodule.
- Varen, struik, blauwe en crèmekleurige bloemen, paddenstoelen, riet en waterlelie.
- Hek, poort en vlinder met afzonderlijke vleugelgroepen.
- Zes grondmodules van 2 × 2 m: gras, recht pad, hoek, kruising, open plek en helling.
- Het level heeft afzonderlijke grond- en rotswandbronnen met exact aansluitende plateaugrenzen.

`assets/environment/forest_opening.blend` bewaart dezelfde plaatsingen als de Godot-scene. `forest_layout.json` is het offline plaatsingsmanifest. Water, botsingsvormen, panda, vijand, lantaarn, camera en licht staan als opgeslagen nodes in de levelscene. De Blender-assembly bevat de omgevingsasset-instances; gameplayactors en Godot-watermaterialen staan in de Godot-scene.

## Authoring en export

De opgeslagen Blender-bronnen zijn leidend. `build_assets.py` is een expliciete herbouw van de nieuwe boskit; voer die niet automatisch uit over latere handmatige verfijningen. Gebruik `--only=forest_<id>` voor een gerichte herbouw.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/forest/review_assets.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/forest/export_assets.py
python3 tools/forest/author_level.py
python3 tools/forest/author_gallery.py
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/forest/assemble_source.py
```

Bekijk vóór export front, beide zijden, achterkant en spelcamera onder `captures/forest/assets/`. De exporter bundelt statische onderdelen per materiaal op een tijdelijke werkversie; hij overschrijft de bewerkbare bron niet. De vlinder behoudt zijn vleugelhiërarchie. Import-LOD is voor deze kleine referentie-assets uitgeschakeld.

Bij terreinwijzigingen wordt `author_ground.py` eerst in Blender uitgevoerd. Die knipt grasplateaus en omringende grond geometrisch op hun echte veelhoekgrens; pad/gras gebruiken één gedeeld oppervlak met een interpolerend masker. De oppervlaktecontrole telt 4671 m² zonder dubbel bezette zichtbare voetafdrukken, met een uitsparing voor de vijver. Er zijn geen op elkaar gelegde gras-/padvlakken met kleine hoogteverschillen. De rotswandbron wordt daarna visueel gereviewd en via de afzonderlijke exporter geëxporteerd.

## Introductie en vijand

`settings/forest_entrance.tres` configureert de nieuwe `EntranceSequence`. `PlayerCharacter` bezit actietijd, sprong, zwaartekracht en landingsdetectie. De nieuwe panda-Action `entrance` voegt zitten/opstaan toe; de geaccepteerde geometrie, skinweights en bestaande 31 clips zijn behouden. De bron bevat nu 32 Actions. Het checkpoint van vóór deze toevoeging staat in de character-map.

Pause en hitstop bevriezen de gedeelde GameClock, inclusief vlinders en water. De ingang buffert geen aanval/dodge. De compacte HUD verschijnt na landing; normale gameplayinvoer krijgt dezelfde bestaande overgangsblokkade. Hurt/death blijven prioriteit houden.

De Eikelwachter heft zijn losse knots zichtbaar, geeft één klap en kantelt kort met een vangstap. Zijn instelbare herstelvensters zijn 0,80 s en 0,90 s, zodat een tegenaanval mogelijk is. Er is geen tweede schadepuls tijdens het herstel. Zie [ACORN_GUARD.md](ACORN_GUARD.md).

## Visuele diagnose

De ervaren pixelvorming is apart gecontroleerd met schaduwen en SSAO uit, zachtere schaduwsampling, actuele bronbeelden en geïmporteerde close-ups. De belangrijkste afwijkingen kwamen uit grove/repetitieve vormen, harde materiaalovergangen en schaduwen. Een verkeerd gekozen SKY-bron zonder Sky verhinderde de bedoelde omgevingskleur; het bos gebruikt nu COLOR (2). MSAA en TAA blijven ingeschakeld. De uiteindelijke kleuren worden ook in de draaiende Forward+ Metal-game gecontroleerd.

De onafhankelijke referentievergelijking en resterende verschillen worden na iedere ronde vastgelegd in `.dream-loop/forest/`. Dit is nog geen claim van 1:1-overeenkomst. Vooral het precieze bladprofiel, mos, rotsranden, terreinverdeling en lichtsfeer vragen een visueel oordeel; een geslaagde replay bewijst die overeenkomst niet.

## Controles

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --forest-replay --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --forest-replay --forest-overview --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/ForestAssetGallery.tscn -- --forest-asset-review
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/ForestOpening.tscn -- --forest-movie --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --intro-replay --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . res://scenes/levels/PrototypeRoom.tscn -- --acorn-replay --fps=60
```

De forestreplay controleert de startpose, pauze, input, sprong/landing, HUD, beweging, de hele route en restart. Caps30/60/120 zijn apart gecontroleerd; JSON-rapporten vermelden echte renderframes en tijd. De Acorn-replay heeft 51 checks en de introreplay 24. Native close-ups staan onder `captures/forest/native_assets/`; `render.json` bewaart de renderer en getekende frames.

De gedeelde melee-, boog-, controller- en crowdregressies slagen voor panda, kraai en capybara bij cap60. De al bestaande enemy-toelatings-/routefout bij de gewijzigde TestArena-muur blijft open en staat los van de begaanbaarheid van het bospad. Godot kan bij afsluiten een shader/RID-lek melden. Een tweede draaiend Godot-proces kan bovendien de bestaande MCP-poort bezetten; screenshots hierboven komen uit de eigen native replay, niet via die poort.

## Uitgebreid en rustiger bos

De bestaande assetkit is opnieuw geplaatst rond één route van circa **90 meter**. De grondcollision beslaat 38 × 86 m; het zichtbare terrein, inclusief de hoge bosranden, heeft 4671 m² exclusief de vijveruitsparing. Er staan **357** opgeslagen omgevingsinstances in het manifest, tegenover 745 in de eerdere kleine area. De losse planten zijn in kleine groepen langs de randen gezet; het zandpad is circa 2,4 m breed en heeft rustige open plekken.

Verbonden rotsbanken met collision sluiten beide zijkanten en de achterkant af. Vanaf de stronk gaat de route langs de vijver en Eikelwachter, vervolgens langs Mos en een leesbare wegwijzer, door de rustige bosbochten naar de lantaarnpoort. De oorspronkelijke extra vlindergroep, tweede Eikelwachter en tweede bosbewoner uit de editor zijn behouden in `tools/forest/authored_details.tscn.inc`. Hun plaatsing is geen runtimegeneratie.

De bovenste `ForestExit` is nu een herbruikbare **ScenePortal** naar `ForestPassage`: een tweede bosgedeelte met een huis. De voordeur opent `ForestHouse`, waar Linde een bewerkbaar gesprek heeft. De deur en bospoort werken ook terug. Target Scene, Target Spawn, Trigger Size en de stap-/fadetiming zijn per portal instelbaar. Zie [SCENE_TRANSITIONS.md](SCENE_TRANSITIONS.md).


De camera blijft 13 m orthografisch, met dezelfde vaste hoek en halfwaardetijden. Alleen de begrenzing volgt het grotere level. Atlas-sampling gebruikt afgeleiden van de ononderbroken UV's, zodat mipmaps geen dun raster met kleuren van andere atlasvakken op de grond veroorzaken.

Voor het herbruikbare gesprekssysteem, de instelbare Praten/Lezen-labels en het naar de speler draaien: zie [DIALOGUE.md](DIALOGUE.md).

De eerdere assetvergelijking met de aangeleverde referenties bleef op 5,6/10. Deze revisie volgt de nieuwe opdracht om de bestaande assets te hergebruiken voor een groter en rustiger level; de individuele modellen zijn niet opnieuw ontworpen en er wordt geen 1:1-overeenkomst geclaimd.

Actuele replaymetingen staan in `FOREST_VALIDATION.json`. De forestreplay loopt van de stronk naar de eerste vijand, schakelt daarna gevechten alleen voor de navigatietest uit en wandelt de resterende route zonder teleportatie. Afzonderlijke vertrekproeven controleren de fysieke bosranden. De cameracontrole vergelijkt bij de uitgang met de begrensde volgpositie.

![Actuele bosopening met de bestaande assetkit](images/forest-current.png)
