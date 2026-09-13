# Herbruikbare sceneovergangen

De bovenste poort in **ForestOpening** opent **ForestPassage**, een tweede bosgedeelte met een huis. Door de voordeur kom je in **ForestHouse**, waar je met Linde kunt praten. De deur binnen brengt je terug voor het huis; de zuidelijke poort brengt je terug naar het eerste bos.

## Een nieuwe doorgang plaatsen

1. Sleep `scenes/components/ScenePortal.tscn` naar je level, bijvoorbeeld in een poort of deuropening.
2. Stel **Target Scene** in op de volgende `.tscn` en **Target Spawn** op de gewenste aankomstnaam.
3. Maak **Trigger Size** breed genoeg voor de doorgang. Bospoorten gebruiken 6 m breedte, deuren circa 2,8 m. Hoogte/diepte zijn ook vrij instelbaar.
4. Draai de portal zodat zijn lokale **−Z-richting** naar de uitgang wijst. Die richting bepaalt de extra stappen bij vertrek.
5. Voeg in de doelscene een `Marker3D` toe met `scripts/world/scene_spawn_point.gd`. Geef **Spawn Id** exact dezelfde naam als Target Spawn. Draai de marker met −Z naar binnen, de nieuwe speelruimte in.
6. Plaats de aankomstmarker op vrije loopgrond, met ruimte voor het korte inlopen. De doelscene bevat de normale `Player`-node. Een `reset_camera()`-methode wordt gebruikt wanneer aanwezig.

Dezelfde doelscene kan meerdere aankomstmarkers hebben voor verschillende deuren. Gebruik unieke Spawn Id's binnen een scene. Portals activeren alleen voor speelbare `PlayerCharacter`-actors. NPC's starten geen mapwissel.

## Tempo instellen

Klap **Settings** op de portal open. Standaard gebruikt hij `settings/transitions/default.tres`:

| Veld | Standaard | Functie |
| --- | --- | --- |
| Exit Walk Distance | 1,5 m | Nog even doorlopen bij vertrek. |
| Entry Walk Distance | 1,5 m | Inlopen na het laden. |
| Walk Speed | 2,6 m/s | Tempo tijdens beide korte bewegingen. |
| Fade Duration | 0,45 s | Rustig uit- en invloeien. |
| Black Hold | 0,12 s | Minimale zwarte tussenfase. |

Deze Resource wordt gedeeld. Kies **Make Unique** of dupliceer de `.tres` als één deur een ander tempo moet hebben. **Enabled** schakelt een doorgang uit zonder de scene te verwijderen.

## Huidige verbindingen

| Vertrek | Doel | Aankomstmarker |
| --- | --- | --- |
| ForestOpening / ForestExit | ForestPassage | SouthGate |
| ForestPassage / SouthGate | ForestOpening | NorthGate |
| ForestPassage / HouseDoor | ForestHouse | Door |
| ForestHouse / Door | ForestPassage | HouseDoor |

`settings/dialogue/house_keeper.tres` bevat het gesprek met Linde. Bewerken werkt hetzelfde als de gesprekken in het bos; zie [DIALOGUE.md](DIALOGUE.md).

## Gedrag en opbouw

`SceneTransit` is een blijvende autoload met een opgeslagen fade-overlay. Hij vraagt de volgende PackedScene asynchroon op, controleert Player en aankomstmarker vóór de oude map wordt verwijderd, en vervangt de map wanneer het beeld volledig donker is. Een foutieve bestemming geeft de speler de controle terug in de bestaande map.

De echte korte bewegingen behoren tot `PlayerCharacter.scene_travel`, op de bestaande GameClock, met collision en loopanimatie. Het is geen teleportatie-animatie van de camera. Levens en magie worden meegenomen. Scenes worden opnieuw geladen; wereldstatus zoals verslagen vijanden wordt nog niet opgeslagen. Aanvallen/rollen kunnen de overgang niet onderbreken; bevestigings- of annuleerknoppen worden na aankomst geen onbedoelde aanval, rol of schot. Aankomen in een overlappende portal veroorzaakt geen directe terugreis: eerst uit het gebied stappen en opnieuw binnenlopen. Wie een gebied binnenrolt, maakt eerst zijn huidige actie af.

De oorspronkelijke bosintro blijft werken bij New Game. Terugkomen vanuit de tweede map gebruikt de aankomstmarker en herhaalt het zitten en springen niet. Bij controllerverlies tijdens een overgang verschijnt na veilige aankomst het gewone pauzemenu.

De maps, props, meubels en collision staan opgeslagen in Godot-scenes. `tools/forest/author_connected_levels.py` is de offline authoringtool voor het tweede bos en interieur. `author_ground.py -- --passage` in Blender bouwt uitsluitend de aparte ondergrond van het tweede bos; de bestaande karakter- en bosmodellen worden hergebruikt.

## Controle

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --forest-replay --transition-replay --fps=60
```

De native replay loopt door alle vier doorgangen, controleert extra loopafstand, afdekking tijdens laden, aankomstbeweging/controle, statistieken, het gesprek binnen, het voorkomen van terugkaatsen en herstel bij ontbrekende bestemmingen. Rapporten staan in `captures/forest/transition_checks_<cap>.json`. Met `--transition-review` worden bovendien vijf actuele bronaanzichten van het interieur opgeslagen.

## Actuele spelbeelden

![Huis in het tweede bos](images/forest-house-exterior.png)

![Gesprek met Linde in het huis](images/forest-house-dialogue.png)
