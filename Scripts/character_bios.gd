extends Control

"res://Resources/Fighter.tres"
"res://Resources/Mage.tres"
"res://Resources/Tank.tres"
@export var characters: Array[CharacterData] = []

@onready var portrait_rect: TextureRect = $HBoxContainer/VBoxContainer/Control/PanelContainer/TextureRect
@onready var name_label: Label = $HBoxContainer/VBoxContainer/ClassName
@onready var short_desc_label: Label = $HBoxContainer/VBoxContainer/SmallDescription
@onready var detailed_desc_label: Label = $HBoxContainer/PanelContainer/LargeDescription

var current_character_index: int = 0
var current_page_index: int = 0

func _ready() -> void:
	if characters.size() > 0:
		load_character(0)

func load_character(index: int) -> void:
	if index < 0 or index >= characters.size():
		return
		
	current_character_index = index
	current_page_index = 0 # Reset to page 1 when switching heroes.
	
	var data: CharacterData = characters[current_character_index]
	
	# Update Left Side
	name_label.text = data.character_name
	portrait_rect.texture = data.portrait
	short_desc_label.text = data.short_description
	
	# Update Right Side
	update_page_display()
	
func update_page_display() -> void:
	var data: CharacterData = characters[current_character_index]
	if data.detailed_pages.size() > 0:
		detailed_desc_label.text = data.detailed_pages[current_page_index]
	else:
		detailed_desc_label.text = ""

# --- BUTTON CONTROLS ---

# Call this when player clicks next page or presses right arrow

func _unhandled_input(event: InputEvent) -> void:
	# Page Flipping / Horizontal Navigation
	if event.is_action_pressed("right"):
		next_page()
		get_viewport().set_input_as_handled() # Stops input from propagating further
	elif event.is_action_pressed("left"):
		prev_page()
		get_viewport().set_input_as_handled()

	# Character Swapping / Vertical Navigation
	elif event.is_action_pressed("down"):
		select_next_character()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("up"):
		select_prev_character()
		get_viewport().set_input_as_handled()

	# Confirm / Select Action
	elif event.is_action_pressed("confirm"):
		# Add confirm logic (e.g. choose character or enter sub-menu)
		get_viewport().set_input_as_handled()

	# Cancel / Back Action
	elif event.is_action_pressed("cancel"):
		# Add back logic (e.g. return to main menu)
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")

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
