shader_type canvas_item;
render_mode unshaded;

uniform sampler2D door_texture : filter_linear, repeat_disable;
uniform sampler2D frame_texture : filter_linear, repeat_disable;
uniform float hover_amount : hint_range(0.0, 1.0) = 0.65;
uniform vec4 glow_color : source_color = vec4(1.0, 0.74, 0.22, 1.0);
uniform vec2 canvas_origin = vec2(1032.0, 418.0);
uniform vec2 canvas_size = vec2(216.0, 308.0);

float door_alpha(vec2 pixel) {
	vec2 uv = pixel / vec2(textureSize(door_texture, 0));
	return max(texture(door_texture, uv).a, texture(frame_texture, uv).a);
}

void fragment() {
	vec2 pixel = canvas_origin + UV * canvas_size;
	float silhouette = door_alpha(pixel);
	float soft_light = 0.0;
	float rim = 0.0;
	for (int i = 0; i < 24; i++) {
		float angle = float(i) * 6.2831853 / 24.0;
		vec2 direction = vec2(cos(angle), sin(angle));
		rim = max(rim, door_alpha(pixel + direction * 2.5));
		soft_light += door_alpha(pixel + direction * 8.0) * 0.40;
		soft_light += door_alpha(pixel + direction * 17.0) * 0.38;
		soft_light += door_alpha(pixel + direction * 30.0) * 0.22;
	}
	soft_light /= 24.0;
	float halo = (rim * 0.42 + soft_light * 2.0) * (1.0 - silhouette);
	vec3 light_color = mix(glow_color.rgb, vec3(1.0, 0.90, 0.58), rim * 0.6);
	COLOR = vec4(light_color, clamp(halo * hover_amount * glow_color.a, 0.0, 0.9));
}
