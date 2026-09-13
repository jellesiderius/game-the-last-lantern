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
@onready var arena = get_parent()


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
	hint = $Root/Hint


func _process(_delta: float) -> void:
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
	$Root/Status/MagicHint.visible = GameClock.elapsed < magic_hint_until
	charge.value = (
		p.charge_amount
		if p.state == "charge"
		else clampf(p.action_time / p.bow.settings.full_draw_duration(), 0, 1)
	)
	charge.visible = p.state in ["charge", "bow_draw"]
	hint.text = ("HEAVY CHARGE" if p.state == "charge" else "")
	if p.state == "bow_draw":
		hint.text = (
			"CHARGED ARROW"
			if p.bow.charged
			else ("RELEASE TO FIRE" if p.action_time >= p.bow.settings.minimum_draw else "DRAWING")
		)
	elif p.state == "bow_empty":
		hint.text = "NO MAGIC"
	state_label.visible = arena.debug_enabled
	state_label.text = (
		"STATE  %s\nTIME   %.3f\nHIT    %s\nI-FRAME %s\nSPEED  %.2f m/s\nINPUT  %s\nFPS    %d"
		% [
			p.state,
			p.action_time,
			p.active_window,
			p.is_invulnerable(),
			Vector2(p.velocity.x, p.velocity.z).length(),
			p.input_device,
			Engine.get_frames_per_second()
		]
	)
	var dead = p.state == "dead" and p.action_time > .9
	if arena.debug_enabled:
		state_label.text += "\n" + AttackTokenManager.debug_status()
	var menu_visible: bool = GameClock.paused or dead
	if menu_visible and not pause_panel.visible:
		pause_panel.open(dead, p.settings.camera_shake, menu_reason)
	elif not menu_visible and pause_panel.visible:
		pause_panel.close()
	$Root/InputHint.visible = not menu_visible
	$Root/InputHint.text = (
		"%s  Sword    %s  Dodge    %s  Bow    %s  Menu"
		% [
			InputRouter.prompt("light"),
			InputRouter.prompt("dodge"),
			InputRouter.prompt("bow_aim"),
			InputRouter.prompt("pause")
		]
	)
	var interaction: Interactable = p.interaction.target
	$Root/ContextPrompt.visible = not menu_visible
	$Root/ContextPrompt.text = (
		"%s  %s" % [InputRouter.prompt("interact"), interaction.prompt]
		if is_instance_valid(interaction) and p.state == "locomotion"
		else ""
	)
	if GameClock.elapsed < ability_hint_until:
		$Root/ContextPrompt.text = "Ability not unlocked · Bow remains selected"
	if p.bow.active() and p.state != "bow_empty" and not menu_visible:
		$Root/InputHint.text = (
			"%s  Release to shoot    %s  Dodge to cancel"
			% [InputRouter.prompt("bow_shoot"), InputRouter.prompt("dodge")]
		)

	$Root/InputHint.text = "[right]" + InputRouter.rich_text($Root/InputHint.text) + "[/right]"
	$Root/ContextPrompt.text = (
		"[center]" + InputRouter.rich_text($Root/ContextPrompt.text) + "[/center]"
	)


func _input(event: InputEvent) -> void:
	if event.is_echo():
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
	menu_reason = ""
	arena.restart()
	InputRouter.block_gameplay_input()
	pause_panel.close()


func _controller_disconnected() -> void:
	if arena.player.state != "dead":
		_pause("Controller disconnected")


func _ability_denied(_slot: int) -> void:
	ability_hint_until = GameClock.elapsed + 1.25


func _magic_changed(_current: int, _maximum: int, reason: StringName) -> void:
	if reason == &"reset":
		magic_feedback_until = 0.0
		magic_hint_until = 0.0
		return
	magic_feedback_until = GameClock.elapsed + .22
	magic_feedback = Color(1.7, 1.7, 1.7) if reason == "restored" else Color(.5, .45, .6)
	magic_hint_until = GameClock.elapsed + (1.1 if reason == "restored" else 0.0)
	$Root/Status/MagicHint.text = "+1 MAGIC" if reason == "restored" else ""


func _magic_denied() -> void:
	magic_feedback_until = GameClock.elapsed + .22
	magic_feedback = Color.RED
	magic_hint_until = GameClock.elapsed + 1.5
	$Root/Status/MagicHint.text = "MELEE TO REFILL"


func _health_changed(current: float, maximum: float) -> void:
	if current < last_health:
		health_feedback_until = GameClock.elapsed + .25
	elif current >= maximum:
		health_feedback_until = 0.0
	last_health = current


func _choose_character() -> void:
	GameClock.reset()
	AttackTokenManager.reset()
	InputRouter.block_gameplay_input()
	get_tree().change_scene_to_file("res://scenes/ui/CharacterSelect.tscn")


func _return_to_title() -> void:
	arena.player.suspend_controls()
	GameClock.reset()
	AttackTokenManager.reset()
	InputRouter.block_gameplay_input()
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
