# Laden en vloeiende doorgangen

Een leeg slot kiezen vanuit **New Game** toont het laadscherm van The Last Lantern: een rustige vlam in een gouden lantaarn, enkele vonkjes, een donkere teal achtergrond en de tekst ‘Een nieuw avontuur’. De introductie op de stronk begint pas nadat het scherm is verdwenen. Testscene en andere directe menulanceringen gebruiken dezelfde laadservice.

**Gebouwen en de huidige bospoorten tonen geen laadscherm.** Terwijl de speler de doorgang nadert, worden de resources op de achtergrond geladen. De speler loopt kort door, het beeld vloeit uit en meteen weer in. Er verschijnt geen lantaarnkaart of laadtekst, ook niet bij een eerste bezoek. Mocht het laden bij een uitzonderlijk snelle benadering nog bezig zijn, dan blijft alleen de bestaande fade gesloten tot de bestemming klaar is.

## Deuren instellen

Gebruik `scenes/components/ScenePortal.tscn` en koppel `settings/transitions/door.tres` bij **Settings**. Dit profiel is al ingesteld op de voordeur en de uitgang van ForestHouse:

| Instelling | Waarde |
| --- | --- |
| Exit Walk Distance | 1,0 m |
| Entry Walk Distance | 1,0 m |
| Walk Speed | 2,8 m/s |
| Fade Duration | 0,28 s |
| Black Hold | 0 s |

**Prefetch Distance** staat op 8 m: vanaf die afstand begint het voorladen. **Allow Loading Screen** staat standaard uit op ScenePortal. Schakel dit alleen bewust in voor een grote gebiedswissel waarvoor het uitgebreide laadscherm gewenst is; de huisdeuren houden het uit. **Loading Title** bepaalt de koptekst wanneer die optie aan staat.

De looprichting, hitbox en aankomstmarkers staan beschreven in [SCENE_TRANSITIONS.md](SCENE_TRANSITIONS.md).

## Het laadscherm aanpassen

- `scenes/ui/LoadingScreen.tscn`: opmaak, kleuren, lettertype en alle opgeslagen UI-elementen. Op de root staat **Caption** voor de korte sfeerzin en **Default Heading** als terugvaltekst.
- `scenes/world/checkpoints/CheckpointService.tscn`: **New Game Loading Title** bepaalt de kop bij New Game.
- `scenes/ui/SceneTransit.tscn`: **New Game Loading Time** is standaard 1,1 s; **Minimum Loading Time** is 0,75 s voor andere werkelijk getoonde laadschermen. Dit voorkomt een korte flits. Deuren gebruiken deze wachttijden niet.
- **Automatic Loading Delay** is 0,25 s voor directe laadacties waarbij resources nog ontbreken. Eerste of eerder dure scene-initialisaties tonen de kaart vóór de scene wordt aangemaakt.
- **Cached Scene Limit** bewaart standaard maximaal drie PackedScenes, met bescherming voor de actieve bestemming en huidige map. Het cachet resources, geen levende NPC's of gameplaytoestand.

De bewegende gouden lijn is een activiteitsindicator; er wordt geen verzonnen percentage getoond. De visuele animatie gebruikt UI-tijd en blijft onafhankelijk van de gepauzeerde gameplayklok.

## Vanuit code

```gdscript
# New Game: altijd het uitgebreide laadscherm, daarna de eigen levelintro.
SceneTransit.change_scene("res://scenes/levels/ForestOpening.tscn", "Een nieuw avontuur", true)

# Directe menulancering: het laadscherm alleen als voorbereiding nodig is.
SceneTransit.change_scene("res://scenes/levels/TestArena.tscn", "De wereld ontwaakt")

# Resources alvast laden zonder zichtbare UI of gameplayverandering.
SceneTransit.prefetch_scene("res://scenes/levels/ForestHouse.tscn")
```

De service voorkomt dubbele laadverzoeken, schermt invoer af en pauzeert gameplay tijdens het wisselen. Resources worden in een achtergrondthread geladen; scene-instanties worden pas tijdens de afgedekte overgang aangemaakt. Achtergrondladen activeert dus geen tweede speler of NPC-AI. Een mislukte bestemming laat de oude map bestaan; bij een menulancering wordt de fout leesbaar getoond. Controllerverlies wordt na veilige aankomst afgehandeld.

## Controle

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --loading-replay --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --intro-replay --fps=60
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --forest-replay --transition-replay --fps=60
```

Native gemeten op een Apple M4 Pro bij caps30/60/120: de 62 overgangscontroles slagen, met huisovergangen van circa 0,81–0,86 s en 57–134 ms volledig afgedekt beeld. Dit zijn lokale metingen, geen tijdgarantie voor andere hardware.

De laadreplay controleert echte knopinvoer, animatie tijdens pauze, verschillende schermformaten, de volledige bosintro, snelle herhaalde loads en foutafhandeling. De overgangsreplay meet beide huisdeuren, controleert dat resources vóór de drempel klaar zijn en bewaakt dat geen laadscherm verschijnt. Resultaten en actuele beelden staan in `captures/loading/` en `captures/forest/`; de samenvatting staat in `LOADING_VALIDATION.json`.

![Laadscherm bij New Game](images/loading-new-game.png)
