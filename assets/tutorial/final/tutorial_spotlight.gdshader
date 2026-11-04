shader_type canvas_item;
render_mode unshaded;

uniform vec2 overlay_size = vec2(1280.0, 800.0);
uniform vec4 holes[6];
uniform int hole_count = 0;
uniform vec4 shade_color : source_color = vec4(0.2, 0.2, 0.2, 0.65);

void fragment() {
	vec2 point = UV * overlay_size;
	float mask = 1.0;
	for (int i = 0; i < 6; i++) {
		if (i < hole_count) {
			vec2 half_size = holes[i].zw * 0.5;
			vec2 q = abs(point - holes[i].xy - half_size) - (half_size - vec2(8.0));
			float distance_to_hole = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 8.0;
			mask = min(mask, smoothstep(-0.75, 0.75, distance_to_hole));
		}
	}
	COLOR = vec4(shade_color.rgb, shade_color.a * mask);
}
