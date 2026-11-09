shader_type canvas_item;

uniform float wave_time = 0.0;
uniform float wave_amplitude = 0.035;

void fragment() {
	// The right end stays tucked under the neck wrap; the free ends drift.
	float free_end = clamp((0.70 - UV.x) / 0.55, 0.0, 1.0);
	vec2 sample_uv = UV;
	sample_uv.y += sin(wave_time * 1.1 + free_end * 4.5) * wave_amplitude * free_end * free_end;
	vec4 scarf = texture(TEXTURE, sample_uv);
	// Keep a crisp pencil silhouette when sampling the cutout's soft matte.
	scarf.a = smoothstep(0.75, 0.93, scarf.a);
	COLOR = scarf;
}
