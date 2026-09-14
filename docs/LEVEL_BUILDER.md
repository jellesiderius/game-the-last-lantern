# Levels bouwen

De **Lantern Level Builder** is een Godot-editorplugin. Open hem via **Level Builder** boven de 3D-weergave of **Project → Tools → Level Builder openen**. Onderaan staat alleen de assetbibliotheek: compacte modelplaatjes met volledige namen, zoeken en categoriefilters. Rechts staat **Level tools** met drie secties:

- **Bouwen**: plaatsen, schilderen, curves tekenen en rasterinstellingen.
- **Bewerken**: kies een bestaand onderdeel en verander afmetingen, hoogten of curvepunten.
- **Level**: nieuw level, areasets, grondafmetingen, controle en spelen.

De previews hebben een vaste grootte; er is geen zoomslider. Het raster past het aantal kolommen aan en kan verticaal scrollen zonder de rest van de editor weg te drukken. Ook in een smalle rechterkolom blijven de drie sectieknoppen zichtbaar. De bovenrand van de ondertab bepaalt hoeveel ruimte je bibliotheek krijgt. Als Godot openstond tijdens de installatie, sla je eigen scene op en herlaad de plugin eenmalig via **Project Settings → Plugins**.

## Beginnen

1. Kies **Bos**, **Grot · startset** of **Stad · startset**.
2. Kies rechts **Level → Nieuw level**, vul een naam, breedte en diepte in meters in. Het level krijgt een gedeelde speler, vaste gameplaycamera, belichting, HUD, effecten, grond, aankomstpunt en eigen gebiedsregistratie.
3. Selecteer een asset en klik in de 3D-weergave. Het raster toont een opgeslagen modelrender met een volledige, omlopende naam. Slepen vanuit het raster gebruikt Godots gewone sceneplaatsing; de kliktool zet het object op de ondergrond.
4. Kies **Pad tekenen**, klik punten en druk Escape om af te ronden. Selecteer de curve voor Godots verplaatsbare curvegrepen; Width bepaalt de padbreedte. Eén punt vormt een ronde open plek; meerdere overlappende paden mengen op hetzelfde grondoppervlak.
5. **Controleer level** controleert configuratie, verwijzingen en grond. **Speel level** slaat op en start het huidige level. F6 werkt eveneens.

Werkende voorbeelden: `scenes/levels/BuilderForest.tscn`, `BuilderCave.tscn`, `BuilderCity.tscn`. Bos en grot hebben gewone portals heen en terug. De grot- en stadssets zijn technische startsets met bestaande rots-/dorpsmodellen, geen afgeronde nieuwe artpacks.

## Grootte en hoogte

Kies **Bewerken → Onderdeel → Terrain** en verander **Breedte/Diepte**, of selecteer Terrain en pas **Size** in de Inspector aan: X is breedte, Y is diepte in het grondvlak. Beide worden in meters opgeslagen. Een resize behoudt paden en geplaatste objecten. Objecten worden niet automatisch verplaatst wanneer je grond verkleint. De levelroot gebruikt standaard **Auto Camera Bounds**; bij starten volgen de cameragrenzen de grondafmetingen. Zet dit uit om de grenzen zelf te bepalen. Camera size13 en 50°/45° blijven behouden.

**Terras tekenen**: klik een gesloten omtrek (minstens drie punten; het laatste punt hoeft niet gelijk te zijn aan het eerste). Selecteer het terras en stel **Height** in. De vlakke bovenkant en rotswanden vervangen de grond binnen die omtrek. Je kunt de hele omtrek verplaatsen of punten verslepen. Terrascurves gebruiken rechte polygonranden; de tangentgrepen veranderen deze randen niet.

**Ramp tekenen**: klik het lage begin en daarna het hoge einde. Een klik op een bestaand plateau laat de ramp loodrecht en vlak tegen een passende rand aansluiten. De breedte wordt zo nodig passend gemaakt. Dit werkt ook bij tekenen van boven naar beneden. De verbinding wordt bijgewerkt na wijzigingen aan het plateau, de rampbreedte of de curvepunten. Een ramp heeft twee echte 3D-eindpunten. Via **Bewerken → Onderdeel → Ramp** kun je:

- De grepen boven de groene lijntjes omhoog/omlaag slepen om begin- of eindhoogte te veranderen.
- **Bewerk curvepunten** kiezen en de uiteinden in 3D verplaatsen om positie, lengte, richting en hoogte aan te passen.
- Breedte, beginhoogte en eindhoogte intypen; deze velden lezen en wijzigen dezelfde curvepunten.
- **Plateau aan hoge kant** kiezen: de opgegeven diepte maakt een aansluitend plateau met de breedte van de ramp. De hoogte blijft gekoppeld aan het hoge rampeinde. Een hoogtewijziging via ramp of plateau houdt beide gelijk. De plateaupunten blijven bewerkbaar om het vlak groter te maken.

De nieuwe grond heeft meteen bijpassende botsing. De builder weigert een plateau buiten de levelgrenzen of boven bestaande grondvlakken. Een plateau dat je vanuit een ramp maakt volgt diens hoogte. Als je die ramp daarna horizontaal verplaatst, pas je de nieuwe plateaurand mee aan. Bij ramps die je naar een al bestaand plateau tekent blijft de randverbinding automatisch uitgelijnd. Eerdere opgeslagen ramps worden bij bewerken omgezet naar hoogtepunten met behoud van hun bestaande hoogte. Zowel tekenen als hoogte- en puntwijzigingen ondersteunen Undo/Redo.

Terrassen en ramps mogen elkaar raken, maar niet in oppervlakte overlappen. De builder controleert dit en behoudt bij een ongeldige vorm het laatste geldige grondresultaat. Gelijke aansluitende randen krijgen geen interne wand. Te steile ramps geven een fout; maak ze langer of verlaag het hoogteverschil. De automatische verbinding maakt de aansluiting loodrecht en past de breedte aan de rand aan. Laat voldoende vrije ruimte voor de ramp; overlap met andere delen of een ligging buiten de grond blijft ongeldig.

De grond gebruikt één gras/zand- of vloer/padoppervlak; er ligt geen extra padmesh boven een andere vloer. De generator bewaakt de totale oppervlakte. Padranden gebruiken een fijn masker met lineaire filtering en mipmaps, onafhankelijk van het driehoeksraster van de grond. Een grove collision-/grondresolutie maakt het pad dus niet blokkerig. Het masker wordt alleen tijdens het bewerken opgebouwd. **Resolution** bepaalt de basisresolutie; bij grote grondvlakken wordt de celgrootte automatisch vergroot om de editorbelasting te begrenzen. Zeer grote gebieden blijven een reden om meerdere verbonden levels te gebruiken. Verhoogde bruggen met begaanbare grond eronder vallen buiten dit enkelvoudige grondmodel en worden als losse complete assets geplaatst.

## Gras, steen en eigen materialen

Selecteer grond, een plateau of een ramp via **Bewerken → Onderdeel**. **Grondmateriaal** biedt **Bosgras**, **Steen** en **Aarde**. **Van areaset / grond** herstelt de standaard. Zo kan een stenen binnenruimte dezelfde gameplay en assets gebruiken als het bos zonder de gedeelde bosset aan te passen.

Met **Bouwen → Vloervlak tekenen** teken je een apart materiaalvlak op grondhoogte. Kies daarna zelf het materiaal bij Bewerken. Dat vlak vervangt de onderliggende grond binnen zijn omtrek; er liggen geen twee vloeren op elkaar. Bestaande plateaus en ramps kunnen elk hun eigen materiaal krijgen.

**Eigen kleuren / texture…** maakt een persoonlijke kopie voor het geselecteerde onderdeel en opent de Resource in de Inspector. Daar kun je grond-, pad- en klifkleur, een eigen herhalende texture en de patroonschaal aanpassen. De standaardpresets blijven behouden. Sla een eigen SurfaceStyle als `.tres` onder `settings/surface_styles/` op om hem opnieuw te gebruiken. De steenpreset heeft zachte antialiasing op voegen; padranden blijven door het afzonderlijke masker glad.

## Assets en botsingsvormen

**Asset toevoegen** kiest een GLB, glTF of opgeslagen scene. Geef naam en categorie op en kies een botsingsbeleid. De builder bewaart een `Asset.tscn` naast de visuele wrapper plus een `LevelAsset` Resource onder `settings/level_assets/`. De asset wordt aan de gekozen set toegevoegd.

- **Automatisch** bewaart bestaande collisions. Anders wordt het oppervlak van elke mesh als statische botsingsvorm opgeslagen; open deuren en gaten blijven mogelijk.
- **Geen** is voor decoratieve begroeiing.
- **Doos** maakt één eenvoudige omhullende botsingsvorm.
- **Convex per mesh** is geschikt voor losse massieve onderdelen; een convex vorm kan holtes sluiten.
- **Modeloppervlak** gebruikt driehoeken van de meshes.
- **Boomstam** schat een cilinder uit het onderste deel, zodat het bladerdak geen enorme blokkade wordt.

De voorbereide **Asset.tscn** bevat het model en de botsingsvorm; verplaatsen/roteren/dupliceren neemt beide mee. De bestaande `Visual.tscn` blijft een visuele bronwrapper. De oorspronkelijke bossen houden voorlopig hun bestaande losse colliders; gebruik de nieuwe complete assets voor nieuwe plaatsingen en voeg geen tweede collider toe aan oude instanties.

Voor speciaal ontworpen botsing kun je in Blender eenvoudige collisionmeshes met `-colonly` of `-convcolonly` in het model exporteren. Godot importeert die als botsingsvorm; de voorbereiding bewaart ze. Eigen collisions in een bronprefab hebben eveneens voorrang. Inspecteer automatisch geschatte vormen in de prefab, vooral bij bomen, trappen en gebouwen. Een exacte trapmesh is niet altijd prettig beloopbaar; geef zo'n model bij voorkeur een expliciete gladde hellingcollider mee.

Na herimport van een geregistreerd model wordt uitsluitend **GeneratedCollision** opnieuw opgebouwd; handmatig toegevoegde sockets of andere nodes blijven behouden. Bij een geopende prefab wordt vervanging uitgesteld om onopgeslagen werk te beschermen. Sluit de prefab en kies **Vernieuwen** om de uitgestelde vernieuwing uit te voeren. Voor handmatig aangepaste collision: plaats die buiten GeneratedCollision en verwijder de automatisch gemaakte vormen. Bewerk nooit `.godot/imported`.

**Begroeiing schilderen** gebruikt alleen assets met **Scatter Allowed**. Spacing, Scale Range en Random Yaw staan op de LevelAsset Resource. Een penseelstreek bewaart de uiteindelijke instances en vormt één Undo-actie. Paden blijven vrij. Wissen verwijdert alleen met de builder gemarkeerde instances van de geselecteerde asset.

## Areasets, gameplay en saves

`AreaSet` bepaalt de assetlijst, grond-/pad-/klifmaterialen en belichting. `WorldArea` bepaalt de identiteit van één speelbaar gebied en zijn scenepad. Zo kunnen tien bossen dezelfde bosset delen en toch afzonderlijke checkpoints hebben.

**Nieuwe set** maakt een eigen Resource met de huidige materiaal-/lichtinstellingen en een lege assetlijst. Voeg bestaande LevelAsset Resources of nieuwe modellen toe. Een set met **Catalog Only** verschijnt als gedeelde assetbibliotheek bij iedere normale areaset. De standaard gedeelde catalogus bevat enemies, portals, rustpunten en NPC's. Nieuwe setcodes vereisen geen aanpassingen in gameplaycode.

**Level → Pas areaset toe** vervangt de geselecteerde kit en belichting met Undo/Redo. Bestaande props worden niet automatisch omgewisseld. Handmatige lichtaanpassingen blijven dus bestaan totdat je deze knop bewust gebruikt.

De plaatsbare eikelwacht gebruikt standaard **On rest**. De editor kent iedere plaatsing automatisch een blijvende `persistent_id` toe. Dupliceren geeft een nieuwe code; verplaatsen/hernoemen behoudt de bestaande. Bestaande handmatig toegekende codes blijven bruikbaar. De gedeelde EnemySettings worden niet per level aangepast.

**Patrouille tekenen** maakt een Path3D met controlepunten. Wijs bij **Enemy** de geplaatste vijand aan. De punten bepalen uitsluitend zijn eigen routine; de bestaande EnemyBrain en navigatie blijven verantwoordelijk voor de beweging. **Encounter** maakt een doel met toegewezen enemies, te ontgrendelen portals en optioneel een DungeonDefinition/blijvende voltooiingsflag.

Eigen patrouilles blijven hun punt volgen zolang de route duurt; de korte tijdslimiet van de standaard lokale dwaalroutine geldt daar niet voor. Op ramps volgt de navigatie het oppervlak verticaal, zonder onnodige zijwaartse herstelbewegingen. De builder verwijdert driehoeken zonder oppervlakte uit de grond en collision: die konden de physics op steile ramps opzij laten springen. Een enemy die na het verlagen van grond eerst naar beneden valt, neemt bij zijn eerste grondcontact de werkelijke hoogte als thuishoogte over.

Een **Doorgang** krijgt Target Scene via de bestandskiezer en Target Spawn via een lijst van beschikbare aankomstpunten. De editor tekent het triggergebied en een richtingspijl. Nieuwe levels bevatten `Spawns/Entrance`; extra Marker3D-nodes krijgen `scene_spawn_point.gd` en een unieke Spawn Id. Drempelpoorten gebruiken de bestaande DungeonDefinition en hun eigen terugkeermarker.

## Eigenaarschap en onderhoud

De Godot-levelscene is leidend voor plaatsing. De builder schrijft alleen de afgeleide Terrain/Baked-nodes opnieuw. Curves, gebieden, props, actors en gameplaynodes worden gewoon opgeslagen. Grote afgeleide meshes, padmaskers en colliders staan als binaire Resources naast het level in `<Levelnaam>.terrain/`; houd die map bij de scene. Hierdoor blijven de tekstscenes leesbaar. Een terreinupdate verplaatst een selectie op gegenereerde nodes naar Terrain voordat die nodes veilig worden vervangen. Play genereert geen terrein- of assetmeshes. De historische Python-bosgeneratoren zijn geen editoropslaagroutine; voer ze niet over handmatig bewerkte levels uit.

De plugin staat onder `addons/level_builder/`; runtimegegevens en configureerbare nodes onder `scripts/world/authoring/`. De bestaande PlayerCharacter, GameClock, SceneTransit, Checkpoints en NavigationWorld blijven eigenaar van hun gameplaytaken.

Gerichte controles:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --max-fps 60 tests/LevelBuilderReplay.tscn -- --save-test-root=level_builder_review
/Applications/Godot.app/Contents/MacOS/Godot --editor --path . -- --level-builder-editor-checks
/Applications/Godot.app/Contents/MacOS/Godot --path . --max-fps 60 tests/LevelBuilderEnemyReplay.tscn -- --save-test-root=builder_enemy_review
```

Voer de editorcontrole in een geïsoleerde projectkopie uit wanneer je tegelijk zelf in Godot werkt. De controle gebruikt een unieke tijdelijke fixture per proces. Resultaten en native beelden komen in `captures/level_builder/`. De replay gebruikt een eigen savemap. De replay kan beperkt worden tot camera/helling via `--builder-traversal-only`; gebruik `--max-fps 30`, `60` of `120`. De bestaande headless replay op poort9090 wordt niet gebruikt om native controles te besturen.

De enemyreplay ondersteunt `--builder-ramp-scene=res://scenes/levels/Testje.tscn` voor de twee ramps uit het gemelde level. Hij bewaart een testkopie onder captures en controleert oplopen, afdalen, achtervolgen en terugkeren. `--builder-patrol-only` controleert een lange, eigen patrouille. Actuele resultaten: [LEVEL_BUILDER_VALIDATION.json](LEVEL_BUILDER_VALIDATION.json).
