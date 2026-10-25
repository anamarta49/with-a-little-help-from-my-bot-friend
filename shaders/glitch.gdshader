shader_type canvas_item;
// Subtle "hallucination" glitch flicker for hazards/bonus pickups.
// Applied identically to hazards AND camouflaged bonus items so it never
// gives away which is which -- it's purely a thematic flourish.

uniform float glitch_strength : hint_range(0.0, 1.0) = 0.35;
uniform float speed : hint_range(0.1, 5.0) = 1.5;

float rand(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	float t = TIME * speed;
	// Occasional short glitch pulses instead of a constant wobble.
	float pulse = step(0.93, rand(floor(t * 3.0)));
	float line_glitch = step(0.985, rand(floor(UV.y * 40.0 + t * 7.0))) * pulse;

	vec2 uv = UV;
	uv.x += line_glitch * (rand(floor(t * 20.0)) - 0.5) * 0.08 * glitch_strength;

	vec4 col = texture(TEXTURE, uv);

	// Slight RGB channel split during a glitch pulse.
	float split = line_glitch * 0.015 * glitch_strength;
	col.r = texture(TEXTURE, uv + vec2(split, 0.0)).r;
	col.b = texture(TEXTURE, uv - vec2(split, 0.0)).b;

	COLOR = col;
}
