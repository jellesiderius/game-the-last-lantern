class_name GamePauseMenu
extends PanelContainer
## Reusable menu owns focus/presentation; its parent decides what resume/restart mean.
signal resume_requested
signal restart_requested
signal choose_character_requested
signal title_requested
signal camera_shake_changed(enabled: bool)
var defeated := false
@onready var tabs: TabContainer = $Layout/Tabs


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tabs.tab_changed.connect(_tab_changed)
	InputRouter.device_changed.connect(func(_kind): _refresh_prompts())
	$Layout/Tabs/Game/Resume.pressed.connect(func(): resume_requested.emit())
	$Layout/Tabs/Game/Restart.pressed.connect(func(): restart_requested.emit())
	$Layout/Tabs/Game/ChooseCharacter.pressed.connect(func(): choose_character_requested.emit())
	$Layout/Tabs/Game/Title.pressed.connect(func(): title_requested.emit())
	$Layout/Tabs/Settings/CameraShake.toggled.connect(
		func(enabled): camera_shake_changed.emit(enabled)
	)
	$Layout/Tabs/Settings/Vibration.toggled.connect(
		func(enabled): InputRouter.vibration_enabled = enabled
	)
	$Layout/Tabs/Game/ChooseCharacter.visible = GameSession.characters.size() > 1
	_refresh_prompts()


func open(is_defeated: bool, shake_enabled: bool, reason := "") -> void:
	defeated = is_defeated
	show()
	$Layout/Title.text = (
		"You have fallen" if defeated else (reason if not reason.is_empty() else "Paused")
	)
	$Layout/Tabs/Game/Resume.disabled = defeated
	$Layout/Tabs/Settings/CameraShake.set_pressed_no_signal(shake_enabled)
	$Layout/Tabs/Settings/Vibration.set_pressed_no_signal(InputRouter.vibration_enabled)
	tabs.current_tab = 0
	_refresh_prompts()
	_focus_page.call_deferred()


func close() -> void:
	hide()
	var focus := get_viewport().gui_get_focus_owner()
	if is_instance_valid(focus) and is_ancestor_of(focus):
		focus.release_focus()


func _input(event: InputEvent) -> void:
	if not visible or event.is_echo():
		return
	if event.is_action_pressed("ui_page_up") or event.is_action_pressed("ui_page_down"):
		var direction := -1 if event.is_action_pressed("ui_page_up") else 1
		tabs.current_tab = posmod(tabs.current_tab + direction, tabs.get_tab_count())
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if not defeated:
			resume_requested.emit()
		get_viewport().set_input_as_handled()


func _tab_changed(_tab: int) -> void:
	_focus_page.call_deferred()


func _focus_page() -> void:
	if not visible:
		return
	var buttons: Array[Control] = []
	for node in tabs.get_current_tab_control().find_children("*", "BaseButton", true, false):
		if not node.disabled and node.is_visible_in_tree():
			buttons.append(node)
	if buttons.is_empty():
		tabs.get_tab_bar().grab_focus()
		return
	for i in buttons.size():
		buttons[i].focus_neighbor_top = buttons[i].get_path_to(
			buttons[posmod(i - 1, buttons.size())]
		)
		buttons[i].focus_neighbor_bottom = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
	buttons[0].grab_focus()


func _refresh_prompts() -> void:
	$Layout/Tabs/Controls/Bindings.text = InputRouter.rich_text(InputRouter.controls_text())
	$Layout/Navigation.text = InputRouter.rich_text(
		(
			"%s  tabs     %s  select     %s  back"
			% [
				InputRouter.prompt("tabs"),
				InputRouter.prompt("accept"),
				InputRouter.prompt("cancel")
			]
		)
	)
