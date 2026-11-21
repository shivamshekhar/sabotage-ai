shader_type canvas_item;
// Puts a picture out of focus, as a camera lens does for things far behind what it is focused on: every pixel becomes the average of a disc of its neighbours (three
// rings of points), then the picture is darkened and tinted so it sinks into the distance. Used on the title screen's backdrop (see TitleBackdrop).

// radius: how far (in pixels of the picture) the blur reaches. Higher: more out of focus.
uniform float radius : hint_range(0.0, 40.0) = 7.0;
// dim: how much light the distance loses (0 = none, 1 = black). tint: the colour it is multiplied by (cooler and bluer = further away).
uniform float dim : hint_range(0.0, 1.0) = 0.32;
uniform vec4 tint : source_color = vec4(0.78, 0.9, 1.0, 1.0);

const int RINGS = 3;
const int POINTS = 12;

void fragment() {
	vec4 sum = texture(TEXTURE, UV);
	float total = 1.0;
	for (int ring = 1; ring <= RINGS; ring++) {
		float r = radius * float(ring) / float(RINGS);
		for (int i = 0; i < POINTS; i++) {
			float angle = 6.2831853 * (float(i) + 0.5 * float(ring)) / float(POINTS);
			sum += texture(TEXTURE, UV + vec2(cos(angle), sin(angle)) * r * TEXTURE_PIXEL_SIZE);
			total += 1.0;
		}
	}
	vec3 blurred = sum.rgb / total;
	COLOR = vec4(blurred * tint.rgb * (1.0 - dim), 1.0);
}
