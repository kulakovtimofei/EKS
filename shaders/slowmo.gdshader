shader_type canvas_item;
// Полноэкранный пост-эффект.
// В замедлении: хроматическая аберрация, кислотный оттенок, виньетка.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint : source_color = vec3(1.0, 0.2, 0.85);
uniform float color_levels = 32.0;
uniform float dither_px = 2.0;     // размер «пикселя» дизеринга

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int idx = i.x + i.y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[idx] / 16.0 - 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - 0.5;
	float d = length(dir);
	vec3 col;
	if (intensity > 0.001) {
		float ab = 0.024 * intensity * d;
		col.r = texture(screen_tex, uv + dir * ab).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - dir * ab).b;
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(col, vec3(lum) * tint * 1.4, 0.35 * intensity);
		col *= mix(1.0, smoothstep(0.85, 0.25, d), 0.8 * intensity);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	COLOR = vec4(col, 1.0);
}
