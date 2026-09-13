---
name: reference-3d-assets
description: Create and refine reference-matched 3D game assets in Blender and Godot, with consistent silhouettes, connected anatomy, skinned animation, weapon sockets and visual runtime checks. Use for character or modular environment asset production and revisions from turnaround images or gameplay footage.
---

# Reference 3D assets

Werk vanuit de gekozen referentie en het bestaande bewerkbare model. Het doel is een consistent 3D asset dat in de uiteindelijke camera en tijdens beweging klopt. Een geslaagde export bewijst geen goede gelijkenis of animatie.

## Begin met de juiste bron

Lees projectinstructies, inspecteer bestanden, applicatieversies, renderer, scenes, rig en Actions. Bekijk alle opgegeven referenties vóór wijzigingen. Hergebruik bruikbare assets en maak een checkpoint van de huidige bron. Houd onderscheid tussen ontwerpafbeelding, bewegingsreferentie en eigen technische keuzes. Een gameplayvideo bewijst geen interne broncode of exacte timing.

Maak een korte lijst van herkenningspunten: hoogteverhoudingen, breedtes, snavel, ogen, kleurgrenzen, vleugelpunten, staart en voeten. Noteer ook wat niet zichtbaar is en dus geïnterpreteerd wordt. Vergelijk overeenkomstige camera's; een perspectiefverschil mag geen onnodige geometriecorrectie veroorzaken.

## Werk per controleerbare wijziging

1. Reproduceer de gemelde afwijking in een opgeslagen screenshot of pose.
2. Zoek de oorzaak in geometrie, shading, skinning, import of camera.
3. Wijzig de kleinste samenhangende bron. Bewaar rig- en materiaalnamen en bestaande geaccepteerde vormen.
4. Controleer vooraanzicht, zijaanzicht, achterkant én spelcamera. Controleer verbindingen ook in bewegende poses. Neus, ogen, oren en markeringen moeten op het werkelijke dragende oppervlak aansluiten; kijk hiervoor ook van laag opzij.
5. Controleer huid-/vachtkleurgrenzen op close-up van voor, opzij en achter: geen trapvormige banden, zichtbare texels of flikkerende patches. Smooth normals zijn hiervoor geen bewijs.
6. Exporteer opnieuw, herimporteer expliciet en controleer het echte resultaat in Godot.
7. Bewaar bewijs en beschrijf resterende afwijkingen. Noem een asset niet “1:1” of “perfect” omdat één hoek goed oogt.

Gebruik [visual-consistency.md](references/visual-consistency.md) bij modelleren, anatomie, materiaalgrenzen en zichtbare pixelvorming. Gebruik [animation-and-engine.md](references/animation-and-engine.md) bij rigging, sockets, clips, effecten en runtimecontrole. Lees [crow-project-lessons.md](references/crow-project-lessons.md) bij dit kraaiproject; de getallen daarin zijn projectspecifiek.

Gebruik [modular-surfaces.md](references/modular-surfaces.md) bij Godot-levelbouw en grondmodules. Controleer vóór export én in de draaiende game dat gras, paden, trappen en water geen overlappende zichtbare loopvlakken hebben. Een kleine hoogte-offset is geen oplossing voor twee concurrerende grondoppervlakken.

## Verplichte visuele controle vóór export

Controleer iedere nieuwe of gewijzigde asset vanuit voor, beide zijkanten, achter en spelcamera. Bij een personage omvat dit ook een close-up van gezicht en anatomische aansluitingen. Gebruik de uitgebreide controle in [visual-consistency.md](references/visual-consistency.md). Controleer altijd kleurverdeling én pixelvorming, ook bij effen materialen zonder textures. Herstel gevonden fouten vóór afronding; benoem en bewaar nog onopgeloste verschillen in plaats van het asset als referentiegelijk af te vinken. Controleer dezelfde punten opnieuw na import en na vervorming.

## Technische controles ondersteunen het kijken

Voer `python3 scripts/inspect_glb.py path/to/asset.glb` uit voor animatienamen, gewichten, botnamen en een vaste root. De inspecteur werkt zonder Blender of extra packages. Hij valideert geen esthetische gelijkenis, afwezigheid van penetratie of goede belichting; die blijven visuele controles.

Houd Blender-bron, exports, geïmporteerde visuele wrappers, gameplay en instellingen gescheiden. Bewerk geen gegenereerde importcache. Als de gebruiker bewerkbare scenes verlangt, sla zichtbare assets en hun plaatsing op als scenenodes vóór Play; genereer de arena niet pas bij runtime.

Een oplevering bevat bronbestanden, exports, startbare scenes, exportinstructies en werkelijk uitgevoerde controles. Rapporteer een mislukte applicatieverbinding, onbereikbare video of niet-uitgevoerde runtimecontrole concreet, en werk aan de overige onderdelen door.
