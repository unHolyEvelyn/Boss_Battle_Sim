extends Node2D

# --- NODE REFERENCES ---
@onready var player: AnimatedSprite2D = $ArenaWorld/Player
@onready var boss: Node2D = $ArenaWorld/Boss
@onready var action_menu: Control = $UILayer/ActionMenu
@onready var class_label: Label = $UILayer/ClassHUD/Label
@onready var dialogue_label: Label = $UILayer/DialogueBox/Label

@onready var attack_button: Button = $UILayer/ActionMenu/AttackButton
@onready var defend_button: Button = $UILayer/ActionMenu/DefendButton
@onready var skill_button: Button = $UILayer/ActionMenu/SkillButton

@onready var parry_bar: TextureProgressBar = $UILayer/ParryBar

@onready var hover_sound: AudioStreamPlayer = $HoverSound
@onready var confirm_sound: AudioStreamPlayer = $ConfirmSound

# --- CUSTOM MENU NAVIGATION ---
var menu_buttons: Array[Button] = []
var selected_index: int = 0

# --- MAGE SUB-MENU NAVIGATION ---
var is_in_spell_menu: bool = false
var selected_spell_index: int = 0
var spell_detonated_this_turn: bool = false

# --- TANK PARRY MINI-GAME VARIABLES ---
var is_parry_minigame_active: bool = false
var parry_value: float = 0.0
var parry_dir: float = 1.0
var parry_speed: float = 180.0  # Speed the bar bounces back and forth
var parry_input_pressed: bool = false

# --- CLASS STAT SYSTEM ---
var max_hp: int = 100
var current_hp: int = 100
var attack_power: int = 10
var defense_power: int = 10
var speed: int = 10
var magic_power: int = 10

var is_defending: bool = false
var is_battle_over: bool = false

var class_stats: Dictionary = {
	"fighter": {
		"max_hp": 115,
		"attack": 20,
		"defense": 12,
		"speed": 14,
		"magic": 5
	},
	"mage": {
		"max_hp": 70,
		"attack": 6,
		"defense": 5,
		"speed": 10,
		"magic": 22
	},
	"tank": {
		"max_hp": 160,
		"attack": 8,
		"defense": 20,
		"speed": 6,
		"magic": 5
	}
}


func _ready() -> void:
	MusicManager.stop_music()
	
	setup_button_hover_sounds(self)
	
	load_character_stats()
	
	menu_buttons = [attack_button, defend_button, skill_button]
	
	attack_button.pressed.connect(_on_attack_button_pressed)
	defend_button.pressed.connect(_on_defend_button_pressed)
	skill_button.pressed.connect(_on_skill_button_pressed)
	
	if boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)
	
	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		bp_system.bp_changed.connect(_on_bp_changed)
	
	if parry_bar:
		parry_bar.hide()

	setup_class_buttons()
	update_button_styles()
	start_player_turn()


func _process(delta: float) -> void:
	# Real-time movement logic for the Tank ParryBar
	if is_parry_minigame_active and not parry_input_pressed and parry_bar:
		parry_value += parry_dir * parry_speed * delta
		
		if parry_value >= parry_bar.max_value:
			parry_value = parry_bar.max_value
			parry_dir = -1.0
		elif parry_value <= parry_bar.min_value:
			parry_value = parry_bar.min_value
			parry_dir = 1.0
			
		parry_bar.value = parry_value


func load_character_stats() -> void:
	var char_key = Global.selected_character.to_lower()
	
	if class_stats.has(char_key):
		var stats = class_stats[char_key]
		max_hp = stats["max_hp"]
		current_hp = max_hp
		attack_power = stats["attack"]
		defense_power = stats["defense"]
		speed = stats["speed"]
		magic_power = stats["magic"]
		
		update_hp_ui()


func update_hp_ui() -> void:
	class_label.text = Global.selected_character.capitalize() + " - HP " + str(current_hp) + "/" + str(max_hp)


func setup_class_buttons() -> void:
	match Global.selected_character.to_lower():
		"fighter":
			attack_button.text = "Attack"
			defend_button.text = "Default (+1 BP)"
			skill_button.text = "Brave (Extra Turn)"
		"mage":
			attack_button.text = "Staff Strike"
			defend_button.text = "Defend"
			skill_button.text = "Spells"
		"tank":
			var tank_node: TankParry = player.get_node("TankParry") if player.has_node("TankParry") else null
			if tank_node and tank_node.is_counter_primed:
				attack_button.text = "COUNTER STRIKE!"
			else:
				attack_button.text = "Attack"
			defend_button.text = "Iron Guard"
			skill_button.text = "Parry"


# --- DIALOGUE & BP DISPLAY HELPERS ---

func _on_bp_changed(new_bp: int) -> void:
	update_bp_display(new_bp)


func update_bp_display(bp_value: int) -> void:
	var formatted_bp = str(bp_value)
	if bp_value > 0:
		formatted_bp = "+" + str(bp_value)
	dialogue_label.text = "FIGHTER BP: " + formatted_bp


# --- INPUT HANDLING & STYLING ---

func _unhandled_input(event: InputEvent) -> void:
	# Catch real-time confirm press during Tank Parry mini-game
	if is_parry_minigame_active and event.is_action_pressed("confirm") and not parry_input_pressed:
		get_viewport().set_input_as_handled()
		parry_input_pressed = true
		return

	if not action_menu.visible or is_battle_over:
		return

	# --- MAGE SPELL SUB-MENU INPUTS ---
	if is_in_spell_menu:
		if player.has_node("MageSpells"):
			var mage_node: MageSpells = player.get_node("MageSpells")
			var total_spells = mage_node.get_spell_count()

			if event.is_action_pressed("right") or event.is_action_pressed("down"):
				selected_spell_index = (selected_spell_index + 1) % total_spells
				_on_button_hovered()
				update_spell_menu_display()

			elif event.is_action_pressed("left") or event.is_action_pressed("up"):
				selected_spell_index = (selected_spell_index - 1 + total_spells) % total_spells
				_on_button_hovered()
				update_spell_menu_display()

			elif event.is_action_pressed("confirm"):
				get_viewport().set_input_as_handled()
				cast_selected_spell(mage_node.get_spell(selected_spell_index))

			elif event.is_action_pressed("cancel"):
				get_viewport().set_input_as_handled()
				exit_spell_menu()
		return

	# --- MAIN ACTION MENU INPUTS ---
	if event.is_action_pressed("left"):
		selected_index = (selected_index - 1 + menu_buttons.size()) % menu_buttons.size()
		update_button_styles()
		_on_button_hovered()

	elif event.is_action_pressed("right"):
		selected_index = (selected_index + 1) % menu_buttons.size()
		update_button_styles()
		_on_button_hovered()

	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_play_confirm_sound()
		menu_buttons[selected_index].emit_signal("pressed")


func update_button_styles() -> void:
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = Color.BLACK
		stylebox.set_corner_radius_all(0)
		stylebox.set_border_width_all(2)

		if i == selected_index:
			match Global.selected_character.to_lower():
				"fighter": stylebox.border_color = Color("10b981")
				"mage":    stylebox.border_color = Color("8b5cf6")
				"tank":    stylebox.border_color = Color("0284c7")
				_:         stylebox.border_color = Color.WHITE
		else:
			stylebox.border_color = Color("555555")

		btn.add_theme_stylebox_override("normal", stylebox)
		btn.add_theme_stylebox_override("hover", stylebox)
		btn.add_theme_stylebox_override("focus", stylebox)
		btn.add_theme_stylebox_override("pressed", stylebox)


# --- MAGE SPELL SUB-MENU HELPERS ---

func open_spell_menu() -> void:
	is_in_spell_menu = true
	selected_spell_index = 0
	update_spell_menu_display()

func exit_spell_menu() -> void:
	is_in_spell_menu = false
	dialogue_label.text = "MAGE TURN!"

func update_spell_menu_display() -> void:
	if player.has_node("MageSpells"):
		var mage_node: MageSpells = player.get_node("MageSpells")
		var spell = mage_node.get_spell(selected_spell_index)
		var total = mage_node.get_spell_count()
		
		dialogue_label.text = "SPELL [" + str(selected_spell_index + 1) + "/" + str(total) + "]: " + spell["name"].to_upper() + "\n" + spell["desc"]

func cast_selected_spell(spell: Dictionary) -> void:
	_play_confirm_sound()
	is_in_spell_menu = false
	action_menu.hide()

	var mage_node: MageSpells = player.get_node("MageSpells") if player.has_node("MageSpells") else null

	match spell["type"]:
		"instant_attack":
			var base_damage = int(magic_power * spell["power"])
			
			if spell_detonated_this_turn:
				base_damage = int(base_damage * 1.75)
				dialogue_label.text = "SPELL CHAIN! " + spell["name"].to_upper() + " AMPLIFIED!"
			else:
				dialogue_label.text = "CAST " + spell["name"].to_upper() + "!"

			await player.play_attack()
			
			if boss.has_method("take_damage"):
				boss.take_damage(base_damage)
			elif boss.has_method("play_hurt"):
				boss.play_hurt()
				
			await get_tree().create_timer(0.4).timeout

		"delayed_attack":
			if mage_node:
				var turns = mage_node.queue_delayed_spell(spell, magic_power)
				dialogue_label.text = "CAST " + spell["name"].to_upper() + "! (DETONATES IN " + str(turns) + " TURNS)"
			
			await player.play_attack()
			await get_tree().create_timer(0.5).timeout

		"heal":
			var heal_amount = int(magic_power * spell["power"])
			current_hp = min(current_hp + heal_amount, max_hp)
			update_hp_ui()
			dialogue_label.text = "HEAL BLOOM! RECOVERED " + str(heal_amount) + " HP!"
			await get_tree().create_timer(0.6).timeout

		"barrier":
			is_defending = true
			dialogue_label.text = "ARCANE BARRIER ERECTED! DAMAGE MITIGATED."
			await get_tree().create_timer(0.6).timeout

		"buff":
			if mage_node:
				mage_node.is_overcharged = true
			dialogue_label.text = "SPELL OVERCHARGE! NEXT DELAYED SPELL +50% POWER!"
			await get_tree().create_timer(0.6).timeout

	end_player_turn()


# --- TURN FLOW LOGIC ---

func start_player_turn() -> void:
	if is_battle_over:
		return

	is_defending = false
	spell_detonated_this_turn = false
	
	# Update button text based on active class features (e.g. Tank Counter Strike)
	setup_class_buttons()
	
	# 1. Fighter BP Debt check
	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		if bp_system.is_in_debt():
			bp_system.current_bp += 1
			bp_system.bp_changed.emit(bp_system.current_bp)
			dialogue_label.text = "FIGHTER IS IN DEBT! RECOVERING BP..."
			end_player_turn()
			return
		else:
			update_bp_display(bp_system.current_bp)
			
	# 2. Mage Delayed Spell Processing
	elif Global.selected_character.to_lower() == "mage" and player.has_node("MageSpells"):
		var mage_node: MageSpells = player.get_node("MageSpells")
		var detonated_list = mage_node.process_turn_tick()
		
		if detonated_list.size() > 0:
			spell_detonated_this_turn = true
			for spell in detonated_list:
				dialogue_label.text = spell["name"].to_upper() + " DETONATES!"
				
				if boss.has_method("take_damage"):
					boss.take_damage(spell["damage"])
				elif boss.has_method("play_hurt"):
					boss.play_hurt()
					
				await get_tree().create_timer(0.6).timeout
				
				if is_battle_over:
					return
		
		dialogue_label.text = "MAGE TURN!"
	else:
		dialogue_label.text = Global.selected_character.to_upper() + " TURN!"

	selected_index = 0
	update_button_styles()
	action_menu.show()


func end_player_turn() -> void:
	action_menu.hide()

	if is_battle_over:
		return

	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		bp_system.reset_turn_actions()

	start_boss_turn()


func start_boss_turn() -> void:
	if is_battle_over:
		return

	print("--- BOSS TURN STARTED ---")
	dialogue_label.text = "BOSS IS ATTACKING!"
	
	await get_tree().create_timer(0.6).timeout
	
	# --- FETCH BOSS ATTACK & CRIT DATA ---
	var attack_info = boss.get_attack_damage() if boss.has_method("get_attack_damage") else {"damage": 25, "is_crit": false}
	var raw_boss_damage: int = attack_info["damage"]
	var is_crit: bool = attack_info["is_crit"]
	
	@warning_ignore("integer_division")
	var mitigated_damage: int = max(1, raw_boss_damage - int(defense_power / 2))

	var tank_node: TankParry = player.get_node("TankParry") if player.has_node("TankParry") else null

	# --- ACTIVE TANK PARRY MINI-GAME ---
	if tank_node and tank_node.is_parry_active:
		# 1. Reset values and reveal the bar on screen
		if parry_bar:
			parry_bar.value = parry_bar.min_value
			parry_value = parry_bar.min_value
			parry_dir = 1.0
			parry_bar.show()

		parry_input_pressed = false
		dialogue_label.text = "GET READY..."
		
		# 2. Delay before movement begins
		await get_tree().create_timer(0.5).timeout
		
		# --- RANDOMIZE SPEED EACH PARRY ATTEMPT ---
		parry_speed = randf_range(150.0, 240.0)

		# 3. Start active movement phase
		is_parry_minigame_active = true
		dialogue_label.text = "TIME YOUR PARRY!"

		var timer = 0.0
		var max_parry_time = 1.8
		
		while timer < max_parry_time and not parry_input_pressed:
			await get_tree().process_frame
			timer += get_process_delta_time()

		# 4. Stop movement and hide the bar
		is_parry_minigame_active = false
		if parry_bar:
			parry_bar.hide()

		# 5. Evaluate accuracy
		var center_target = (parry_bar.max_value - parry_bar.min_value) / 2.0 if parry_bar else 50.0
		var result = tank_node.evaluate_timing(parry_value, center_target, 10.0, 25.0)

		match result:
			TankParry.ParryResult.PERFECT:
				_play_confirm_sound()
				mitigated_damage = 0
				dialogue_label.text = "PERFECT PARRY! DAMAGE NEGATED!"
			TankParry.ParryResult.PARTIAL:
				mitigated_damage = max(1, int(mitigated_damage * 0.4))
				dialogue_label.text = "PARTIAL PARRY! " + ("CRIT REDUCED!" if is_crit else "DAMAGE REDUCED!")
			TankParry.ParryResult.MISS:
				mitigated_damage = raw_boss_damage
				dialogue_label.text = "PARRY MISSED! CRITICAL HIT!" if is_crit else "PARRY MISSED!"

		tank_node.reset_parry_stance()
		await get_tree().create_timer(0.8).timeout

	# --- STANDARD GUARD ---
	elif is_defending:
		mitigated_damage = max(1, int(mitigated_damage * 0.5))

	# Boss animation execution
	if boss.has_method("play_and_wait"):
		await boss.play_and_wait("attack")
	else:
		boss.play_attack()
		await get_tree().create_timer(0.4).timeout

	current_hp = max(0, current_hp - mitigated_damage)
	update_hp_ui()

	if player.has_method("take_damage"):
		player.take_damage(mitigated_damage)
	elif player.has_method("play_hurt"):
		player.play_hurt()

	# Display Critical status in dialogue when damage is dealt
	if mitigated_damage > 0:
		if is_crit and not (tank_node and tank_node.is_parry_active):
			dialogue_label.text = "CRITICAL HIT! BOSS DEALT " + str(mitigated_damage) + " DAMAGE!"
		elif dialogue_label.text == "BOSS IS ATTACKING!" or is_defending:
			dialogue_label.text = "BOSS DEALT " + str(mitigated_damage) + " DAMAGE!"

	await get_tree().create_timer(0.8).timeout

	if current_hp <= 0:
		dialogue_label.text = "DEFEATED..."
		is_battle_over = true
		print("Player has been defeated!")
		
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
		return

	print("--- PLAYER TURN STARTED ---")
	start_player_turn()


# --- ACTION BUTTON SIGNALS ---

func _on_attack_button_pressed() -> void:
	_play_confirm_sound()
	action_menu.hide()

	var attacks_to_run = 1

	if Global.selected_character.to_lower() == "fighter" and player.has_node("FighterBP"):
		var bp_system = player.get_node("FighterBP")
		attacks_to_run = bp_system.queued_actions

	var base_hit = attack_power

	# Check for Tank Counter Strike boost
	if Global.selected_character.to_lower() == "tank" and player.has_node("TankParry"):
		var tank_node: TankParry = player.get_node("TankParry")
		var multiplier = tank_node.consume_counter_bonus()

		if multiplier > 1.0:
			base_hit = int(base_hit * multiplier)
			dialogue_label.text = "DEVASTATING COUNTER STRIKE (" + str(base_hit) + " DMG)!"
		else:
			dialogue_label.text = "TANK ATTACKS!"
	else:
		dialogue_label.text = "ATTACKING (" + str(attacks_to_run) + "x)!"

	for i in range(attacks_to_run):
		await player.play_attack()
		
		var combo_multiplier: float = 1.0 + (i * 0.25)
		var hit_damage: int = int(base_hit * combo_multiplier)
		
		if boss.has_method("take_damage"):
			boss.take_damage(hit_damage)
		elif boss.has_method("play_hurt"):
			boss.play_hurt()
			
		await get_tree().create_timer(0.15).timeout
		
		if is_battle_over:
			return

	attack_button.text = "Attack"
	end_player_turn()


func _on_defend_button_pressed() -> void:
	_play_confirm_sound()
	action_menu.hide()
	is_defending = true

	match Global.selected_character.to_lower():
		"fighter":
			if player.has_node("FighterBP"):
				var bp_system = player.get_node("FighterBP")
				bp_system.perform_default()
				dialogue_label.text = "DEFAULT! +1 BP STORED (BP: " + str(bp_system.current_bp) + ")"
		"mage":
			dialogue_label.text = "MAGE GUARDS! INCOMING DAMAGE HALVED."
		"tank":
			dialogue_label.text = "IRON GUARD! TANK FORTIFIES DEFENSES."

	end_player_turn()


func _on_skill_button_pressed() -> void:
	_play_confirm_sound()
	match Global.selected_character.to_lower():
		"fighter":
			if player.has_node("FighterBP"):
				var bp_system = player.get_node("FighterBP")
				if bp_system.try_brave():
					attack_button.text = "Attack (" + str(bp_system.queued_actions) + "x)"
					dialogue_label.text = "BRAVE! Queued Attacks: " + str(bp_system.queued_actions) + " | BP: " + str(bp_system.current_bp)
				else:
					dialogue_label.text = "CANNOT BRAVE! Limit Reached."

		"mage":
			open_spell_menu()

		"tank":
			action_menu.hide()
			if player.has_node("TankParry"):
				var tank_node: TankParry = player.get_node("TankParry")
				tank_node.prime_parry_stance()
			dialogue_label.text = "TANK RAISES SHIELD! READY TO PARRY..."
			await get_tree().create_timer(0.6).timeout
			end_player_turn()


# --- VICTORY HANDLER ---

func _on_boss_defeated() -> void:
	is_battle_over = true
	action_menu.hide()
	if parry_bar:
		parry_bar.hide()
		
	dialogue_label.text = "VICTORY! YOU DEFEATED THE BOSS!"
	print("BATTLE WON!")
	
	# Pause to let the victory text sink in, then change scenes
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")


# --- AUDIO HELPER METHODS ---

func setup_button_hover_sounds(parent_node: Node) -> void:
	for child in parent_node.get_children():
		if child is Button:
			child.mouse_entered.connect(_on_button_hovered)
			child.pressed.connect(_play_confirm_sound)
		
		if child.get_child_count() > 0:
			setup_button_hover_sounds(child)


func _on_button_hovered() -> void:
	if hover_sound:
		hover_sound.play()

func _play_confirm_sound() -> void:
	if confirm_sound:
		confirm_sound.play()
