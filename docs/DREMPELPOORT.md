# Drempelpoorten

De staande stenen boog blijft behouden. Het portaalvlak is ondoorzichtig en rustig bewegend. Er zijn precies twee visuele toestanden: grijs met gedoofd kristal vóór voltooiing, warm oranje/geel na voltooiing. Beide geven direct toegang, ook tijdens een rol. Er is geen activatie of interactieknop.

## Plaatsen en instellen

1. Sleep `scenes/world/dungeons/Drempelpoort.tscn` in een level. De lokale negatieve Z-as wijst door de poort.
2. Kies bij **Dungeon** een bestaande `DungeonDefinition`, of maak een eigen Resource met vaste `id`, `display_name`, `scene_path` en `entrance`.
3. Sla het level op. De poort krijgt automatisch een eigen blijvende `gate_id`. Verplaatsen/hernoemen bewaart deze; dupliceren maakt een nieuwe ID.
4. Zet **Editable Children** aan om de `ReturnPoint`-marker te verplaatsen. Houd hem buiten de trigger en buiten andere colliders. De negatieve Z-as van de marker bepaalt de kijk-/inlooprichting bij terugkomst. Standaard staat hij twee meter vóór de poort en kijkt de panda ervan weg.
5. De root heeft een instelbare `trigger_size` en gedeelde overgangsinstellingen. Alleen het steenwerk blokkeert; de opstap heeft een onzichtbare helling. Plaats op vlakke, begaanbare grond en houd beide kanten vrij.

De gekoppelde dungeon bevat een `Player`, een `SceneSpawnPoint` met dezelfde code als **entrance**, en een `scenes/world/dungeons/DungeonExit.tscn` met dezelfde Dungeon Resource. De uitgang zoekt automatisch de oorspronkelijke poort en bronmap. Een rechtstreeks met F6 geopende dungeon heeft geen oorspronkelijke ingang: test het terugreizen daarom via een geplaatste poort.

## Voorbeelden

| Gebied | Poortpositie | Dungeon |
| --- | --- | --- |
| ForestOpening | `(3.8, 0, -29.5)` naast de route | `RootCellar.tscn` — Wortelkelder |
| ForestPassage | `(5.5, 0, -5.6)` rechts van het huis | `ForgottenSanctum.tscn` — Vergeten heiligdom |

Beide bossen behouden hun eigen assets, scripts, normale doorgangen en gameplay. `DrempelpoortGallery.tscn` is een afzonderlijke testscene met twee ingangen naar dezelfde dungeon, om verschillende terugkeerpunten te kunnen controleren.

De twee voorbeeld-dungeons zijn kleine speelbare kamers met elk twee eikelwachters. Hun eigen `DungeonDefinition` bepaalt de onafhankelijke voortgang en eenmalige loot. Na beide wachters verschijnt één `lantern_shard` in de opgeslagen inventaris. Ze zijn een basis om verder in te richten, geen volledig uitgewerkte dungeons.

Gewone dungeonwachters gebruiken **Respawn Rule → On rest**. Rusten bij een Vuurlelie reset hun verslagen-status wereldwijd, ook als hun dungeon niet geladen is. Alleen de map verlaten en terugkomen laat ze verslagen; na rusten komen ze terug met volle levens. De gouden poortstatus en eenmalige beloning blijven behouden. **Permanent** is voor bosses of bewust eenmalige vijanden, niet voor gewone wachters. Oudere saves met de foutieve permanente vlaggen voor deze vier wachters blijven bruikbaar: hun huidige On-rest-regel gebruikt de tijdelijke verslagen-status.

## Eigen uitdagingen en loot

`DungeonRoom` is alleen de adapter van de voorbeelden: de lijst `required_enemies` bepaalt welke vijanden verslagen moeten zijn. Een ander level mag zijn eigen puzzel, boss of challenge gebruiken en bij succes `DungeonTravel.complete(dungeon_definition)` aanroepen. De bijbehorende wereldflag voorkomt dubbele loot; het huidige actieve slot wordt opgeslagen. Lootcodes/aantallen staan in **completion_loot**. Een permanente vijand behoudt daarnaast zijn eigen `persistent_id` en respawnregel.

De route en voltooiing horen bij `GameProgress.data.world` van het huidige slot. Doodgaan laadt deze dictionary niet opnieuw vanaf schijf. Meerdere ingangen naar dezelfde dungeon delen de voltooiing, maar onthouden de werkelijk gebruikte ingang. Geneste dungeons bewaren een stapel terugkeerroutes; een nieuwe ingang buiten die route ruimt verouderde routegegevens op.

## Verdwijnen en laden

`PortalAbsorption` bereidt materiaalvarianten vooraf voor, behoudt de oorspronkelijke kleuren en laat de hele panda inclusief uitrusting vloeiend vervagen vóór het portaalvlak. Silhouetpasses, schaduwen, voetstof en gedragen licht verdwijnen mee. De materiaalvarianten worden ook werkelijk getekend tijdens de voorbereiding, zodat hun eerste render niet op het moment van binnengaan valt. `SceneTransit` wacht hierop terwijl de overgang het beeld afdekt.

Dungeonpoorten gebruiken dezelfde korte petrolfade als huisdeuren, zonder laadscherm of minimale wachttijd. Nabije poorten laden hun bestemming vooraf; materiaalvoorbereiding gebeurt vóór de speler de poort raakt. Alleen New Game en laden vanuit het hoofdmenu behouden hun laadscherm. Vertrek en aankomst gebruiken de bestaande spelerbesturing en invoerblokkade; er start geen tweede laadactie. Een overlappende aankomsttrigger blijft geblokkeerd totdat de speler eruit is geweest. Een ongeldige bestemming laat de bronmap staan en herstelt zichtbaarheid en bediening.

## Bron en controle

Bewerkbare bron: `assets/environment/threshold_gate/source.blend`; export: `model.glb`; Godot-wrappers: `scenes/assets/environment/threshold_gate/`. De aangeleverde referenties staan in `assets/references/drempelpoort/`. De steenmaterialen zijn eenvoudiger dan de referentierender; dit is geen claim van exacte 1:1-gelijkenis.

Exporteer de opgeslagen bron met Blender en `tools/drempelpoort/build_asset.py -- --export`. Zonder `--export` bouwt dit script de bron opnieuw: alleen bewust uitvoeren. `tools/drempelpoort/author_scenes.py` genereert de prefabs en voorbeeld-dungeons offline; het schrijft niet naar ForestOpening of ForestPassage. Handmatige scene-aanpassingen eerst bewaren.

Gerichte native controle, zonder andere karakter-/combatsuites:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --max-fps 60 tests/DrempelpoortReplay.tscn -- --save-test-root=threshold_review
```

`--portal-presentation-only` beperkt de replay tot één heen-en-terugreis. Voeg `--portal-performance-only` toe voor frametijdmetingen zonder screenshot-I/O. Bewijs staat lokaal in `captures/drempelpoort/`; de tests gebruiken uitsluitend een eigen save-testmap.

`--dungeon-rest-only` controleert uitsluitend rusten over gebiedsgrenzen: beide dungeons leegmaken, terugkomen vóór rusten, echt rusten in het bos, beide dungeons opnieuw bezoeken, permanente voortgang/bossregels en dubbele loot. De controle gebruikt ook een oude-save-fixture met de foutieve permanente wachtersvlaggen. Rapport: `captures/drempelpoort/rest_review.json`.
