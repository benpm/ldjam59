shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float levels : hint_range(2.0, 32.0) = 6.0;

void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	color = floor(color * levels + 0.5) / levels;
	COLOR = vec4(color, 1.0);
}
