shader_type canvas_item;
// Full-screen CRT/terminal overlay: vignette darkening + faint scanlines.
// Drawn on a top CanvasLayer ColorRect so it affects the whole game view.
// funky_strength > 0 kicks in once too many hallucinations have been missed:
// pulsing vignette, jittery scanlines and brief red/cyan flicker tints.

uniform float vignette_strength : hint_range(0.0, 2.0) = 1.1;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(50.0, 800.0) = 270.0;
uniform float funky_strength : hint_range(0.0, 1.0) = 0.0;

float rand(float n) {
	return fract(sin(n) * 43758.5453123);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);

	float t = TIME;
	float extra_vignette = funky_strength * (sin(t * 5.0) * 0.15 + 0.15);
	float vignette = 1.0 - dot(centered, centered) * (vignette_strength + extra_vignette);
	vignette = clamp(vignette, 0.0, 1.0);

	float scan_wobble = funky_strength * sin(t * 37.0 + uv.y * 80.0) * 0.1;
	float scanline = sin(uv.y * scanline_count) * 0.5 + 0.5;
	float scan_dark = 1.0 - scanline * (scanline_strength + scan_wobble);

	float shade = vignette * scan_dark;
	float alpha = clamp(1.0 - shade, 0.0, 1.0);

	vec3 tint = vec3(0.0);
	if (funky_strength > 0.0) {
		float pulse = step(0.9, rand(floor(t * 4.0))) * funky_strength;
		float flicker_pick = rand(floor(t * 4.0) + 7.0);
		vec3 flicker_color = flicker_pick > 0.5 ? vec3(1.0, 0.1, 0.2) : vec3(0.2, 0.9, 1.0);
		tint = flicker_color * pulse * 0.35;
		alpha = clamp(alpha + pulse * 0.25, 0.0, 1.0);
	}

	COLOR = vec4(tint, alpha);
}

