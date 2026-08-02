extends Node

@onready var bgm_player: AudioStreamPlayer = AudioStreamPlayer.new()

# Replace with the actual path to your exported music file!
var title_theme: AudioStream = preload("res://Music/titlesong.ogg")

func _ready() -> void:
	add_child(bgm_player)
	
	# Routes to Music bus
	bgm_player.bus = "Music"

func play_title_theme() -> void:
	# Prevent the track from restarting if it's already playing
	if bgm_player.stream == title_theme and bgm_player.playing:
		return
		
	bgm_player.stream = title_theme
	bgm_player.play()

func stop_music() -> void:
	bgm_player.stop()
