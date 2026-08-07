extends Node

# --- SCRIPT PRELOADS ---
const FighterBPScript = preload("res://Scripts/fighter_bp.gd")
const MageSpellsScript = preload("res://Scripts/mage_spells.gd")

# --- ENUMS & BATTLE STATES ---
enum BattleState { PLAYER_TURN, SPELL_MENU, TARGET_SELECT, EXECUTING_TURNS, BOSS_TURN, VICTORY, DEFEAT }
var current_state: BattleState = BattleState.PLAYER_TURN

# Turn & Navigation
var current_party_index: int = 0
var selected_action_index: int = 0 # 0: Attack, 1: Defend/Default, 2: Skill/Brave/Spells
var menu_options_count: int = 3
var is_battle_over: bool = false

# Sub-Menu & Target Selection Navigation
var selected_spell_index: int = 0
var selected_target_index: int = 0
var pending_spell: Dictionary = {}

# --- COMMAND QUEUE & TANK TAUNT ---
var selected_actions: Array = []
var is_tank_taunting: bool = false
@export var taunt_success_chance: float = 0.65

# --- ONREADY UI & SCENE NODES ---
@onready var action_menu: Control = $"../UILayer/ActionMenu"
@onready var action_cursor: Label = $"../UILayer/ActionMenu/CursorLabel"
@onready var attack_button: Button = $"../UILayer/ActionMenu/VBoxContainer/AttackButton"
@onready var defend_button: Button = $"../UILayer/ActionMenu/VBoxContainer/DefendButton"
@onready var skill_button: Button = $"../UILayer/ActionMenu/VBoxContainer/SkillButton"

@onready var spell_menu: Control = $"../UILayer/SpellSubMenu"
@onready var spell_vbox: VBoxContainer = $"../UILayer/SpellSubMenu/VBoxContainer" if has_node("../UILayer/SpellSubMenu/VBoxContainer") else null
@onready var dialogue_label: Label = $"../UILayer/BattleDialogue/Label"

# BOSS & BOSS HP LABEL REFERENCE
@onready var boss: Node2D = $"../ArenaWorld/Boss"
@onready var boss_hp_label: Label = $"../ArenaWorld/Boss/BossHPLabel" if has_node("../ArenaWorld/Boss/BossHPLabel") else null

@onready var hover_sound: AudioStreamPlayer = $"../AudioLayer/UI/HoverSound" if has_node("../AudioLayer/UI/HoverSound") else null
@onready var confirm_sound: AudioStreamPlayer = $"../AudioLayer/UI/ConfirmSound" if has_node("../AudioLayer/UI/ConfirmSound") else null

# --- PARTY MEMBERS DATA ---
@onready var party_members: Array = [
	{
		"key": "fighter",
		"name": "Fighter",
		"sprite": $"../ArenaWorld/FighterSprite",
		"slot": $"../UILayer/PartyStatusPanel/VBoxContainer/FighterSlot/HBoxContainer",
		"hp": 115, "max_hp": 115,
		"is_alive": true, "defending": false,
		"attack_power": 20, "defense": 12, "speed": 14
	},
	{
		"key": "mage",
		"name": "Mage",
		"sprite": $"../ArenaWorld/MageSprite",
		"slot": $"../UILayer/PartyStatusPanel/VBoxContainer/MageSlot/HBoxContainer",
		"hp": 90, "max_hp": 90, "mp": 100, "max_mp": 100, "is_alive": true, "defending": false,
		"attack_power": 6, "magic_power": 22, "defense": 8, "speed": 10
	},
	{
		"key": "tank",
		"name": "Tank",
		"sprite": $"../ArenaWorld/TankSprite",
		"slot": $"../UILayer/PartyStatusPanel/VBoxContainer/TankSlot/HBoxContainer",
		"hp": 140, "max_hp": 140, "is_alive": true, "defending": false,
		"attack_power": 8, "defense": 16, "speed": 6
	}
]

const MENU_OPTION_HEIGHT: int = 16
var member_home_positions: Dictionary = {}


func _ready() -> void:
	randomize()

	if MusicManager and MusicManager.has_method("stop_music"):
		MusicManager.stop_music()

	for member in party_members:
		var sprite = member["sprite"]
		if sprite:
			member_home_positions[member["key"]] = sprite.position
			_play_hero_anim(member, "idle")

	if spell_menu: spell_menu.hide()

	if boss and boss.has_signal("boss_defeated"):
		boss.boss_defeated.connect(_on_boss_defeated)

	update_party_ui()
	update_boss_hp_ui()
	update_cursor_ui()
	start_player_turn()


func update_boss_hp_ui() -> void:
	if not boss: return
	if not boss_hp_label and boss.has_node("BossHPLabel"):
		boss_hp_label = boss.get_node("BossHPLabel") as Label

	if boss_hp_label:
		var current_hp = boss.get("current_hp") if "current_hp" in boss else (boss.get("hp") if "hp" in boss else 0)
		var max_hp = boss.get("max_hp") if "max_hp" in boss else 1000
		boss_hp_label.text = "BOSS HP: " + str(current_hp) + "/" + str(max_hp)


func damage_boss(amount: int) -> void:
	if boss and boss.has_method("take_damage"):
		boss.take_damage(amount)
		update_boss_hp_ui()


func _get_hero_component(hero_dict: Dictionary, node_name: String) -> Node:
	if hero_dict.is_empty(): return null
	var sprite = hero_dict.get("sprite")
	if sprite and sprite.has_node(node_name): return sprite.get_node(node_name)
	if has_node("../ArenaWorld/" + node_name): return get_node("../ArenaWorld/" + node_name)
	if sprite:
		var found = sprite.find_child(node_name, true, false)
		if found: return found
	return null


func _unhandled_input(event: InputEvent) -> void:
	if is_battle_over: return

	if current_state == BattleState.TARGET_SELECT:
		_handle_target_select_input(event)
		return

	if current_state == BattleState.SPELL_MENU:
		_handle_spell_menu_input(event)
		return

	if current_state != BattleState.PLAYER_TURN or not action_menu.visible:
		return

	if event.is_action_pressed("up") or event.is_action_pressed("left"):
		get_viewport().set_input_as_handled()
		selected_action_index = posmod(selected_action_index - 1, menu_options_count)
		_play_sfx(hover_sound)
		update_cursor_ui()

	elif event.is_action_pressed("down") or event.is_action_pressed("right"):
		get_viewport().set_input_as_handled()
		selected_action_index = posmod(selected_action_index + 1, menu_options_count)
		_play_sfx(hover_sound)
		update_cursor_ui()

	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_play_sfx(confirm_sound)
		handle_action_selection()

	elif event.is_action_pressed("cancel"):
		if current_party_index > 0:
			get_viewport().set_input_as_handled()
			current_party_index -= 1
			selected_actions.pop_back() # Remove previous choice from queue
			set_dialogue_text("Re-choosing action for " + party_members[current_party_index]["name"])
			update_cursor_ui()


# --- FIGHTER MENU SETUP ---
func _setup_fighter_menu() -> void:
	var fighter_bp = _get_hero_component(party_members[0], "FighterBP")
	var actions_count = fighter_bp.queued_actions if fighter_bp else 1
	if attack_button: attack_button.text = "Attack (" + str(actions_count) + "x)"
	if defend_button: defend_button.text = "Default (+1)"
	if skill_button: skill_button.text = "Brave (-1)"


# --- MAGE SPELL MENU SETUP ---
func open_spell_menu() -> void:
	current_state = BattleState.SPELL_MENU
	selected_spell_index = 0
	action_menu.hide()

	_populate_spell_menu_ui()
	_update_spell_selection_display()

	if spell_menu:
		spell_menu.show()
		spell_menu.position.y = action_menu.position.y - spell_menu.size.y + 12


func _populate_spell_menu_ui() -> void:
	var mage_node = _get_hero_component(party_members[1], "MageSpells")
	if not mage_node or not spell_vbox: return

	for child in spell_vbox.get_children():
		child.free()

	var pixel_font = load("res://Fonts/ari-w9500-bold.ttf")

	for i in range(mage_node.get_spell_count()):
		var spell = mage_node.get_spell(i)
		var btn = Button.new()
		btn.text = spell["name"] + " (" + str(spell["cost"]) + " MP)"
		if pixel_font: btn.add_theme_font_override("font", pixel_font)
		btn.add_theme_font_size_override("font_size", 8)
		
		var empty_style = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		spell_vbox.add_child(btn)


func _update_spell_selection_display() -> void:
	var mage_node = _get_hero_component(party_members[1], "MageSpells")
	if not mage_node: return

	selected_spell_index = clampi(selected_spell_index, 0, mage_node.get_spell_count() - 1)
	var spell = mage_node.get_spell(selected_spell_index)
	set_dialogue_text("[" + spell["name"] + "]: " + spell["desc"])

	if spell_vbox:
		var spell_count = mage_node.get_spell_count()
		for i in range(spell_vbox.get_child_count()):
			var btn = spell_vbox.get_child(i) as Button
			if btn and i < spell_count:
				var s = mage_node.get_spell(i)
				btn.text = ("> " if i == selected_spell_index else "    ") + s["name"] + " (" + str(s["cost"]) + " MP)"


func _handle_spell_menu_input(event: InputEvent) -> void:
	var mage_node = _get_hero_component(party_members[1], "MageSpells")
	if not mage_node: return

	if event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		selected_spell_index = posmod(selected_spell_index - 1, mage_node.get_spell_count())
		_play_sfx(hover_sound)
		_update_spell_selection_display()

	elif event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		selected_spell_index = posmod(selected_spell_index + 1, mage_node.get_spell_count())
		_play_sfx(hover_sound)
		_update_spell_selection_display()

	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		var spell = mage_node.get_spell(selected_spell_index)
		var mage = party_members[1]

		if mage["mp"] < spell["cost"]:
			set_dialogue_text("NOT ENOUGH MP!")
			return

		_play_sfx(confirm_sound)

		if spell["type"] == "heal":
			pending_spell = spell
			if spell_menu: spell_menu.hide()
			open_target_selection()
		else:
			if spell_menu: spell_menu.hide()
			commit_hero_action({
				"hero": mage,
				"type": "spell",
				"spell": spell
			})

	elif event.is_action_pressed("cancel"):
		if spell_menu: spell_menu.hide()
		current_state = BattleState.PLAYER_TURN
		action_menu.show()
		update_cursor_ui()


# --- TARGET SELECTION (HEAL BLOOM) ---
func open_target_selection() -> void:
	current_state = BattleState.TARGET_SELECT
	selected_target_index = 0
	while selected_target_index < party_members.size() and not party_members[selected_target_index]["is_alive"]:
		selected_target_index += 1
	update_target_cursor_ui()


func _handle_target_select_input(event: InputEvent) -> void:
	if event.is_action_pressed("up"):
		get_viewport().set_input_as_handled()
		_cycle_target_selection(-1)
		_play_sfx(hover_sound)
	elif event.is_action_pressed("down"):
		get_viewport().set_input_as_handled()
		_cycle_target_selection(1)
		_play_sfx(hover_sound)
	elif event.is_action_pressed("confirm"):
		get_viewport().set_input_as_handled()
		_play_sfx(confirm_sound)
		var target = party_members[selected_target_index]
		var mage = party_members[1]
		var spell = pending_spell
		pending_spell = {}
		
		commit_hero_action({
			"hero": mage,
			"type": "heal",
			"spell": spell,
			"target": target
		})
	elif event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		pending_spell = {}
		open_spell_menu()


func _cycle_target_selection(direction: int) -> void:
	var new_index = selected_target_index
	for i in range(party_members.size()):
		new_index = posmod(new_index + direction, party_members.size())
		if party_members[new_index]["is_alive"]:
			selected_target_index = new_index
			break
	update_target_cursor_ui()


func update_target_cursor_ui() -> void:
	var target = party_members[selected_target_index]
	set_dialogue_text("Select ally to heal: " + target["name"] + " (HP: " + str(target["hp"]) + "/" + str(target["max_hp"]) + ")")
	for i in range(party_members.size()):
		var slot = party_members[i]["slot"]
		if slot:
			var cursor_lbl = slot.get_node_or_null("CursorLabel")
			if cursor_lbl: cursor_lbl.text = "▶" if i == selected_target_index else " "


# --- HANDLING ACTION SUBMISSION FOR CURRENT HERO ---
func handle_action_selection() -> void:
	var hero = party_members[current_party_index]
	
	if hero["key"] == "fighter":
		var fighter_bp = _get_hero_component(hero, "FighterBP")
		match selected_action_index:
			0: # ATTACK
				commit_hero_action({"hero": hero, "type": "fighter_attack"})
			1: # DEFAULT (+1 BP)
				commit_hero_action({"hero": hero, "type": "fighter_default"})
			2: # BRAVE (-1 BP)
				if fighter_bp:
					if fighter_bp.try_brave():
						set_dialogue_text("BRAVE!\nQueued attacks: " + str(fighter_bp.queued_actions))
						update_party_ui()
						_setup_fighter_menu()
					else:
						set_dialogue_text("CANNOT BRAVE! Limit Reached.")
		return

	match selected_action_index:
		0: # ATTACK
			commit_hero_action({"hero": hero, "type": "attack"})
		1: # DEFEND
			commit_hero_action({"hero": hero, "type": "defend"})
		2: # SKILL
			if hero["key"] == "mage":
				open_spell_menu()
			elif hero["key"] == "tank":
				var roll = randf()
				commit_hero_action({"hero": hero, "type": "tank_taunt", "success": roll <= taunt_success_chance})


func commit_hero_action(action_data: Dictionary) -> void:
	action_menu.hide()
	selected_actions.append(action_data)
	current_party_index += 1
	start_player_turn()


# --- TURN FLOW & BATCH EXECUTION ---
func start_player_turn() -> void:
	if is_battle_over: return

	# Skip dead party members
	while current_party_index < party_members.size() and not party_members[current_party_index]["is_alive"]:
		current_party_index += 1

	# If all living members have locked in their choices, begin execution phase
	if current_party_index >= party_members.size():
		execute_batched_turns()
		return

	var hero = party_members[current_party_index]

	# Handle Fighter negative BP freeze check
	if hero["key"] == "fighter":
		var fighter_bp = _get_hero_component(hero, "FighterBP")
		if fighter_bp and fighter_bp.current_bp < 0:
			action_menu.hide()
			fighter_bp.current_bp += 1
			set_dialogue_text("Fighter is frozen in Negative BP (" + str(fighter_bp.current_bp) + ")!\nSkipping action...")
			update_party_ui()
			await get_tree().create_timer(1.2).timeout
			
			commit_hero_action({"hero": hero, "type": "skip"})
			return

	# Mage natural mana regeneration (+10 MP) at start of round input
	if hero["key"] == "mage":
		if hero["mp"] < hero["max_mp"]:
			var prev_mp = hero["mp"]
			hero["mp"] = min(hero["max_mp"], hero["mp"] + 10)
			update_party_ui()
			set_dialogue_text("Mage naturally regenerated +" + str(hero["mp"] - prev_mp) + " MP!")
			await get_tree().create_timer(0.8).timeout

	selected_action_index = 0
	current_state = BattleState.PLAYER_TURN
	action_menu.show()

	var ui_styler = $"../UILayer"
	if ui_styler and ui_styler.has_method("set_active_hero_theme"):
		ui_styler.set_active_hero_theme(hero["key"])

	if hero["key"] == "fighter":
		_setup_fighter_menu()
	elif hero["key"] == "mage":
		if attack_button: attack_button.text = "Staff Strike"
		if defend_button: defend_button.text = "Meditate"
		if skill_button: skill_button.text = "Spells"
	elif hero["key"] == "tank":
		if attack_button: attack_button.text = "Shield Bash"
		if defend_button: defend_button.text = "Iron Guard"
		if skill_button: skill_button.text = "Taunt"

	set_dialogue_text("Select action for " + hero["name"] + "...")
	await get_tree().process_frame
	update_cursor_ui()


func execute_batched_turns() -> void:
	current_state = BattleState.EXECUTING_TURNS
	action_menu.hide()

	var detonated_this_turn: Array = []

	for action in selected_actions:
		if is_battle_over: break
		var hero = action["hero"]
		if not hero["is_alive"]: continue
		hero["defending"] = false

		# TICK DELAYED SPELLS ON THE MAGE'S TURN BEFORE THE MAGE EXECUTES THEIR ACTION
		if hero["key"] == "mage":
			var mage_node = _get_hero_component(hero, "MageSpells")
			if mage_node and mage_node.has_method("process_turn_tick"):
				detonated_this_turn = mage_node.process_turn_tick()
				for spell in detonated_this_turn:
					if spell.get("is_overcharged", false):
						set_dialogue_text("OVERCHARGED DETONATION!\n" + str(spell["name"]) + " explodes for " + str(spell["damage"]) + " damage!")
					else:
						set_dialogue_text("DETONATION!\n" + str(spell["name"]) + " explodes for " + str(spell["damage"]) + " damage!")
					damage_boss(spell["damage"])
					await get_tree().create_timer(1.4).timeout

		match action["type"]:
			"skip":
				pass
			"attack":
				set_dialogue_text(hero["name"] + " attacks!")
				await animate_lunge(hero, "attack")
				damage_boss(hero["attack_power"])
				await get_tree().create_timer(0.8).timeout
			"defend":
				hero["defending"] = true
				if hero["key"] == "mage":
					hero["mp"] = min(hero["mp"] + 15, hero["max_mp"])
				update_party_ui()
				set_dialogue_text(hero["name"] + " guards!")
				await get_tree().create_timer(0.8).timeout
			"fighter_default":
				var fighter_bp = _get_hero_component(hero, "FighterBP")
				if fighter_bp: fighter_bp.perform_default()
				hero["defending"] = true
				update_party_ui()
				set_dialogue_text("Fighter defaults and gains 1 BP!")
				await get_tree().create_timer(1.0).timeout
			"fighter_attack":
				var fighter_bp = _get_hero_component(hero, "FighterBP")
				var total_hits = fighter_bp.queued_actions if fighter_bp else 1
				set_dialogue_text("Fighter attacks " + str(total_hits) + " time(s)!")
				for i in range(total_hits):
					var mult = 1.5 if (fighter_bp and fighter_bp.current_stance == FighterBPScript.Stance.BERSERK) else 1.0
					damage_boss(int(hero["attack_power"] * mult))
					await animate_lunge(hero, "attack")
					await get_tree().create_timer(0.4).timeout
				if fighter_bp: fighter_bp.queued_actions = 1
				await get_tree().create_timer(0.8).timeout
			"tank_taunt":
				if action["success"]:
					is_tank_taunting = true
					hero["defending"] = true
					set_dialogue_text("TAUNT SUCCESSFUL!\nBoss aggro locked on Tank!")
				else:
					is_tank_taunting = false
					set_dialogue_text("TAUNT FAILED!\nThe Boss ignores the Tank!")
				update_party_ui()
				await get_tree().create_timer(1.4).timeout
			"heal":
				var spell = action["spell"]
				var target = action["target"]
				hero["mp"] -= spell["cost"]
				set_dialogue_text("Mage casts " + spell["name"] + " on " + target["name"] + "!")
				await animate_lunge(hero, "cast")
				var heal_amount = int(hero["magic_power"] * 1.5 * spell.get("power", 1.0))
				target["hp"] = min(target["max_hp"], target["hp"] + heal_amount)
				set_dialogue_text(target["name"] + " restored " + str(heal_amount) + " HP!")
				update_party_ui()
				await get_tree().create_timer(1.2).timeout
			"spell":
				var spell = action["spell"]
				hero["mp"] -= spell["cost"]
				set_dialogue_text("Mage casts " + spell["name"] + "!")
				await animate_levitate_slam(hero)

				var mage_node = _get_hero_component(party_members[1], "MageSpells")
				if spell["name"] == "Overcharge":
					if mage_node: mage_node.is_overcharged = true
					set_dialogue_text("Mage casts Overcharge!\nNext delayed spell boosted!")
					await get_tree().create_timer(1.2).timeout
				elif spell["type"] == "delayed_attack" and mage_node:
					var was_overcharged = mage_node.queue_delayed_spell(spell, hero["magic_power"])
					if was_overcharged:
						set_dialogue_text("[OVERCHARGED] " + spell["name"] + " queued!\n(+50% Power)")
					else:
						set_dialogue_text(spell["name"] + " queued for detonation!")
					await get_tree().create_timer(1.4).timeout
				elif spell["type"] == "instant_attack":
					var base_power: float = float(spell.get("power", 1.0))
					var final_dmg: int = int(float(hero["magic_power"]) * base_power)

					if spell["name"] == "Spark":
						var chained_name: String = ""

						# Priority 1: Check if a spell detonated on this turn
						if not detonated_this_turn.is_empty():
							chained_name = str(detonated_this_turn[0].get("name", "Detonated Spell"))
						# Priority 2: Check if a delayed spell is actively brewing in queue
						elif mage_node and not mage_node.active_delayed_spells.is_empty():
							chained_name = str(mage_node.active_delayed_spells[0].get("name", "Delayed Spell"))
						# Priority 3: Check if a delayed spell was queued in selected_actions this round
						else:
							for act in selected_actions:
								if act.get("type") == "spell" and act.get("spell", {}).get("type") == "delayed_attack":
									chained_name = str(act["spell"].get("name", "Delayed Spell"))
									break

						if chained_name != "":
							final_dmg = int(float(hero["magic_power"]) * base_power * 1.75)
							set_dialogue_text("SPARK POWERED UP!\nChained with " + chained_name + " for 1.75x damage!")
							await get_tree().create_timer(1.4).timeout

					damage_boss(final_dmg)
				update_party_ui()
				await get_tree().create_timer(0.8).timeout

	selected_actions.clear()
	execute_boss_turn()


func execute_boss_turn() -> void:
	current_state = BattleState.BOSS_TURN
	action_menu.hide()
	set_dialogue_text("Boss is preparing to strike...")
	await get_tree().create_timer(1.2).timeout

	var living_party: Array = []
	for member in party_members:
		if member["is_alive"]: living_party.append(member)

	if living_party.is_empty():
		game_over(false)
		return

	var target = null
	var tank_member = party_members[2]
	if is_tank_taunting and tank_member["is_alive"]:
		target = tank_member
		set_dialogue_text("Boss focuses entirely on Tank!")
		await get_tree().create_timer(1.0).timeout
	else:
		if boss and boss.has_method("perform_turn"):
			var turn_data = await boss.perform_turn(living_party)
			var chosen_target = turn_data.get("target", living_party.pick_random())
			var target_key = chosen_target.get("key", "") if typeof(chosen_target) == TYPE_DICTIONARY else ""
			for member in party_members:
				if member["key"] == target_key:
					target = member
					break
		if not target and not living_party.is_empty():
			target = living_party.pick_random()

	var raw_damage = 20
	if target:
		apply_damage_to_hero(target, raw_damage)

	is_tank_taunting = false
	update_party_ui()
	await get_tree().create_timer(1.2).timeout

	current_party_index = 0
	start_player_turn()


func apply_damage_to_hero(hero: Dictionary, damage_amount: int) -> void:
	var final_damage = max(1, damage_amount - int(hero["defense"] / 2))
	if hero["defending"]: final_damage = int(final_damage * 0.5)

	hero["hp"] = max(0, hero["hp"] - final_damage)
	set_dialogue_text(hero["name"] + " took " + str(final_damage) + " damage!")

	if hero["hp"] <= 0:
		hero["is_alive"] = false
		set_dialogue_text(hero["name"] + " was downed!")


func update_cursor_ui() -> void:
	if action_cursor and action_menu.has_node("VBoxContainer"):
		var vbox = action_menu.get_node("VBoxContainer")
		if vbox and vbox.get_child_count() > selected_action_index:
			var target_btn = vbox.get_child(selected_action_index) as Control
			if target_btn:
				action_cursor.position.y = vbox.position.y + target_btn.position.y - 3

	for i in range(party_members.size()):
		var slot = party_members[i]["slot"]
		if slot:
			var cursor_lbl = slot.get_node_or_null("CursorLabel")
			if cursor_lbl:
				cursor_lbl.text = "▶" if i == current_party_index else " "


func update_party_ui() -> void:
	var stances_map = ["BERSERK", "BALANCED", "GUARD"]
	for member in party_members:
		var slot = member["slot"]
		if not slot: continue

		var hp_label = slot.get_node_or_null("HPLabel")
		if not hp_label: hp_label = slot.get_node_or_null("HealthLabel")
		if hp_label:
			hp_label.text = "HP: " + str(member["hp"]) + "/" + str(member["max_hp"])

		var mp_label = slot.get_node_or_null("MPLabel")
		if mp_label:
			if member.has("mp"):
				mp_label.text = "MP: " + str(member.get("mp", 0)) + "/" + str(member.get("max_mp", 100))
			else:
				mp_label.text = ""

		var status_lbl = slot.get_node_or_null("StatusLabel")
		if member["key"] == "fighter":
			var bp_node = _get_hero_component(member, "FighterBP")
			var bp_lbl = slot.get_node_or_null("BPLabel")
			if bp_lbl and bp_node: bp_lbl.text = "BP: " + str(bp_node.current_bp)
			if status_lbl and bp_node:
				var idx = clampi(bp_node.current_stance, 0, stances_map.size() - 1)
				status_lbl.text = stances_map[idx]
		elif member["key"] == "mage":
			if status_lbl: status_lbl.text = ""
		elif member["key"] == "tank":
			if status_lbl: status_lbl.text = "ACTIVE" if is_tank_taunting else "INACTIVE"


func animate_lunge(hero: Dictionary, anim_type: String) -> void:
	var sprite = hero["sprite"]
	if not sprite or not member_home_positions.has(hero["key"]): return
	var original_pos: Vector2 = member_home_positions[hero["key"]]
	var lunge_pos: Vector2 = original_pos + Vector2(40, 0)

	var lunge_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lunge_tween.tween_property(sprite, "position", lunge_pos, 0.15)
	_play_hero_anim(hero, anim_type)
	await lunge_tween.finished

	var return_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return_tween.tween_property(sprite, "position", original_pos, 0.12)
	await return_tween.finished
	_play_hero_anim(hero, "idle")


func animate_levitate_slam(hero: Dictionary) -> void:
	var sprite = hero.get("sprite")
	if not sprite or not member_home_positions.has(hero["key"]): return
	var original_pos: Vector2 = member_home_positions[hero["key"]]
	var apex_pos: Vector2 = original_pos + Vector2(0, -32)

	_play_hero_anim(hero, "cast")
	var float_up = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	float_up.tween_property(sprite, "position", apex_pos, 0.35)
	await float_up.finished

	var slam_down = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	slam_down.tween_property(sprite, "position", original_pos, 0.12)
	await slam_down.finished

	if sprite.has_signal("animation_finished"): await sprite.animation_finished
	_play_hero_anim(hero, "idle")


func _play_hero_anim(hero: Dictionary, anim_type: String) -> void:
	var sprite = hero.get("sprite")
	if not sprite or not sprite.has_method("play"): return
	var key = hero.get("key", "").to_lower()
	var full_anim_name = ("mage_cast" if (key == "mage" and anim_type == "cast") else key + "_" + anim_type)
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(full_anim_name):
		sprite.play(full_anim_name)
	else:
		push_warning("Animation key not found on sprite: " + full_anim_name)


func set_dialogue_text(text: String) -> void:
	if dialogue_label: dialogue_label.text = text


func _play_sfx(sound_node: AudioStreamPlayer) -> void:
	if sound_node: sound_node.play()


func _on_boss_defeated() -> void:
	game_over(true)


func game_over(victory: bool) -> void:
	is_battle_over = true
	current_state = BattleState.VICTORY if victory else BattleState.DEFEAT
	action_menu.hide()
	set_dialogue_text("VICTORY!" if victory else "PARTY DEFEATED...")
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://Scenes/main_menu.tscn")
