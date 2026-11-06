shader_type canvas_item;
render_mode unshaded;

uniform float hover_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.72, 0.18, 0.9);

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	float near_alpha = 0.0;
	float far_alpha = 0.0;
	for (int i = 0; i < 24; i++) {
		float angle = float(i) * 6.2831853 / 24.0;
		vec2 direction = vec2(cos(angle), sin(angle)) * TEXTURE_PIXEL_SIZE;
		near_alpha = max(near_alpha, smoothstep(0.15, 0.65, texture(TEXTURE, UV + direction * 5.0).a));
		far_alpha = max(far_alpha, smoothstep(0.15, 0.65, texture(TEXTURE, UV + direction * 12.0).a));
	}
	float halo = (near_alpha * 0.8 + far_alpha * 0.3) * hover_amount * glow_color.a * (1.0 - base.a);
	float alpha = base.a + halo;
	vec3 rgb = (base.rgb * base.a + glow_color.rgb * halo) / max(alpha, 0.0001);
	COLOR = vec4(rgb, alpha);
}
