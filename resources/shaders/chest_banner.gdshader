// Chest banner — the cache standing in its niche, drawn from a two-frame sheet.
//
// Lit like the room rather than unshaded, which is the whole point of it: the
// dungeon is recoloured per band and an unshaded decal keeps its own colours at
// every depth, so it reads as a picture pasted into the corridor instead of a
// thing standing in a hole in the wall. Everything below exists to give a flat
// quad something for the light to happen to.
//
// Same treatment as the computer banner on the backrooms branch, and the same
// four knobs: zeroing bevel, tint_amount, sheen and contact returns the plain
// lit sprite exactly.
shader_type spatial;
render_mode blend_mix, cull_disabled;

uniform sampler2D tex : filter_nearest, source_color;

// The sheet is frames side by side — closed, then lid tipped back. The window
// is picked here rather than with uv1_offset on the material, because the
// bevel has to sample its neighbours in the SAME frame and a material-level
// offset would let it read across the seam into the other one.
uniform float frames = 2.0;
uniform float frame  = 0.0;

// bevel: a normal map derived from the art's OWN luminance — bright pixels read
// as raised, so light rakes across the lid and the bands instead of flooding
// the whole chest evenly. There is no authored normal map and there does not
// need to be; edges in the sprite are edges in the shading.
uniform float bevel : hint_range(0.0, 4.0) = 0.0;
// tint: pulls the chest towards the band's own wire colour. The dungeon changes
// colour every five floors and the chest does not, which is most of what would
// make it look imported.
uniform vec3 tint : source_color = vec3(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
// sheen: some specular, so the metal bands catch the light in the niche. Does
// nothing without `bevel` — a flat normal makes a flat highlight.
uniform float sheen : hint_range(0.0, 1.0) = 0.0;
// contact: darkens the bottom few rows where the chest meets the shelf, which
// is the shadow it would cast if anything down here cast shadows.
uniform float contact : hint_range(0.0, 1.0) = 0.0;

// Lit from inside while it still holds something — the game's own language for
// a cache worth opening. Driven by the art's brightness so the gold trim and
// the lock carry the glow and the shadowed panels do not; no hand-typed
// rectangles to fall out of step with the drawing. Zero on a looted chest.
uniform float glow = 0.0;
uniform vec3 glow_color : source_color = vec3(1.0, 0.80, 0.32);


vec2 frame_uv(vec2 uv) {
	return vec2((uv.x + frame) / frames, uv.y);
}

float relief(vec2 uv) {
	vec4 c = texture(tex, frame_uv(uv));
	return c.a * dot(c.rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec4 c = texture(tex, frame_uv(UV));
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	vec3 albedo = mix(c.rgb, c.rgb * tint, tint_amount);
	// The shelf it stands on. UV.y is 1 at the bottom of the sprite.
	albedo *= mix(1.0, mix(0.42, 1.0, smoothstep(0.0, 0.18, 1.0 - UV.y)), contact);
	ALBEDO = albedo;

	// A flat normal at bevel 0, so this costs nothing when it is off. The x step
	// is widened by `frames` because one texel of the sheet is that much of a
	// single frame's UV span.
	vec2 t = 1.0 / vec2(textureSize(tex, 0));
	float hl = relief(UV - vec2(t.x * frames, 0.0));
	float hr = relief(UV + vec2(t.x * frames, 0.0));
	float hu = relief(UV - vec2(0.0, t.y));
	float hd = relief(UV + vec2(0.0, t.y));
	NORMAL_MAP = normalize(vec3((hl - hr) * bevel, (hd - hu) * bevel, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;

	ROUGHNESS = mix(1.0, 0.42, sheen);
	SPECULAR  = mix(0.0, 0.55, sheen);

	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	EMISSION = glow_color * glow * smoothstep(0.35, 0.95, lum) * c.a;
}
