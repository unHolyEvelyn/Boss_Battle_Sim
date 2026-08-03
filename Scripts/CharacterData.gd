class_name CharacterData
extends Resource

@export var character_name: String = "Class"
@export var portrait: Texture2D
@export_multiline var short_description: String = ""
# Array of strings so each entry is a new page
@export_multiline var detailed_pages: Array[String] = []
