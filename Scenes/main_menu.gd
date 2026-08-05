extends Control

# Direct paths matching your MainMenu scene tree
@onready var title_label: Label = $Title
@onready var menu_container: VBoxContainer = $VBoxContainer

@onready var character_select_btn: Button = $VBoxContainer/CharacterSelectButton
@onready var party_mode_btn: Button = $VBoxContainer/PartyModeButton if has_node("VBoxContainer/PartyModeButton") else null
@onready var bios_btn: Button = $VBoxContainer/BiosButton
@onready var options_btn: Button = $VBoxContainer/OptionsButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound
@onready var particles: CPUParticles2D = $CPUParticles2D

# Reference to your SettingsMenu overlay node & Back button inside it
@onready var settings_menu: Control = $SettingsMenu if has_node("SettingsMenu") else null
@onready var settings_back_btn: Button = $SettingsMenu/VBoxContainer/BackButton if has_node("SettingsMenu/VBoxContainer/BackButton") else null

var menu_buttons: Array[Button] = []

# --- ANIMATION CONFIGURATION ---
@export var slide_offset: float = 60.0    # Distance in pixels for the slide entrance
@export var anim_duration: float = 0.5    # Duration of the entrance transition in seconds

var selected_index: int = 0
var _menu_target_pos: Vector2
var _title_target_pos: Vector2
var _is_fading_settings: bool = false


func _ready() -> void:
	MusicManager.play_title_theme()
	
	# Populate menu buttons array in vertical navigation order
	menu_buttons = [
		character_select_btn,
		party_mode_btn,
		bios_btn,
		options_btn,
		quit_btn
	]
	
	# Filter out any null nodes if a button hasn't been added to scene tree yet
	menu_buttons = menu_buttons.filter(func(btn): return btn != null)

	# Make sure settings menu starts hidden so it doesn't block inputs on boot
	if settings_menu:
		settings_menu.hide()
		
	# Connect the Settings BackButton signal if available
	if settings_back_btn:
		settings_back_btn.pressed.connect(_on_settings_back_pressed)
	
	# Register particle system with SettingsManager
	if particles:
		particles.add_to_group("particle_emitters")
		if SettingsManager:
			SettingsManager.apply_density_to_node(particles)
	
	# Disable all mouse focus and mouse click/hover interactions on buttons
	for btn in menu_buttons:
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Initialize keyboard/controller navigation styling
	selected_index = 0
	update_button_styles()

	# WAIT for Godot to complete a layout pass before caching target positions
	await get_tree().process_frame

	# Cache the default layout positions configured in the Editor
	if menu_container:
		_menu_target_pos = menu_container.position
	
	if title_label:
		_title_target_pos = title_label.position

	# Play opening slide-in transitions
	animate_menu_in()


# --- UI TRANSITION ANIMATION ---

func animate_menu_in() -> void:
	# Create a parallel tween so movement and transparency happen together
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 1. MENU CONTAINER (Slides UP from bottom)
	if menu_container:
		menu_container.position = _menu_target_pos + Vector2(0, slide_offset)
		menu_container.modulate.a = 0.0

		tween.tween_property(menu_container, "position", _menu_target_pos, anim_duration)
		tween.tween_property(menu_container, "modulate:a", 1.0, anim_duration)

	# 2. TITLE LABEL (Slides DOWN from top)
	if title_label:
		title_label.position = _title_target_pos - Vector2(0, slide_offset)
		title_label.modulate.a = 0.0

		tween.tween_property(title_label, "position", _title_target_pos, anim_duration)
		tween.tween_property(title_label, "modulate:a", 1.0, anim_duration)


func _unhandled_input(event: InputEvent) -> void:
	# Handle inputs when settings menu overlay is active
	if settings_menu and settings_menu.visible:
		if event.is_action_pressed("cancel") and not _is_fading_settings:
			get_viewport().set_input_as_handled()
			_play_confirm_sound()
			close_settings_menu()
		return

	# Ignore raw analog motion if desired
	if event is InputEventJoypadMotion:
		return

	if event.is_action_pressed("down"):
		var next_index = (selected_index + 1) % menu_buttons.size()
		select_index(next_index)
	elif event.is_action_pressed("up"):
		var prev_index = (selected_index - 1 + menu_buttons.size()) % menu_buttons.size()
		select_index(prev_index)
	elif event.is_action_pressed("confirm"):
		trigger_selected_action()


func select_index(index: int) -> void:
	if selected_index != index:
		selected_index = index
		_on_button_hovered()
		update_button_styles()


func trigger_selected_action() -> void:
	_play_confirm_sound()
	var selected_button = menu_buttons[selected_index]
	
	if selected_button == character_select_btn:
		_on_character_select_button_pressed()
	elif selected_button == party_mode_btn:
		_on_party_mode_button_pressed()
	elif selected_button == bios_btn:
		_on_bios_button_pressed()
	elif selected_button == options_btn:
		_on_options_button_pressed()
	elif selected_button == quit_btn:
		_on_quit_button_pressed()


func update_button_styles() -> void:
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.BLACK
		stylebox.set_corner_radius_all(0)
		stylebox.set_border_width_all(2)

		if i == selected_index:
			stylebox.border_color = Color.WHITE
		else:
			stylebox.border_color = Color("555555")

		btn.add_theme_stylebox_override("normal", stylebox)
		btn.add_theme_stylebox_override("hover", stylebox)
		btn.add_theme_stylebox_override("focus", stylebox)
		btn.add_theme_stylebox_override("pressed", stylebox)


# --- SETTINGS OVERLAY FADE ANIMATIONS ---

func open_settings_menu() -> void:
	if not settings_menu or _is_fading_settings:
		return

	_is_fading_settings = true
	settings_menu.show()
	settings_menu.modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(settings_menu, "modulate:a", 1.0, 0.25)\
		 .set_trans(Tween.TRANS_CUBIC)\
		 .set_ease(Tween.EASE_OUT)

	await tween.finished
	_is_fading_settings = false


func close_settings_menu() -> void:
	if not settings_menu or _is_fading_settings:
		return

	_is_fading_settings = true
	var tween = create_tween()
	tween.tween_property(settings_menu, "modulate:a", 0.0, 0.25)\
		 .set_trans(Tween.TRANS_CUBIC)\
		 .set_ease(Tween.EASE_IN)
	
	await tween.finished
	settings_menu.hide()
	_is_fading_settings = false


func _on_settings_back_pressed() -> void:
	_play_confirm_sound()
	close_settings_menu()


# --- BUTTON ACTIONS ---

func _on_character_select_button_pressed() -> void:
	if SceneTransition:
		SceneTransition.transition_to_scene("res://Scenes/character_select.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/character_select.tscn")


func _on_party_mode_button_pressed() -> void:
	if SceneTransition:
		SceneTransition.transition_to_scene("res://Scenes/party_battle_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/party_battle_scene.tscn")


func _on_bios_button_pressed() -> void:
	if SceneTransition:
		SceneTransition.transition_to_scene("res://Scenes/character_bios.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/character_bios.tscn")


func _on_options_button_pressed() -> void:
	open_settings_menu()


func _on_quit_button_pressed() -> void:
	get_tree().quit()


# --- AUDIO HELPER METHODS ---

func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()


func _play_confirm_sound() -> void:
	if confirm_sound:
		confirm_sound.play()
