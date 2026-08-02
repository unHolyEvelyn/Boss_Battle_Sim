shader_type canvas_item;

// Exposed parameters to tweak in the Godot Inspector
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.035;
uniform float wave_frequency : hint_range(0.0, 50.0) = 20.0;
uniform float wave_speed : hint_range(0.0, 10.0) = 3.5;
uniform vec2 scroll_speed = vec2(0.02, -0.03);

void fragment() {
    // 1. Diagonal scrolling
    vec2 uv = UV + (scroll_speed * TIME);
    
    // 2. Multi-axis liquid distortion (X affects Y, Y affects X)
    uv.x += sin(uv.y * wave_frequency + (TIME * wave_speed)) * wave_amplitude;
    uv.y += cos(uv.x * wave_frequency + (TIME * wave_speed * 0.8)) * wave_amplitude;
    
    // 3. Sample texture with warped coordinates
    COLOR = texture(TEXTURE, uv);
}