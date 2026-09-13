# Sunblade-melee — 10 september 2026

Lichte slagen wisselen linksom en rechtsom af, ook over de derde slag heen en na terugkeer naar locomotion. Variatie zit in echte botanimaties: horizontaal, schuin stijgend en schuin dalend, elk in beide richtingen. De helling is bewust beperkt tot 20 graden; geen verticale hakbeweging bij lichte aanvallen.

## Directe klikken, geen wachtrij

Klikken tijdens voorbereiding of actieve slag worden weggegooid. Een nieuwe klik in de laatste 0,10 s herstel start meteen de volgende aanval; die klik wordt niet bewaard voor later. `MovementSettings.light_reinput_window` bepaalt dit venster. Zonder nieuwe klik speelt er geen vervolgaanval. Dodge houdt prioriteit. De eerdere wachtrij van vier klikken is op gebruikersverzoek verwijderd uit alle gedeelde playercode.

De combo blijft drie gameplayacties met hun bestaande schadevensters: `attack_1`, `attack_2`, `attack_3`. Een geldige nieuwe klik kan de index na drie laten doorlopen. De visuele richting blijft afwisselen onafhankelijk van de combo-index. Vasthouden veroorzaakt geen herhaalde aanvallen.

## Botposes en effect

`MeleeSwingStyle` koppelt een linker/rechter botclip aan de helling, effecthoogte en clipfasen. De drie Resources staan in `settings/combat/swings/`. `WeaponDefinition.light_swing_styles` is optioneel, zodat historische wapens hun eigen clips behouden. Een willekeurige stijl wordt eenmaal bij slagstart gekozen en mag niet meteen worden herhaald. Sector en sikkelbreedte blijven beperkt willekeurig variëren. De vastgelegde richting, stijl en waarden veranderen niet tijdens de slag of hitstop.

De zes nieuwe Actions zijn `light_{level,rising,falling}_{left,right}`. Voorbereiding, actieve fase en herstel worden afzonderlijk op de gameplayklok geschaald. Arm, hand, zwaard en romp veranderen samen; het effect alleen draaien geldt niet als een andere aanval.

Normaal energiebereik blijft **1,9 m**, volledig geladen **2,4 m**. De effectbasis compenseert horizontale verkorting door kanteling. Shader en physics gebruiken dezelfde basis, straal, hoogte en voorrand, zodat ook een schuine energiebaan dezelfde horizontale straal heeft. Kleine lunge en hurtboxomvang beïnvloeden de afstand tussen objectmiddens waarop een treffer mogelijk is.

Het fysieke lemmet en de zichtbare energievoorrand worden gesweept. De energiesamples liggen maximaal 7 cm uit elkaar. Beide routes delen attack-id en doelregistratie. Alleen het actieve venster kan schade geven; de vervagende naloop en grondgolf zijn cosmetisch. Wereldgeometrie blokkeert treffers. Een brede treffer herstelt maximaal één magiepunt.

## Snellere heavy-charge

`MovementSettings.charge_duration` is **0,45 s** (was 0,60 s). De volledige bestaande laadclip wordt op deze duur geschaald. De eigen zware release, schade, knockback, impactfeedback en 2,4 m geladen bereik blijven gelijk. De speler mag tijdens laden vertraagd bewegen; volledige charge slaat eenmaal automatisch, vroeg loslaten geeft de gewone zware aanval en dodge/hurt/death onderbreken.

De geladen Sunblade-energiebaan gebruikt 16 graden kanteling en 0,75 m hoogte. De zichtbare voorrand en de schadequeries volgen samen deze lagere, minder steile baan; daarmee blijft de brede slag ook bij zes nabije doelen bruikbaar. Deze waarden staan in de WeaponDefinition, zonder het bereik te vergroten.

## Bron en import

`assets/characters/red_panda/source.blend` bevat 29 Actions; geometrie, kleding en gewichten zijn behouden. `author_light_styles.py` voegt alleen de zes nieuwe Actions toe op de bestaande rig. Checkpoint: `checkpoints/before_light_styles_20260910.blend`. `refine_heavy_actions.py` documenteert de eerder gemaakte zware poses. Geen van beide is een algemene karaktergenerator.

De bewerkbare importinstelling `assets/characters/red_panda/model.glb.import` gebruikt `animation/fps=120`, passend bij 120 Hz physics. Op 30 samples/s veroorzaakte interpolatie van de korte stijgende rechterzwaai een verkeerde zwaardoriëntatie. Dit is vastgesteld door dezelfde socket en actietijd in Blender en Godot te vergelijken. De importcache is niet handmatig gewijzigd.

## Controle

- `--energy-replay --fps=60`: bereik, muren, deduplicatie, magie, schuine varianten, afwisselen, onmiddellijke late klik en geen opgeslagen vroege klikken.
- `--swing-style-replay --fps=60`: iedere stijl in beide richtingen, echte zwaardpunt omhoog/omlaag, horizontale straal over de hele boog, grondvrijheid, bereik en meerdere doelen.
- Optioneel `--style-closeup` vergroot alleen de testpresentatie. Normale gameplaycamera blijft 13 m, vaste 50°/45° hoek.
- Bronbeelden: `captures/lantern_village/light_<style>_<direction>_<start|end>/`, elk voor, links, rechts, achter en spelcamera. Runtimebeelden: `room_style_*`.

Resultaten en demonstraties staan in `VALIDATION_LANTERN.md`.
