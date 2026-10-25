shader_type canvas_item;
// Full-screen CRT/terminal overlay: vignette darkening + faint scanlines.
// Drawn on a top CanvasLayer ColorRect so it affects the whole game view.

uniform float vignette_strength : hint_range(0.0, 2.0) = 1.1;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(50.0, 800.0) = 270.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 centered = uv - vec2(0.5);
	float vignette = 1.0 - dot(centered, centered) * vignette_strength;
	vignette = clamp(vignette, 0.0, 1.0);

	float scanline = sin(uv.y * scanline_count) * 0.5 + 0.5;
	float scan_dark = 1.0 - scanline * scanline_strength;

	float shade = vignette * scan_dark;
	COLOR = vec4(0.0, 0.0, 0.0, clamp(1.0 - shade, 0.0, 1.0));
}
