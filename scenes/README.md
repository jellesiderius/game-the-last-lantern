# Scenes vinden

| Map | Inhoud |
|---|---|
| `levels/` | Complete speelvelden; open `TestArena.tscn` om de arena te bewerken. |
| `actors/player/` | Speelbare personages met de gedeelde controller, collision en componenten. |
| `actors/npcs/friendly/` | Niet-vijandige NPC's en passieve trainingsdoelen. |
| `actors/npcs/enemy/` | Vijanden met collision, gezondheid en AI-componenten. |
| `assets/characters/` | Visuele wrappers per personage, rig en attachments. |
| `assets/environment/` | Herbruikbare grond- en muurmodules. |
| `weapons/` | Geassembleerde wapens met grip, markers en presentatiecode. |
| `projectiles/` | Bewegende projectielprefabs met traject- en schaderegels. |
| `effects/` | Slagsporen, impacteffecten en andere herbruikbare effecten. |
| `ui/` | HUD, menu's en personagekeuze. |

De bewerkbare Blenderbestanden en GLB-modelbestanden staan onder `assets/` in de projectroot. Plaats herbruikbare scenes als instances in een level; kopieer hun interne meshes of scripts niet naar ieder level. Geïmporteerde modellen krijgen gameplay via wrappers; wijzig de importcache niet.
