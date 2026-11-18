package main

import "core:math"
import "core:math/linalg"

ModelId :: enum {
	Cobra,
	Sidewinder,
	Viper,
	Missile,
	Canister,
	Asteroid,
	Shard,
	Station,
}

Model :: struct {
	verts:  []Vec3,
	edges:  [][2]u8,
	radius: f32,
	// Hidden-line data: per-face outward normal and a vertex on it, and per-edge bitmask of
	// adjacent faces. An edge is drawn if it has no faces or any adjacent face faces the camera.
	fnorm:  []Vec3,
	fvert:  []u8,
	emask:  []u32,
}

// Face = up to 4 vertex indices (X pads triangles). Non-triangles must be planar-ish.
X :: u8(255)

models: [ModelId]Model

// Station geometry (local space: +Z is the face with the docking slot).
ST_R :: 360.0
ST_L :: 250.0
SLOT_W :: 130.0
SLOT_H :: 65.0
SLOT_D :: 160.0

@(private = "file")
cobra_v := [?]Vec3{
	{0, 0, 100}, {-90, -5, -60}, {90, -5, -60}, {0, 25, -40},
	{0, -20, -50}, {-30, 0, -70}, {30, 0, -70},
}
@(private = "file")
cobra_e := [?][2]u8{
	{0, 1}, {0, 2}, {0, 3}, {0, 4}, {1, 3}, {2, 3}, {1, 4}, {2, 4},
	{1, 5}, {2, 6}, {5, 6}, {3, 5}, {3, 6}, {4, 5}, {4, 6},
}
@(private = "file")
cobra_f := [?][4]u8{
	{0, 1, 3, X}, {0, 3, 2, X}, {0, 4, 1, X}, {0, 2, 4, X},
	{1, 3, 5, X}, {3, 5, 6, X}, {2, 3, 6, X}, {1, 4, 5, X}, {4, 5, 6, X}, {2, 4, 6, X},
}

@(private = "file")
side_v := [?]Vec3{
	{0, 0, 70}, {-50, 0, -30}, {50, 0, -30}, {0, 20, -30}, {0, -15, -30}, {0, 0, -60},
}
@(private = "file")
side_e := [?][2]u8{
	{0, 1}, {0, 2}, {0, 3}, {0, 4}, {1, 3}, {3, 2}, {2, 4}, {4, 1},
	{1, 5}, {2, 5}, {3, 5}, {4, 5},
}
@(private = "file")
side_f := [?][4]u8{
	{0, 1, 3, X}, {0, 3, 2, X}, {0, 2, 4, X}, {0, 4, 1, X},
	{5, 1, 3, X}, {5, 3, 2, X}, {5, 2, 4, X}, {5, 4, 1, X},
}

@(private = "file")
viper_v := [?]Vec3{
	{0, 0, 110}, {-60, 0, -50}, {60, 0, -50}, {0, 30, -50}, {0, -30, -50},
	{0, 0, -90}, {-90, -10, -70}, {90, -10, -70},
}
@(private = "file")
viper_e := [?][2]u8{
	{0, 1}, {0, 2}, {0, 3}, {0, 4}, {1, 3}, {3, 2}, {2, 4}, {4, 1},
	{1, 6}, {2, 7}, {6, 5}, {7, 5}, {3, 5}, {4, 5},
}
@(private = "file")
viper_f := [?][4]u8{
	{0, 1, 3, X}, {0, 3, 2, X}, {0, 2, 4, X}, {0, 4, 1, X},
	{1, 3, 6, X}, {3, 5, 6, X}, {1, 4, 6, X}, {4, 5, 6, X},
	{2, 3, 7, X}, {3, 5, 7, X}, {2, 4, 7, X}, {4, 5, 7, X},
}

@(private = "file")
missile_v := [?]Vec3{{0, 0, 30}, {-6, -6, -30}, {6, -6, -30}, {0, 8, -30}}
@(private = "file")
missile_e := [?][2]u8{{0, 1}, {0, 2}, {0, 3}, {1, 2}, {2, 3}, {3, 1}}
@(private = "file")
missile_f := [?][4]u8{{0, 1, 2, X}, {0, 2, 3, X}, {0, 3, 1, X}, {1, 2, 3, X}}

@(private = "file")
canister_v := [?]Vec3{
	{-10, -10, -10}, {10, -10, -10}, {10, 10, -10}, {-10, 10, -10},
	{-10, -10, 10}, {10, -10, 10}, {10, 10, 10}, {-10, 10, 10},
}
@(private = "file")
canister_e := [?][2]u8{
	{0, 1}, {1, 2}, {2, 3}, {3, 0}, {4, 5}, {5, 6}, {6, 7}, {7, 4},
	{0, 4}, {1, 5}, {2, 6}, {3, 7},
}
@(private = "file")
canister_f := [?][4]u8{
	{0, 1, 2, 3}, {4, 5, 6, 7}, {0, 1, 5, 4}, {1, 2, 6, 5}, {2, 3, 7, 6}, {3, 0, 4, 7},
}

@(private = "file")
rock_v := [?]Vec3{{55, 5, 0}, {-50, -8, 10}, {5, 60, -5}, {-3, -45, 8}, {10, 4, 52}, {-8, -6, -58}}
@(private = "file")
rock_e := [?][2]u8{
	{0, 2}, {0, 3}, {0, 4}, {0, 5}, {1, 2}, {1, 3}, {1, 4}, {1, 5},
	{2, 4}, {4, 3}, {3, 5}, {5, 2},
}
@(private = "file")
rock_f := [?][4]u8{
	{0, 2, 4, X}, {0, 2, 5, X}, {0, 3, 4, X}, {0, 3, 5, X},
	{1, 2, 4, X}, {1, 2, 5, X}, {1, 3, 4, X}, {1, 3, 5, X},
}

@(private = "file")
shard_v := [?]Vec3{{0, 0, 12}, {0, 0, -12}}
@(private = "file")
shard_e := [?][2]u8{{0, 1}}

@(private = "file")
set_model :: proc(id: ModelId, v: []Vec3, e: [][2]u8, f: [][4]u8 = nil, flip: u32 = 0) {
	r: f32 = 0
	mean: Vec3
	for p in v {
		r = max(r, linalg.length(p))
		mean += p / f32(len(v))
	}
	assert(len(f) <= 32) // render uses a u32 visibility mask
	m := Model{verts = v, edges = e, radius = r}
	m.fnorm = make([]Vec3, len(f))
	m.fvert = make([]u8, len(f))
	m.emask = make([]u32, len(e))
	for fc, i in f {
		n := linalg.cross(v[fc[1]] - v[fc[0]], v[fc[2]] - v[fc[0]])
		// shortcut: outward = away from vertex mean, so concave faces need the flip bit
		if (linalg.dot(n, v[fc[0]] - mean) < 0) != (flip >> u32(i) & 1 == 1) {
			n = -n
		}
		m.fnorm[i], m.fvert[i] = linalg.normalize(n), fc[0]
		// the normal comes from 3 vertices, so a 4th off the plane gives wrong hidden-line results
		assert(fc[3] == X || abs(linalg.dot(m.fnorm[i], v[fc[3]] - v[fc[0]])) < 1, "non-planar model face")
		for ei, k in e {
			a, b := false, false
			for w in fc {
				a ||= w == ei[0]
				b ||= w == ei[1]
			}
			if a && b {
				m.emask[k] |= 1 << u32(i)
			}
		}
	}
	models[id] = m
}

init_models :: proc() {
	set_model(.Cobra, cobra_v[:], cobra_e[:], cobra_f[:])
	set_model(.Sidewinder, side_v[:], side_e[:], side_f[:])
	set_model(.Viper, viper_v[:], viper_e[:], viper_f[:])
	set_model(.Missile, missile_v[:], missile_e[:], missile_f[:])
	set_model(.Canister, canister_v[:], canister_e[:], canister_f[:])
	set_model(.Asteroid, rock_v[:], rock_e[:], rock_f[:])
	set_model(.Shard, shard_v[:], shard_e[:])

	// Station: octagonal prism with a rectangular docking slot in the +Z face.
	v := make([]Vec3, 24)
	e := make([dynamic][2]u8, 0, 40)
	for i in 0 ..< 8 {
		a := (f32(i) + 0.5) * math.PI / 4
		x, y := ST_R * math.cos(a), ST_R * math.sin(a)
		v[i] = {x, y, ST_L}
		v[8 + i] = {x, y, -ST_L}
	}
	sx := [4]f32{-SLOT_W, SLOT_W, SLOT_W, -SLOT_W}
	sy := [4]f32{-SLOT_H, -SLOT_H, SLOT_H, SLOT_H}
	for i in 0 ..< 4 {
		v[16 + i] = {sx[i], sy[i], ST_L}
		v[20 + i] = {sx[i], sy[i], ST_L - SLOT_D}
	}
	for i in 0 ..< 8 {
		n := (i + 1) % 8
		append(&e, [2]u8{u8(i), u8(n)})
		append(&e, [2]u8{u8(8 + i), u8(8 + n)})
		append(&e, [2]u8{u8(i), u8(8 + i)})
	}
	for i in 0 ..< 4 {
		n := (i + 1) % 4
		append(&e, [2]u8{u8(16 + i), u8(16 + n)})
		append(&e, [2]u8{u8(20 + i), u8(20 + n)})
		append(&e, [2]u8{u8(16 + i), u8(20 + i)})
	}
	f := make([dynamic][4]u8, 0, 32)
	for i in 1 ..< 7 { // front and back octagons as triangle fans
		append(&f, [4]u8{0, u8(i), u8(i + 1), X})
		append(&f, [4]u8{8, u8(8 + i), u8(9 + i), X})
	}
	for i in 0 ..< 8 {
		n := (i + 1) % 8
		append(&f, [4]u8{u8(i), u8(n), u8(8 + n), u8(8 + i)})
	}
	for i in 0 ..< 4 { // slot walls (faces 20..23); normals point into the slot, hence flipped
		n := (i + 1) % 4
		append(&f, [4]u8{u8(16 + i), u8(16 + n), u8(20 + n), u8(20 + i)})
	}
	append(&f, [4]u8{16, 17, 18, 19}) // front face around the slot
	append(&f, [4]u8{20, 21, 22, 23}) // slot floor
	set_model(.Station, v, e[:], f[:], 0xF << 20)
}
