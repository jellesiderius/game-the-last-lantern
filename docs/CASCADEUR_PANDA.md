# Panda in Cascadeur — bewaarde werkbestanden

De aangevraagde loop en uitgebreidere zwaardanimatie zijn als bewerkbare native scenes opgeslagen in `assets/characters/red_panda/cascadeur/`:

- `red_panda_walk.casc`: cyclus van 0,8 s, frames 0–24 bij 30 fps, op het bestaande pandarig.
- `red_panda_sword_combat.casc`: performance van 8,25 s, frames 0–990 bij 120 fps. Zes lichte stijlen, normale en geladen zware slag en rolaanval, met rust/herstel ertussen. Sunblade en lantaarn zijn in de uitwisselscene aanwezig.
- `combat_segments.json`: knipplan met bestaande gameplayclipnamen. De demonstratietijdlijn voegt geen automatische combo of invoerwachtrij aan de game toe.
- `native_source_checks.json`: gecontroleerde framerate, tijdlijngrenzen en hashes van de opgeslagen bronnen.

`tools/cascadeur/prepare_panda.py` en `prepare_combat.py` maken de invoer uit de huidige Blender-bron. `author_walk.py` en `author_combat.py` zetten echte jointkeys via de Python-API in Cascadeur. De gevechtsbewerking voegt romp-/hoofdtegenbeweging en vertraagde staartbeweging toe en bewaart de bestaande handbanen. Geen AutoPhysics- of AutoPosing-resultaat geclaimd. De loop heeft een native render in `captures/cascadeur_walk/native_preview.png`; volledige visuele review van alle gevechtssegmenten blijft open.

**Nog niet geïntegreerd in Godot.** De geïnstalleerde Free-licentie meldde dat FBX-export niet beschikbaar is. De oorspronkelijke pandabron en game-GLB zijn behouden. Er is geen alternatieve animatie-export langs de licentiebeperking gemaakt. Integratie vereist een exportgerechtigde Cascadeur-licentie, daarna FBX-export, benoemde clips terugzetten, 120-fps-import en de bestaande melee-/energy-/controllerreplays.

Bij de laatste poging om de gevechtsrapportage opnieuw uit te voeren was de lokale Cascadeur-server op poort8765 niet actief. Het native bestand was eerder al opgeslagen; het knipplan is uit hetzelfde authoringscript gereconstrueerd en de opgeslagen tijdlijn is gecontroleerd. Het rapport bevat dus geen nieuw gemeten handafwijkingscijfer. Start voor verdere bewerking Cascadeur en de aanwezige opdracht `MCP.Start script server`.
