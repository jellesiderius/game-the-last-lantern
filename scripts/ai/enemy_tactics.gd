class_name EnemyTactics
extends Resource
## Scores visible combat opportunities. Perception, timers and execution stay in EnemyBrain.
@export var reaction_delay := 0.14
@export var spacing_trigger_range := 1.65
@export var spacing_distance := 0.60
@export var spacing_duration := 0.55
@export var spacing_cooldown := 1.50
@export var flank_offset := 0.65
@export var repeat_penalty := 0.22
## Visible opponent actions that leave an opening worth pressing instead of circling.
@export var punish_states := PackedStringArray(
	["light_attack", "heavy_attack", "roll_attack", "bow_shoot", "bow_recover", "bow_empty", "hurt"]
)
## Seconds an observed opening stays actionable after the last sighting.
@export var opening_memory := 0.35


func choose_attack(
	beats: Array[EnemyAttackDefinition],
	observation: Dictionary,
	previous: int,
	preferences: Array = [],
	choice_noise: Array = []
) -> Dictionary:
	var scores: Array = []
	var best := -INF
	var selected := 0
	var distance: float = observation.get("distance", 0.0)
	var ranged: bool = observation.get("state", "") in ["bow_aim", "bow_draw"]
	var retreating: bool = observation.get("retreat_speed", 0.0) > .35
	for i in beats.size():
		var beat := beats[i]
		# Prefer a quick opening nearby; pay the longer tell only when its
		# approach distance is useful or the opponent visibly commits to a bow.
		var closing_need := clampf((distance - .8) / .9, 0.0, 1.0)
		var long_step := clampf((beat.lunge - .24) / .41, 0.0, 1.0)
		var score := 1.0 - absf(distance - beat.start_range) * .6 + beat.selection_bias
		score += closing_need * long_step * .8
		score -= long_step * .25
		if ranged or retreating:
			score += long_step * .35
		# A finished string also discourages its followups: strings alternate with other beats.
		var followup_of_previous := (
			previous >= 0 and previous < beats.size() and i in beats[previous].followups
		)
		if i == previous or followup_of_previous:
			score -= repeat_penalty
		if i < preferences.size():
			score += preferences[i]
		if i < choice_noise.size():
			score += choice_noise[i]
		scores.append({"clip": beat.clip, "score": score})
		if score > best:
			best = score
			selected = i
	return {
		"index": selected,
		"reason":
		(
			"bow_pressure"
			if ranged
			else ("close_distance" if retreating or distance > 1.05 else "near_opening")
		),
		"scores": scores
	}
