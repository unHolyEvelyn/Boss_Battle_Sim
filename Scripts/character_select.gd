extends Control

# --- SCENE REFERENCES ---
@onready var title_label: Label = $Title
@onready var portrait_container: HBoxContainer = $PortraitContainer
@onready var info_container: VBoxContainer = $VBoxContainer

@onready var name_label: Label = $VBoxContainer/Name
@onready var desc_label: Label = $VBoxContainer/Description

@onready var hard_mode_toggle: CheckBox = $VBoxContainer/HBoxContainer/CheckBox
@onready var hard_mode_status: Label = $VBoxContainer/HBoxContainer/Label

@onready var hover_sound: AudioStreamPlayer = $HoverSound if has_node("HoverSound") else null
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound if has_node("ConfirmSound") else null
@onready var particles: CPUParticles2D = $CPUParticles2D if has_node("CPUParticles2D") else null

# Outer panels for border styling
@onready var panels: Dictionary = {
	"fighter": $PortraitContainer/FighterVBox/Fighter,
	"mage": $PortraitContainer/MageVBox/Mage,
	"tank": $PortraitContainer/TankVBox/Tank
}

# Inner texture buttons
@onready var buttons: Dictionary = {
	"fighter": $PortraitContainer/FighterVBox/Fighter/TextureButton,
	"mage": $PortraitContainer/MageVBox/Mage/TextureButton,
	"tank": $PortraitContainer/TankVBox/Tank/TextureButton
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
var selected_character: String = "fighter"
var win_labels: Dictionary = {}

# Tracks menu selection: "HEROES" or "HARD_MODE"
var active_focus_area: String = "HEROES"

# --- ANIMATION CONFIGURATION ---
@export var slide_offset: float = 60.0    # Distance in pixels for movement transitions
@export var anim_duration: float = 0.5    # Transition speed in seconds

var _title_target_pos: Vector2
var _portrait_target_pos: Vector2
var _info_target_pos: Vector2


func _ready() -> void:
	MusicManager.play_title_theme()

	# Completely disable engine auto-focus on all interactive UI controls
	hard_mode_toggle.focus_mode = Control.FOCUS_NONE
	for char_key in buttons:
		if buttons[char_key]:
			buttons[char_key].focus_mode = Control.FOCUS_NONE

	# Connect CheckBox toggle signal
	hard_mode_toggle.toggled.connect(_on_hard_mode_toggled)

	# Set up victory labels above portraits
	setup_victory_labels()

	# Register particle system with SettingsManager
	if particles:
		particles.add_to_group("particle_emitters")
		if SettingsManager:
			SettingsManager.apply_density_to_node(particles)

	# Initialize default state
	_apply_character_info("fighter")
	update_borders()
	_update_hard_mode_status()

	# Center text labels and set smart autowrapping
	if name_label:
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	if desc_label:
		desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Center inner containers
	if has_node("VBoxContainer/HBoxContainer"):
		$VBoxContainer/HBoxContainer.alignment = BoxContainer.ALIGNMENT_CENTER
	if info_container:
		info_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# WAIT for Godot to finish calculating UI container layout before caching target coordinates
	await get_tree().process_frame

	# Cache layout positions
	if title_label:
		_title_target_pos = title_label.position
	if portrait_container:
		_portrait_target_pos = portrait_container.position
	if info_container:
		_info_target_pos = info_container.position

	# Trigger entrance animations
	animate_scene_in()


# --- ENTRANCE ANIMATIONS ---

func animate_scene_in() -> void:
	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# 1. Title fades in and slides DOWN from above
	if title_label:
		title_label.position = _title_target_pos - Vector2(0, slide_offset)
		title_label.modulate.a = 0.0
		tween.tween_property(title_label, "position", _title_target_pos, anim_duration)
		tween.tween_property(title_label, "modulate:a", 1.0, anim_duration)

	# 2. Portraits fade in and slide IN FROM THE LEFT
	if portrait_container:
		portrait_container.position = _portrait_target_pos - Vector2(slide_offset, 0)
		portrait_container.modulate.a = 0.0
		tween.tween_property(portrait_container, "position", _portrait_target_pos, anim_duration)
		tween.tween_property(portrait_container, "modulate:a", 1.0, anim_duration)

	# 3. Info Container (Name/Desc/Hard Mode) fades in and slides IN FROM THE LEFT
	if info_container:
		info_container.position = _info_target_pos - Vector2(slide_offset, 0)
		info_container.modulate.a = 0.0
		tween.tween_property(info_container, "position", _info_target_pos, anim_duration)
		tween.tween_property(info_container, "modulate:a", 1.0, anim_duration)


func setup_victory_labels() -> void:
	for char_key in panels:
		var panel = panels[char_key]
		if not panel:
			continue

		var vbox = panel.get_parent() # Gets FighterVBox / MageVBox / TankVBox
		var wins = SaveManager.get_hero_wins(char_key)

		for child in vbox.get_children():
			if child is Label:
				child.text = "WINS: " + str(wins)
				win_labels[char_key] = child
				break


# --- EXCLUSIVE INPUT HANDLING ---

func _unhandled_input(event: InputEvent) -> void:
	# 1. NAVIGATION: LEFT / RIGHT
	if event.is_action_pressed("left"):
		get_viewport().set_input_as_handled()
		if active_focus_area == "HEROES":
			var current_index = character_order.find(selected_character)
			var prev_index = (current_index - 1 + character_order.size()) % character_order.size()
			select_char(character_order[prev_index])

	elif event.is_action_pressed("right"):
		get_viewport().set_input_as_handled()
		if active_focus_area == "HEROES":
			var current_index = character_order.find(selected_character)
			var next_index = (current_index + 1) % character_order.size()
			select_char(character_order[next_index])

	# 2. NAVIGATION: DOWN / UP
	elif event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		if active_focus_area == "HEROES":
			active_focus_area = "HARD_MODE"
			_on_button_hovered()
			update_borders()

	elif event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		if active_focus_area == "HARD_MODE":
			active_focus_area = "HEROES"
			_on_button_hovered()
			update_borders()

	# 3. CONFIRM ACTION
	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		if active_focus_area == "HEROES":
			_confirm_character_selection()
		elif active_focus_area == "HARD_MODE":
			if Global.is_hard_mode_unlocked(selected_character):
				hard_mode_toggle.button_pressed = !hard_mode_toggle.button_pressed

	# 4. CANCEL ACTION
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_go_back_to_main_menu()


func select_char(char_key: String) -> void:
	if selected_character != char_key:
		selected_character = char_key
		_on_button_hovered()
		
		_apply_character_info(char_key)
		update_borders()
		_update_hard_mode_status()


func _apply_character_info(char_key: String) -> void:
	var info = character_data[char_key]
	name_label.text = info["name"]
	name_label.modulate = info["color"]
	desc_label.text = info["desc"]


func _update_hard_mode_status() -> void:
	var wins = SaveManager.get_hero_wins(selected_character)
	var unlocked = Global.is_hard_mode_unlocked(selected_character)

	if unlocked:
		hard_mode_toggle.disabled = false
		hard_mode_status.text = "HARD MODE UNLOCKED!"
		hard_mode_status.modulate = Color.GREEN
	else:
		hard_mode_toggle.disabled = true
		hard_mode_toggle.button_pressed = false
		Global.set_hard_mode(false)
		
		var needed = 5 - wins
		hard_mode_status.text = "Requires 5 Wins (" + str(needed) + " More Needed)"
		hard_mode_status.modulate = Color("e11d48")


func _on_hard_mode_toggled(toggled_on: bool) -> void:
	if Global.is_hard_mode_unlocked(selected_character):
		_on_button_hovered()
		Global.set_hard_mode(toggled_on)
	else:
		hard_mode_toggle.button_pressed = false
		Global.set_hard_mode(false)


func update_borders() -> void:
	for char_key in panels:
		var panel = panels[char_key]
		if not panel:
			continue
			
		var info = character_data[char_key]
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.BLACK
		stylebox.set_corner_radius_all(0)
		stylebox.set_border_width_all(2)

		if char_key == selected_character and active_focus_area == "HEROES":
			stylebox.border_color = info["color"]
			if win_labels.has(char_key):
				win_labels[char_key].modulate = info["color"]
		else:
			stylebox.border_color = Color("222222")
			if win_labels.has(char_key):
				win_labels[char_key].modulate = Color("888888")

		panel.add_theme_stylebox_override("panel", stylebox)

	if active_focus_area == "HARD_MODE":
		hard_mode_toggle.modulate = Color(1.3, 1.3, 1.3, 1.0)
	else:
		hard_mode_toggle.modulate = Color(1.0, 1.0, 1.0, 1.0)


# --- SCENE TRANSITIONS ---

func _confirm_character_selection() -> void:
	_play_confirm_sound()
	Global.selected_character = selected_character
	
	if SceneTransition:
		SceneTransition.transition_to_scene("res://Scenes/battle_scene.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/battle_scene.tscn")


func _go_back_to_main_menu() -> void:
	_play_confirm_sound()
	
	if SceneTransition:
		SceneTransition.transition_to_scene("res://Scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


# --- AUDIO HELPERS ---

func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()


func _play_confirm_sound() -> void:
	if confirm_sound:
		confirm_sound.play()
