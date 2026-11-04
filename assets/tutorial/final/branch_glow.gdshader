shader_type canvas_item;
render_mode unshaded;

uniform float glow_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.92, 0.72, 0.55);
const float PADDING = 8.0;
varying vec4 sprite_color;

void vertex() {
	sprite_color = COLOR;
	VERTEX += sign(VERTEX) * PADDING;
}

void fragment() {
	vec2 uv = (UV - 0.5) * (vec2(1.0) + 2.0 * PADDING * TEXTURE_PIXEL_SIZE) + 0.5;
	vec4 art = vec4(0.0);
	if (all(greaterThanEqual(uv, vec2(0.0))) && all(lessThanEqual(uv, vec2(1.0)))) {
		art = texture(TEXTURE, uv);
	}
	float halo = 0.0;
	for (int ring = 1; ring <= 3; ring++) {
		float radius = float(ring) * 2.0;
		float weight = exp(-radius * radius / 22.0);
		for (int direction = 0; direction < 16; direction++) {
			float angle = float(direction) * 6.283185 / 16.0;
			vec2 sample_uv = uv + vec2(cos(angle), sin(angle)) * radius * TEXTURE_PIXEL_SIZE;
			if (all(greaterThanEqual(sample_uv, vec2(0.0))) && all(lessThanEqual(sample_uv, vec2(1.0)))) {
				halo = max(halo, texture(TEXTURE, sample_uv).a * weight);
			}
		}
	}
	float glow_alpha = halo * glow_strength * glow_color.a * (1.0 - art.a);
	float opacity = art.a + glow_alpha;
	vec3 rgb = (art.rgb * art.a + glow_color.rgb * glow_alpha) / max(opacity, 0.0001);
	COLOR = sprite_color * vec4(rgb, opacity);
}
