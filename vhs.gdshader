shader_type canvas_item;

// VHS поверх игрового поля: строки развёртки, сдвиг цветовых каналов, зерно,
// ползущая полоса трекинга и виньетка. Uniform-ы выставляет vhs.gd:
// glitch — короткие всплески (удар по броне, босс, конец дубля), slow — «Фокус», rewind — перемотка.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float glitch : hint_range(0.0, 1.0) = 0.0;
uniform float slow : hint_range(0.0, 1.0) = 0.0;
uniform float rewind : hint_range(0.0, 1.0) = 0.0;
// Разрешение кадра игры: строки развёртки привязаны к нему, а не к пикселям экрана телефона.
uniform vec2 frame_size = vec2(720.0, 1280.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float row = floor(uv.y * frame_size.y * 0.5);

	// Полоса трекинга медленно ползёт вверх, при перемотке быстро бежит вниз.
	float band_y = mix(fract(1.0 - TIME * 0.05), fract(TIME * 1.7), step(0.01, rewind));
	float band = smoothstep(0.05, 0.0, abs(uv.y - band_y));
	// Внутри полосы и на всплесках строки рвутся по горизонтали.
	float jitter = hash(vec2(row, floor(TIME * 24.0))) - 0.5;
	float torn = step(0.82, hash(vec2(floor(uv.y * 36.0), floor(TIME * 18.0))));
	uv.x += jitter * (band * 0.008 + glitch * torn * 0.05 + rewind * 0.012) * strength;
	uv.x += rewind * 0.006 * sin(uv.y * 40.0 + TIME * 30.0) * strength;

	vec2 c = SCREEN_UV - 0.5;
	float edge = dot(c, c);
	float shift = (0.0012 + 0.006 * edge + glitch * 0.01 + rewind * 0.006 + slow * 0.002) * strength;
	vec3 col = vec3(
		texture(screen_tex, uv + vec2(shift, 0.0)).r,
		texture(screen_tex, uv).g,
		texture(screen_tex, uv - vec2(shift, 0.0)).b
	);

	// Строки развёртки: каждая вторая строка кадра чуть темнее, в «Фокусе» заметнее.
	float scan = 0.5 + 0.5 * cos(SCREEN_UV.y * frame_size.y * PI);
	col *= 1.0 - (0.07 + 0.08 * slow) * scan * strength;
	// Зерно и светлая полоса трекинга.
	col += (hash(SCREEN_UV * 1000.0 + fract(TIME)) - 0.5) * (0.035 + 0.05 * glitch + 0.04 * rewind) * strength;
	col += band * 0.05 * strength;

	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	// «Фокус»: картинка выцветает и уходит в холодный фиолетовый.
	col = mix(col, vec3(grey) * vec3(0.85, 0.9, 1.25), slow * 0.45 * strength);
	// Перемотка: выцветание и белые строки-помехи.
	col = mix(col, vec3(grey), rewind * 0.5);
	col += rewind * step(0.985, hash(vec2(row, floor(TIME * 40.0)))) * 0.6;

	col *= 1.0 - edge * (0.45 + 0.3 * slow) * strength;
	COLOR = vec4(col, 1.0);
}
