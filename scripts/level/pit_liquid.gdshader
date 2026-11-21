shader_type canvas_item;
// The liquid of a deadly pit (see PitHazard). It is fully opaque: whatever falls in disappears behind it. The liquid
// texture drifts sideways and wobbles, the surface is a moving double wave, and the edge shines.

uniform sampler2D liquid_tex : repeat_enable, filter_linear_mipmap;
uniform vec2 size_px = vec2(210.0, 140.0);   // the size of the pit's rectangle in pixels
uniform float tile_px = 96.0;                // how many pixels one repeat of the texture covers
uniform float surface_px = 20.0;             // average depth of the surface below the top of the rectangle
uniform float wave_px = 5.0;                 // height of the surface waves
uniform float scroll = 0.05;                 // how fast the liquid drifts sideways (texture repeats per second)
uniform vec4 rim_color : source_color = vec4(1.0, 0.9, 0.5, 1.0);   // the bright line along the surface
uniform vec4 deep_color : source_color = vec4(0.3, 0.05, 0.0, 1.0); // what the liquid darkens towards at the bottom
uniform float glow = 0.12;                   // strength of the slow brightness pulse

void fragment() {
	vec2 p = UV * size_px;
	// two crossing waves make the surface line; the second one runs the other way
	float surf = surface_px + wave_px * sin(p.x * 0.085 + TIME * 2.1) + 0.55 * wave_px * sin(p.x * 0.19 - TIME * 3.3);
	if (p.y < surf) {
		discard;
	}
	float below = p.y - surf;
	// the texture drifts and the flow wobbles up and down, more strongly the further from the surface
	vec2 uv = vec2(p.x / tile_px + TIME * scroll + 0.05 * sin(p.y * 0.11 + TIME * 1.3),
				p.y / tile_px + 0.035 * sin(p.x * 0.07 - TIME * 1.1));
	vec3 c = texture(liquid_tex, uv).rgb;
	// depth: darker towards the bottom and towards the side walls
	float depth = clamp(below / max(1.0, size_px.y - surf), 0.0, 1.0);
	float side = min(p.x, size_px.x - p.x);
	float wall = 1.0 - smoothstep(0.0, 14.0, side);
	c = mix(c, deep_color.rgb, depth * 0.55 + wall * 0.35);
	// a bright rim along the surface and a faint band just under it
	float rim = 1.0 - smoothstep(0.0, 5.0, below);
	float band = 1.0 - smoothstep(5.0, 16.0, below);
	c = mix(c, rim_color.rgb, rim * 0.9);
	c += rim_color.rgb * band * 0.12;
	// slow pulsing glow, out of step along the pit
	c *= 1.0 + glow * sin(TIME * 2.0 + p.x * 0.04);
	COLOR = vec4(c, 1.0);
}
