shader_type canvas_item;
// Turns a picture white: `flash` 0 shows it as it is, 1 is pure white (its shape and transparency are kept). The parts of the mech share one material, so one
// number whitens them all at once (see MechAssembly).

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(mix(c.rgb, vec3(1.0), flash), c.a);
}
