extends Control

# Direct paths matching your MainMenu scene tree
@onready var character_select_btn: Button = $VBoxContainer/CharacterSelectButton
@onready var options_btn: Button = $VBoxContainer/OptionsButton
@onready var quit_btn: Button = $VBoxContainer/QuitButton

@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound
@onready var particles: CPUParticles2D = $CPUParticles2D

# Reference to your SettingsMenu node
@onready var settings_menu: Control = $SettingsMenu if has_node("SettingsMenu") else null

@onready var menu_buttons: Array[Button] = [
	character_select_btn,
	options_btn,
	quit_btn
]

var selected_index: int = 0

func _ready() -> void:
	MusicManager.play_title_theme()
	
	# Make sure settings menu starts hidden so it doesn't block inputs on boot
	if settings_menu:
		settings_menu.hide()
	
	# Register particle system with SettingsManager
	if particles:
		particles.add_to_group("particles")
		SettingsManager.set_particle_density(SettingsManager.particle_density)
	
	# Connect mouse enter and disable built-in UI focus stealing
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		var button_index = i
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_entered.connect(func(): select_index(button_index))

	# Initialize styling on start
	selected_index = 0
	update_button_styles()

func _unhandled_input(event: InputEvent) -> void:
	if settings_menu and settings_menu.visible:
		return

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
	else:
		selected_index = index
		update_button_styles()

func trigger_selected_action() -> void:
	_play_confirm_sound()
	match selected_index:
		0:
			_on_character_select_button_pressed()
		1:
			_on_options_button_pressed()
		2:
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


# --- BUTTON ACTIONS ---

func _on_character_select_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/character_select.tscn")

func _on_options_button_pressed() -> void:
	if settings_menu:
		settings_menu.show()

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# --- AUDIO HELPER METHODS ---

func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()

func _play_confirm_sound() -> void:
	if confirm_sound:
		confirm_sound.play()
