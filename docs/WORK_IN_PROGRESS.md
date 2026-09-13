# Huidige stand — 13 september 2026

## Groter, rustiger bos en configureerbare gesprekken

ForestOpening heeft nu een enkele route van circa 90 meter, een breder vrij zandpad, rustige open plekken en doorlopende fysieke rotsbanken met bomen op de randen. Het manifest bevat 357 props tegenover de eerdere 745. De bestaande assetmodellen zijn hergebruikt. De editor-toevoegingen van de gebruiker (extra vlinders, Eikelwachter en tweede bosbewoner) zijn behouden. De poort ligt nu aan het einde van het uitgebreide gebied en opent ForestPassage met een huis. De voordeur opent ForestHouse met de aanspreekbare Linde; beide verbindingen werken ook terug. De herbruikbare ScenePortal heeft een instelbaar detectiegebied, bestemming, aankomstmarker en instellingen voor doorlopen/inlopen en fade. Zie [SCENE_TRANSITIONS.md](SCENE_TRANSITIONS.md).

Er is een herbruikbaar dialoogsysteem voor NPC's, borden en inscripties. Complete gesprekken en hun tekstblokken zijn `.tres`-Resources; `Prompt` bepaalt per instance of prefab het label zoals Praten/Lezen. NPC's kunnen met een instelbaar visueel draaipunt naar de speler kijken. De kleine interactieknop volgt het actieve apparaat. Openen/afsluiten gebruikt de bestaande klok en inputblokkades. Zie [DIALOGUE.md](DIALOGUE.md) en [FOREST_OPENING.md](FOREST_OPENING.md). Native Forward+ Metal: 18 boscontroles en 51 overgangscontroles slagen bij caps30/60/120; 29 dialoogcontroles en 42 controllercontroles slagen bij cap60. Vertrek en aankomst lopen elk circa 1,5 m door, alle vier verbindingen werken zonder directe terugreis en levens/magie blijven behouden. De actuele metingen staan in `FOREST_VALIDATION.json`.

De eerdere onafhankelijke assetmatch bleef op 5,6/10; de nieuwe opdracht gebruikt die bestaande assets voor levelbouw. De vormmatch is hiermee niet als 1:1 afgerond verklaard.

## Introscherm: The Last Lantern

F5 opent nu `TitleScreen.tscn`, gebaseerd op de aangeleverde afbeelding. De titel verschijnt rustig zonder transparantievlekken. De opties volgen later met dezelfde easing en een kleinere beweging; ze blijven boven de lantaarn. Een bewegende vlam, subtiele lichtvariatie en enkele vonkjes vervangen de snelle pulsering en te grote deeltjeshoeveelheid. Testscene is instelbaar in de Inspector en opent voorlopig TestArena. New Game opent ForestOpening; Main menu in het pauzemenu keert terug. Continue blijft uitgeschakeld zolang er geen opslagsysteem is. Instellingen voor volledig scherm en controllertrilling werken. Zie [INTRO_SCREEN.md](INTRO_SCREEN.md) voor bestanden en controles.

## Panda-beweging en grijze silhouetten

Idle/walk/run zijn opnieuw geanimeerd op de bestaande panda; geometrie en skinweights zijn gelijk gebleven. De lage zwaardhouding beweegt met de arm mee, voetfasen sluiten aan tussen lopen/rennen en romp/staart bewegen mee. De laatste snelheidskeuze is 3,8 m/s. Negentien bestaande clips hebben aangepaste begin-/herstelposes voor de nieuwe draaghouding; actieve zwaardbanen en gameplayvensters blijven behouden. De actuele bron bevat 32 Actions, inclusief fall/land. Broncheckpoint, controles en opname: [PANDA_MOTION.md](PANDA_MOTION.md).

Speler, vijanden en passieve doelen tonen achter ondoorzichtige meshes hun volledige silhouet in `#414342`. De centrale materiaalresource en opgeslagen stencilpass gebruiken dezelfde kleur. Actuele Forward+ Metal-beelden staan in `captures/occlusion/`; `render.json` bevestigt de geladen kleur.

Melee-, boog-, controller- en crowdregressies slagen voor panda, kraai en capybara bij cap60. De enemy-suite heeft nog een mislukte toelatings-/routecontrole bij de gewijzigde TestArena-muur; dit blijft expliciet open. Oudere volledige groene suites hieronder zijn historische resultaten, geen actuele claim voor die veranderde arena.

## Nieuw: eikelwacht en Cascadeur-bronnen

Twee referentiegestuurde eikelwachters staan in PrototypeRoom, met eigen bewerkbare bron, losse knots en dertien botclips. Ze gebruiken de gedeelde EnemyBrain/Health/Damageable, eigen rust-/patrouilleschema's, contextuele aanvalskeuze en verschillende tempo's. De nieuwe besturing combineert automatische 3D-navmeshes uit wereldcolliders, vrije padsegmenten, vooruitkijkend ontwijken, afremmen en lopend indraaien bij gewone bochten. Onderzoek en uitbreiden naar nieuwe types: [ENEMY_AI_DESIGN.md](ENEMY_AI_DESIGN.md).

Alle 50 acorncontroles en 18 nieuwe bewegingscontroles slagen in Forward+ Metal (938 en 986 renderframes). Bewegingslogica slaagt ook bij caps30/120, inclusief vier kruisende vijanden. Alle vijf bestaande suites slagen voor panda, kraai en capybara bij cap60: 798 headless checks. De oorspronkelijke panda-bron/GLB zijn hashgelijk gebleven. Details, previews en visuele verschillen: [ACORN_GUARD.md](ACORN_GUARD.md). De 23 nieuwe brug-/trapcontroles slagen in Metal met 1041 renderframes, inclusief benadering vanaf de zijkant zoals in de screenshots. Navigatie werkt zonder Arena-script of vaste levelgrenzen: een afzonderlijke 256 × 256 m wereld vindt automatisch een route van 200 m om een muur (7 geslaagde controles). Gehoor, bewegende platforms, voet-IK en profiling met grote dichte menigten blijven open. Automatisch herberekenen omvat nu de hele geladen scene; chunkgewijze streaming is nog niet geïmplementeerd.

De gevraagde panda-loop (0,8 s) en uitgebreide gevechtstijdlijn (8,25 s) zijn native `.casc`-bestanden. Integratie in Godot blijft open: de aanwezige Cascadeur Free-licentie staat geen FBX-export toe. Volledige gevechtsreview moet nog gebeuren; bron/game-GLB zijn behouden. Zie [CASCADEUR_PANDA.md](CASCADEUR_PANDA.md).

## Correctie: hoeken, passieve doelen en natuurlijke bochten

De nieuwe hoekreplay reproduceerde zes blokkades die de eerdere brug-/traptests niet afdekten. EnemyLocomotion controleert nu de werkelijke capsulebeweging, ook tegen passieve trainingsdoelen. Het herstel vlak naast de navmesh blijft niet meer steken op een te kleine draai-input. De planner verkiest een kaart met 0,20 m extra ruimte, met automatische terugval op de fysieke maat voor smalle routes. Vooruitkijken langs het pad en lopend indraaien vervangen het stoppen bij gewone hoeken. Volledige hoek-/doorgangsreplay: 54 checks; native opname: 14 geslaagde gerichte checks met 720 renderframes. Zie ENEMY_AI_DESIGN.md en de actuele `captures/acorn_guard/corner_checks_*.json`.

## Geldende gebruikerskeuzes

- Eén rode panda. De oorspronkelijke ronde chibi-anatomie uit `lantern_panda.png` blijft leidend. `ranger_panda.png` levert uitsluitend jack, shirt, riem/tasje, handschoenen en beenwikkels. Geen brede ranger-anatomie, geen cape. Bron: `assets/characters/red_panda/source.blend`; 32 clips in model.glb.
- Zwaard in rust in de rechterhand, brede zijden naar links/rechts. De tijdelijke rugvariant is expliciet teruggedraaid. Eén zwaardinstance; linkerhand draagt de losse lantaarn. Boog/rollen/dood verbergen de lantaarn.
- Opgeslagen 32 × 32 m prototypekamer. Camera 13 m orthografisch, vaste 50°/45° hoek, zachtere horizontale halfwaardetijd 0,12 s en verticale 0,08 s. Geen vertraging toegevoegd aan spelerinvoer.
- Lange testtrap links/west: 16 treden, 2 m breed, 8 m lang, 4 m stijging; bordes op 4 m. Onderkant (-11,0,0), bovenkant (-11,4,-8). Gladde rampcollision. Bestaande korte trap naar het dorpshuis blijft.
- Nieuwe HUD uit de screenshot van 12:20:44, met de laatste correctie: schuine GROENE levenssegmenten met tegenovergestelde puntige uiteinden, donker teal contour en vier GELE BOLLETJES voor magie. Vlamiconen zijn op verzoek vervangen. Oude grote diamant-wapenslots verdwijnen uit de HUD; besturing/loadoutlogica blijft bestaan.

## Opgeslagen en gecontroleerd

- Long_stairs heeft eigen Blender-bron, GLB en Godot-wrapper. De treden zijn verlengd door zestien echte stappen; geen uitgerekte kopie van vier treden. Voorkant, beide zijden, achterkant en spelcamera van de bron zijn bekeken vóór export. Nieuwe instances staan ook in `prototype_room.blend`.
- Lange trap, bordes, hekjes en colliders staan als nodes in PrototypeRoom.tscn. `author_room.py --final` reproduceert de plaatsing offline en controleert niet-overlappende grondvlakken. Runtime bouwt geen levelmeshes.
- Grond/pad-overlap is opgelost met echte aansluitende deelmodules. Verlaagde trapkern en warm omgevingslicht zijn opgeslagen.
- Camera-onderzoek: Death’s Door-beeldreeks 3:18–3:26 bekeken. Het karakter beweegt binnen het beeld terwijl de wereld meeschuift. Onze formule en getallen zijn eigen keuzes, niet bewezen Acid Nerve-instellingen. Zie CAMERA_FOLLOW.md.
- Actuele roomreplay controleert camera, brug, beide trappen, diagonale snelheid, grenzen, wapenhouding en HUD. Zie `captures/lantern_village/room_checks_*.json` en VALIDATION_LANTERN.md; alleen runs met echte renderframes gelden als visuele runtimecontrole.

## Huidige combatwijziging

Sunblade: bereik blijft1,9 m, geladen2,4 m. Zes nieuwe botclips leveren rechte, stijgende en dalende slagen in beide richtingen, ondiep20°. De richting wisselt vast af en de stijl is willekeurig zonder directe herhaling. Geen klik-wachtrij: vroege klikken verdwijnen; een verse klik in de laatste0,10 s herstel start direct. Heavy-charge is versneld naar0,45 s en de laadclip schaalt mee. Godot importeert panda-animaties op120 samples/s na een gevonden foute tussendraai bij30. Die combatrevisie bevatte29 Actions; de actuele bron telt32 inclusief fall/land/entrance. Details en bewijs: COMBAT_SWINGS.md en VALIDATION_LANTERN.md.

## Bronnen / voorzichtig hergebruik

De bewerkbare bestanden zijn leidend. Niet blind `build_ranger.py` rerunnen: dat is de verworpen bredere lichaamsvariant. `fit_ranger_clothes.py`, `refine_chibi_outfit.py` en andere hersteltools waren gerichte stappen op checkpoints. Bestaande fijnbewerkte mesh niet overschrijven met een eerdere generator.

`build_long_stairs.py` maakt alleen een ontbrekende nieuwe collectie; bestaande asset eerst inspecteren. `review_blender.py` neemt het actuele bronframe over en ondersteunt grotere lichtafstanden voor grote assets. Exporteer alleen de assetcollectie; nooit previewwapens of reviewvloeren.

## Eerlijke resterende beperkingen

De wereld blijft een functionele, vrij open testkamer met eenvoudige waterweergave. Geen claim dat alle details of kleding-/bewegingsposes exact 1:1 met de referentie zijn. De bovenste cameraschaal bij de hoge trap toont buiten de diorama wat achtergrond; de camera draait of zoomt niet automatisch om dit te verbergen. De treden gebruiken bewust een gladde loophelling; afzonderlijke voet-IK per trede is niet geïmplementeerd.

Godot meldt bij sommige sluitingen één gelekte shader/RID; dit is geen gemeten gameplay-freeze. Behandel headless replayresultaten niet als bewijs voor FPS of perfecte animaties. Oudere buildgeschiedenis staat in HISTORY_LANTERN_BUILD_LOG.md.
