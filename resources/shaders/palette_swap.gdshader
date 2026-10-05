// Repaints a sprite in one element's palette for the Abyss (Abyss.PALETTE):
// each pixel's brightness picks a colour between the palette's dark and light
// ends, mixed over the original by `amount` so the shading and the outline
// still read. Alpha is left alone.
shader_type canvas_item;

uniform vec4 dark_col : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 light_col : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.8;

void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 painted = mix(dark_col.rgb, light_col.rgb, smoothstep(0.04, 0.92, lum));
	COLOR = vec4(mix(c.rgb, painted, amount), c.a);
}
