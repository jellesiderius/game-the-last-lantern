extends Control
## The reference plate stays fixed; only its light and the saved particle layers animate.
@export_file("*.tscn") var new_game_scene := "res://scenes/levels/PrototypeRoom.tscn"
@export_file("*.tscn") var test_scene := "res://scenes/levels/TestArena.tscn"
@export_range(0.0, 1.0, .05) var flicker_strength := 1.0
var animation_time := 0.0
var starting := false
var settings_open := false
var active_button: Button
@onready var artwork: Control = $Artwork
@onready var options: VBoxContainer = $Artwork/Options
@onready var pointer: TextureRect = $Artwork/Selection
@onready var settings_panel: PanelContainer = $Artwork/SettingsPanel


func _ready() -> void:
	GameClock.reset()
	AttackTokenManager.reset()
	InputRouter.block_gameplay_input()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fps="):
			Engine.max_fps = arg.trim_prefix("--fps=").to_int()
	# Existing CLI room reviews still launch the gameplay level directly.
	var room_reviews := [
		"--room-replay",
		"--energy-replay",
		"--swing-style-replay",
		"--acorn-replay",
		"--enemy-movement-replay",
		"--enemy-surface-replay",
		"--fall-dust-replay"
	]
	for arg in OS.get_cmdline_user_args():
		if arg in room_reviews:
			get_tree().change_scene_to_file.call_deferred(new_game_scene)
			return
	resized.connect(_fit_artwork)
	_fit_artwork()
	var buttons: Array[Control] = []
	for button: Button in options.get_children():
		var entrance := ShaderMaterial.new()
		entrance.shader = preload("res://shaders/menu_entrance.gdshader")
		button.material = entrance
		if button.disabled:
			continue
		buttons.append(button)
		button.focus_entered.connect(_focus.bind(button))
		button.mouse_entered.connect(button.grab_focus)
	_wire_focus(buttons)
	$Artwork/Options/NewGame.pressed.connect(_launch.bind(new_game_scene))
	$Artwork/Options/TestScene.pressed.connect(_launch_test_scene)
	$Artwork/Options/Settings.pressed.connect(_open_settings)
	$Artwork/Options/Quit.pressed.connect(func(): get_tree().quit())
	$Artwork/SettingsPanel/Layout/Back.pressed.connect(_close_settings)
	$Artwork/SettingsPanel/Layout/Vibration.set_pressed_no_signal(InputRouter.vibration_enabled)
	$Artwork/SettingsPanel/Layout/Vibration.toggled.connect(
		func(enabled): InputRouter.vibration_enabled = enabled
	)
	$Artwork/SettingsPanel/Layout/Fullscreen.set_pressed_no_signal(
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	)
	$Artwork/SettingsPanel/Layout/Fullscreen.toggled.connect(_set_fullscreen)
	_wire_focus(
		[
			$Artwork/SettingsPanel/Layout/Fullscreen,
			$Artwork/SettingsPanel/Layout/Vibration,
			$Artwork/SettingsPanel/Layout/Back
		]
	)
	$Artwork/Options/NewGame.grab_focus.call_deferred()
	if (
		"--intro-replay" in OS.get_cmdline_user_args()
		and not get_tree().root.has_node("IntroReplay")
	):
		var replay := load("res://tests/intro_replay.gd").new() as Node
		replay.name = "IntroReplay"
		get_tree().root.add_child.call_deferred(replay)


func _process(delta: float) -> void:
	# Menu presentation continues while settings are open; it does not drive gameplay.
	animation_time += delta
	var title_reveal := smoothstep(.15, 2.55, animation_time)
	$Artwork/TitleLogo.modulate.a = title_reveal
	$Artwork/TitleLogo.position.y = (1.0 - title_reveal) * 16.0
	$Artwork/Flame.material.set_shader_parameter("animation_time", animation_time)
	for button: Button in options.get_children():
		if button.material:
			button.material.set_shader_parameter("reveal", _menu_reveal(button.get_index()))
	for plate in [$Artwork/Background, $Artwork/LanternForeground]:
		plate.material.set_shader_parameter("animation_time", animation_time)
		plate.material.set_shader_parameter("flicker_strength", flicker_strength)
	if is_instance_valid(active_button):
		var reveal := _menu_reveal(active_button.get_index())
		pointer.modulate.a = reveal
		var font := active_button.get_theme_font("font")
		var width := (
			font
			. get_string_size(
				active_button.text,
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				active_button.get_theme_font_size("font_size")
			)
			. x
		)
		pointer.position = Vector2(
			836.0 - width * .5 - 46.0,
			(
				options.position.y
				+ active_button.position.y
				+ active_button.size.y * .5
				- 20.0
				+ (1.0 - reveal) * 4.0
			)
		)


func _menu_reveal(index: int) -> float:
	var begin := 1.58 + index * .05
	return smoothstep(begin, begin + .42, animation_time)


func _fit_artwork() -> void:
	var factor := minf(size.x / 1672.0, size.y / 941.0)
	artwork.scale = Vector2.ONE * factor
	artwork.position = (size - Vector2(1672, 941) * factor) * .5


func _wire_focus(buttons: Array[Control]) -> void:
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(
			buttons[posmod(i - 1, buttons.size())]
		)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])


func _focus(button: Button) -> void:
	active_button = button


func _open_settings() -> void:
	settings_open = true
	options.hide()
	pointer.hide()
	settings_panel.show()
	$Artwork/SettingsPanel/Layout/Fullscreen.grab_focus()


func _close_settings() -> void:
	settings_open = false
	settings_panel.hide()
	options.show()
	pointer.show()
	$Artwork/Options/Settings.grab_focus()


func _set_fullscreen(enabled: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	)


func _unhandled_input(event: InputEvent) -> void:
	if settings_open and event.is_action_pressed("ui_cancel"):
		_close_settings()
		get_viewport().set_input_as_handled()


func _launch_test_scene() -> void:
	_launch(test_scene)


func _launch(scene_path: String) -> void:
	if starting or scene_path.is_empty():
		return
	starting = true
	GameClock.reset()
	AttackTokenManager.reset()
	InputRouter.block_gameplay_input()
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		starting = false
		$Artwork/LaunchError.text = "This scene could not be opened."
		$Artwork/LaunchError.show()
		push_error("Title scene could not open %s: %s" % [scene_path, error])
