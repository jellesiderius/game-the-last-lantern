# Referenties en eigen keuzes

De aangeleverde kraai-afbeelding bepaalt silhouet, kleuren, snavel, ogen, vleugels en voeten. Het moduleblad bepaalt de 2×2×0,2 m tegel en de 2×0,3×0,7 m muur. Beide zijn vóór modelleren bekeken; kopieën staan in `assets/references`.

## Geobserveerde beweging en combat

[Combat Design in Death’s Door — Mark Foster and David Fenn](https://www.youtube.com/watch?v=EOY-FMjExYA): overzicht en gerichte passages 0:04–0:13, 0:50–0:57 en 1:34–1:40 bekeken. De native ondertiteling is gebruikt; geen Whisper-upload.

- Rond 0:10–0:13: brede rode voorwaartse sikkels, korte slagen en sterk wit oplichtende geraakte doelen. Hierop zijn de grotere voorwaartse slash, snellere rompbeweging en korte hitflash gebaseerd.
- In het gesprek rond 0:16–0:29 en 0:42–0:59: korte voorbereiding vóór schade en een snelle zwaai, met relatief veel tijd in herstel. Onze voorbereiding/actieve vensters/hersteltijden blijven eigen instelbare keuzes.

[Death’s Door | Early Boss Fights and Combat](https://www.youtube.com/watch?v=XCUOD8hMCEM): overzicht plus gerichte frames rond 3:18–3:24 en **2:10–2:14** bekeken. Er waren geen captions; de analyse van deze video is visueel.

- Beweging: een vooroverhellende romp bij verplaatsing, korte passen en een leesbare kop. In ons model zijn walk en run botposes aangepast; de afspeelsnelheid volgt de werkelijk afgelegde snelheid.
- 3:18–3:24: afstand nemen, kort in de aanval stappen, heldere rode slagen en terug naar beweging. De lunge concentreert zich daarom bij impact; de romp draait mee en herstelt.
- 2:10–2:14: compacte richthouding, rode/roze gloed bij de boog, een rechte heldere pijl en een kort witte trefreactie. Rond 2:11,55 is een pijl onderweg zichtbaar; rond 2:11,65 volgt contact. Dit zijn geschatte beeldtijdstippen, geen bewezen interne framevensters.

De korte richtlijn, grotere projectielkern en rood-roze effecten zijn ook bijgestuurd op de expliciete feedback van de gebruiker. De uiteindelijke pc-bediening gebruikt één knop: Q of RMB indrukken, richten met de muis, loslaten om te schieten. LMB is melee; MMB/B is zwaar.

## Technische bronnen

- [Godot CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- [Godot AnimationTree](https://docs.godotengine.org/en/stable/classes/class_animationtree.html)
- [Godot 3D-import](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/index.html)
- [Godot environment en postprocessing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)
- [EIP — interview met Mark Foster](https://eip.gg/deaths-door/news/developer-interview-soul-searching/)
- [WellPlayed — interview over Death’s Door](https://www.well-played.com.au/oddly-enough-deaths-door-started-with-the-concept-of-a-door/)

De oorspronkelijke opdracht noemt daarnaast Unity Creator Spotlight en de beperkte zoekindexvermelding van Blender bij Game Developer, *Emotion in motion*. De volledige Game Developer-pagina is hier niet gebruikt als bewijs voor technische details.

Controllerarchitectuur, camerahoeken, combo, magievoorraad, cooldowns en alle getallen in deze repository zijn ontwerpkeuzes voor dit prototype. Ze reconstrueren geen interne Acid Nerve-broncode.
