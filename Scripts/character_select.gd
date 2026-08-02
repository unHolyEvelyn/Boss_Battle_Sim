extends Control

# References matching your exact scene tree
@onready var name_label: Label = $VBoxContainer/Name
@onready var desc_label: Label = $VBoxContainer/Description

@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound

# Outer panels
@onready var panels: Dictionary = {
	"fighter": $PortraitContainer/Fighter,
	"mage": $PortraitContainer/Mage,
	"tank": $PortraitContainer/Tank
}

# Inner texture buttons
@onready var buttons: Dictionary = {
	"fighter": $PortraitContainer/Fighter/TextureButton,
	"mage": $PortraitContainer/Mage/TextureButton,
	"tank": $PortraitContainer/Tank/TextureButton
}

var character_data: Dictionary = {
	"fighter": {
		"name": "THE FIGHTER",
		"desc": "Balanced brawler. Stacks actions to unleash powerful strikes.",
		"color": Color("10b981")
	},
	"mage": {
		"name": "THE MAGE",
		"desc": "Tactical caster. Combos powerful and fast spells to cause damage.",
		"color": Color("8b5cf6")
	},
	"tank": {
		"name": "THE TANK",
		"desc": "Heavy defender. Absorbs hits and counters with massive force.",
		"color": Color("0284c7")
	}
}

var character_order: Array[String] = ["fighter", "mage", "tank"]
var selected_character: String = ""

func _ready() -> void:
	MusicManager.play_title_theme()
	
	setup_button_hover_sounds(self)
	
	setup_action_button($StartButton)
	setup_action_button($BackButton)

	# Connect character portrait signals for mouse support
	for char_key in buttons:
		var btn = buttons[char_key]
		btn.pressed.connect(func(): select_char(char_key))
		btn.mouse_entered.connect(func(): select_char(char_key))

	selected_character = "fighter"
	var info = character_data["fighter"]
	name_label.text = info["name"]
	name_label.modulate = info["color"]
	desc_label.text = info["desc"]
	update_borders()

func _unhandled_input(event: InputEvent) -> void:
	var current_index = character_order.find(selected_character)

	if event.is_action_pressed("right"):
		var next_index = (current_index + 1) % character_order.size()
		select_char(character_order[next_index])
	elif event.is_action_pressed("left"):
		var prev_index = (current_index - 1 + character_order.size()) % character_order.size()
		select_char(character_order[prev_index])
	elif event.is_action_pressed("confirm"):
		_on_start_button_pressed()

func select_char(char_key: String) -> void:
	if selected_character != char_key:
		selected_character = char_key
		_on_button_hovered()
		
		var info = character_data[char_key]

		name_label.text = info["name"]
		name_label.modulate = info["color"]
		desc_label.text = info["desc"]

		update_borders()

func update_borders() -> void:
	for char_key in panels:
		var panel = panels[char_key]
		var info = character_data[char_key]
		
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.BLACK
		stylebox.set_corner_radius_all(0)
		stylebox.set_border_width_all(2)

		if char_key == selected_character:
			stylebox.border_color = info["color"]
		else:
			stylebox.border_color = Color("222222")

		panel.add_theme_stylebox_override("panel", stylebox)

func _on_start_button_pressed() -> void:
	_play_confirm_sound()
	Global.selected_character = selected_character
	get_tree().change_scene_to_file("res://Scenes/battle_scene.tscn")

func _on_back_button_pressed() -> void:
	_play_confirm_sound()
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

func setup_action_button(btn: Button) -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color.BLACK
	normal_style.set_corner_radius_all(0)
	normal_style.set_border_width_all(2)
	normal_style.border_color = Color("555555")

	var selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color.BLACK
	selected_style.set_corner_radius_all(0)
	selected_style.set_border_width_all(2)
	selected_style.border_color = Color.WHITE

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", selected_style)
	btn.add_theme_stylebox_override("focus", selected_style)
	btn.add_theme_stylebox_override("pressed", selected_style)


# --- AUDIO HELPER METHODS ---

func setup_button_hover_sounds(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is Button or child is TextureButton:
			child.mouse_entered.connect(_on_button_hovered)
		
		if child.get_child_count() > 0:
			setup_button_hover_sounds(child)


func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()

func _play_confirm_sound() -> void:
	if confirm_sound:
		confirm_sound.play()
