shader_type spatial;
render_mode blend_mix;

global uniform vec3 tower_world_pos;
uniform float ring_speed : hint_range(0.0, 20.0) = 3.0;
uniform float ring_scale : hint_range(0.1, 10.0) = 1.5;
uniform float ring_sharpness : hint_range(0.0, 0.99) = 0.7;
uniform float quant_steps : hint_range(2.0, 32.0) = 4.0;
uniform vec4 albedo : source_color = vec4(0.35, 0.32, 0.28, 1.0);
uniform vec4 ring_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;
uniform vec2 texture_scale = vec2(1.0, 1.0);
uniform float fade_distance : hint_range(0.0, 10.0) = 2.5;

instance uniform vec3 chain_anchor_pos;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(world_pos.xz - tower_world_pos.xz);
	float wave = sin(dist * ring_scale - TIME * ring_speed) * 0.5 + 0.5;
	float ring = smoothstep(ring_sharpness, 1.0, wave);

	vec3 tex = texture(albedo_texture, UV * texture_scale).rgb;
	vec3 base = albedo.rgb * tex;
	vec3 quantized = floor(base * quant_steps + 0.5) / quant_steps;
	vec3 off_ring = quantized * (0.5 + wave * 0.5);
	vec3 on_ring = base;

	ALBEDO   = mix(off_ring, on_ring, ring);
	EMISSION = ring_color.rgb * ring;
	ROUGHNESS = 0.95;
	METALLIC  = 0.0;
	ALPHA     = clamp(length(world_pos - chain_anchor_pos) / fade_distance, 0.0, 1.0);
}
