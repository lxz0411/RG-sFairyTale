shader_type canvas_item;
render_mode unshaded;

uniform float progress : hint_range(0.0, 1.05) = 0.0;

void fragment() {
	// Pixel distance keeps the circle round on every viewport aspect ratio.
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float distance_from_center = length((SCREEN_UV - vec2(0.5)) * screen_size);
	float radius = 2.0 + length(screen_size) * 0.5 * progress;
	float mask = 1.0 - smoothstep(radius - 1.0, radius + 1.0, distance_from_center);
	COLOR = vec4(0.0, 0.0, 0.0, mask);
}
