shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never;

global uniform vec3 tower_world_pos;

uniform float ring_speed     : hint_range(0.0, 20.0) = 2.0;
uniform float ring_spacing   : hint_range(0.1, 20.0) = 4.0;
uniform float ring_width     : hint_range(0.0, 1.0)  = 0.25;
uniform float ring_sharpness : hint_range(0.0, 0.99) = 0.5;

uniform vec4  ring_color        : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float ring_albedo_blend : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform vec2  texture_scale = vec2(1.0, 1.0);

uniform vec4  albedo        : source_color = vec4(0.35, 0.32, 0.28, 1.0);
uniform float quant_steps   : hint_range(2.0, 32.0) = 4.0;
uniform float fade_distance : hint_range(0.0, 10.0) = 0.0;

// 1.0 = overlay mode (alpha = ring, transparent between rings)
// 0.0 = direct mode  (alpha = fade, full mesh with chain fade)
uniform float overlay : hint_range(0.0, 1.0) = 1.0;

instance uniform vec3 chain_anchor_pos;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist  = length(world_pos.xz - tower_world_pos.xz);
	float cycle = fract((dist - TIME * ring_speed) / ring_spacing);
	float centered = cycle - 0.5;
	float half_w = ring_width * 0.5;
	float soft   = ring_sharpness * half_w;
	float ring   = max(0.0, 1.0 - smoothstep(half_w - soft, half_w + soft, abs(centered)));

	float fade = (fade_distance > 0.001)
		? clamp(length(world_pos - chain_anchor_pos) / fade_distance, 0.0, 1.0)
		: 1.0;

	vec3 tex      = texture(albedo_texture, UV * texture_scale).rgb;
	vec3 ring_vis = mix(ring_color.rgb, ring_color.rgb * tex, ring_albedo_blend);

	vec3 base      = albedo.rgb * tex;
	vec3 quantized = floor(base * quant_steps + 0.5) / quant_steps;
	vec3 off_ring  = quantized * (0.5 + ring * 0.5);
	vec3 on_ring   = mix(base, ring_color.rgb, ring_albedo_blend);
	vec3 direct_albedo = mix(off_ring, on_ring, ring);

	ALBEDO   = mix(direct_albedo, ring_vis, overlay);
	EMISSION = ring_color.rgb * ring;
	ALPHA    = mix(fade, ring * fade, overlay);
}
