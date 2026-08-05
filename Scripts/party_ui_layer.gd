extends CanvasLayer

@export var custom_font: Font = preload("res://Fonts/ari-w9500-bold.ttf")
@export var font_size: int = 8

# Base colors matching character selection
var hero_colors: Dictionary = {
	"fighter": Color("10b98199"), # Emerald Green
	"mage":    Color("8b5cf699"), # Purple / Violet
	"tank":    Color("0284c799")  # Sky Blue
}

@export_group("Palette")
@export var outline_color: Color = Color("ffffff") # Solid White outlines
@export var border_thickness: int = 1

var box_style: StyleBoxFlat
var slot_style: StyleBoxFlat
var btn_style: StyleBoxFlat

func _ready() -> void:
	_init_styles()
	# Set default starting theme to Fighter
	set_active_hero_theme("fighter")

func _init_styles() -> void:
	# 1. Main Outer Window Box Style (With White Outline)
	box_style = StyleBoxFlat.new()
	box_style.border_color = outline_color
	box_style.set_border_width_all(border_thickness)
	box_style.content_margin_left = 3
	box_style.content_margin_right = 3
	box_style.content_margin_top = 2
	box_style.content_margin_bottom = 2

	# 2. Inner Character Slot Style (NO OUTLINE, NO BACKGROUND FILL)
	slot_style = StyleBoxFlat.new()
	slot_style.set_border_width_all(0)
	slot_style.bg_color = Color(0, 0, 0, 0) # Completely transparent background
	slot_style.content_margin_left = 4
	slot_style.content_margin_right = 4
	slot_style.content_margin_top = 1
	slot_style.content_margin_bottom = 1

	# 3. Transparent Button Style
	btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0, 0, 0, 0)
	btn_style.content_margin_left = 8
	btn_style.content_margin_right = 2
	btn_style.content_margin_top = 0
	btn_style.content_margin_bottom = 0

## Call this function when turn changes!
func set_active_hero_theme(hero_key: String) -> void:
	if not hero_colors.has(hero_key): return

	var base_color: Color = hero_colors[hero_key]
	
	# Desaturate slightly (-30% saturation) and darken (-75% brightness)
	var dark_bg = base_color
	dark_bg.s = clamp(dark_bg.s * 0.7, 0.0, 1.0)
	dark_bg = dark_bg.darkened(0.75)
	
	# Main window gets colored background & white border
	box_style.bg_color = dark_bg
	box_style.border_color = outline_color

	# Keep inner character rows completely transparent
	slot_style.bg_color = Color(0, 0, 0, 0)

	# Re-apply updated theme styles to UI elements
	apply_style_recursive(self)

func style_node(node: Node) -> void:
	if node is Label:
		_style_label(node as Label)
	elif node is Button:
		_style_button(node as Button)
	elif node is PanelContainer or node is Panel:
		_style_panel(node)

func apply_style_recursive(parent: Node) -> void:
	for child in parent.get_children():
		style_node(child)
		if child.get_child_count() > 0:
			apply_style_recursive(child)

func _style_label(label: Label) -> void:
	if custom_font:
		label.add_theme_font_override("font", custom_font)
	label.add_theme_font_size_override("font_size", font_size)

func _style_button(button: Button) -> void:
	if custom_font:
		button.add_theme_font_override("font", custom_font)
	
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_stylebox_override("normal", btn_style)
	button.add_theme_stylebox_override("hover", btn_style)
	button.add_theme_stylebox_override("focus", btn_style)
	button.add_theme_stylebox_override("pressed", btn_style)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT

func _style_panel(panel: Node) -> void:
	if not panel.has_method("add_theme_stylebox_override"):
		return
		
	var panel_name = panel.name.to_lower()
	var is_inner_slot = panel.get_parent() is Panel or panel.get_parent() is PanelContainer \
						or "slot" in panel_name or "member" in panel_name or panel.is_in_group("no_outline")
						
	if "actionmenu" in panel_name or "partypanel" in panel_name or "dialogue" in panel_name or "spell" in panel_name:
		is_inner_slot = false

	if is_inner_slot:
		panel.add_theme_stylebox_override("panel", slot_style)
	else:
		panel.add_theme_stylebox_override("panel", box_style)
