// Stone for the maze: coursed blocks on the walls, flagstones on the floor and
// the ceiling.
//
// Drawn from world position rather than UVs, so the maze mesh stays the bare
// list of quads it always was and the pattern runs on unbroken round corners
// and across neighbouring cells. Snapped to a coarse texel grid first, so the
// stone is pixel art at the same chunkiness as the sprites rather than a smooth
// 3D texture sitting next to them.
//
// Unshaded, with its own lighting: the walls are one mesh for the whole floor,
// and the Compatibility renderer lights a mesh from eight lights at most, so a
// corridor of real torches would have lost most of them. The player's carried
// light and the torches are passed in as positions and summed here instead.
shader_type spatial;
render_mode unshaded, cull_disabled;

// 0 = walls, 1 = floor, 2 = ceiling, 3 = the planks of the locked door,
// 4 = the steps up out of the floor.
uniform int surface = 0;
// Texels per course of wall stone. The stairs lay theirs at 5, one course to a
// riser, so every step's top row catches the light as a nosing.
uniform float course_h = 6.0;
// Where the door's planks start, in world units across the door, so they are
// cut to the door and not to wherever the world grid happens to fall.
uniform float plank_origin = 0.0;
// The band's line colour. The stone takes a little of it, so each band's rock
// is its own without the walls turning into coloured plastic.
uniform vec3 tint : source_color = vec3(0.55, 0.88, 1.0);
uniform float tint_amount = 0.34;
uniform float brightness = 1.0;

// Texels per world unit. A cell is 2 units, so 20 here is 40 px across a wall.
uniform float texel = 20.0;

// Light the stone carries on its own, before any flame reaches it.
uniform vec3 ambient : source_color = vec3(0.10, 0.10, 0.12);

// The player's light, at the camera.
uniform vec3 viewer = vec3(0.0);
uniform vec3 viewer_color : source_color = vec3(1.0, 0.78, 0.52);
uniform float viewer_range = 7.0;

// Wall torches near the player. Only the nearest few are sent; the rest are too
// far away to reach anything on screen and the fog has them anyway.
const int MAX_TORCHES = 12;
uniform int torch_count = 0;
uniform vec3 torches[12];
uniform vec3 torch_color : source_color = vec3(1.0, 0.62, 0.28);
uniform float torch_range = 4.2;
uniform float torch_power = 1.6;

// One coloured glow the way out gives off: green down the stairs, violet from
// the lock while it is shut. Black is off.
uniform vec3 glow_pos = vec3(0.0);
uniform vec3 glow_color : source_color = vec3(0.0);
uniform float glow_range = 4.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
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

// Coursed stone: rows of blocks, each row shifted, block lengths varying
// along the row. The walls and the floor use the same layout at different
// sizes. Returns (block id, distance to the nearest joint in texels, texels
// from the top of the course: 1 is a block's top row, row_h - 1 its bottom).
vec3 coursed(vec2 p, float row_h, float seg, float min_len, float max_len) {
	float row = floor(p.y / row_h);
	float in_row = p.y - row * row_h;
	float x = p.x + hash21(vec2(row, 7.0)) * seg * 1.7;
	float s = floor(x / seg);
	float split = floor(mix(min_len, max_len, hash21(vec2(s, row))));
	float local = x - s * seg;
	float id_x = local < split ? s * 2.0 : s * 2.0 + 1.0;
	float left = local < split ? local : local - split;
	float right = local < split ? split - local : seg - local;
	float dx = min(left, right);
	float dy = min(in_row, row_h - in_row);
	return vec3(hash21(vec2(id_x, row)), min(dx, dy), row_h - in_row);
}

// A door of upright planks 6 texels wide, with two iron straps across and a
// rivet on each plank where a strap crosses it. `p` is in texels from the
// door's bottom-left corner.
vec3 planks(vec2 p) {
	float plank = floor(p.x / 6.0);
	float x = p.x - plank * 6.0;
	float shade = 0.80 + hash21(vec2(plank, 3.0)) * 0.35;
	// Grain runs up the plank: noise stretched tall, and a knot now and then.
	float grain = value_noise(vec2(p.x * 0.8 + plank * 17.0, p.y * 0.15));
	vec3 col = vec3(0.34, 0.21, 0.12) * shade * (0.80 + grain * 0.35);
	if (hash21(floor(p / vec2(1.0, 3.0)) + plank) > 0.97) {
		col *= 0.70;
	}
	if (x < 1.0) {
		col *= 0.35;                    // the gap between planks
	} else if (x > 4.5) {
		col *= 0.82;                    // each plank's shadowed edge
	}
	for (int i = 0; i < 2; i++) {
		float y0 = i == 0 ? 4.0 : 26.0;
		if (p.y >= y0 && p.y < y0 + 3.0) {
			col = vec3(0.16, 0.15, 0.16) * (p.y == y0 + 2.0 ? 1.35 : p.y == y0 ? 0.65 : 1.0);
			if (x == 3.0 && p.y == y0 + 1.0) {
				col = vec3(0.42, 0.40, 0.40);
			}
		}
	}
	return col;
}

vec3 light_at(vec3 p) {
	vec3 lit = ambient;
	float dv = distance(p, viewer);
	float fv = clamp(1.0 - dv / viewer_range, 0.0, 1.0);
	lit += viewer_color * fv * fv * 1.15;
	for (int i = 0; i < MAX_TORCHES; i++) {
		if (i >= torch_count) {
			break;
		}
		vec3 t = torches[i];
		float d = distance(p, t);
		float f = clamp(1.0 - d / torch_range, 0.0, 1.0);
		// Two slow waves and a quick one: a flame, not a strobe.
		float flicker = 0.86 + 0.08 * sin(TIME * 7.3 + float(i) * 1.7)
				+ 0.06 * sin(TIME * 13.1 + float(i) * 4.1);
		lit += torch_color * f * f * torch_power * flicker;
	}
	float fg = clamp(1.0 - distance(p, glow_pos) / glow_range, 0.0, 1.0);
	lit += glow_color * fg * fg;
	return lit;
}

void fragment() {
	// Which way the face points decides which two world axes are "across" and
	// "up" on it. The maze is all axis-aligned quads, so this is exact.
	vec3 n = abs(world_normal);
	vec2 plane;
	if (surface == 1 || surface == 2 || (n.y > n.x && n.y > n.z)) {
		plane = world_pos.xz;
	} else if (n.x > n.z) {
		plane = vec2(world_pos.z, world_pos.y);
	} else {
		plane = vec2(world_pos.x, world_pos.y);
	}
	vec2 p = floor(plane * texel);

	vec3 col;
	if (surface == 3) {
		col = planks(p - vec2(floor(plank_origin * texel), 0.0));
	} else {
		// Walls: courses course_h texels high, blocks 7 to 13 long. Floor: bigger slabs.
		// The ceiling is laid the other way from the floor, so looking up and down
		// in the same spot does not show the same slabs mirrored.
		vec3 b = surface == 2 ? coursed(p.yx, 9.0, 24.0, 8.0, 16.0)
				: surface == 1 ? coursed(p, 9.0, 24.0, 8.0, 16.0)
				: coursed(p, course_h, 20.0, 7.0, 13.0);
		bool tread = n.y > n.x && n.y > n.z;
		float id = b.x;
		float edge = b.y;

		// The rock: warm grey, a touch of the band's colour, each block its own shade.
		vec3 rock = mix(vec3(0.40, 0.38, 0.35), tint * 0.55, tint_amount);
		rock *= 0.78 + id * 0.40;
		// Grain and the odd pit, at texel scale so it stays pixel art.
		float grain = value_noise(p * 0.45 + id * 31.0);
		rock *= 0.86 + grain * 0.22;
		if (hash21(p + id * 13.0) > 0.965) {
			rock *= 0.72;
		}

		// Mortar in the joints, and a bevel: a block's top row of texels catches
		// the light, its bottom row sits in shadow.
		col = rock;
		if (edge < 1.0) {
			col = rock * (surface >= 1 ? 0.50 : 0.30);
		} else if (surface == 0 && b.z < 1.5) {
			col = rock * 1.20;
		} else if (surface == 0 && b.z > course_h - 1.5) {
			col = rock * 0.80;
		} else if (surface == 4 && !tread) {
			// A riser is one course: a worn, bright nosing along its top and
			// the shadow of the step above along its foot. That contrast is
			// what makes six risers read as a flight and not as a wall.
			col = rock * (b.z < 1.5 ? 1.75 : b.z > course_h - 1.5 ? 0.45 : 0.85);
		}
		if (surface == 4 && tread) {
			col *= 1.30;
		}

		if (surface == 1) {
			col *= 0.50;
		} else if (surface == 2) {
			// Darker again: light from a flame or the player's lamp reaches it,
			// but it is the one surface nobody is meant to look at.
			col *= 0.32;
		}
	}

	vec3 light = light_at(world_pos);
	ALBEDO = col * light * brightness;
}
