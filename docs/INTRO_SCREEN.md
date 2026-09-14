# Introscherm — The Last Lantern

`scenes/ui/TitleScreen.tscn` is de hoofdscene. De meegeleverde afbeelding bepaalt compositie, logo, kleuren en lantaarn. De achtergrond is in twee gerichte imagegen-bewerkingen vrijgemaakt van vaste menutekst/deeltjes en daarna van logo/kristal, zodat die afzonderlijk kunnen bewegen. `assets/ui/title/logo_source.png` bewaart de oorspronkelijke titel. Het masker gebruikt het rode kanaal om de donkere teal achtergrond te verwijderen; ook bijna witte letterhooglichten blijven daardoor volledig dekkend.

## Huidige animatie

- Titel: fade en 16 px opwaartse beweging van 0,15 tot 2,55 s.
- Menu: begint bij 1,58 s wanneer de titel al duidelijk leesbaar is; per optie 0,42 s met 0,05 s tussenruimte. De laatste optie staat bij 2,20 s stil. Dezelfde smoothstep-easing als de titel, slechts 4 px verplaatsing. Knoppen blijven direct bedienbaar.
- Vlam: afzonderlijke canvas-shader met een bewegende punt en wisselende contour in de glazen kamer. De grondgloed verandert veel minder dan de vlam zelf; de hele lantaarn knippert niet aan/uit.
- Vonkjes: twee opgeslagen GPUParticles2D-nodes, zeven grotere en vier fijne deeltjes per levenscyclus, met opkomst/uitdoving. Ze staan achter de voorgrond van de lantaarn en de rots. Deeltjes zijn niet allemaal tegelijk even zichtbaar.

De animatie gebruikt presentatietijd van het menu. Gameplay behoudt GameClock. De wereldcamera en gameplayviewportinstellingen zijn behouden; de afbeelding past binnen andere beeldverhoudingen met een donkere rand.

## Menu en instellen

Selecteer **TitleScreen** in de Inspector:

| Eigenschap | Standaard |
|---|---|
| Startgebied van een nieuw slot | `settings/areas/forest_opening.tres` |
| Test Scene | `res://scenes/levels/TestArena.tscn` |
| Flicker Strength | 1,0, op de rustige lichtcurve |

De Testscene-knop leest de ingestelde scene bij activering. New Game en Testscene gebruiken dezelfde bestaande GameSession/PlayerCharacter. New Game en Continue openen hetzelfde overzicht met drie onafhankelijke save slots. Continue is verborgen zolang geen geldig slot bestaat. Zie [VUURLELIE.md](VUURLELIE.md). Settings biedt volledig scherm en controllertrilling. Deze instellingen worden binnen de sessie toegepast; er is nog geen nieuw instellingenbestand op schijf. Main menu in het gameplaypauzemenu opent het introscherm opnieuw.

Muis, toetsenbord en controller gebruiken native focus. Openen/terugkeren wist de gameplaypauze en gebruikt de bestaande InputRouter-overgangsblokkade; kruisje-bevestigen wordt geen dodge. Bestaande CLI room-/energyreplays worden vanuit het introscherm naar PrototypeRoom doorgestuurd. TestArena blijft rechtstreeks startbaar.

## Controle

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . -- --intro-replay --fps=60
```

`captures/intro/checks.json` bevat de native Forward+ Metal-controles: startup, titelopkomst, ruimte tussen menu/lantaarn, werkelijk veranderende vlampixels/deeltjes, controllerfocus, settings, terugkeren, instelbare Testscene, beide levelstarts en bevestigingsinvoer. De meting zonder screenshot-I/O haalde 60,04 FPS. Alle 24 introcontroles slagen. De gedeelde controllerregressie voor de panda slaagt na toevoeging van Main menu. Eerdere vijandroutebeperkingen in TestArena staan afzonderlijk in PANDA_MOTION.md.

De opname in `captures/intro/intro.mp4` gebruikt Godots vaste 60-FPS movieklok en toont de actuele opkomst. De onafhankelijke visuele controle scoort 9,5/10: geen tekstvlekken, overlap of te grote deeltjeshoeveelheid. De laatste movie is op twaalf tijdstippen bekeken: titel eerst, menu nog afwezig op 1,5 s, eerste zachte regels rond 1,7 s en het complete menu rond 2,3 s. De volgorde is als samenhangend beoordeeld. Het menulettertype is iets kleiner/smaller dan de oorspronkelijke referentie om de extra optie te laten passen.

De gebruikte EB Garamond wordt meegeleverd met OFL-licentie in `assets/ui/fonts/`. De deeltjes gebruiken Godots [GPUParticles2D](https://docs.godotengine.org/en/4.7/classes/class_gpuparticles2d.html); hun instellingen zijn opgeslagen in de scene.
