# Kraai: concrete lessen uit dit project

Dit zijn projectspecifieke voorbeelden, geen universele stijlregels.

- De kraaireferentie heeft een lange nek, witte ogen zonder pupillen, een afgeronde snavel, zwarte mantel, cream-kleurige nekzijden en borst, lage buik, drie staartveren en korte geveerde pootjes. Een willekeurige ronde vogel met dezelfde kleuren bleek onvoldoende.
- Alle aanzichten telden. Een overtuigend vooraanzicht verborg een verkeerde rug en te brede, zwevende cream-vlakken. De vlakken zijn uiteindelijk op de echte romp geprojecteerd met circa 1,8 mm afstand en een smallere omslag aan de achterkant.
- Pootjes moesten aan het lijf vastzitten. De veerbenen zijn met de buik verenigd; heupgewichten verlopen geleidelijk. Later bleken onafhankelijk geplante voeten ook een gewichtsverloop door de enkel nodig te hebben.
- De zwarte borstband moest dikker en doorlopend vanuit de vleugels worden. De bovenzijde van de cream-borst werd verlaagd; dit is een contourwijziging, geen algemene “meer zwart”-correctie.
- Een latere posecontrole vond ongewenste zwarte strepen midden op de borst tijdens lopen en boogspannen. De dunne cream-mesh gebruikte andere gewichten dan de onderliggende romp. `refine_crow_marking_skin.py` draagt de echte lichaamsgewichten per driehoek over en houdt 3 mm oppervlakafstand. De contour verschoof minder dan 1,4 mm; botten, romp en Actions bleven behouden. De opnieuw geïmporteerde poses toonden weer één doorlopend borstvlak.
- “Pixelated” had meerdere oorzaken: grove zichtbare kleurgrenzen, onvoldoende gladde contouren en runtime-rendering. Smooth normals alleen waren niet genoeg. Subdivision vóór Armature en geïnterpoleerde vertexkleuren hielpen; Godot moest die kleuren ook werkelijk gebruiken.
- Er is één zwaard. Het staat in rust op lokale X=0 op de rug. De grip ligt in Blender rond Z=0,94; de punt rond Z=0,10. De brede zijden kijken links/rechts. De actieve grip beweegt met de dragende vleugel.
- Een gemeten bug: het lemmet zwaaide eerst rond 1,4–1,5 m hoogte. Een mooi spoor zou die fout alleen maskeren. De actieve griporiëntatie is gebakken om de zwaai rond 0,4–0,5 m hoogte voor het lijf te laten lopen.
- De eerste slagen voelden statisch omdat vooral de vleugel bewoog. Rompverdraaiing, steunwisseling, been- en hoofdreacties, snelle inzet en zichtbaar herstel geven meer gewicht.
- Lopen bleef te rechtop. De gekozen loop- en renposes kregen respectievelijk circa 13° en 26° vooroverbuiging van de romp, met gedeeltelijke hoofdcompensatie. De idle-vorm bleef intact.
- Korte pootjes kunnen bij 4,5 m/s niet met iedere willekeurige 0,55 s-cyclus geplant blijven. De nominale clips worden op werkelijke snelheid geschaald; de steunvoet heeft een lineaire teruggaande baan.
- Additieve roze boogjes werden bleek op licht steen en waren te klein ten opzichte van de videoreferentie. De aangepaste shader heeft een volle rode sikkel, lichtgekleurde rand, bloom en een begrensde voorwaartse sector. Er is geen 360° schade-effect.
- De gameplayklok bestuurt animatie, effectvoortgang en actieve hitvensters. Meerdere doelen veroorzaken één gecoördineerde hitstop.
- Godot-scenes moeten vóór Play zichtbaar gevuld zijn. De arena heeft opgeslagen module-instances en colliders; player, dummies, vijand, HUD en effectnodes staan in .tscn-bestanden.
- Een MCP-mutatie via een externe Godot-scriptmodus kon autoloadnamen niet oplossen en sloeg een scene toch zonder scripts op. Controleer het bestand na zulke fouten en herstel vanuit de eigen bekende bron; ga niet uit van een betrouwbare toolmelding.
- Een afgedekt macOS-spelvenster leverde een oude screenshot terwijl physics doorging. Verifieer focus en getekende frames voordat je visuele conclusies trekt.
- Een replay werd beïnvloed door live toetsen. Testinput moet handmatige input voor de testduur uitsluiten; daarna moet het normale spelen terugkomen.

Bronnen voor beweging: de door de gebruiker aangeleverde video's `EOY-FMjExYA` (vooral 0:10–0:13) en `XCUOD8hMCEM` (onder meer 3:18–3:24). De gebruikte architectuur en getallen zijn eigen ontwerpkeuzes, geen reconstructie van Acid Nerve-broncode.


## Boog, projectielen en veranderende bediening

- Schrijf bij nieuwe feedback de actuele invoer expliciet uit. In dit project werd Q+LMB later vervangen door één pc-knop: Q/RMB vasthouden en loslaten. Pas InputMap, gameplayrouter, HUD, README én invoerreplay samen aan; bewaar controllerbediening apart.
- Voeg sockets en Actions toe zonder de geaccepteerde karaktermeshes te herbouwen. Controleer dat elke bestaande clip nog in de export staat. Een nieuwe boog is geen reden om lichaamsverhoudingen aan te passen.
- Twee grips moeten in dezelfde ruimte kloppen. De pees raakt de trekhand, de nock volgt die hand en de losse pijl verschijnt met zijn zichtbare punt op hetzelfde afvuurpunt. Een generieke lange blend kan de pees laten achterlopen op het schot; gebruik een passende korte releaseblend en controleer het gedeelde actiemoment.
- Een boog op exact muurhoogte is kwetsbaar voor randfouten. Deze boog zit op circa 0,66 m, onder de 0,7 m muur. Controleer zowel speler→muzzle als het volledige traject van iedere pijlstap.
- Een heldere pijl en een richtlijn hebben verschillende taken. Vergroot de projectielkern en het korte rood-roze spoor als de pijl onleesbaar is. Houd de richtlijn kort en dun; dit project gebruikt 2,2 m in plaats van het volledige bereik van 16 m.
- Visuele kracht komt uit samenhang: kleur, compacte voorbereiding, snelle release, duidelijke vliegende kern en korte contactflits. Bloom alleen lost een onduidelijke vorm of zwakke timing niet op.
- Maak magiekosten atomair bij het werkelijk aanmaken van het projectiel. Gebruik één contactsignaal per meleezwaai voor herstel. Test multi-target, twee hurtboxes, missen, onderbrekingen en een lege voorraad.
- `use_selection` bij GLB-export kan geselecteerde objecten uit een andere Blender-scene meenemen. Deselecteer via `bpy.data.objects` en gebruik `use_active_scene=True`; controleer de geëxporteerde namen (een onverwachte default Cube is een fout).
- macOS kan onzichtbare vensters niet tekenen terwijl physics doorgaat. Een opname met 1140 physicsstappen hoort bij 120 Hz ongeveer 9,5 s te duren. 111 opgenomen frames bij 60 fps bewijst weggevallen renderframes. Zet het reviewvenster zichtbaar, controleer werkelijk getekende frames en neem opnieuw op.
