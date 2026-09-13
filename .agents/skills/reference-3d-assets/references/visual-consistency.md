# Visuele consistentie en zelfcontrole

## Referentie ontleden

Bepaal eerst de leidende bron. Een personageblad bepaalt het uiterlijk; een andere game kan beweging en presentatie bepalen zonder het personageontwerp te vervangen. Bewaar de originele referenties en zet ze naast eigen renders. Gebruik ze niet als platte personages of grondvlakken wanneer echte 3D meshes gevraagd zijn.

Meet relatieve posities vanaf dezelfde grondlijn en totale hoogte: kruin, ogen, snavel, schouder, borstgrens, onderbuik, knieën, enkels en tenen. Meet zowel de rompbreedte als het totale vleugelsilhouet. Controleer de ruimte tussen beide benen. Gebruik zij- en achteraanzicht om te voorkomen dat een goede voorkant een bolle rug, zwevende borstplaat of verkeerde staart verbergt.

Een referentieblad kan kleine onderlinge verschillen bevatten. Kies een consistente volumetrische interpretatie en leg die vast; probeer niet iedere perspectivische afwijking letterlijk tegelijk in dezelfde mesh te bouwen. Behoud herkenbare hoofdmaten en kledingloze anatomie wanneer dat gevraagd is.

## Modelbouw en anatomische verbindingen

Begin met grote volumes en rustige oppervlakken. Voeg silhouetkenmerken toe voordat je microdetails modelleert. Een afgeronde primitive is geen vervanging voor de specifieke contour van een snavel, vleugel of voet.

Een poot die in rust net tegen de buik raakt kan tijdens lopen los lijken. Controleer zowel geometrische overlap/verbinding als gewichten. Verbind veerbenen met de buik waar de anatomie één volume moet zijn. Geef de heup een geleidelijke overgang van bekken naar been. Laat een beweeglijke enkel bovenaan het been volgen en onderaan de voet; rigide tenen en voetkussens blijven op het voetbot. Overlap is soms voldoende voor afzonderlijke harde onderdelen, maar verbergt geen gapende zachte gewrichten.

Een zichtbare kleurgrens hoeft geen dikke zwevende plaat te zijn. Projecteer een dun oppervlak op het werkelijke lichaam of gebruik geschikte materiaal-/kleurdata. Bij een opzetvlak: controleer een kleine, consistente afstand, aansluitende normales en dezelfde huidgewichten als de onderliggende vorm. Een eenvoudige profielbenadering kan op de voorkant kloppen en aan de achterzijde centimeters loskomen.

Voeten hebben een duidelijke contactzijde. Controleer aantal en spreiding van tenen, hiel/achterteen, enkelbreedte, voetrichting en grondhoogte. Kijk van laag opzij én vanuit de spelcamera. Een voet die frontaal verborgen wordt door de romp kan technisch aanwezig maar visueel onleesbaar zijn.

## Pixelvorming diagnosticeren

Verhoog niet blind de polygonentelling. Onderscheid:

- Hoekig silhouet: onvoldoende segmenten of te grove curvebemonstering. Corrigeer de contour en pas waar nodig subdivision vóór skinning toe.
- Platte lichtvlakken: flat normals, verkeerde smooth/sharp boundaries of slechte topologie. Controleer normales en shading in een egaal materiaal.
- Gekartelde kleurgrens: materiaalindex per grof polygon. Gebruik passend fijnere geometrie of geïnterpoleerde vertexkleuren; een harde tintwisseling per vlak blijft blokkerig met smooth normals.
- Moiré, stippen of flikkerende patches: bijna coplanaire oppervlakken, z-fighting of verkeerde normals. Corrigeer diepte en aansluiting; meer samples lossen dit niet op.
- Grove randen alleen in de game: resolutieschaal, anti-aliasing, import-LOD of filtering. Test op de echte uitvoerresolutie.
- Donkere spikkels: schaduwsampling, SSAO, rendernoise of te lage renderkwaliteit. Vergelijk met schaduwen/SSAO tijdelijk uit om de oorzaak te isoleren.

Controleer materiaalnamen én schakelaars na import. glTF kan `COLOR_0` correct exporteren terwijl het Godot-materiaal vertexkleuren niet als albedo gebruikt. In dit geval is het materiaal wit ondanks correcte meshdata. Een opgeslagen materiaaloverride in de visuele wrapper kan het importgedrag corrigeren zonder de importcache te wijzigen.

## Reviewbeelden

Bij kledingwissels blijven geaccepteerde anatomie en verhoudingen behouden, tenzij de gebruiker die expliciet wil veranderen. Een kledingreferentie is geen toestemming om het personage breder, langer of anders van gezicht te maken. Pas kleding op de bestaande vorm. Projecteer bij een dikke kledingmesh eerst het buitenoppervlak en maak daarna de dikte; beide zijden op hetzelfde oppervlak projecteren laat de mesh instorten en veroorzaakt z-fighting.

Gebruik voor geometrievergelijking dezelfde ortho-schaal, grondlijn, kijkrichting, neutrale pose en rustige belichting. Gebruik daarnaast echte spelbelichting. Een glanzende materiaalpreview kan de achterkant goed doen lijken terwijl gameplay harde lelijke facetten laat zien.

Bewaar minimaal front, side, back, three-quarter en spelcamera bij belangrijke geometriewijzigingen. Bij geanimeerde verbindingen leg je rust, maximale stap, grootste rompbuiging en actieve aanval vast. Controleer negatieve ruimte, penetraties, zwevende oppervlakken en voetcontact.

Een afzonderlijke reviewscene moet de bedoelde Action, action-slot, pose-modus en het actuele bronframe overnemen. Een gedeeld rigobject kan in een nieuwe scene anders worden geëvalueerd. Controleer een werkelijk veranderde botpose voordat de render als animatiebewijs wordt gebruikt.

Schrijf bij een fout niet alleen “verbeteren”, maar bijvoorbeeld “achterste cream-vlak steekt uit de rug; projecteer opnieuw en controleer dezelfde zijpose”. Controleer na de fix ook de andere kant. Vermijd een lange reeks correcties die ieder het vorige aanzicht weer beschadigen.

## Lessen bij een tweede personage

Deel een materiaal dat vertexkleuren leest niet blind met losse oren of wenkbrauwen zonder dat attribuut: ze kunnen zwart worden. Geef ze het benoemde attribuut of een passend zelfstandig materiaal. Controleer Blender én de export.

Meet hoofd- en snuitbreedte apart, plus oogdiameter en uitsteekdiepte. Een kleine oogbol boven op het oppervlak is nog geen diep liggend oog. Controleer oogkas en wenkbrauwrand van opzij. Vermijd zichtbare stapels bolvormen bij romp, nek, schouders en bovenbenen; gladde normals corrigeren hun verkeerde contour niet.

## Gladde vachtvlakken en staartbanden

Een harde materiaalkeuze op basis van het middelpunt van een veelhoek maakt diagonale of ronde kleurgrenzen trapvormig. Dit gebeurde bij de rode-panda-staart: een drempel op wereld-Y kruiste schuine ringen van de mesh. Meer smooth shading verandert die materiaalgrens niet.

Kies een kleurmethode passend bij de contour: laat een scherpe band exact langs een voldoende fijn bemonsterde, gesloten edge-loop lopen; gebruik voor vrij gevormde markeringen een UV-textuur met voldoende texeldichtheid en filtering, een gebakken masker of interpolerende vertexkleuren. Beoordeel ook UV-naden, mipmaps en rek onder skinning. Een ring moet helemaal rondlopen zonder zaagtanden; een vlakke projectie die alleen vooraan klopt is onvoldoende.

Bij effen gestileerde huid zijn onnodige bitmaptexturen geen vereiste. Geometrisch begrensde kleurvlakken kunnen scherp én glad blijven. Bij bitmapgebruik mag vergroten geen zichtbare blokjes geven op de beoogde close-upafstand. Verhoog resolutie pas na controle van UV-schaal, filtering en de werkelijke import.

Na een kleurwijziging: maak nieuwe zij- en achterbeelden van de opgeslagen bron, inspecteer de kleurgrens op 100% en controleer de herimporteerde mesh tijdens buigen in de game. Een oude capture of alleen een materiaalpreview telt niet. Bewaar het voorbeeld van de fout en de actuele correctie.

## Aansluiting van aangezette delen

Een neus die frontaal goed lijkt kan van opzij vóór de snuit zweven. Plaats het contactvlak op het werkelijke snuitoppervlak, bijvoorbeeld met een BVH-ray of nearest-surface-query; ga niet uit van een handmatig geschatte diepte. Laat de achterkant licht in het dragende volume vallen en behoud alleen de bedoelde uitsteekvorm. Controleer normale richting en objecttransforms voordat je punten projecteert.

Doe dezelfde controle voor ogen, oren, borstmarkeringen, cape/schouders, vingers en enkels. Onderscheid een bedoelde opening (tussen vingers, onder een cape) van een los onderdeel. Bekijk de aansluitrand frontaal, van beide zijkanten en van achteren; gebruik een laag zijaanzicht om open lucht tussen contactvlakken te zien. Pas de controle opnieuw toe na smoothing, remeshing of schaalwijzigingen: daarmee kan een eerder correct contact verdwijnen.

Na skinning moeten dragend en aangezet deel compatibele gewichten hebben. Een neus en ogen bewegen rigide mee met het hoofd; een lichaamsmarkering volgt dezelfde lokale huiddeformatie als het lichaam. Controleer neutraal, grootste stap, maximale buiging en actieve slag in de daadwerkelijke export. Een geslaagde bovengrondse afstandscontrole is geen vervanging voor kijken naar zwevende naden.

## Controleblad bij iedere assetwijziging

Bewaar actuele orthografische voor-, linkerzij-, rechterzij- en achterbeelden plus spelcamera. Noteer per controlepunt de gevonden afwijking, toegepaste correctie en het nieuwe beeld dat die correctie laat zien. Controleer:

- Silhouet en verhoudingen tegen dezelfde aanzichten van de gekozen referentie.
- Alle gezichtsaansluitingen: neus/snuit, wenkbrauw/hoofd, ogen/hoofd en oren/schedel. Wenkbrauwen zijn geen vrij zwevende schijfjes. Projecteer hun achterzijde op de daadwerkelijke hoofdmesh en houd die verbinding bij een gebogen oppervlak over de hele breedte aan.
- Lichaamsaansluitingen, vingers en voeten; cape tegenover romp en staart.
- Kleur per herkenbaar vlak onder neutraal licht én spellicht. Kijk naar warm/koud, verzadiging en onderlinge contrasten, niet alleen materiaalnamen. Een effen bruine mesh in Solid-view bewijst geen juiste materiaalverdeling.
- Alle kleurgrenzen op 100%: geen zaagtanden, blokjes, texture-naad of flikkerend overlapvlak. Controleer ook de achterkant van staartbanden en gezichtsmarkeringen.
- Animatie-extremen na rigging: blijven delen vastzitten en behouden de kleuren hun vorm? Controleer de export opnieuw; dezelfde botnaam alleen is geen bewijs van goede skinning.

Bij een gevonden zwevend onderdeel controleer je alle andere aangezette onderdelen meteen mee. Corrigeer de systematische plaatsingsmethode zodat niet eerst de neus, daarna de wenkbrauwen en daarna de ogen hetzelfde probleem herhalen.
