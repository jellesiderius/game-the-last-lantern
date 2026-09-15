# Fireshards

Fireshards zijn de valuta van de game. Verslagen vijanden laten ze als een klein hoopje vuurvliegjes op de grond achter, en de speler moet er zelf naartoe lopen om ze op te zuigen. Sterft de speler, dan valt de hele voorraad op de plek van overlijden. Een tweede dood voordat die voorraad is opgeraapt wist hem definitief.

De regels komen uit de souls-like traditie (zielen als enige valuta, één opraapbaar verlies, tweede dood is verlies), maar de zichtbare naam en vorm zijn eigen: vuurscherven met vuurvliegjes in plaats van bloedvlekken. In Elden Ring worden zielen meteen bijgeschreven bij de kill; hier blijven ze bewust liggen zodat de speler ze moet komen halen.

## Spelerregels

| Gebeurtenis | Gedrag |
|---|---|
| Vijand verslaan met een beloning boven 0 | Er verschijnt een hoopje vuurvliegjes op de plek van overlijden. Er wordt nog niets bijgeschreven. |
| Binnen 1,4 m komen van een hoopje | Het hoopje komt eerst omhoog (0,3 s wachttijd plus 0,22 s rijzen) en stroomt daarna in circa 0,5 s naar de borst van het personage. Pas dan zijn de punten binnen. |
| Interactie (E / driehoek) in de buurt | Zelfde absorptie; handig als het hoopje net buiten loopbereik op een rand ligt. |
| Vijand vlak bij de speler verslaan | Het hoopje is even niet opraapbaar, komt omhoog en vliegt daarna zichtbaar in het personage. |
| Speler sterft | De hele voorraad gaat naar de plek van overlijden en de teller wordt 0. |
| Speler raapt die voorraad op | De voorraad komt terug in de teller. |
| Speler sterft opnieuw zonder oprapen | Het oudere verlies wordt definitief verwijderd. Hoopjes van verslagen vijanden blijven liggen. |
| Speler is dood | Een dood lichaam zuigt niets op, ook niet als er een hoopje onder ligt. |
| Rusten bij de vuurlelie | Voorraad, verlies en vijandelijke hoopjes blijven bestaan; gewone vijanden komen terug. |

## Opbouw

| Onderdeel | Verantwoordelijkheid |
|---|---|
| `scripts/core/fireshards.gd` (`Fireshards`, autoload) | Enige eigenaar van de regels: voorraad, verlies, absorptie, beloning per vijand, scene-identiteit en seinen |
| `scenes/world/fireshards/FireShard.tscn` + `scripts/world/fire_shard.gd` | Opgeslagen hoopje: presentatie, nabijheid, twee-traps absorptie; kent alleen zijn eigen id en aantal |
| `scripts/saves/save_schema.gd` | `fireshards` en `fire_shards` in de save, inclusief migratie van oudere saves |
| `scripts/components/damageable.gd` | Vraagt bij de dood om een hoopje, net als de bestaande wereldvlaggen |
| `scripts/ai/enemy_settings.gd` | `Fireshards → Fireshard Reward` per vijandprofiel |
| `scripts/ui/hud.gd` + `scenes/ui/HUD.tscn` | Teller rechtsboven die alleen rond een verandering opkomt, rustig naar het nieuwe totaal toe loopt en daarna weer wegzakt |
| `scripts/characters/player_controller.gd` | Zendt `died` uit nadat de dode toestand is ingegaan |

De service bezit geen HUD en de HUD bezit geen regels: de HUD leest alleen `fireshards_changed`, `shards_collected`, `shards_lost` en `Fireshards.pending_loss()`.

## Beloning per vijand instellen in Godot

Er zijn twee plekken, in deze volgorde:

1. **Per profiel** — `settings/enemies/<naam>.tres` → groep **Fireshards** → **Fireshard Reward**. Dit is de standaardwaarde voor elk geplaatst exemplaar dat zijn eigen waarde niet aanpast. Eikelwacht staat op 60, Bruiser op 140, het trainingsdoel (`sentinel.tres`) op 0.
2. **Per geplaatste vijand** — selecteer de vijand in de levelscene en zet in de Inspector **Fireshards → Fireshard Reward Override**. `-1` (standaard) houdt het profiel; een waarde vanaf 0 vervangt het profiel alleen voor dat ene exemplaar. Handig voor een eenmalige elite of een baas zonder een nieuw profiel te maken.

De regel staat op één plek: `Fireshards.reward_for(enemy)`. Een override wint van het profiel, en een profiel zonder `brain` levert altijd 0 op. Trainingsdoelen en andere niet-vijandelijke `Damageable`s blijven daardoor waardeloos.

## Savecontract

```gdscript
"fireshards": 0,
"fire_shards": [
    {"id": "…", "area": "forest.opening", "position": [x, y, z], "amount": 60, "kind": "enemy"}
]
```

`kind` is `enemy` of `lost`; er is maximaal één `lost`-item. `area` is de `WorldArea.code` van het level, of het scenepad voor levels zonder `WorldArea` (zoals de testarena). Daardoor kan een hoopje alleen in zijn eigen level verschijnen en overleeft het een scenewissel, een dood en een save. Onbekende of beschadigde items worden bij het laden weggefilterd (`SaveSchema.clean_shard`), en een save zonder deze velden blijft geldig.

Saves uit de tussenversie waarin dit systeem nog "souls" heette (`souls`, `soul_drops`, `soul_drop`) worden bij het laden automatisch omgezet naar `fireshards` en `fire_shards`.

## Visueel

De hoopjes zijn bewust klein: een klein amberkleurig kooltje, vier langzaam opstijgende vuurvliegjes, een zwakke gloed en een omni-light van 0,35 energie. Er staat geen aantal boven, en ook de HUD toont geen "+60"/"-60": de teller zelf vertelt het verhaal. Het verlies van de speler is iets bleker dan de scherven van een verslagen vijand. Tijdens het opzuigen zwelt het hoopje kort op en wordt het licht feller, zodat ook een kill bovenop de vijand duidelijk zichtbaar is.

De teller met vuurscherficoontje (`assets/ui/fireshard.svg`) is normaal verborgen. Alleen rond een verandering komt hij op: fade-in 0,12 s, ongeveer 2,2 s zichtbaar, fade-out 0,6 s. In die tijd loopt het getal rustig naar het nieuwe totaal met een ease-out (`HUD._set_shards()`: 0,22 s plus 0,007 s per shard, begrensd op 0,3-1,2 s), dus 60 shards tellen in circa 0,65 s en 120 -> 180 in ongeveer 1,1 s. De weergave staat altijd exact op het eindbedrag en meerdere winsten achter elkaar starten vanaf wat er op dat moment staat. Bij een levelstart blijft de teller verborgen in plaats van vanaf 0 op te lopen.

## Controleren

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --fireshards-replay --fps=60
```

`tests/fireshards_replay.gd` draait in het echte ForestOpening met een wegwerp-saveslot in `user://save_tests/`. Het dekt: oudere saves zonder deze velden, de souls-era migratie, de beloning pas bij absorberen, absorptie door echt naar het hoopje te lopen, de override per geplaatste vijand, verlies bij dood, oprapen na een echte `Checkpoints.respawn_player()`, het wissen van een oud verlies bij een tweede dood en de save-round-trip. Rapport en beelden: `captures/fireshards/checks_60.json`, `enemy_shards.png`, `lost_shards.png`, `second_loss.png`.

## Nog open

Er is nog geen besteding van fireshards (geen handelaar of upgrade), geen audio bij absorberen, geen merkteken op een kaart of kompas, en geen aparte animatie op het personage tijdens het opzuigen. Sterft de speler binnen de opraapstraal van het respawnpunt, dan pakt hij zijn verlies direct bij aankomst weer op; dat is hetzelfde gedrag als een bloedvlek naast een bonfire.
