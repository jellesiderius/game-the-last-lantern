# Vuurlelie en drie opgeslagen spellen

De laatste bediening is **Ontsteek/Rust → plaatsnemen → Rusten of Verdergaan**. Alleen plaatsnemen opent het menu: dit herstelt geen meters, verplaatst het checkpoint niet en schrijft geen save. Een gesloten bloem opent bij de eerste interactie met een vonk uit de gedragen lantaarn. Daarna blijven een echte 3D-vlam en rustige vonkjes zichtbaar.

**Rusten** herstelt health en magic, kiest deze lelie als checkpoint, laat gewone vijanden terugkeren en slaat het actieve slot op. Dit gebruikt dezelfde volledig afdekkende petrolfade en dezelfde `default.tres`-duur als de bospoort. Er verschijnt geen laadscherm. De panda blijft zitten en het rustmenu blijft op zijn plaats. **Verdergaan** sluit het menu. Er is geen aparte Opslaan-knop of tekstmelding bij succes: linksonder verschijnt kort een lantaarn die oplicht en weer uitfade. Alleen een daadwerkelijk geslaagde schrijfactie mag dat icoon activeren. Een opslagfout blijft als foutmelding in het menu staan.

Dit reset gewone vijanden in **alle gebieden**, ook niet-geladen dungeons. Geplaatste gewone vijanden gebruiken **Respawn Rule → On rest** met een blijvende `persistent_id`; **Permanent** blijft voor bosses/eenmalige vijanden. Dungeonvoltooiing, eenmalige loot en andere permanente wereldvoortgang worden niet gereset.

## Een rustpunt plaatsen

1. Sleep `scenes/world/checkpoints/Vuurlelie.tscn` vanuit FileSystem in je level.
2. **Checkpoint Id wordt automatisch ingevuld** zodra de instantie geplaatst is, ook als Godot de scene-eigenaar pas later instelt. Je hoeft niets te typen of op een knop te klikken. Het veld is alleen-lezen. In ForestOpening, ForestPassage en ForestHouse wordt **Area** automatisch ingevuld. Bewaar je level zoals gewoonlijk.
3. Versleep de hele instantie naar de gewenste plek. De code blijft gelijk bij verplaatsen en hernoemen.
4. Rechtsklik op de instantie → **Editable Children**. Verplaats de interne **Spawn**-marker naar vrije grond naast de lelie en draai hem naar de gewenste kijkrichting; de speler kijkt langs de lokale **-Z**-as. Je kunt ook een externe Marker3D aanwijzen via **Spawn Path**.
5. Stel zo nodig **Location Name**, **Interaction Radius**, **Rest Distance**, **Open Duration**, **Flame Size** en **Ember Count** in op de root. De interactiezone volgt de ingestelde afstand in de editor.

Bij dupliceren krijgt de nieuwe lelie automatisch een eigen code; de originele lelie behoudt haar code. Ook kopiëren naar een ander opgeslagen level krijgt een nieuwe identiteit. Verplaatsen, hernoemen en opnieuw openen behouden de opgeslagen code. De editor bewaart de willekeurige ID in het level; de game maakt bij starten geen nieuwe IDs, zodat bestaande saves naar hetzelfde rustpunt blijven verwijzen. De losse bronprefab blijft ongecodeerd tot je hem plaatst.

De standaardlelie heeft de grotere, tweemaal geschaalde bronvisual, een bijpassende collider, een interactieradius van 2,2 m en een spawn op 1,55 m van de kern. Er staat een rustpunt bij de startstronk en er staan drie lelies in ForestPassage. Alle drie Passage-lelies zijn in de echte game gecontroleerd op bereikbaarheid, interactie en opslaan via Rusten.

Het vuur bestaat uit één brede, doorlopende vlam van ongeveer 1,1 m hoog boven de kern. De gele kern, oranje rand en naar boven bewegende vervorming worden door de shader geanimeerd. Negen grotere, heldere vonkjes stijgen op en vervagen; **Flame Size** en **Ember Count** blijven per instantie instelbaar.

### Een nieuw gebied toevoegen

Maak een **WorldArea** Resource onder `settings/areas/`. Vul een blijvende **Code**, de **Scene Path** en eventueel **Display Name** in. Resources in die map worden automatisch ontdekt door de checkpointservice, ook voor laden vanaf schijf. Klik bij je lelie op **Vul gebied automatisch in**, of sleep de Resource naar **Area**. Zonder naam toont het menu ‘Onbekende locatie’. De gebiedsscene heeft een gedeelde `Player`-node nodig. Een optionele `reset_camera()` voorkomt een camerabeweging vanaf de vorige positie.

De startstronk gebruikt een afzonderlijke `CheckpointAnchor` met code `start.forest_stump`. De lelie is geen startpunt zolang nog niet op Rusten is gedrukt. Een nieuw spel bewaart meteen dit veilige startpunt en de status van de stronkintro. Een dood speelt de intro niet opnieuw af; een vanaf schijf geladen spel voltooit de intro als die nog niet voltooid was.

## Spellen en doodgaan

New Game en Continue openen hetzelfde overzicht met drie slots. New Game focust het eerste lege slot. Continue is volledig verborgen zonder geldige saves en focust anders het laatst gespeelde slot. Een gevuld slot wordt altijd geladen, ook vanuit New Game. Alle slots vol betekent dat eerst een spel via de afzonderlijke bevestiging moet worden verwijderd.

Een slot bewaart seconden speeltijd, maximale health/magic, `display_lives`, inventaris, skills, permanente wereldflags, ontstoken lelies, het laatste checkpoint met gebied en locatienaam, introstatus, formaatversie en succesvolle savetijd. `display_lives` is voorlopig het maximale aantal health chunks; er bestaat geen limiet aan respawnpogingen. Tijd telt alleen tijdens actieve gameplay. Menu’s, laden, intro en doodtijd tellen niet mee. De weergave is uren:minuten.

**Doodgaan gebruikt de actuele toestand in het geheugen.** Verzamelde spullen, nieuwe skills en permanente flags sinds het rusten verdwijnen daardoor niet. Alleen bewust een slot laden leest zijn opgeslagen toestand terug. Beide aankomsten herstellen health en magic volledig. Valutaverlies is niet aan checkpoints gekoppeld.

Het nieuwe spel verwijst naar de opgeslagen `StartCheckpoint` in ForestOpening, met vaste code `start.forest_stump`. Bewaar deze marker bij het aanpassen van het bos: de opening start op de stronk, maar laden/respawn na de opening gebruikt de veilige grondmarker. De gerichte controle `--checkpoint-replay --checkpoint-start-only --fps=60` controleert New Game en bestaande slots zonder de volledige checkpoint-suite uit te voeren.

## Verantwoordelijkheden en uitbreiden

| Bestand | Taak |
|---|---|
| `scripts/saves/save_schema.gd` | Versie en validatie van de gewone savegegevens |
| `scripts/saves/save_store.gd` | Drie bestanden, transacties, herstelkopieën en verwijdering |
| `scripts/saves/game_progress.gd` | Actuele voortgang en actieve speeltijd, los van de schijf |
| `scripts/core/checkpoints.gd` | Plaatsnemen, expliciet rusten, respawn en aankomstvalidatie |
| `scripts/world/vuurlelie.gd` | Instellingen, interactiezone, mechanische bladen en vuurpresentatie |
| `scripts/characters/player_controller.gd` | Actietijd van benaderen, lantaarn aanbieden en gaan zitten |
| `scenes/ui/RestMenu.tscn` | Vast menu met een lijst `RestMenuOption`-Resources |
| `scenes/ui/SaveIndicator.tscn` | Kort lantaarnsignaal na `SaveStore.save_succeeded` |
| `scripts/core/scene_transit.gd` | Gemeenschappelijke overgang; `refresh_world()` bouwt geen map opnieuw op |

Nieuwe menuopties krijgen een `RestMenuOption` met id en label en worden toegevoegd aan **Options** in RestMenu. Handel hun id af via `option_selected`/de checkpointcoördinator. Alleen Rusten en Verdergaan zijn nu zichtbaar; Skills en Reizen zijn nog niet toegevoegd.

Vijanden hebben **Respawn Rule** en bij permanente of rustgebonden regels een **Persistent Id**. Timed behoudt de bestaande trainingsarena-reset. On rest blijft verslagen tot rusten, ook wanneer je tussendoor een ander gebied bezoekt. Permanent bewaart `world["enemy:" + id]`; zo blijft een verslagen boss weg bij rusten, doodgaan én opslaan/laden. Bij rusten verdwijnen tijdelijke projectielen en herstarten gewone vijanden op hun eigen spawn met volle health. Het signaal `world_refreshed` biedt ruimte voor andere toekomstige rustregels.

## Veilige opslag

De game schrijft naar `user://saves/slot_1.json` tot en met `slot_3.json`. Op macOS staat dit onder `~/Library/Application Support/Godot/app_userdata/The Last Lantern/saves/`. Elk bestand heeft een gevalideerde payload en SHA-256-controlesom. Een nieuwe generatie wordt eerst naar `.tmp` geschreven en teruggelezen. De vorige geldige generatie gaat via `.bak.tmp` naar `.bak`; daarna vervangt een rename het hoofdbestand. Een beschadigd hoofdbestand kan uit de geldige backup laden. Een beschadigd bezet slot wordt nooit automatisch als leeg behandeld.

Een afzonderlijk verwijdermarkeerbestand voorkomt dat een achtergebleven backup na een onderbroken verwijdering weer als spel verschijnt. Het markeerbestand verdwijnt pas nadat een nieuw spel succesvol is geschreven. Er is nog geen migratie van toekomstige saveversies; onbekende versies worden behouden en geweigerd.

## Bron en controleren

De bewerkbare bloem staat in `assets/environment/vuurlelie/source.blend`, met afzonderlijke scharnieren voor vijf bronzen bladen. `tools/vuurlelie/build_asset.py` documenteert de bronbouw en de afzonderlijke `--export` stap. De vlam is een opgeslagen effectmesh (`flame.tres`); `author_flame.gd` schrijft deze offline. De panda heeft twee toegevoegde Actions, `kindle` en `rest`, en nu 34 Actions. Geometrie, skinweights en de eerdere 32 Actions zijn gecontroleerd op ongewijzigde hashes. `author_panda.py` bewaart het eerdere broncheckpoint; inspecteer nieuwe bronrenders vóór een karakterexport.

```sh
python3 tools/vuurlelie/run_checkpoint_checks.py
```

De runner controleert echte schijftransacties, een native Forward+ Metal-spelverloop en een afzonderlijke herstart van Godot. Hij gebruikt uitsluitend `user://save_tests/` en raakt spelerssaves niet aan. Resultaten staan in `captures/vuurlelie/`; screenshots omvatten gesloten, openen, zitten, rusten, vlam/vonkjes, slots, bevestiging en het save-icoon. De interactietest gebruikt echte controller-, toetsenbord- en muisevents. Reguliere combat-/controllercontroles blijven onder `tools/run_checks.py`.

De vorm volgt de vijfbladige referentie, met de door de gebruiker gevraagde grotere presentatie. De bronsvlakken zijn strakker en minder verweerd dan het referentiebeeld; dit is geen claim van een exacte materiaal- of vormmatch.
