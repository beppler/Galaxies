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
}

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
side_v := [?]Vec3{
	{0, 0, 70}, {-50, 0, -30}, {50, 0, -30}, {0, 20, -30}, {0, -15, -30}, {0, 0, -60},
}
@(private = "file")
side_e := [?][2]u8{
	{0, 1}, {0, 2}, {0, 3}, {0, 4}, {1, 3}, {3, 2}, {2, 4}, {4, 1},
	{1, 5}, {2, 5}, {3, 5}, {4, 5},
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
missile_v := [?]Vec3{{0, 0, 30}, {-6, -6, -30}, {6, -6, -30}, {0, 8, -30}}
@(private = "file")
missile_e := [?][2]u8{{0, 1}, {0, 2}, {0, 3}, {1, 2}, {2, 3}, {3, 1}}

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
rock_v := [?]Vec3{{55, 5, 0}, {-50, -8, 10}, {5, 60, -5}, {-3, -45, 8}, {10, 4, 52}, {-8, -6, -58}}
@(private = "file")
rock_e := [?][2]u8{
	{0, 2}, {0, 3}, {0, 4}, {0, 5}, {1, 2}, {1, 3}, {1, 4}, {1, 5},
	{2, 4}, {4, 3}, {3, 5}, {5, 2},
}

@(private = "file")
shard_v := [?]Vec3{{0, 0, 12}, {0, 0, -12}}
@(private = "file")
shard_e := [?][2]u8{{0, 1}}

@(private = "file")
set_model :: proc(id: ModelId, v: []Vec3, e: [][2]u8) {
	r: f32 = 0
	for p in v {
		r = max(r, linalg.length(p))
	}
	models[id] = Model{v, e, r}
}

init_models :: proc() {
	set_model(.Cobra, cobra_v[:], cobra_e[:])
	set_model(.Sidewinder, side_v[:], side_e[:])
	set_model(.Viper, viper_v[:], viper_e[:])
	set_model(.Missile, missile_v[:], missile_e[:])
	set_model(.Canister, canister_v[:], canister_e[:])
	set_model(.Asteroid, rock_v[:], rock_e[:])
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
	set_model(.Station, v, e[:])
}
