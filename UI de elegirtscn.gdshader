shader_type canvas_item;

uniform float blur_amount : hint_range(0.0, 10.0) = 0.0;
uniform float fog_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.9, 0.9, 0.8, 1.0);

void fragment() {
    vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
    vec4 color = vec4(0.0);
    int samples = 8;

    for (int x = -samples; x <= samples; x++) {
        for (int y = -samples; y <= samples; y++) {
            vec2 offset = vec2(float(x), float(y)) * blur_amount;
            color += texture(SCREEN_TEXTURE, SCREEN_UV + offset / size);
        }
    }
    color /= pow(float(samples * 2 + 1), 2.0);
    
    // Añadir niebla suave encima
    color = mix(color, fog_color, fog_intensity);
    
    COLOR = color;
}
