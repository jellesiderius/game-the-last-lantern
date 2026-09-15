# Levels bouwen

De **Lantern Level Builder** is een Godot-editorplugin voor levels in een schone, Tunic-achtige stijl: vlakke grond, plateaus op vaste hoogten, trappen die in de klifrand aansluiten, paden en props. Open hem via **Level Builder** boven de 3D-weergave. Onderaan staat de assetbibliotheek: plaatjes met volledige namen, zoeken en categoriefilters. Rechts staat één dock **Level tools**:

- bovenaan de gereedschappen **Selecteer · Plaats · Strooi · Plateau · Trap · Brug · Water · Pad · Patrouille**, met alleen de instellingen van het gekozen gereedschap;
- daaronder **hoogte en materiaal van de selectie** (grond, plateau of trap);
- onderaan de levelacties: nieuw level, areasets, encounter, controleren en spelen.

**Escape** gaat terug naar Selecteer. Met **Alt** ingedrukt werkt Godots eigen camera- en selectiebesturing gewoon door. Maten, hoogten en curvepunten blijven ook in de Inspector bewerkbaar. Als Godot openstond tijdens een update van de plugin, sla je scene op en herlaad de plugin eenmalig via **Project Settings → Plugins**.

## Beginnen

1. Kies bovenaan de bibliotheek **Bos**, **Grot · startset** of **Stad · startset**.
2. Kies rechts **Nieuw level**, vul een naam, breedte en diepte in meters in. Het level krijgt speler, gameplaycamera, belichting, HUD, effecten, grond, aankomstpunt en eigen gebiedsregistratie.
3. Kies **Plateau**, stel **Hoogte** in en sleep een rechthoek. Kies **Trap** en klik op de rand van dat plateau.
4. Kies een asset in de bibliotheek (het gereedschap springt naar **Plaats**) en klik in de 3D-weergave.
5. **Controleer level** controleert configuratie, verwijzingen en grond. **Speel level** slaat op en start het level. F6 werkt eveneens.

Werkende voorbeelden: `scenes/levels/BuilderForest.tscn`, `BuilderCave.tscn`, `BuilderCity.tscn`. Een render van de stijl maak je met `tools/level_builder/look_preview.gd` (zie Controles).

## Selecteren en verplaatsen

Kies **Selecteer** en wijs naar een plateau, trap, brug, water of pad. Een **witte omtrek** toont wat je gaat selecteren. Klikken selecteert de bewerkbare node; ook plateaumuren en schuine bruggen zijn aanklikbaar.

- **Sleep** om over X/Z te verplaatsen. **Raster** bepaalt de stap; **0** geeft vrije beweging. Een klik zonder slepen wijzigt alleen de selectie.
- **Plateau verplaatsen** neemt de aangesloten trappen mee en verplaatst de bruguiteinden die erop rusten. Bij gestapelde plateaus bepaalt het daadwerkelijke steunvlak welke verbinding meegaat.
- **Een trap apart verplaatsen** past hem bij loslaten weer loodrecht op een nabije plateaurand, binnen 1,5 m en als de trap daar past.
- **Undo/Redo** herstelt de hele verplaatsing, inclusief curvepunten en gekoppelde onderdelen. **Escape** tijdens slepen annuleert; wisselen van gereedschap of vensterfocus herstelt eveneens de beginstand. Loslaten buiten het viewport rondt de verplaatsing af.
- Props en actors houden Godots selectie. **Alt+klik/sleep** geeft Godots eigen selectie, curvegrepen en verplaatsgereedschap voorrang. Ook water en bruggen vernieuwen na zo'n transformwijziging. **Delete** werkt via de gewone editorselectie.

## Plateaus

- **Hoogte** loopt van 0,5 tot 100 m in stappen van 0,5 m. Elk plateau en elk trapeinde valt altijd op zo'n stap, zodat klifranden overal gelijk lopen. Die stap is vast; er is geen globale instelling die bestaande plateaus kan verschuiven.
- **Sleep een rechthoek** op het raster (**Raster**, standaard 1 m), of **klik twee hoeken**: een klik zonder slepen zet de eerste hoek, de preview volgt de muis en de tweede klik zet de tegenoverliggende hoek (Esc annuleert). Een gele lijn toont vooraf rand en hoogte.
- **Ctrl** tijdens het slepen houdt de hoogte van de grond eronder: zo teken je een vlak met ander materiaal, bijvoorbeeld een stenen vloer.
- **Rechthoeken tegen elkaar** op dezelfde hoogte vormen één plateau zonder muur ertussen; zo bouw je L- en U-vormen.
- **Plateaus mogen overlappen.** Het hogere plateau wint het gedeelde stuk, dus een heuvel op een heuvel teken je gewoon bovenop. Bij gelijke hoogte wint het eerst getekende.
- **Hoogte van één plateau aanpassen**: selecteer het en wijzig **Hoogte** in het dock. Alleen dat plateau verandert; Undo werkt.
- **Vorm aanpassen**: selecteer het plateau en versleep Godots curvepunten. Randen zijn recht; tangentgrepen doen niets.

Elk plateau krijgt een muur van grove stenen blokken met een smalle, afgeschuinde lip in de kleur van de bovenkant. Waar de muur lager wordt dan die lip (naast een helling of trap) stopt de lip recht in plaats van puntig uit te lopen. Aan de voet van de muur ligt een zachte schaduw op de lagere grond. Botsing wordt meteen mee gebakken.

## Trappen en hellingen

Kies **Trap** en **beweeg over de rand van een plateau**. De builder zoekt de rand die op het scherm het dichtst bij de muis ligt, dus je kunt gewoon op de rand, de kaprand of de muur zelf wijzen. Een gele preview toont de treden; rood betekent dat de trap daar niet past (de reden staat onderin het dock). **Klik** om te plaatsen.

- **Muis óp het plateau** naast de rand: de trap wordt **in het plateau gezet**, met muur en kaprand aan beide kanten.
- **Muis op de muur of de grond ervoor**: de trap loopt **naar buiten**, met zijwangen van klifmateriaal.
- Past de gekozen richting niet (plateau te klein, er ligt al iets, buiten de grond), dan probeert de builder automatisch de andere richting en meldt dat.
- **Trapbreedte** bepaalt de breedte; de trap wordt langs de rand op het raster gezet en loopt altijd loodrecht op de rand.
- **Treden** uit maakt een gladde grashelling met een flauwere hoek. Boven en onder loopt die helling afgerond over in het plateau en de grond, zonder harde knik; beeld en botsing volgen dezelfde ronding. De zijkanten krijgen een lage stenen stoeprand die de ronding volgt, bovenaan gelijk met het plateau loopt en onderaan recht eindigt. Hellingen die al steiler zijn dan 0,8 blijven recht, zodat vijanden ze kunnen beklimmen.
- De lengte volgt uit het hoogteverschil. Beide uiteinden **volgen de grond** (**Follow Ground**): verander je later de hoogte van het plateau, dan past de trap zich aan. Sleep je een eindhoogte met de gizmo of typ je die in de Inspector, dan wordt die ene trap handmatig.
- De treden zijn 0,25 m hoog en echte geometrie; de **botsing blijft een gladde helling**, zodat lopen niet hobbelt.
- Verhoog of verlaag je het plateau, dan wordt de trap vanaf zijn aansluitende uiteinde langer of korter, zodat hij altijd even steil blijft.

Trappen en hellingen mogen elkaar niet overlappen. Bij een ongeldige vorm behoudt de builder het laatste geldige grondresultaat en toont hij een waarschuwing. Ramps uit oudere levels blijven hellingen; zet **Stairs** aan op zo'n LevelRamp als je er treden van wilt maken.

## Bruggen

Kies **Brug**. Beweeg over een plateaurand (of de grond): een geel vierkantje toont het ankerpunt. **Klik** voor het begin, beweeg naar het tweede punt en **klik** opnieuw. **Esc** annuleert een half getekende brug.

- Een brug mag **omhoog of omlaag** lopen, tot een helling van 0,6. Elk uiteinde krijgt de hoogte van het plateau waarop het rust en volgt die later mee (**Follow Ground**).
- Rood betekent: te steil, te kort, buiten de grond, of de brug gaat door een hoger plateau heen. De reden staat onderin het dock.
- **Brugbreedte** en **Leuningen** stel je vooraf in; kleuren en breedte zijn daarna in de Inspector te wijzigen.
- De brug bouwt bij het laden zijn eigen planken, balken, palen en botsing. De grond eronder blijft beloopbaar. Korte vlakke stukjes op elk plateau maken op- en aflopen naadloos; onzichtbare zijwanden houden je op het dek. Het zichtbare dek ligt 5 cm boven het loopvlak, zodat planken nooit door de plateaubovenkant heen steken.
- Vijanden lopen gewoon over bruggen: hun navigatie gebruikt de brugbotsing.

## Water

Kies **Water** en daarna de **Vorm**:

- **Vierkant**: sleep een rechthoek of klik twee hoeken, net als bij een plateau. Versleep daarna de hoekpunten om de vorm aan te passen.
- **Pad**: klik punten voor een rivier en druk **Esc** om af te ronden. **Breedte** bepaalt hoe breed de rivier is.

De eerste klik bepaalt de hoogte van de plas of rivier. Klik je op een plateau van **10 m**, dan komt het water daar: standaard ligt het oppervlak op **9,88 m** en de diepe bodem op **9,4 m**. De grond zakt vanzelf in tot **Diepte**, met zachte oevers. De shader komt uit het test2-project (`shaders/level_water.gdshader`): kleur op diepte, lichtbreking, bewegende lichtpatronen op de bodem en schuim waar iets door het oppervlak steekt. Oevers, plateaumuren, rotsen en brugpalen krijgen die schuimrand dus automatisch. De speler en vijanden die door het water waden laten kringen achter; tot vier tegelijk per waterplas.

Water vervangt grond op de aangeklikte hoogte en stopt bij de rand van het ondersteunende plateau of terrein. Hogere plateaus vormen eilanden; trappen behouden hun doorgang. Overlappende wateroppervlakken worden één keer getekend. Selecteer een **LevelWater** voor **Depth**, **Bank** (oeverbreedte), **Surface Drop** en **Ripples**; wijs een eigen **Surface Material** toe om één plas anders te laten ogen. De steunhoogte staat in **Transform → Position → Y**. Het water is ondiep en doorwaadbaar; er is geen zwemmen.

## Botsing

Beeld en botsing zijn gescheiden. Treden, zaagtandwangen, kapranden en eindkapjes zijn alleen beeld. De botsing bestaat uit gladde vlakken: grond, trappen als helling en muren die die helling volgen. Zo blijf je nergens haken, ook niet langs trapranden of vlak langs een muur. Gegenereerde punten liggen op een raster van 0,1 mm, zodat aansluitende vlakken exact sluiten en er geen driehoeken zonder oppervlakte ontstaan. Muren naast afgeronde hellingen en water volgen het celraster van de grond, zodat hun bovenrand punt voor punt op het oppervlak aansluit.

## Grootte, paden en patrouilles

Selecteer **Terrain** en pas **Size** in de Inspector aan: X is breedte, Y is diepte in meters. Een resize behoudt paden en geplaatste objecten; objecten worden niet verplaatst als je de grond verkleint. De levelroot gebruikt standaard **Auto Camera Bounds**; zet dit uit om cameragrenzen zelf te bepalen.

**Pad**: klik punten en druk Escape om af te ronden. Selecteer het pad voor de curvegrepen; Width bepaalt de breedte. Het pad krijgt een zacht geschulpte rand met een donkere grasrand ernaast. Padranden gebruiken een eigen fijn masker, onafhankelijk van **Resolution** van de grond, en blijven dus glad op grove grond.

**Patrouille**: klik punten op de route. Punten krijgen de hoogte van het oppervlak waarop je klikt, ook op plateaus en trappen.

## Grond- en klifmateriaal

Alle uiterlijk staat in één Resource: **SurfaceStyle** (`settings/surface_styles/`). Die bevat grond- en padkleur en -texture, het procedurele patroon (**Effen, Gras, Steen, Aarde**), de klifkleur, een klif-texture met schaal, en kleur en hoogte van de kaprand. Een **AreaSet** kiest alleen de standaard via **Default Surface**.

Selecteer grond, een plateau of een trap: het dock toont de **materiaalkiezer**. **Standaard** volgt de grond of de areaset; **Eigen kleuren / textures…** maakt een kopie voor dat onderdeel en opent hem in de Inspector. Sla een eigen stijl als `.tres` in `settings/surface_styles/` op om hem opnieuw te kiezen.

Zonder textures tekenen de shaders het uiterlijk zelf, in een vlakke, schone Tunic-achtige stijl: `shaders/level_ground.gdshader` maakt effen grond met brede zachte vlekken, een schone padrand en de treden; `shaders/level_cliff.gdshader` maakt grove stenen blokken die elk het licht net anders vangen (low-poly facetten), met donkere naden en een afgeschuinde onderkant. De presets **Bos** (olijfgroen en leisteen), **Stad** (zand en rode baksteen) en **Grot** (lichte platen en lavendelsteen) volgen dat palet; nieuwe levels gebruiken ACES-tonemapping voor verzadigde kleuren. Wijs je een **Ground Texture**, **Path Texture** of **Cliff Texture** toe, dan neemt die het over. Klif-textures worden in wereldruimte geplaatst en rekken dus niet uit bij hoge muren.

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

Met **Plaats** zet een klik één exemplaar op de aangeklikte plek.

### Object-scatter: bloemen en andere props

Kies bijvoorbeeld **Flowers Blue** of **Flowers Cream** in de bibliotheek: voor begroeiing opent automatisch **Strooi**. Voor andere props kun je zelf **Strooi** kiezen.

1. Stel **Straal** in voor de grootte van het penseel.
2. Kies **Aantal** per stempel en **Afstand** tussen objecten. Voor veel bloemen: bijvoorbeeld straal **2 m**, aantal **30**, afstand **0,4 m**.
3. De gele cirkel toont het gebied. **Klik** voor één groep of **sleep** om een strook te vullen. Als de ruimte vol is, plaatst de builder minder exemplaren en meldt dat.

Objecten volgen de grond en plateaus. **Hoogte +** bepaalt de plaatsingshoogte ten opzichte van dat oppervlak, in stappen van **0,5 m**: op een plateau van 10 m plaatst **0 m** op 10 m en **+2 m** op 12 m. Negatieve waarden laten objecten wat in de grond zakken. Dit veld werkt ook bij **Plaats**. Paden en patrouillepunten bewaren eveneens de aangeklikte oppervlaktehoogte.

Met **Willekeurige hoek** draait ieder gestrooid object willekeurig om zijn verticale as; uitgeschakeld blijft de oorspronkelijke assetoriëntatie behouden. **Random Yaw** van de LevelAsset bepaalt de beginstand van deze schakelaar. Schaalvariatie volgt **Scale Range**; **Spacing** levert de beginwaarde voor Afstand. **Paden vrijhouden** staat standaard aan; water wordt overgeslagen. Actors en gameplayobjecten gebruiken **Plaats**.

Vink **Overlap toestaan** aan om een nieuwe groep over bestaande assets heen te strooien. **Afstand** blijft instelbaar en geldt tussen alle nieuwe objecten binnen dezelfde klik of strooistreek. Zonder dit vinkje houdt de builder ook afstand tot eerder geplaatste assets. **Paden vrijhouden** blijft een aparte keuze; terreingrenzen en water worden nog steeds gecontroleerd.

**Shift+slepen** toont een rood penseel en wist alleen geplaatste exemplaren van het gekozen type. Zowel een volledige strooi- als wisstreek vormt **één Undo-actie**, met Redo. Alle exemplaren zijn gewone opgeslagen scene-instances: je kunt ze daarna afzonderlijk selecteren, verplaatsen en verwijderen.

## Areasets, gameplay en saves

`AreaSet` bepaalt de assetlijst, het standaard grondmateriaal (**Default Surface**) en de belichting. `WorldArea` bepaalt de identiteit van één speelbaar gebied en zijn scenepad. Zo kunnen tien bossen dezelfde bosset delen en toch afzonderlijke checkpoints hebben.

**Nieuwe areaset** maakt een eigen Resource met de huidige materiaal-/lichtinstellingen en een lege assetlijst. Voeg bestaande LevelAsset Resources of nieuwe modellen toe. Een set met **Catalog Only** verschijnt als gedeelde assetbibliotheek bij iedere normale areaset. De standaard gedeelde catalogus bevat enemies, portals, rustpunten en NPC's. Nieuwe setcodes vereisen geen aanpassingen in gameplaycode.

**Pas areaset toe** vervangt de geselecteerde kit en belichting met Undo/Redo. Bestaande props worden niet automatisch omgewisseld. Handmatige lichtaanpassingen blijven dus bestaan totdat je deze knop bewust gebruikt.

De plaatsbare eikelwacht gebruikt standaard **On rest**. De editor kent iedere plaatsing automatisch een blijvende `persistent_id` toe. Dupliceren geeft een nieuwe code; verplaatsen/hernoemen behoudt de bestaande. Bestaande handmatig toegekende codes blijven bruikbaar. De gedeelde EnemySettings worden niet per level aangepast.

**Patrouille** maakt een Path3D met controlepunten. Wijs bij **Enemy** de geplaatste vijand aan. De punten bepalen uitsluitend zijn eigen routine; de bestaande EnemyBrain en navigatie blijven verantwoordelijk voor de beweging. **Nieuwe encounter** maakt een doel met toegewezen enemies, te ontgrendelen portals en optioneel een DungeonDefinition/blijvende voltooiingsflag.

Eigen patrouilles blijven hun punt volgen zolang de route duurt; de korte tijdslimiet van de standaard lokale dwaalroutine geldt daar niet voor. Op ramps volgt de navigatie het oppervlak verticaal, zonder onnodige zijwaartse herstelbewegingen. De builder verwijdert driehoeken zonder oppervlakte uit de grond en collision: die konden de physics op steile ramps opzij laten springen. Een enemy die na het verlagen van grond eerst naar beneden valt, neemt bij zijn eerste grondcontact de werkelijke hoogte als thuishoogte over.

Een **Doorgang** krijgt Target Scene via de bestandskiezer en Target Spawn via een lijst van beschikbare aankomstpunten. De editor tekent het triggergebied en een richtingspijl. Nieuwe levels bevatten `Spawns/Entrance`; extra Marker3D-nodes krijgen `scene_spawn_point.gd` en een unieke Spawn Id. Drempelpoorten gebruiken de bestaande DungeonDefinition en hun eigen terugkeermarker.

## Eigenaarschap en onderhoud

De Godot-levelscene is leidend voor plaatsing. De builder schrijft alleen de afgeleide Terrain/Baked-nodes opnieuw. Curves, gebieden, props, actors en gameplaynodes worden gewoon opgeslagen. Grote afgeleide meshes, padmaskers en colliders staan als binaire Resources naast het level in `<Levelnaam>.terrain/`; houd die map bij de scene. Hierdoor blijven de tekstscenes leesbaar. Een terreinupdate verplaatst een selectie op gegenereerde nodes naar Terrain voordat die nodes veilig worden vervangen. Play genereert geen terrein- of assetmeshes. De historische Python-bosgeneratoren zijn geen editoropslaagroutine; voer ze niet over handmatig bewerkte levels uit.

De plugin staat onder `addons/level_builder/`; runtimegegevens en configureerbare nodes onder `scripts/world/authoring/`. De bestaande PlayerCharacter, GameClock, SceneTransit, Checkpoints en NavigationWorld blijven eigenaar van hun gameplaytaken.

Gerichte controles en een stijlrender:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --max-fps 60 tests/LevelBuilderReplay.tscn -- --save-test-root=level_builder_review
/Applications/Godot.app/Contents/MacOS/Godot --editor --path . -- --level-builder-editor-checks
/Applications/Godot.app/Contents/MacOS/Godot --path . --max-fps 60 tests/LevelBuilderEnemyReplay.tscn -- --save-test-root=builder_enemy_review
/Applications/Godot.app/Contents/MacOS/Godot --path . tests/LevelBuilderStairsReplay.tscn
/Applications/Godot.app/Contents/MacOS/Godot --path . -s res://tools/level_builder/look_preview.gd
```

De stairs-replay laat de echte speler over en langs trappen, bruggen en plateauranden lopen en faalt bij haken, stilstaan of vallen. De stijlrender schrijft `captures/level_builder/look.png`, een close-up van de trappen (`look_close.png`) en van de bruggen (`look_bridge.png`).

Voer de editorcontrole in een geïsoleerde projectkopie uit wanneer je tegelijk zelf in Godot werkt. De controle gebruikt een unieke tijdelijke fixture per proces. Resultaten en native beelden komen in `captures/level_builder/`. De replay gebruikt een eigen savemap. De replay kan beperkt worden tot camera/helling via `--builder-traversal-only`; gebruik `--max-fps 30`, `60` of `120`. De bestaande headless replay op poort9090 wordt niet gebruikt om native controles te besturen.

De enemyreplay ondersteunt `--builder-ramp-scene=res://scenes/levels/Testje.tscn` voor de twee ramps uit het gemelde level. Hij bewaart een testkopie onder captures en controleert oplopen, afdalen, achtervolgen en terugkeren. `--builder-patrol-only` controleert een lange, eigen patrouille. Actuele resultaten: [LEVEL_BUILDER_VALIDATION.json](LEVEL_BUILDER_VALIDATION.json).
