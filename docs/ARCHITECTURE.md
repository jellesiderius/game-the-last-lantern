# Een uitbreidbare basis

De scene bezit de onderdelen; gameplaycode verandert hun toestand. Imports zitten in visuele wrappers, zodat een nieuwe GLB-export geen controller of wapenattachment vervangt.

## Verantwoordelijkheden

| Onderdeel | Verantwoordelijkheid |
|---|---|
| `PlayerCharacter` | CharacterBody-beweging, actieprioriteit, buffers, de gameplaystate en gedeelde actietijd |
| `CharacterDefinition` / `GameSession` | Geselecteerd type, opgeslagen visual, collidermaat en HP; dezelfde Player-scene met een CharacterDefinition |
| `WeaponDefinition` | Kleuren, emissie, optioneel energiebereik en swingvariatie voor geërfde zwaardscenes |
| `CombatFeedback` | Voorwaartse slash, charge, zware grondenergie en geluid, uitsluitend gesampled uit actietijd |
| `MovementSettings` | Beweging, rol, onkwetsbaarheid en hitstop |
| `CombatMoveset` / `AttackDefinition` | Benoemde meleeclips, voorbereiding, actieve duur, herstel en schade; bewerkbaar in `default_melee.tres` |
| `CharacterVisual` | Handmatig gesamplede AnimationTree, botblends, hand-/rugsocket en zichtbaarheid van de twee wapentypes |
| `MeleeWeapon` | Het echte lemmetpad en optionele zichtbare energievoorrand sweepen, doelen per zwaai dedupliceren en één `swing_connected`-signaal versturen |
| `BowCombat` / `BowSettings` | Booginvoer en regels, gestuurd door dezelfde playerstate/actietijd; afvuurpunt, korte richtlijn en projectielaanmaak |
| `MagicComponent` | Begrensde voorraad, atomaire `try_spend`, herstel en feedbacksignalen; geen automatische regeneratie |
| `MagicArrow` | Rechte beweging, volledige trajectray per physicsstap, eerste treffer, opruimen bij afstandslimiet |
| `HealthComponent` | Leven, schade en verandering-/depleted-signalen |
| `Damageable` | Gedeelde doelbody, gezondheid, hitreactie en reset; optionele AI-component |
| `EnemyBrain` / `EnemySettings` | Waarneming, navigatie, wachten, windup, vastgelegde slag en herstel |
| `EnemyTactics` / `EnemyAttackDefinition` | Contextuele aanvalscores en instelbare slagdata; uitvoering en klok blijven in EnemyBrain |
| `EnemyVariation` | Gedeelde grenzen voor individuele snelheid, reactietijd, rust, routes en voorkeuren; RNG/eigenschappen zijn per Brain |
| `NavigationWorld` / `EnemySurfaceNavigation` | Automatische 3D-navmeshes uit wereldcolliders, gedeeld per lichaamsstraal/hoogte; routes, oppervlakcontrole en ruimtelijke buurtselectie |
| `EnemyLocomotion` / `EnemyMovementSettings` | Route volgen, nabije beweging voorspellen, versnellen, afremmen en draaien vóór lopen |
| `skinned_enemy_visual.gd` | Geïmporteerde botclips samplen uit EnemyBrain-actietijd, inclusief optionele doodpresentatie |
| `AttackTokenManager` | Maximaal twee toegelaten aanvallers, gewogen beurtverdeling en vrijgeven bij onderbreking |
| `InputRouter` | Actief apparaat, prompts, menu-invoergrens, disconnect en trilling |
| `ActorInteraction` / `Interactable` | Nabij doel met zichtlijn selecteren en de specifieke interactie uitvoeren |
| `RangedLoadout` | Afstandsvaardigheid kiezen; lege slots blijven vergrendeld |
| `GamePauseMenu` | Herbruikbare tabs, controllerfocus, instellingen en hervatten/herstartsignalen |
| `GameClock` | Eén physicsklok met gecoördineerde pauze/hitstop; geen gewijzigde `Engine.time_scale` |
| `HUD` | Presentatie van HP/magie/feedback en pauzemenu |

De eikelwacht activeert de optionele tactiek- en variatieprofielen. Alle enemies gebruiken de algemene navigatie met een instelbaar bewegingsprofiel. Andere enemyprofielen kunnen deze componenten hergebruiken met eigen data en visuals. Een Resource bewaart geen toestand van een individuele vijand. Onderbouwing, scenario's en huidige navigatiegrenzen: [ENEMY_AI_DESIGN.md](ENEMY_AI_DESIGN.md).

`BowCombat` schrijft niet via eigen timers naar animatie of schade. Het gebruikt `player.state` en `player.action_time`; het loslaatmoment maakt precies één `Arrow.tscn` en schrijft op datzelfde moment één magiepunt af. Onderbreken wist `shot_pending`. De zichtbare pees wordt via de botpose gesampled vóór het projectiel verschijnt.

Een getroffen melee-target veroorzaakt maximaal één `swing_connected` per zwaai. De speler vertaalt dat signaal naar `magic.restore(1)`. Pijlen gebruiken dezelfde `receive_hit`-ingang, maar versturen dit meleesignaal nooit.

## Collisioncontract

Wereld = 1, speler = 2, vijand/doelbody = 4, doelhurtbox = 8, spelerhurtbox = 16. Deze bitmasks staan benoemd in `CombatLayers`. De wereldcolliders zijn eenvoudige dozen; één vloerbox voorkomt naden tussen tegelcolliders. Het zwaard gebruikt capsule-samples over het volledige vorige/huidige lemmetpad en een extra world-ray. De pijl raycast zowel speler→afvuurpunt als vorige→volgende punt. Het eerste obstakel beëindigt het projectiel.

## Uitbreiden

Voeg een nieuwe meleeslag toe als `AttackDefinition` plus benoemde botclip en een expliciete gameplaytransitie. Voeg een doel toe met Health, hurtboxes en `receive_hit(amount, attack_id, origin, force)`. Verander geen animatie- of shaderklok los van `GameClock`. Nieuwe afstandswapens kunnen MagicComponent, Arrow's trajectcontrole en het damagecontract hergebruiken. Het gedeelde `MeleeWeapon.tscn` is de basis voor rose_sword/Weapon.tscn en amber_sword/Weapon.tscn; de varianten leveren een opgeslagen model en een WeaponDefinition.

`EnemyBrain` is een component op een doelbody. De AI vraagt eerst een aanvalstoken aan; alleen de eigenaar mag naar engage/windup/strike/recover. De manager scoort afstand, recent geraakt worden, archetype en wachttijd. Een geblokkeerde aanloop behoudt zijn wachttijd na verlopen toelating; de wachtbonus blijft groeien zodat nieuwe aanvragen hem niet blijvend verdringen. Hij geeft maximaal twee tokens uit met een korte tussenruimte. Recovery, stagger, dood, uitschakelen en herstart geven tokens vrij. Een gecommitteerde voorbereiding wordt niet stilzwijgend gestolen.

NavigationWorld bakt de wereldcolliders automatisch naar een 3D-navmesh met lichaamsruimte, hoogte en beloopbare hellingen. De service vereist geen Arena-script, vaste bounds of speciale brug-/trapnamen. Gelijke lichaamsmaten delen hun fysieke kaart en een ruimere voorkeurskaart; smalle doorgangen vallen terug op de fysieke maat. Vooruitkijken langs het pad maakt gewone bochten lopende bogen. Werkelijke capsuleprobes controleren ook passieve doelen en blokkades aan lage randen. De optionele opgeslagen cache wordt op colliderhash gecontroleerd. De controller gebruikt nog steeds `move_and_slide()`; een pad is geen toestemming om door een muur te bewegen. Wachtende vijanden houden afstand en spreiden zich rond het doel. De slag volgt na een duidelijke voorbereiding; alleen het eerste deel daarvan mag nog bijrichten. De oranje grondsector vult van de voorrand terug naar de vijand; zijn fractie komt uit dezelfde `state_time / windup`. Een korte lichtpuls staat vóór de actieve rode fase.

Gebruik overerving voor echte specialisatie. `Bruiser.tscn` erft de gedeelde vijandscene en vervangt instellingen. `training_interaction.gd` erft `Interactable` en implementeert het resetten van een trainingsdoel. Spelers, vijanden en HUD delen losse gezondheid-/magiecomponenten waar dat past; ze hoeven geen kunstmatige gezamenlijke actor-superklasse te krijgen.

## Validatie en onderhoud

`runtime_replay.gd` bewaakt de bestaande melee-, bewegings- en onderbrekingsregels. `bow_replay.gd` bewaakt magie, directe pc-invoer, controllerachtige aparte richtinvoer, trajecten en wapenterugkeer. Beide draaien in het opgeslagen TestArena. PrototypeRoom heeft eigen room- en energyreplays; de nieuwe TitleScreen-hoofdscene stuurt die CLI-verzoeken door. `captures/*checks*.json` rapporteert resultaten en gemeten renderfrequentie. Visuele reviews en beperkingen staan in `VALIDATION.md`.

GDScript is met gdformat geformatteerd. Tooling heeft geen runtime Python-afhankelijkheid. De Blender-scripts documenteren de bronbewerking; het opgeslagen `.blend` is leidend.

## Controller en menu

De Input Map staat in `project.godot`, zichtbaar in de editor. `tools/configure_input.gd` schrijft de huidige standaardindeling alleen wanneer expliciet uitgevoerd. Godots positionele A/B/X/Y-benamingen komen overeen met kruisje/rondje/vierkant/driehoek. Zie de [Godot-controllerdocumentatie](https://docs.godotengine.org/en/4.7/tutorials/inputs/controllers_gamepads_joysticks.html).

`InputRouter` wisselt alleen bij echte toets-/knopinput of voldoende stick-/muismotion. De rechter stick verschuift de vaste camera beperkt; de linker stick blijft eigenaar van loop- en controller-aanvalsrichting. Menuovergangen wissen pending laadinput en blokkeren gameplaypolling kort: Godots globale Input-status verdwijnt niet doordat GUI een event verwerkt. Dat voorkomt rollen bij bevestigen en schieten bij teruggaan. Een losgekoppelde actieve controller pauzeert en annuleert een niet afgevuurd schot.

Het pauzemenu kent Game/Controls/Settings, schouderknoppen voor tabs, expliciete focusvolgorde en een herstartfocus na dood. PC en controller gebruiken dezelfde acties; prompts veranderen mee. De controllerreplay gebruikt echte InputEvents door de opgeslagen InputMap en native GUI, en controleert ook menulekken en disconnect.

## Speelbare typen en geladen slagen

Een nieuw speelbaar type krijgt `assets/characters/<id>/{source.blend,model.glb}`, een visuele wrapper in `scenes/assets/characters/<id>/Visual.tscn` en een `CharacterDefinition` in `settings/characters/`. Registreer die alleen in GameSession wanneer meerdere speelbare typen weer gewenst zijn; momenteel opent New Game vanuit TitleScreen één rode panda in ForestOpening; direct starten blijft mogelijk. CharacterSelect is historisch. De wrapper levert Skeleton3D, AnimationPlayer, SwordAttachment, BowAttachment en BowDrawAttachment met het gedeelde socketcontract. De speler kent geen GLB-botpad of vogel-/zoogdierbranch. `stow_at_rest` en natuurlijke stapcyclus-snelheden staan op de visual.

GameSession initialiseert zijn standaardprofiel en eventuele `--character=<id>` al in `_init()`. Een direct gestart level kan `_enter_tree()` bereiken vóór de autoload-`_ready()`; een pas daar ingevulde keuze was te laat. Selectie, herstart en menuovergangen worden apart getest.

Gameplay houdt `heavy_release` als actie-ID en timingdefinitie. Bij volle charge kiest alleen de presentatie `charged_clip`; schade, knockback en hitstop worden bij swingstart één keer uit dezelfde AttackDefinition vastgelegd. De grondenergie is cosmetisch en voorwaarts begrensd. CombatFeedback heeft geen eigen timer of damagecode. Alle zichtbare effectmeshes zijn opgeslagen scenes.

Een vijand die zijn leash overschrijdt keert eerst terug binnen 0,18 m van zijn startpositie. Hij mag tijdens die terugkeer geen nieuwe token aanvragen; zo wisselt hij bij de grens niet iedere stap tussen achtervolgen en teruglopen.

InputRouter schakelt eventaccumulatie uit voor directere aim-/triggerinput. Volgens de [Godot Input-documentatie](https://docs.godotengine.org/en/4.7/classes/class_input.html#class-input-property-use-accumulated-input) kan accumulatie eventafhandeling aan de renderfrequentie koppelen. De controllerreplay wacht bij native GUI-activering ook op een rendergrens, omdat focus via deferred layout wordt gezet; dat is gescheiden van het testen van gameplay-actieduren op 120 Hz physics.

## Huidige miniature room

PrototypeRoom erft de gedeelde arena-feedback en levert eigen grenzen, respawn en cameravolging. Het level bestaat uit opgeslagen asset-instances; author_room.py is uitsluitend offline tooling. Grondvoetafdrukken zijn niet overlappend, colliders zijn doorlopend en de vier treden hebben een hellingcollider. De ruimte is 32 × 32 m, camera size 13 m met vaste 50°/45° kijkrichting.

De cameravolging gebruikt exponentiële demping met een instelbare halfwaardetijd (horizontaal 0,12 s; verticaal 0,08 s). De gewichten komen uit `GameClock.dt`, zodat renderfrequentie, pauze en hitstop geen afzonderlijke cameraklok introduceren. De speler reageert direct; alleen de framing loopt iets achter. Het doel wordt vóór het dempen begrensd. `reset_camera()` wist die achterstand bij respawn/teleport. Het historische TestArena behoudt zijn eigen beperkte arena-framing. Er is geen extra vertraging in beweging of input.

CharacterVisual heeft optionele upright_accessory_paths voor gedragen props. Ze volgen de botpositie en blijven rechtop; boog/rollen/dood verbergen de lantaarn. De keuze voor hand- of rugwapen blijft een visual-instelling. De panda gebruikt stow_at_rest=false. Een opgeslagen roll op sunblade/WeaponModel laat de brede lemmetzijden naar buiten wijzen zonder een extra controller of andere schadebaan.

`synchronize_gait_phase` laat passende walk/run-clips dezelfde genormaliseerde voetfase gebruiken. De panda schakelt dit in; bestaande andere rigs behouden hun eigen afspeelwijze. De fase gebruikt de werkelijk afgelegde snelheid van CharacterBody3D en `GameClock.dt`. De visuele snelheidsblend heeft een halfwaardetijd van 0,035 s; gameplay-invoer krijgt daardoor geen extra demping. Actieterugkeer blendt de vorige botpose in 0,12 s naar locomotion.

`OcclusionSilhouette.apply()` geeft actoroppervlakken een eigen kopie van hun BaseMaterial3D met Godots XRAY-stencilmodus. CharacterVisual past dit toe op de speler inclusief socketprops; Damageable op NPC-visuals. Eén gedeelde stencilwaarde voorkomt dat een verborgen arm over de zichtbare romp wordt getekend. Basismateriaal, silhouet en schade-overlay hebben respectievelijk renderprioriteit 10, 11 en 20. De kleur komt uit `settings/occlusion_silhouette.tres` (`#414342`). De helper maakt geen nieuwe meshes en wijzigt geen geïmporteerde materialen.

## Energiebereik en doorlopende slagen

De sunblade kan expliciet energie toevoegen aan het korte fysieke lemmet. MeleeWeapon bezit hiervoor straal, hoogte, 3D-basis en bewegende voorrand; CombatFeedback geeft precies die waarden door aan de opgeslagen slashscene. Willekeurige hoek-/breedtevariatie wordt één keer bij swingstart gekozen. Lichte slagrichting wisselt deterministisch over de combo-grens en kiest een passende botclip; de presentatieklok wordt per fase naar de gameplayklok geschaald. De grondgolf van heavy blijft cosmetisch. Zie `COMBAT_SWINGS.md`.

MeleeSwingStyle koppelt echte linker/rechter clipvarianten aan vlak/helling en faseverhoudingen. De player bewaart geen lichte vervolgaanvallen; alleen een verse klik in het instelbare laatste herstel start direct. Charge-duur schaalt de volledige laadclip, onafhankelijk van de bronduur.

## Bosopening en introductieactie

`ForestOpening` gebruikt de bestaande camera/feedback uit PrototypeRoom en opgeslagen omgevingsinstances. `EntranceSequence` is een instelbare Resource; `PlayerCharacter` bezit de `entrance`-toestand, actietijd, echte sprongvelocity, zwaartekracht en landingsdetectie. De pose volgt dezelfde GameClock. Er is geen extra AnimationTree-state-machine of timer die controle of schade afhandelt. Pause/hitstop bevriezen ook water en vlinders; hurt/death behouden hun prioriteit. Na landing wordt invoer kort afgeschermd en verschijnt de compacte HUD. Restart begint op veilige grond.

`forest_butterfly.gd` beweegt de vleugelgroepen van het opgeslagen GLB en de vluchtpositie met GameClock. `tools/forest/` is uitsluitend offline authoring: bronnen, export, precisie-geknipte niet-overlappende grond, colliders en alle plaatsingen worden vooraf opgeslagen. De grasranden delen hun exacte veelhoekgrens met de rotswanden.


## Gedeelde dialogen en interactielabels

`DialogueConversation` en `DialogueLine` zijn bewerkbare Resources onder `scripts/components`. `DialogueInteractable` specialiseert de bestaande `Interactable`: dezelfde afstandsselectie en wereld-zichttest werken voor NPC's, borden en inscripties. Alleen colliders van het aangesproken object zelf worden uitgesloten. `Prompt`, `Conversation`, `Interaction Radius`, `Facing Node` en `Turn Speed` zijn Inspector-velden; tekst is niet hardcoded in de HUD.

De `Dialogue`-autoload instantieert de opgeslagen `scenes/ui/Dialogue.tscn`. Hij presenteert een lineaire reeks tekstblokken, gebruikt de bestaande `GameClock.paused` en de overgangsblokkade van InputRouter en laat de HUD het pauzemenu onderdrukken zolang een gesprek actief is. UI-tekstanimatie loopt op UI-tijd; er is geen extra gameplayclock. Het optionele naar-de-lezer-draaien blijft tijdens het gesprek alleen een visuele reactie. `conversation_finished` is een gebeurtenis voor verdere gameplay, geen rechtstreekse quest-/HUD-koppeling.

`InteractionPrompt.tscn` projecteert een klein configureerbaar label naast de speler en toont de actieve interactieknop. `ForestKeeper` en `ForestWaymarker` zijn opgeslagen gebruiksvoorbeelden. Zie [DIALOGUE.md](DIALOGUE.md) voor beheren en koppelen.


## Gedeelde sceneovergangen

`ScenePortal` (Area3D) en `SceneSpawnPoint` (Marker3D) bevatten alleen de doorgangsconfiguratie. De blijvende `SceneTransit`-autoload regelt asynchroon laden en de fade. `SceneTravelSettings` is een Resource. `PlayerCharacter` bezit de tijdelijke `scene_travel`-toestand, loopafstand, collisionbeweging en animaties op GameClock; er is geen tweede gameplay-state-machine in een AnimationTree. Tijdens de zwarte laadfase staat dezelfde klok stil.

De manager valideert de geïnstantieerde bestemming vóór verwijdering van de bronmap, neemt levens/magie mee en positioneert de speler op de benoemde marker. InputRouter schermt vertrek/aankomst af; de HUD behandelt de transit apart van een pauzemenu. Aankomst in een overlappende portal blijft geblokkeerd tot verlaten/herintreden. ForestOpening, ForestPassage en ForestHouse zijn actuele toepassingen; zie [SCENE_TRANSITIONS.md](SCENE_TRANSITIONS.md).


`SceneTransit.change_scene()` is ook de gedeelde ingang voor New Game, Testscene en menulanceringen. De opgeslagen `LoadingScreen` gebruikt UI-tijd, terwijl GameClock de afgedekte gameplay pauzeert. De New Game-intro blijft bevroren tot de fade is verdwenen. `ScenePortal` vraagt vanaf een configureerbare afstand resource-prefetch aan. De manager dedupliceert achtergrondtaken en bewaart maximaal drie recente PackedScenes; de huidige map en actieve bestemming worden beschermd. Er worden tijdens voorladen geen live actors aangemaakt. Gewone portals hebben `allow_loading_screen=false`; de huisdeuren gebruiken bovendien het korte deurprofiel zonder black hold. Alleen een expliciete grote overgang kan de laadkaart inschakelen. Zie [LOADING_SCREEN.md](LOADING_SCREEN.md).
