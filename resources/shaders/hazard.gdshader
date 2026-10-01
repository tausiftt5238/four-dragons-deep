shader_type spatial;
// Floor hazards: one quad per tile, lying just on the flagstones. Four looks
// from one shader, picked by `mode`, all snapped to the same 20-texels-a-unit
// grid the stone uses so they read as pixel art beside it:
//   0 lava      molten rock glowing up through a crust that slowly shifts
//   1 ice       a pale, see-through sheet with cracks and a glint sliding over it
//   2 spark     an iron plate that crackles with lightning while its group is live
//   3 void      a slow violet swirl with specks drifting in it
// Self-lit and unshaded. A real light per tile is what these used to carry, and
// the web renderer lights a mesh from eight lights at most, so a floor of them
// started losing its torches.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;

uniform int mode = 0;
uniform float texel = 20.0;
// Spark tiles: which group this one is, and which group is live right now.
uniform int group = 0;
uniform int live = 0;
// Teleporters: each pair has its own colour, so which two go together is plain.
uniform vec3 pair_color : source_color = vec3(0.62, 0.36, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Texel coordinates in the floor plane, and UV centred on the tile.
	vec2 p = floor(world_pos.xz * texel);
	vec2 c = UV - 0.5;
	// Time moves in steps too, so the animation stays as chunky as the pixels.
	float t = floor(TIME * 8.0) / 8.0;
	vec3 col = vec3(0.0);
	float a = 1.0;

	if (mode == 0) {
		// Lava: two layers of noise drifting against each other; where they
		// agree the crust has split and the melt shows.
		float n1 = value_noise(p * 0.18 + vec2(t * 0.35, t * 0.12));
		float n2 = value_noise(p * 0.31 - vec2(t * 0.22, -t * 0.18));
		float heat = n1 * 0.6 + n2 * 0.4;
		float pulse = 0.85 + 0.15 * sin(TIME * 2.2);
		if (heat > 0.58) {
			col = mix(vec3(1.0, 0.45, 0.08), vec3(1.0, 0.86, 0.35), (heat - 0.58) * 3.0) * pulse;
		} else if (heat > 0.48) {
			col = vec3(0.78, 0.16, 0.04) * pulse;
		} else {
			col = vec3(0.16, 0.05, 0.03) + vec3(0.10, 0.02, 0.0) * heat;
		}
		// A darker rim, so the pool reads as sunk into the floor.
		float rim = max(abs(c.x), abs(c.y));
		if (rim > 0.44) {
			col *= 0.55;
		}
	} else if (mode == 1) {
		// Ice: pale blue and partly clear, so the flagstones show through.
		col = vec3(0.62, 0.84, 1.0);
		a = 0.50;
		// Cracks: thin lines where a coarse noise crosses a threshold.
		float k = value_noise(p * 0.12);
		if (abs(k - 0.5) < 0.022) {
			col = vec3(0.92, 0.98, 1.0);
			a = 0.85;
		}
		// A glint that slides diagonally across the sheet every few seconds.
		float band = fract((p.x + p.y) / 60.0 - TIME * 0.25);
		if (band < 0.05) {
			col = vec3(1.0);
			a = 0.80;
		}
		float rim = max(abs(c.x), abs(c.y));
		if (rim > 0.46) {
			col = vec3(0.80, 0.93, 1.0);
			a = 0.75;
		}
	} else if (mode == 2) {
		// Spark: an iron plate. Live, it crackles bright with a jagged bolt that
		// re-forms every frame step; dark, only a faint blue glimmer, so a live
		// tile is never mistaken for a safe one.
		bool on = group == live;
		col = vec3(0.14, 0.15, 0.19);
		float rim = max(abs(c.x), abs(c.y));
		if (rim > 0.44) {
			col = on ? vec3(0.95, 0.90, 0.40) : vec3(0.26, 0.30, 0.40);
		}
		// Rivets in the corners.
		if (rim > 0.36 && rim < 0.42 && abs(abs(c.x) - abs(c.y)) < 0.05) {
			col = vec3(0.40, 0.42, 0.48);
		}
		if (on) {
			float seed = floor(TIME * 10.0);
			// Three bolts zig-zagging across the plate.
			for (int i = 0; i < 3; i++) {
				float row = (float(i) + 0.5) / 3.0 - 0.5;
				float wob = (value_noise(vec2(p.x * 0.35, seed + float(i) * 7.0)) - 0.5) * 0.30;
				if (abs(c.y - row - wob) < 0.035) {
					col = vec3(0.85, 0.95, 1.0);
				}
			}
			col += vec3(0.10, 0.12, 0.20);
		} else if (hash21(p + floor(TIME * 3.0)) > 0.985) {
			col = vec3(0.35, 0.55, 0.90);
		}
	} else {
		// Void: a disc, turning slowly, darker toward its heart.
		float r = length(c) * 2.0;
		if (r > 1.0) {
			discard;
		}
		float ang = atan(c.y, c.x);
		float swirl = value_noise(vec2(ang * 3.0 + r * 6.0 - TIME * 1.2, r * 4.0));
		col = mix(vec3(0.03, 0.01, 0.06), pair_color, swirl * (1.0 - r * 0.4) * 0.9);
		if (r > 0.88) {
			col = pair_color * 1.2;       // a bright lip, so it reads as an edge
		}
		// Specks drifting inward.
		if (hash21(floor(vec2(ang * 12.0, r * 10.0 + TIME * 2.0))) > 0.96) {
			col = vec3(0.95, 0.85, 1.0);
		}
	}
	ALBEDO = col;
	ALPHA = a;
}
