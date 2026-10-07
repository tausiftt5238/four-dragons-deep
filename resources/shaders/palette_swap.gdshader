// Repaints a sprite in one element's colours for the Abyss (Abyss.palette_material):
// the pixels of the sprite's own main colour (src_hue, give or take src_half)
// are turned to the element's hue, keeping their shading, and everything else
// — skin, steel, eyes, the outline — is left as drawn. A sprite that is mostly
// grey has little colour to turn, so its greys take a light wash of the
// element instead (grey_amount). Alpha is left alone.
shader_type canvas_item;

uniform float src_hue = 0.0;
uniform float src_half = 0.08;
uniform float dst_hue = 0.0;
uniform float sat_scale = 1.0;
uniform float val_shift = 0.0;
uniform float grey_amount = 0.0;
// How much of the sprite's own spread of hues survives the turn: a little,
// so a two-tone hide stays two-tone without spilling into other colours.
const float SPREAD = 0.35;
const float GREY_SAT = 0.4;
// The red outline every Hurt sheet flashes; it stays red in any element.
const vec3 HURT_RED = vec3(237.0, 13.0, 13.0) / 255.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	// COLOR arrives already multiplied by the texture; reading TEXTURE again
	// and multiplying would square every channel and sink the sprite.
	vec4 c = COLOR;
	vec3 hsv = rgb2hsv(c.rgb);
	float off = fract(hsv.x - src_hue + 0.5) - 0.5;
	float w = (1.0 - smoothstep(src_half + 0.01, src_half + 0.05, abs(off)))
			* smoothstep(0.08, 0.2, hsv.y) * smoothstep(0.06, 0.14, hsv.z);
	float v = clamp(hsv.z + val_shift, 0.0, 1.0);
	vec3 turned = hsv2rgb(vec3(fract(dst_hue + off * SPREAD), clamp(hsv.y * sat_scale, 0.0, 1.0), v));
	vec3 washed = hsv2rgb(vec3(dst_hue, GREY_SAT * min(sat_scale, 1.0), v));
	float g = grey_amount * (1.0 - w) * smoothstep(0.08, 0.16, hsv.z);
	vec3 rgb = mix(c.rgb, turned, w);
	rgb = mix(rgb, washed, g);
	if (distance(c.rgb, HURT_RED) < 0.02) {
		rgb = c.rgb;
	}
	COLOR = vec4(rgb, c.a);
}
