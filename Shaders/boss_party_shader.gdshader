shader_type canvas_item;

// Exposed parameters in the Inspector
uniform vec4 aura_color : source_color = vec4(0.8, 0.1, 0.2, 1.0); // Red glow
uniform float pulse_speed : hint_range(0.5, 10.0) = 3.0;
uniform float aura_intensity : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	// For CanvasItem / CanvasGroup, COLOR contains the merged result of child sprites
	vec4 tex_color = COLOR;
	
	// Create a smooth pulse effect over time
	float pulse = (sin(TIME * pulse_speed) + 1.0) * 0.5;
	
	// Blend aura color into the sprite's RGB channels
	vec3 glowing_rgb = mix(tex_color.rgb, aura_color.rgb, pulse * aura_intensity * tex_color.a);
	
	// Apply glowing RGB while strictly preserving alpha transparency
	COLOR = vec4(glowing_rgb, tex_color.a);
}