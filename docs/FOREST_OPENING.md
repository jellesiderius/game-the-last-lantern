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

Bij terreinwijzigingen wordt `author_ground.py` eerst in Blender uitgevoerd. Die knipt grasplateaus en omringende grond geometrisch op hun echte veelhoekgrens; pad/gras gebruiken één gedeeld oppervlak met een interpolerend masker. De oppervlaktecontrole telt 2091 m² zonder dubbel bezette zichtbare voetafdrukken, met een uitsparing voor de vijver. Er zijn geen op elkaar gelegde gras-/padvlakken met kleine hoogteverschillen. De rotswandbron wordt daarna visueel gereviewd en via de afzonderlijke exporter geëxporteerd.

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

## Stand van deze revisie

De speelbare scene bevat 745 opgeslagen omgevingsinstances. De nieuwste onafhankelijke stijlvergelijking scoort 5,6/10, gelijk aan de vorige ronde. De grote herziening verbeterde de totale referentiematch dus niet verder. Volgens het stall-criterium van de gevraagde dream-loop-workflow wordt eerst feedback gevraagd over de boomkronen, rotsvlakken en kleine planten. De verdere vormgeving is niet als afgerond gemarkeerd.

De nieuwste native bosreplays slagen alle 11 checks op elke cap. Stabiele metingen na opwarming: 30,03 FPS bij cap30, 60,11 bij cap60 en 120,12 bij cap120. De schone opening/aanloopopname bevat 706 werkelijk getekende frames; de geïmporteerde assetgalerij 999. De intro- en acornreplays slagen met respectievelijk 24 en 51 controles. De opname staat lokaal in `captures/forest/forest_opening.mp4`.

![Actuele native bosarea; de referentiematch is nog niet afgerond](images/forest-opening-progress.png)

Een schone checkout van commit `7a99424` importeert zelfstandig en doorstaat alle 11 boscontroles native, met 734 getekende frames en 59,97 FPS na opwarming. De assetreview plaatst zijn vloer op de werkelijke onderkant van elk geïmporteerd asset; grondmodules hebben in de opgeslagen galerij hun eigen hoogte-offset.
