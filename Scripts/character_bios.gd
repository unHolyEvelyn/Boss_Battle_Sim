extends Control

# --- RESOURCE DATA ---
@export var characters: Array[CharacterData] = []

# --- SCENE REFERENCES ---
@onready var portrait_rect: TextureRect = $HBoxContainer/VBoxContainer/Control/PanelContainer/TextureRect
@onready var name_label: Label = $HBoxContainer/VBoxContainer/ClassName
@onready var short_desc_label: Label = $HBoxContainer/VBoxContainer/SmallDescription
@onready var detailed_desc_label: Label = $HBoxContainer/PanelContainer/LargeDescription
@onready var main_container: HBoxContainer = $HBoxContainer

@onready var hover_sound: AudioStreamPlayer = $HoverSound if has_node("HoverSound") else null
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound if has_node("ConfirmSound") else null

var current_character_index: int = 0
var current_page_index: int = 0

# --- ANIMATION CONFIGURATION ---
@export var slide_offset: float = 60.0
@export var anim_duration: float = 0.5

var _container_target_pos: Vector2


func _ready() -> void:
	if characters.size() > 0:
		load_character(0)

	# Configure description text autowrapping & alignment
	if short_desc_label:
		short_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		short_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
	if detailed_desc_label:
		detailed_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# WAIT for Godot layout pass before caching target positions
	await get_tree().process_frame

	if main_container:
		_container_target_pos = main_container.position
		animate_scene_in()
		


# --- ENTRANCE ANIMATION ---

func animate_scene_in() -> void:
	if not main_container:
		return

	# Main layout slides in from the left and fades in
	main_container.position = _container_target_pos - Vector2(slide_offset, 0)
	main_container.modulate.a = 0.0

	var tween = create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(main_container, "position", _container_target_pos, anim_duration)
	tween.tween_property(main_container, "modulate:a", 1.0, anim_duration)


func load_character(index: int) -> void:
	if index < 0 or index >= characters.size():
		return
		
	current_character_index = index
	current_page_index = 0 # Reset to page 1 when switching heroes.
	
	var data: CharacterData = characters[current_character_index]
	
	# Update Left Side
	if name_label: name_label.text = data.character_name
	if portrait_rect: portrait_rect.texture = data.portrait
	if short_desc_label: short_desc_label.text = data.short_description
	
	# Update Right Side
	update_page_display()

	
func update_page_display() -> void:
	var data: CharacterData = characters[current_character_index]
	if data.detailed_pages.size() > 0:
		detailed_desc_label.text = data.detailed_pages[current_page_index]
	else:
		detailed_desc_label.text = ""


# --- UNHANDLED INPUT handling ---

func _unhandled_input(event: InputEvent) -> void:
	# Page Flipping / Horizontal Navigation
	if event.is_action_pressed("right"):
		_play_hover_sound()
		next_page()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("left"):
		_play_hover_sound()
		prev_page()
		get_viewport().set_input_as_handled()

	# Character Swapping / Vertical Navigation
	elif event.is_action_pressed("down"):
		_play_hover_sound()
		select_next_character()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up"):
		_play_hover_sound()
		select_prev_character()
		get_viewport().set_input_as_handled()

	# Confirm Action
	elif event.is_action_pressed("confirm"):
		_play_confirm_sound()
		get_viewport().set_input_as_handled()

	# Cancel / Back Action
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_go_back_to_main_menu()


func next_page() -> void:
	var data: CharacterData = characters[current_character_index]
	if current_page_index < data.detailed_pages.size() - 1:
		current_page_index += 1
		update_page_display()


func prev_page() -> void:
	if current_page_index > 0:
		current_page_index -= 1
		update_page_display()


func select_next_character() -> void:
	var next_idx = (current_character_index + 1) % characters.size()
	load_character(next_idx)


func select_prev_character() -> void:
	var prev_idx = (current_character_index - 1 + characters.size()) % characters.size()
	load_character(prev_idx)


# --- SCENE TRANSITION & AUDIO ---

func _go_back_to_main_menu() -> void:
	_play_confirm_sound()
	
	if SceneTransition:
		SceneTransition.transition_to_scene("res://Scenes/main_menu.tscn")
	else:
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


func _play_hover_sound() -> void:
	if hover_sound:
		hover_sound.play()


func _play_confirm_sound() -> void:
	if confirm_sound:
		confirm_sound.play()
