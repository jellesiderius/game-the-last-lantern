# Cameravolging — 10 september 2026

De gebruiker wil een kleine, voelbare volgvertraging bij de bestaande vaste camera. De orthografische grootte blijft 13 m, de hoek 50° neerwaarts / 45° rond de verticale as.

## Referentie en bewijsgrens

[Death’s Door | Early Boss Fights and Combat, 3:18–3:26](https://www.youtube.com/watch?v=XCUOD8hMCEM&t=198s) is met de watch-skill bekeken in opeenvolgende beelden, met stilstaande brugpilaren en balustrades als referentie voor de cameraverplaatsing. De kraai verschuift binnen het beeld tijdens verplaatsen en korte gevechtsacties; de omgeving schuift mee terwijl de kijkrichting gelijk blijft. De speler staat niet steeds op exact dezelfde pixelpositie.

Dat ondersteunt een camera die kleine positieveranderingen opvangt en geleidelijk volgt. Het bewijst geen specifieke deadzone, spring, lerpformule, vertraging of interne cameramatrix. De bekeken video heeft geen ondertiteling; deze conclusie is visueel. De Unity-blog over de omgevingen was tijdens deze controle niet toegankelijk en is niet als bewijs voor de camera gebruikt.

## Eigen implementatie

De bestaande exponentiële volging had snelheid 16 en circa 0,30 m achterstand bij 4,5 m/s. Dat voelde voor de gebruiker vrijwel vastgeklikt. `prototype_room.gd` gebruikt nu een horizontale halfwaardetijd van 0,12 s: iedere 0,12 s verdwijnt de helft van de resterende volgafstand. De camera reageert meteen, maar haalt geleidelijk in. Er is geen timer die beweging uitstelt en geen invloed op de spelerbesturing.

Het gewicht per physicsstap is `1 - pow(0.5, dt / half_life)`. Dit geeft bij een stilstaand doel dezelfde respons ongeacht de stapgrootte en veroorzaakt geen overshoot. Met onze bewegende speler bedraagt de gemeten maximale achterstand tijdens normaal rennen ongeveer 0,798 m. Na loslaten blijft de camera kort doorbewegen; 0,6 s later is de resterende afwijking ongeveer 0,030 m. Dit zijn onze waarden, geen gereconstrueerde Death’s Door-instellingen.

- Horizontaal: `camera_follow_half_life = 0.12` s.
- Hoogte op trappen: `camera_height_half_life = 0.08` s.
- Doelhoogte: 0,65 m boven de voeten.
- X/Z-doelgrenzen: −12 tot +12 m.
- Pauze/hitstop gebruiken dezelfde `GameClock.dt`; herstart centreert onmiddellijk.
- Rechter stick blijft beperkt verschuiven zonder de camera te draaien.

## Reproduceerbare controle

`tests/room_replay.gd` controleert vertrekken, begrensde achterstand, uitlopen na stoppen, monotonisch inhalen, omkeren, pauze, hitstop, herstart, hoek en grenzen. Dezelfde replay loopt over brug en trap, controleert diagonale snelheid en demonstreert melee/boog. De tests meten gameplay op 120 Hz physics, bij verschillende renderlimieten.

Start met `Godot --path . -- --room-replay --fps=60`. Resultaten staan in `captures/lantern_village/room_checks_<cap>.json`. Het veld `rendered_frames` onderscheidt echte rendercontrole van een headless run. De opgenomen demonstratie is `captures/lantern_village/camera_follow_demo.mp4`; opname bevat ook expliciete testteleports tussen losse controles. De doorlopende eerste brugpassage laat het volgen en uitlopen zien.
