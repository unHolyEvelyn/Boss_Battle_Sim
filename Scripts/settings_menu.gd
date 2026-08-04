extends Control

signal closed  # Signal sent to MainMenu when this menu closes

# Preload your pixel font file
var pixel_font: Font = preload("res://Fonts/ari-w9500-bold.ttf") if ResourceLoader.exists("res://Fonts/ari-w9500-bold.ttf") else null

@onready var particle_slider: HSlider = $VBoxContainer/ParticleSlider
@onready var window_option: OptionButton = $VBoxContainer/WindowOption
@onready var music_checkbox: CheckBox = $VBoxContainer/MusicCheckBox
@onready var sfx_checkbox: CheckBox = $VBoxContainer/SFXCheckBox
@onready var back_button: Button = $VBoxContainer/BackButton

@onready var hover_sound: AudioStreamPlayer = $HoverSound if has_node("HoverSound") else null
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound if has_node("ConfirmSound") else null

# Navigation items array (ordered top to bottom)
@onready var menu_items: Array[Control] = [
	particle_slider,
	window_option,
	music_checkbox,
	sfx_checkbox,
	back_button
]

var selected_index: int = 0


func _ready() -> void:
	# Configure Slider Range & Step
	particle_slider.min_value = 0.0
	particle_slider.max_value = 1.0
	particle_slider.step = 0.05

	# Populate Window OptionButton
	window_option.clear()
	window_option.add_item("Windowed", 0)
	window_option.add_item("Borderless Fullscreen", 1)

	# Sync initial values with SettingsManager
	particle_slider.value = SettingsManager.particle_density
	window_option.selected = SettingsManager.window_mode
	music_checkbox.button_pressed = SettingsManager.music_enabled
	sfx_checkbox.button_pressed = SettingsManager.sfx_enabled

	# Connect control signals (Note: back_button pressed signal removed to prevent double-firing)
	particle_slider.value_changed.connect(_on_particle_slider_changed)
	window_option.item_selected.connect(_on_window_option_selected)
	music_checkbox.toggled.connect(_on_music_toggled)
	sfx_checkbox.toggled.connect(_on_sfx_toggled)

	# Disable all built-in focus and block mouse interactions
	for item in menu_items:
		item.focus_mode = Control.FOCUS_NONE
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE

	selected_index = 0
	update_button_styles()


# Reset selection whenever the settings menu is shown
func show_menu() -> void:
	selected_index = 0
	update_button_styles()
	show()


func _unhandled_input(event: InputEvent) -> void:
	# Only listen for input when settings menu is active
	if not visible:
		return

	if event is InputEventJoypadMotion:
		return

	# --- Vertical Navigation ---
	if event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		var next_index = (selected_index + 1) % menu_items.size()
		select_index(next_index)
	elif event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		var prev_index = (selected_index - 1 + menu_items.size()) % menu_items.size()
		select_index(prev_index)

	# --- Left / Right Adjustments ---
	elif event.is_action_pressed("left"):
		get_viewport().set_input_as_handled()
		handle_horizontal_input(-1)
	elif event.is_action_pressed("right"):
		get_viewport().set_input_as_handled()
		handle_horizontal_input(1)

	# --- Confirm Action ---
	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		trigger_selected_action()

	# --- Cancel / Close with 'Z' key or Cancel Actions ---
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_Z):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func select_index(index: int) -> void:
	if selected_index != index:
		selected_index = index
		_on_button_hovered()
		update_button_styles()


func handle_horizontal_input(direction: int) -> void:
	var current_item = menu_items[selected_index]

	# Adjust Slider with Left/Right
	if current_item == particle_slider:
		particle_slider.value = clamp(
			particle_slider.value + (direction * particle_slider.step),
			particle_slider.min_value,
			particle_slider.max_value
		)
		_on_button_hovered()

	# Cycle Window Mode with Left/Right
	elif current_item == window_option:
		var new_idx = posmod(window_option.selected + direction, window_option.item_count)
		window_option.selected = new_idx
		_on_window_option_selected(new_idx)
		_on_button_hovered()

	# Toggle Checkboxes with Left/Right
	elif current_item == music_checkbox:
		music_checkbox.button_pressed = !music_checkbox.button_pressed
		_on_button_hovered()
	elif current_item == sfx_checkbox:
		sfx_checkbox.button_pressed = !sfx_checkbox.button_pressed
		_on_button_hovered()


func trigger_selected_action() -> void:
	var current_item = menu_items[selected_index]

	if current_item == back_button:
		_on_back_pressed()
	elif current_item == music_checkbox:
		music_checkbox.button_pressed = !music_checkbox.button_pressed
	elif current_item == sfx_checkbox:
		sfx_checkbox.button_pressed = !sfx_checkbox.button_pressed
	elif current_item == window_option:
		var next_idx = (window_option.selected + 1) % window_option.item_count
		window_option.selected = next_idx
		_on_window_option_selected(next_idx)


func update_button_styles() -> void:
	for i in range(menu_items.size()):
		var item = menu_items[i]
		
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.BLACK
		stylebox.set_corner_radius_all(0)
		stylebox.set_border_width_all(2)

		# Highlight active item in white, inactive in dark gray
		if i == selected_index:
			stylebox.border_color = Color.WHITE
		else:
			stylebox.border_color = Color("555555")

		item.add_theme_stylebox_override("normal", stylebox)
		item.add_theme_stylebox_override("hover", stylebox)
		item.add_theme_stylebox_override("focus", stylebox)
		item.add_theme_stylebox_override("pressed", stylebox)

		if pixel_font:
			item.add_theme_font_override("font", pixel_font)


# --- SIGNAL HANDLERS ---

func _on_particle_slider_changed(value: float) -> void:
	SettingsManager.set_particle_density(value)

func _on_window_option_selected(index: int) -> void:
	SettingsManager.set_window_mode(index)

func _on_music_toggled(toggled_on: bool) -> void:
	SettingsManager.set_music_enabled(toggled_on)

func _on_sfx_toggled(toggled_on: bool) -> void:
	SettingsManager.set_sfx_enabled(toggled_on)

# --- AUDIO HELPER METHODS ---

func _on_back_pressed() -> void:
	if confirm_sound:
		confirm_sound.play()
	hide()
	closed.emit()

func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()
