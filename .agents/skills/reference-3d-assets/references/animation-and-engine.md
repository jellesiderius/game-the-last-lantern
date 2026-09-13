# Rig, animatie en runtime

## Ruimtes en sockets

Leg metrische schaal en voorrichting vast. Blender Z-up en Godot Y-up worden via glTF geconverteerd. Verifieer de uiteindelijke voorrichting met een onmiskenbaar kenmerk zoals de snavel. Corrigeer een verkeerde richting eenmaal op de visuele parent; bouw geen stapel rotatiecorrecties in input en aanvalscode.

Plaats een vaste root bij de voeten. Rootbeweging en fysieke beweging hebben één eigenaar. Bij in-place clips blijft de root horizontaal en qua rotatie vast; veren, rollen en lichaamsbuiging horen op onderliggende botten. De CharacterBody-collider draait niet mee met de koprol.

Een wapen heeft een expliciete grip, lemmetbasis en punt. Benoem de draaghand/vleugel en eventuele bergsocket. Controleer welke as langs het lemmet loopt en welke normaal de brede zijde heeft. “90 graden draaien” zonder die assen te meten kan een rechtop gehouden zwaard met de brede zijde horizontaal opleveren.

Bij één wapen dat op de rug rust en in de vleugel slaat, houd je één mesh-instance. Laat die tussen twee bestaande bottransforms overgaan, met een BoneAttachment3D als attachment. Centreer de rugsocket in lokale karakterruimte; een verschuiving in cameraruimte lost een scheve montage niet op. Controleer pommel- en punthoogte, rugafstand en broad-face normaal. Test ook lopen, buigen, rollen en doodgaan.

## Poses die gewicht hebben

Maak voorbereiding, snelle inzet, impactpose en herstel afzonderlijk leesbaar. Een statische romp met alleen een draaiende arm voelt als een mechanische prop. Betrek bekken, romp, hoofd, beide vleugels en voeten, met tegengestelde beweging waar het gewicht opgevangen wordt. Gebruik gedoseerde rompverdraaiing en een geplante voorvoet. Het hoofd kan deels tegensturen om het doel leesbaar te houden.

Laat clips een eigen houding hebben. Een terugslag verandert richting én steun; een afsluiter krijgt meer lichaamsinzet en langer herstel. Een zware aanval bouwt spanning op. Meng bij vroeg loslaten kort vanaf de echte gedeeltelijke laadpose, zonder de impact weg te mengen. Start een clip niet iedere tick opnieuw.

Voor lopen en rennen: maak afwisselende stappen met een steunfase en een opgetilde terugzwaai. Controleer de werkelijk afgelegde grondafstand tegenover de voetbaan. Een nominale animatie van 0,55 s is niet automatisch passend bij 4,5 m/s voor korte kraaienpootjes. Bereken de natuurlijke snelheid uit staplengte en steunfase, en schaal playback op de gemeten snelheid. Houd lopen minder voorover dan rennen; bewaar de rechtopstaande rustvorm in idle.

Verifieer contact onder vervorming. Meet de laagste geëvalueerde meshvertices per frame wanneer dat praktisch is. Bake een kleine pelviscorrectie waar nodig; beweeg niet de root of collider om penetrerende voeten te verbergen. Een lange nek kan tijdens een volledige koprol door de vloer zakken, ook als de voeten correct zijn.

### Gewichten beoordelen na het binden

Afstand tot een bot alleen is een zwakke skinmethode bij dikke ledematen dicht bij de romp. Vergelijk een heat bind met doelgerichte gewichten en test eerst een gebogen knie, geheven arm en maximale boogtrek. Ook een heat bind kan kleine arminvloeden op de buik achterlaten. Begrens die invloeden met vloeiende anatomische maskers; geef snuit en ogen een stabiel hoofdbot. Socket- en rootbotten hoeven geen huid te vervormen.

Bij opschonen in Blender: maak vóór `VertexGroup.remove()` een kopie van de **integer group-ID's**. Bewaar geen `VertexGroupElement`-objecten terwijl je dezelfde lijst wijzigt; die RNA-verwijzingen kunnen tijdens verwijderen veranderen. Controleer daarna iedere vertex op normalisatie, ontbrekende gewichten en maximaal vier bedoelde invloeden. Controleer ook vervormingsranden: een technisch geldige selectie van de vier grootste gewichten kan zichtbare plooien veroorzaken als naburige vertices opeens andere botten volgen.

Een IK-doel buiten het bereik van de arm wordt begrensd. Het werkelijke hand-/socketpunt kan daardoor hoger liggen dan de opgegeven doelhoogte. Meet de geëvalueerde botpose én de geïmporteerde afvuurhoogte. Controleer booghand, trekhand, pees, pijl en muur samen; een mooi handdoel in de generatiescript bewijst geen correcte grip in de game.

Een dun kleurvlak kan in rust netjes aansluiten en bij buigen alsnog door de huid verdwijnen. Een aparte gewichtsformule op basis van hoogte hoeft niet overeen te komen met de werkelijke romp. Draag gewichten bij voorkeur barycentrisch over vanaf de onderliggende meshdriehoeken, met een kleine consistente oppervlakafstand. Controleer de volledige loopcyclus en maximale rompbuiging in de import: zwarte banden of stippen op een licht vlak zijn geen normaal kleurdetail. Vergroot niet alleen de afstand om verschillende vervormingen te verbergen.

## Export

Controleer vóór posebewerking dat de armature niet in Edit Mode staat. Keyframewaarden kunnen daar wel veranderen terwijl de geëvalueerde botmatrices de oude pose blijven tonen. Verlaat Edit Mode, werk de dependency graph bij en controleer daarna de werkelijke socketposities. Bij Action slots wijs je de bedoelde rig-slot expliciet toe; controleer de geëvalueerde pose, niet alleen curvewaarden.

Inspecteer de Blender-versie en geldige glTF-opties. Nieuwere Action slots veranderen hoe clips aan rigs gekoppeld zijn. Exporteer afzonderlijke Actions met hun bedoelde namen en duur; voorkom ongewenste samengevoegde tijdlijnen. Bake constraints naar botcurves. Verifieer daadwerkelijk de clips in het geïmporteerde AnimationPlayer.

Gebruik één editor-scene als gameplaywrapper rond het geïmporteerde model. Scripts, sockets, materialen en effectnodes horen in de wrapper. Een herexport mag geen gameplay vernietigen. Generatiescripts zijn nuttig, maar markeer oudere destructieve scripts duidelijk; een later handmatig verfijnd model is niet automatisch reproduceerbaar door het allereerste script opnieuw te draaien.

## Synchronisatie en effecten

Gameplay bepaalt toegestane acties en actietijd. Laat AnimationTree die toestand weergeven. Voer physics en animatiesampling op een consistente tijdstap uit. Pauzeer actievoortgang, botanimatie en schadevenster samen tijdens hitstop; gebruik één gecoördineerde regeling.

Koppel schade aan de werkelijke zwaardbaan. Sample basis en punt, sweep tussen opeenvolgende posities, query overlappende hurtboxes tijdens iedere actieve tick, en dedupliceer per doelinstantie en attack-id. Test ook een doel dat al overlapt, twee hurtboxes op één doel, meerdere doelen en een doel achter een lage muur.

Een rode slash is geen continue ring. Gebruik een begrensde voorwaartse sector en een bewegende, taps toelopende sikkel. Laat de hoek uit de werkelijke lemmetrichting komen. Gebruik actietijd als shaderparameter, niet ongeremde shader-TIME, zodat hitstop consistent blijft. Controleer PlaneMesh-UV-richting of gebruik expliciet lokale geometriecoördinaten.

Een zichtbaar magisch verlengd lemmet mag alleen extra bereik krijgen wanneer dat de gevraagde gameplay is. Leg dan hoogte, straal, sector en schuine basis vast in dezelfde swingdata voor shader én physics. Sweep de bewegende voorrand in 3D; vergroot niet stilzwijgend een onzichtbare cirkel om een cosmetisch effect te laten raken. De vervagende naloop en grondgolf blijven cosmetisch. Test nabije overlap, uiterste bereik, voor/achter, muren en onderbreking. Leid ook warme/highlightkleuren en doelimpact af van het wapenpalet; alleen een albedokleur aanpassen verwijdert geen hardcoded roze shaderaccenten.

Sample willekeurige pose-/effectvariatie eenmaal bij slagstart en houd die vast tijdens de actie en hitstop. Als opeenvolgende slagen moeten afwisselen, bewaar de richting over de combo-grens; gebruik toeval alleen voor de afgesproken variabelen. Een omgekeerde shader vraagt een passende omgekeerde botclip. Remap voorbereiding, actieve fase en herstel afzonderlijk wanneer de gekozen clip andere faselengtes heeft. Een nieuwe heavy moet herkenbare laad-, impact- en herstelposes hebben; een groter effect op dezelfde heupzwaai is daarvoor onvoldoende.

Additieve rode effecten kunnen op lichte grond bleek worden. Een vollere rode kern met alpha-blending en gerichte emissie kan leesbaarder zijn. Controleer bloom in de werkelijke renderer. Emissie, bloom en lokaal gereflecteerd licht zijn verschillende zaken; een klein lokaal licht is optioneel. Vergroot een effect bewust en controleer de relatie tussen zichtbare kern en werkelijk schadebereik.

## Bewijs

Start de game. Headless import is alleen technische verificatie. Leg clips vast in de spelcamera, liefst als korte replay/video, en bekijk daadwerkelijk beelden uit die opname. MacOS kan een afgedekt spelvenster niet meer tekenen terwijl physics blijft lopen: een screenshot kan dan verouderd zijn. Controleer getekende frames, vensterfocus en een zichtbaar gewijzigde pose.

Gebruik gerichte replays voor afstand, actieduur, combo-buffering, muren, schade, invulnerability, hitstop, pauze en respawn. Vergelijk rendercaps met dezelfde physicsinstellingen. Isoleer replay-invoer van handmatige toetsen; anders kan een spelende gebruiker een deterministische afstandstest veranderen. Laat na tests een normaal speelbare scene achter.

## Meerdere personages en bewegende feedback

Bewaar bron/export per personage en deel besturing en damagecontracten. Een personagedefinitie koppelt model, uitrusting, kleuren en instellingen. Controleer per type grip, lemmetpad en staplengte; zet vogelanimaties niet ongecontroleerd op een ander lichaam.

Een weigering wegens lege magie mag geen onbedoelde bewegingsbeperking veroorzaken. Als de speler moet blijven lopen, maskeer de weigeranimatie tot het bovenlichaam en laat locomotion bekken en benen aansturen. Een nette pose die de speler stilzet of voeten laat glijden is geen geslaagde controle.

## Lessons from short diagonal attacks

Een schuine shader boven dezelfde armbeweging is onvoldoende animatievariatie. Maak afzonderlijke rechte, stijgende en dalende botbanen met dezelfde gevraagde slagrichting. Begrens de helling als de gebruiker brede zijwaartse slagen wil. Een animatieverzoek is geen toestemming om een klik-wachtrij toe te voegen. Test dat afstanden en multi-target treffers behouden blijven wanneer alleen presentatie verandert; compenseer horizontale verkorting bij kanteling indien het bereik gelijk moet blijven.

Controleer snelle clipbanen ook TUSSEN de sleutelposes na import. In dit project vervormde Godots30-Hz import een0,10-s zwaai die in Blender wel goed was. Vergelijk dezelfde actietijd en de geëvalueerde socketmatrix in beide applicaties. Hier loste de bewerkbare instelling animation/fps=120 dit op, bevestigd met echte zwaardpuntsampling. Verhoog sampling gericht; schrijf niet in .godot/imported en ga niet uit van alleen begin/eindposes. Wanneer charge sneller wordt, schaal de hele laadclip naar de nieuwe duur zodat de release vanuit de volledige laadpose begint.
