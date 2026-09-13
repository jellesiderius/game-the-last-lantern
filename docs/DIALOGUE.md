# Gesprekken beheren

Alle tekst staat in gewone Godot Resources. Er is geen codewijziging nodig om een gesprek te schrijven, tekstblokken toe te voegen of het interactielabel te wijzigen.

## Bestaand gesprek aanpassen

1. Open `settings/dialogue/forest_keeper.tres` in Godot. Dit is het gesprek van Mos in het bos.
2. Vul bij **Speaker** de standaardnaam in. Klap **Lines** open: ieder `DialogueLine`-element is één tekstblok waar de speler doorheen klikt.
3. Bewerk **Text**. Een lege **Speaker** op een tekstblok gebruikt de standaardnaam; een ingevulde naam wisselt de spreker voor dat blok.
4. Voeg in **Lines** een element toe en kies **New DialogueLine**. Sleep elementen naar de gewenste volgorde. Lege blokken worden overgeslagen.
5. Sla het `.tres`-bestand op. Het gesprek kan zo veel blokken bevatten als nodig. Houd een blok bij voorkeur op twee à drie regels; langere blokken blijven binnen het tekstvak en zijn scrollbaar.

**Letters Per Second** bepaalt het schrijftempo. `0` toont de tekst meteen. De tekst ondersteunt RichText/BBCode, bijvoorbeeld `[color=#e5ba71]de lantaarnpoort[/color]` om een aanwijzing goud te maken.

Het gesprek met Linde in het huis staat in `settings/dialogue/house_keeper.tres`.

Voor een nieuw gesprek: rechtsklik in `settings/dialogue/`, **New Resource → DialogueConversation**, sla op en voeg `DialogueLine`-elementen toe. Je kunt ook een bestaand `.tres`-bestand dupliceren. Een gesprek kan door meerdere objecten worden gedeeld; dupliceer het bestand als een object eigen tekst moet krijgen.

## Koppelen aan NPC, bord of muur

Voeg een `Node3D` toe onder het object en koppel `scripts/components/dialogue_interactable.gd`. Stel in de Inspector in:

| Veld | Betekenis |
| --- | --- |
| **Conversation** | Het complete gespreksbestand. |
| **Prompt** | Vrij instelbaar label: bijvoorbeeld `Praten`, `Lezen` of `Onderzoeken`. |
| **Interaction Radius** | Afstand waarop de speler de interactie kan gebruiken. |
| **Enabled** | Interactie aan/uit. |
| **Facing Node** | Optioneel pad naar het visuele draaipunt van een NPC; leeg bij borden/inscripties. |
| **Turn Speed** | Hoe vlot het personage naar de speler draait. |

In `scenes/levels/ForestOpening.tscn` staan twee voorbeelden:

- `ForestKeeper/Conversation`: `Praten`, drie tekstblokken, capybara draait naar de speler.
- `Waymarker/Conversation`: `Lezen`, twee tekstblokken, bord blijft staan.

Voor wijzigingen aan een prefab open je de prefabscene; voor één levelinstance kun je **Editable Children** inschakelen en de waarden op het `Conversation`-kind overriden. Het tekstvak staat in `scenes/ui/Dialogue.tscn`, de kleine knop naast de speler in `scenes/ui/InteractionPrompt.tscn`.

## Bediening

- **E / △**: starten via het instelbare interactielabel.
- **Klik / Enter / ✕**: eerst de lopende tekst volledig tonen; daarna naar het volgende blok. E / △ werkt tijdens het gesprek ook.
- Na het laatste blok sluit dezelfde bevestiging het gesprek.
- **Esc / ○**: voortijdig sluiten. Het gesprek begint bij opnieuw aanspreken weer bij het eerste blok.

Het label naast de speler neemt altijd `Prompt` over. Het knopicoon volgt het actieve invoerapparaat. Het verschijnt alleen binnen bereik en met vrij zicht. Het eigen lichaam/bord blokkeert de zichttest niet; muren ertussen wel. NPC's draaien soepel naar de geselecteerde lezer, ook vanuit een andere benaderingsrichting.

De dialoog onderbreekt gameplay via de bestaande `GameClock`, zonder het pauzemenu te tonen. Openen en sluiten gebruiken de bestaande inputblokkade: bevestigen wordt geen dodge en annuleren geen boogschot. Controllerverlies sluit het gesprek en opent het gewone pauzemenu.

## Aansluiten op andere gameplay

`DialogueInteractable.conversation_finished(actor)` wordt alleen uitgezonden na het laatste tekstblok. Annuleren telt niet als voltooid. `Dialogue.started(conversation)` en `Dialogue.finished(conversation, completed)` zijn beschikbaar voor aanvullende reacties. Er is nu een lineaire tekstvolgorde; keuzes, questvoorwaarden, stemmen en een gesprekshistorie zijn niet toegevoegd.

Validatie: `Godot --path . -- --forest-replay --dialogue-replay --fps=60`. De replay gebruikt echte toetsen-, muis- en controllergebeurtenissen, test bereik/zicht, instelbare labels, draaien, doorschakelen, annuleren en veilige hervatting. Beelden en resultaat staan in `captures/forest/dialogue_*`.

![Configureerbare interactieknop in de game](images/forest-talk-prompt.png)
