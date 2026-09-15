extends CanvasLayer
var magic_feedback_until := 0.0
var magic_feedback := Color.WHITE
var magic_hint_until := 0.0
var health_feedback_until := 0.0
var last_health := 5.0
var hp: HUDMeter
var magic_meter: HUDMeter
var magic_home := Vector2.ZERO
var charge: ProgressBar
var state_label: Label
var pause_panel: GamePauseMenu
var ability_hint_until := 0.0
var menu_reason := ""
var hint: Label
var shard_value: Label
var shard_group: HBoxContainer
var shard_feedback := Color.WHITE
var shard_feedback_until := 0.0
## The readout only appears around a change, climbs to the new total instead of snapping,
## and fades away again. Any message on top of that would be noise.
var shard_display := 0.0
var shard_from := 0.0
var shard_target := 0
var shard_elapsed := 0.0
var shard_duration := 0.0
var shard_show_time := INF
const SHARD_FADE_IN := .12
const SHARD_HOLD := 2.2
const SHARD_FADE_OUT := .6
@onready var arena = get_parent()
@onready var input_hint: RichTextLabel = $Root/InputHint
@onready var context_prompt: RichTextLabel = $Root/ContextPrompt
@onready var magic_hint: Label = $Root/Status/MagicHint


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hp = $Root/Status/HP
	magic_meter = $Root/Status/Magic
	magic_home = magic_meter.position
	last_health = arena.get_node("Player").health.current
	arena.get_node("Player").health.changed.connect(_health_changed)
	arena.get_node("Player").magic.changed.connect(_magic_changed)
	arena.get_node("Player").magic.denied.connect(_magic_denied)
	charge = $Root/Charge
	state_label = $Root/DebugState
	pause_panel = $Root/PausePanel
	pause_panel.resume_requested.connect(_resume)
	pause_panel.restart_requested.connect(_restart)
	pause_panel.choose_character_requested.connect(_choose_character)
	pause_panel.title_requested.connect(_return_to_title)
	pause_panel.camera_shake_changed.connect(
		func(enabled): arena.player.settings.camera_shake = enabled
	)
	InputRouter.controller_disconnected.connect(_controller_disconnected)
	arena.get_node("Player").ranged_loadout.selection_denied.connect(_ability_denied)
	shard_value = $Root/Fireshards/Value
	shard_group = $Root/Fireshards
	shard_group.visible = false
	Fireshards.fireshards_changed.connect(_shards_changed)
	_set_shards(Fireshards.total(), true)
	hint = $Root/Hint


func _process(delta: float) -> void:
	var p = arena.player
	if not is_instance_valid(p):
		return
	hp.display(p.health.current, p.health.maximum)
	magic_meter.display(p.magic.current, p.magic.maximum)
	var damage_feedback := clampf((health_feedback_until - GameClock.elapsed) / .25, 0, 1)
	hp.modulate = Color.WHITE.lerp(Color(2.0, .4, .4), damage_feedback)
	var feedback := clampf((magic_feedback_until - GameClock.elapsed) / .22, 0, 1)
	magic_meter.modulate = Color.WHITE.lerp(magic_feedback, feedback)
	magic_meter.position = magic_home
	if magic_feedback == Color.RED:
		magic_meter.position.x += sin(GameClock.elapsed * 90) * 3 * feedback
	magic_hint.visible = GameClock.elapsed < magic_hint_until
	_update_shards(delta)
	charge.value = (
		p.charge_amount
		if p.state == "charge"
		else clampf(p.action_time / p.bow.settings.full_draw_duration(), 0, 1)
	)
	charge.visible = p.state in ["charge", "bow_draw"]
	var hint_text := "HEAVY CHARGE" if p.state == "charge" else ""
	if p.state == "bow_draw":
		hint_text = (
			"CHARGED ARROW"
			if p.bow.charged
			else ("RELEASE TO FIRE" if p.action_time >= p.bow.settings.minimum_draw else "DRAWING")
		)
	elif p.state == "bow_empty":
		hint_text = "NO MAGIC"
	_set_text(hint, hint_text)
	state_label.visible = arena.debug_enabled
	if arena.debug_enabled:
		state_label.text = (
			"STATE  %s\nTIME   %.3f\nHIT    %s\nI-FRAME %s\nSPEED  %.2f m/s\nINPUT  %s\nFPS    %d\n%s"
			% [
				p.state,
				p.action_time,
				p.active_window,
				p.is_invulnerable(),
				Vector2(p.velocity.x, p.velocity.z).length(),
				p.input_device,
				Engine.get_frames_per_second(),
				AttackTokenManager.debug_status()
			]
		)
	var dead = p.state == "dead" and p.action_time > .9
	var menu_visible: bool = (
		(
			GameClock.paused
			and not Dialogue.active
			and not SceneTransit.active
			and not Checkpoints.active
		)
		or (dead and not SceneTransit.active)
	)
	if menu_visible and not pause_panel.visible:
		pause_panel.open(dead, p.settings.camera_shake, menu_reason)
	elif not menu_visible and pause_panel.visible:
		pause_panel.close()
	var overlays_allowed: bool = (
		not menu_visible
		and not Dialogue.active
		and not SceneTransit.active
		and not Checkpoints.active
	)
	var interaction: Interactable = p.interaction.target
	input_hint.visible = overlays_allowed and p.state != "entrance"
	context_prompt.visible = overlays_allowed and not is_instance_valid(interaction)
	var input_text := (
		"%s  Sword    %s  Dodge    %s  Bow    %s  Menu"
		% [
			InputRouter.prompt("light"),
			InputRouter.prompt("dodge"),
			InputRouter.prompt("bow_aim"),
			InputRouter.prompt("pause")
		]
	)
	if p.bow.active() and p.state != "bow_empty" and not menu_visible:
		input_text = (
			"%s  Release to shoot    %s  Dodge to cancel"
			% [InputRouter.prompt("bow_shoot"), InputRouter.prompt("dodge")]
		)
	var context_text := (
		"%s  %s" % [InputRouter.prompt("interact"), interaction.prompt]
		if is_instance_valid(interaction) and p.state == "locomotion"
		else ""
	)
	if GameClock.elapsed < ability_hint_until:
		context_text = "Ability not unlocked · Bow remains selected"
	_set_text(input_hint, "[right]" + InputRouter.rich_text(input_text) + "[/right]")
	_set_text(context_prompt, "[center]" + InputRouter.rich_text(context_text) + "[/center]")


## Assigning text re-parses BBCode and re-layouts the label, so only write real changes.
func _set_text(control: Control, value: String) -> void:
	if control.text != value:
		control.text = value


func _input(event: InputEvent) -> void:
	if Dialogue.active or SceneTransit.active or Checkpoints.active or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		if arena.player.state == "dead":
			return
		if GameClock.paused:
			_resume()
		else:
			_pause()
		get_viewport().set_input_as_handled()
	if event.is_action_pressed("restart"):
		_restart()
	if event.is_action_pressed("debug"):
		arena.debug_enabled = not arena.debug_enabled
	if event.is_action_pressed("shake"):
		arena.player.settings.camera_shake = not arena.player.settings.camera_shake


func _pause(reason := "") -> void:
	menu_reason = reason
	GameClock.paused = true
	arena.player.suspend_controls()
	InputRouter.block_gameplay_input()
	pause_panel.open(false, arena.player.settings.camera_shake, reason)


func _resume() -> void:
	menu_reason = ""
	GameClock.paused = false
	arena.player.suspend_controls()
	InputRouter.block_gameplay_input()
	pause_panel.close()


func _restart() -> void:
	if GameProgress.active_slot >= 0:
		Checkpoints.respawn_player()
		return
	Dialogue.close(false)
	menu_reason = ""
	arena.restart()
	InputRouter.block_gameplay_input()
	pause_panel.close()


func _controller_disconnected() -> void:
	if Checkpoints.active:
		return
	if SceneTransit.active:
		SceneTransit.pause_on_arrival = true
		return
	Dialogue.close(false)
	if arena.player.state != "dead":
		_pause("Controller disconnected")


func _ability_denied(_slot: int) -> void:
	ability_hint_until = GameClock.elapsed + 1.25


func _magic_changed(_current: int, _maximum: int, reason: StringName) -> void:
	if reason in [&"reset", &"scene_travel"]:
		magic_feedback_until = 0.0
		magic_hint_until = 0.0
		return
	magic_feedback_until = GameClock.elapsed + .22
	magic_feedback = Color(1.7, 1.7, 1.7) if reason == "restored" else Color(.5, .45, .6)
	magic_hint_until = GameClock.elapsed + (1.1 if reason == "restored" else 0.0)
	magic_hint.text = "+1 MAGIC" if reason == "restored" else ""


func _magic_denied() -> void:
	magic_feedback_until = GameClock.elapsed + .22
	magic_feedback = Color.RED
	magic_hint_until = GameClock.elapsed + 1.5
	magic_hint.text = "MELEE TO REFILL"


func _update_shards(delta: float) -> void:
	var feedback := clampf((shard_feedback_until - GameClock.elapsed) / .3, 0, 1)
	shard_value.modulate = Color.WHITE.lerp(shard_feedback, feedback)
	if shard_display != float(shard_target):
		shard_elapsed = minf(shard_elapsed + delta, shard_duration)
		var progress := clampf(shard_elapsed / maxf(shard_duration, .01), 0, 1)
		var eased := 1.0 - pow(1.0 - progress, 3.0)
		shard_display = lerpf(shard_from, float(shard_target), eased)
		if progress >= 1.0:
			shard_display = float(shard_target)
	_set_text(shard_value, str(roundi(shard_display)))
	var alpha := _shard_alpha(delta)
	shard_group.visible = alpha > .01
	shard_group.modulate.a = alpha


## Fades the readout in, holds it long enough to read the climb, then fades it out again.
func _shard_alpha(delta: float) -> float:
	if is_inf(shard_show_time):
		return 0.0
	shard_show_time += delta
	if shard_show_time < SHARD_FADE_IN:
		return shard_show_time / SHARD_FADE_IN
	if shard_show_time < SHARD_FADE_IN + SHARD_HOLD:
		return 1.0
	var fading := shard_show_time - SHARD_FADE_IN - SHARD_HOLD
	return clampf(1.0 - fading / SHARD_FADE_OUT, 0.0, 1.0)


func _shards_changed(total: int) -> void:
	_set_shards(total)
	shard_show_time = 0.0
	shard_feedback = Color(1.7, 1.55, 1.15)
	shard_feedback_until = GameClock.elapsed + .3


## A new total starts a fresh climb from whatever is on screen right now. A scene load or a
## fresh HUD snaps instead, otherwise arriving would look like a gain.
func _set_shards(total: int, snap := false) -> void:
	shard_from = float(total) if snap else shard_display
	shard_target = total
	shard_elapsed = 0.0
	# Calm but still snappy: roughly 0,65 s over 60 shards, capped for huge piles.
	shard_duration = clampf(.22 + absf(float(total) - shard_from) * .007, .3, 1.2)
	if snap:
		shard_display = float(total)
	_set_text(shard_value, str(roundi(shard_display)))


func _health_changed(current: float, maximum: float) -> void:
	if SceneTransit.active:
		health_feedback_until = 0.0
	elif current < last_health:
		health_feedback_until = GameClock.elapsed + .25
	elif current >= maximum:
		health_feedback_until = 0.0
	last_health = current


func _choose_character() -> void:
	SceneTransit.change_scene("res://scenes/ui/CharacterSelect.tscn", "Kies je reiziger")


func _return_to_title() -> void:
	SceneTransit.change_scene(
		"res://scenes/ui/TitleScreen.tscn",
		"Terug bij het licht",
		false,
		func(_scene): GameProgress.leave_game()
	)
