# Godot: aansluitende modulaire oppervlakken

## Eén eigenaar per zichtbaar loopvlak

Een zandpad vervangt het gras binnen zijn voetafdruk. Leg geen zandblok enkele millimeters boven een doorlopende grasmesh. Dit veroorzaakte in de prototypekamer groene fragmenten en flikkerende randen. Bij schuine camera's, schaduwen en andere afstanden kan de fout zichtbaar blijven ondanks een ogenschijnlijk voldoende Y-offset.

Deel het grondvlak op in aansluitende, niet overlappende gebieden. Gebruik passende halve modules, hoekmodules of een echte uitsparing wanneer een pad het moduleraster kruist. Interne aansluitranden blijven exact vlak. Bevel uitsluitend zichtbare buitenranden; een bevel aan een interne naad kan een kier of de onderliggende grond onthullen. Houd zichtbare topvlakken op de afgesproken hoogte. Een aparte eenvoudige, doorlopende collider voorkomt hapering zonder de rendergeometrie te dupliceren.

## Controle vóór opslaan

- Bekijk de opgeslagen levelscene zonder gameplay. Gras, pad, waterrand, brugdek en traptreden moeten op de bedoelde hoogte liggen.
- Controleer wereldtransforms ná een dependency-graph-update in Blender. Objectlocatie en lokale meshcoördinaten zijn verschillende grootheden. Controleer de GLB opnieuw in Godot.
- Vergelijk bij rechthoekige modules de echte voetafdrukken en hoogtes. Positieve oppervlakteoverlap op dezelfde tophoogte is een fout. Bewaar deze controle naast de scene-authoringtool.
- Controleer ook verborgen dubbele instances, coplanaire zijvlakken, onderliggende graslippen en een trapkern die door een trede steekt.

## Runtimecontrole is verplicht

Start het level met de gebruikte renderer. Bekijk naden vanaf de gameplaycamera én dichtbij en laag langs het oppervlak. Beweeg de speler en camera-look langs de rand; flikkerende stippen, groene schilfers, moiré en kleurwisselende driehoeken zijn geen acceptabel detail. Controleer bij verschillende afstanden en rendercaps. Vergelijk tijdelijk zonder SSAO/schaduwen om geometrische overlap van samplingruis te onderscheiden, maar los geometrie niet op door schaduwen uit te schakelen.

Leg de gemelde fout en de huidige correctie vast. Controleer aansluitende modules mee wanneer één rand faalt. Noem een overlap niet opgelost op basis van alleen een import of één stilstaand beeld. Schrijf resterende afwijkingen expliciet in het werklog.
