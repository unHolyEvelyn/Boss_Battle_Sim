extends Control

# Preload your pixel font file (adjust path if your font is stored elsewhere!)
var pixel_font: Font = preload("res://Fonts/ari-w9500-bold.ttf") if ResourceLoader.exists("res://Fonts/ari-w9500-bold.ttf") else null

@onready var particle_slider: HSlider = $VBoxContainer/ParticleSlider
@onready var window_option: OptionButton = $VBoxContainer/WindowOption
@onready var music_checkbox: CheckBox = $VBoxContainer/MusicCheckBox
@onready var sfx_checkbox: CheckBox = $VBoxContainer/SFXCheckBox
@onready var back_button: Button = $VBoxContainer/BackButton

@onready var hover_sound: AudioStreamPlayer = $HoverSound if has_node("HoverSound") else null
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound if has_node("ConfirmSound") else null

# Track buttons for custom styling and keyboard/controller input
@onready var menu_buttons: Array[Button] = [
	back_button
]

var selected_index: int = 0


func _ready() -> void:
	# Populate Window OptionButton
	window_option.clear()
	window_option.add_item("Windowed", 0)
	window_option.add_item("Borderless Fullscreen", 1)

	# Sync initial values with SettingsManager
	particle_slider.value = SettingsManager.particle_density
	window_option.selected = SettingsManager.window_mode
	music_checkbox.button_pressed = SettingsManager.music_enabled
	sfx_checkbox.button_pressed = SettingsManager.sfx_enabled

	# Connect control signals
	particle_slider.value_changed.connect(_on_particle_slider_changed)
	window_option.item_selected.connect(_on_window_option_selected)
	music_checkbox.toggled.connect(_on_music_toggled)
	sfx_checkbox.toggled.connect(_on_sfx_toggled)
	
	# Button hover & press setup
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		var button_index = i
		btn.focus_mode = Control.FOCUS_NONE
		btn.mouse_entered.connect(func(): select_index(button_index))

	back_button.pressed.connect(_on_back_pressed)

	selected_index = 0
	update_button_styles()


func _unhandled_input(event: InputEvent) -> void:
	# Only listen for input when settings menu is active
	if not visible:
		return

	if event is InputEventJoypadMotion:
		return

	# Navigation between settings buttons
	if event.is_action_pressed("down"):
		var next_index = (selected_index + 1) % menu_buttons.size()
		select_index(next_index)
	elif event.is_action_pressed("up"):
		var prev_index = (selected_index - 1 + menu_buttons.size()) % menu_buttons.size()
		select_index(prev_index)
	elif event.is_action_pressed("confirm"):
		trigger_selected_action()
	elif event.is_action_pressed("cancel") or event.is_action_pressed("ui_cancel"):
		_on_back_pressed()


func select_index(index: int) -> void:
	if selected_index != index:
		selected_index = index
		_on_button_hovered()
		update_button_styles()
	else:
		selected_index = index
		update_button_styles()


func trigger_selected_action() -> void:
	match selected_index:
		0:
			_on_back_pressed()


func update_button_styles() -> void:
	# --- 1. Style standard buttons ---
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

		if pixel_font:
			btn.add_theme_font_override("font", pixel_font)

	# --- 2. Style the OptionButton Dropdown ---
	if window_option:
		var opt_stylebox = StyleBoxFlat.new()
		opt_stylebox.bg_color = Color.BLACK
		opt_stylebox.set_corner_radius_all(0)
		opt_stylebox.set_border_width_all(2)
		opt_stylebox.border_color = Color("555555")

		window_option.add_theme_stylebox_override("normal", opt_stylebox)
		window_option.add_theme_stylebox_override("hover", opt_stylebox)
		window_option.add_theme_stylebox_override("focus", opt_stylebox)
		window_option.add_theme_stylebox_override("pressed", opt_stylebox)

		if pixel_font:
			window_option.add_theme_font_override("font", pixel_font)

		# --- 3. Style the Popup Menu panel & apply font to dropdown options ---
		var popup_stylebox = StyleBoxFlat.new()
		popup_stylebox.bg_color = Color.BLACK
		popup_stylebox.set_corner_radius_all(0)
		popup_stylebox.set_border_width_all(2)
		popup_stylebox.border_color = Color.WHITE

		var popup = window_option.get_popup()
		if popup:
			popup.add_theme_stylebox_override("panel", popup_stylebox)
			if pixel_font:
				popup.add_theme_font_override("font", pixel_font)


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
	
func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()
