extends AnimatedSprite2D

var current_character: String = "fighter" # Default fallback

func _ready() -> void:
	# Pull selection from Global autoload, fallback to default if missing
	if Global and Global.selected_character != "":
		current_character = Global.selected_character

	play_idle()

# Plays the looping idle for whichever hero was selected
func play_idle() -> void:
	var anim_name = current_character + "_idle"
	
	if sprite_frames.has_animation(anim_name):
		play(anim_name)
	elif sprite_frames.has_animation(current_character):
		# Fallback if track is named just "mage" instead of "mage_idle"
		play(current_character)

# Helper function to trigger attack animations during battle turns
func play_attack() -> void:
	var anim_name = current_character + "_attack"
	
	if sprite_frames.has_animation(anim_name):
		play(anim_name)
		await animation_finished
	else:
		# Stand-in quick flash/bump forward if no attack animation frames exist yet
		var tween = create_tween()
		tween.tween_property(self, "position:x", position.x + 20.0, 0.1)
		tween.tween_property(self, "position:x", position.x, 0.1)
		await tween.finished

	# Automatically revert to idle after attacking
	play_idle()
