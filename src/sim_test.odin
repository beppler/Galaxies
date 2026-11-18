package main

import "core:testing"
import "core:math/linalg"

@(test)
flight_simulation_runs :: proc(t: ^testing.T) {
	init_models()
	new_game()
	defer free_game()
	launch()
	testing.expect_value(t, g.state, State.Flight)
	for _ in 0 ..< 1200 {
		g.spawn_t = min(g.spawn_t, 0.01)
		flight_update(1.0 / 60)
		if g.state != .Flight { break }
	}
	testing.expect(t, g.p.hull <= 100)
	testing.expect(t, len(g.ents) > 0)
}

@(test)
docking_works_when_aligned :: proc(t: ^testing.T) {
	init_models()
	new_game()
	defer free_game()
	launch()
	clear(&g.ents)
	g.station.spin = 0
	// fly in from outside, nose into slot, matching station orientation
	g.p.b = g.station.b
	g.p.b.f = -g.station.b.f
	g.p.b.r = -g.station.b.r
	orthonormalize(&g.p.b)
	g.p.pos = {0, 0, ST_L + 300}
	g.p.speed = 100
	for _ in 0 ..< 300 {
		flight_update(1.0 / 60)
		if g.state == .Docked { break }
	}
	testing.expect_value(t, g.state, State.Docked)
}

@(test)
jump_changes_system :: proc(t: ^testing.T) {
	init_models()
	new_game()
	defer free_game()
	// find a reachable neighbour
	for i in 0 ..< 256 {
		if i != g.cur && jump_cost(i) <= g.p.fuel {
			g.target = i
			break
		}
	}
	old := g.cur
	launch()
	start_jump()
	testing.expect_value(t, g.state, State.Hyper)
	g.hyper_t = 0
	update(0.016)
	testing.expect(t, g.cur != old)
	testing.expect_value(t, g.state, State.Flight)
}

@(test)
dock_repairs_hull :: proc(t: ^testing.T) {
	init_models()
	new_game()
	defer free_game()
	launch()
	g.p.hull = 10
	do_dock()
	testing.expect_value(t, g.p.hull, 100)
}

@(test)
trade_and_equip_money :: proc(t: ^testing.T) {
	new_game()
	defer free_game()
	g.market.qty[0] = 5
	g.market.price[0] = 100
	g.p.cash = 250
	buy(0, 10) // only cash for 2
	testing.expect_value(t, g.p.cargo[0], 2)
	testing.expect_value(t, g.p.cash, 50)
	sell(0, 10) // only 2 in hold
	testing.expect_value(t, g.p.cargo[0], 0)
	testing.expect_value(t, g.p.cash, 250)
	g.p.cash = 100
	buy_equip(3) // galactic drive costs 50000
	testing.expect(t, !g.p.gal_drive)
	testing.expect_value(t, g.p.cash, 100)
	g.p.fuel = MAX_FUEL - 10
	buy_equip(0) // 20 for 10 fuel
	testing.expect_value(t, g.p.fuel, MAX_FUEL)
	testing.expect_value(t, g.p.cash, 80)
}

@(test)
apply_save_clamps :: proc(t: ^testing.T) {
	d := SaveData{galaxy = 1, system = 3, cash = -5, missiles = 99, cargo_cap = 999, epoch = 0, kills = -50}
	d.cargo[2] = -1000
	d.cargo[4] = 3
	testing.expect(t, apply_save(d))
	testing.expect_value(t, g.p.cash, 0)
	testing.expect_value(t, g.p.kills, 0)
	testing.expect_value(t, g.p.missiles, 4)
	testing.expect_value(t, g.p.cargo_cap, 45)
	testing.expect_value(t, g.p.cargo[2], 0)
	testing.expect_value(t, g.p.cargo[4], 3)
	testing.expect_value(t, g.epoch, u32(1))
	testing.expect(t, !apply_save(SaveData{galaxy = 9}))
}

@(test)
models_are_closed :: proc(t: ^testing.T) {
	init_models()
	for m, id in models {
		if id == .Shard { continue }
		if id != .Station && id != .Viper { // convex: no vertex may lie in front of any face
			for n, i in m.fnorm {
				for p in m.verts {
					testing.expectf(t, linalg.dot(n, p - m.verts[m.fvert[i]]) < 1, "%v: face %d not outward", id, i)
				}
			}
		}
		for k in m.emask {
			testing.expectf(t, bits_set(k) == 2, "%v: edge in %d faces", id, bits_set(k))
		}
	}
}

@(private = "file")
bits_set :: proc(x: u32) -> int {
	n := 0
	for i in 0 ..< 32 { n += int(x >> u32(i) & 1) }
	return n
}

@(test)
slot_clip_respects_opening :: proc(t: ^testing.T) {
	p0, p1 := Vec3{-SLOT_W, -SLOT_H, ST_L}, Vec3{-SLOT_W, -SLOT_H, ST_L - SLOT_D}
	_, _, on := slot_clip({0, 0, 1000}, p0, p1)
	a, c, off := slot_clip({3000, 0, 300}, p0, p1)
	testing.expect(t, on)
	// grazing view: only a sliver of the far wall by the opening corner shows
	testing.expect(t, !off || linalg.length(c - a) < 0.2 * SLOT_D)
}

@(test)
station_slot_hidden_from_behind :: proc(t: ^testing.T) {
	init_models()
	m := &models[.Station]
	rim_drawn :: proc(m: ^Model, cam: Vec3) -> bool {
		pts: [32]Vec3
		for v, i in m.verts { pts[i] = v - cam }
		vis := face_vis(.Station, m, basis_identity(), basis_identity(), pts[:])
		for e, i in m.edges {
			if e[0] >= 16 && e[1] < 20 && m.emask[i] & vis != 0 { return true }
		}
		return false
	}
	testing.expect(t, rim_drawn(m, {0, 0, 1000}))
	testing.expect(t, !rim_drawn(m, {0, 0, -1000}))
	testing.expect(t, !rim_drawn(m, {0, 800, 0}))
}

@(test)
planets_clear_launch_and_crash_kills :: proc(t: ^testing.T) {
	init_models()
	new_game()
	defer free_game()
	for s in g.galaxy {
		s := s
		pl := make_planet(&s)
		testing.expect(t, pl.r > 0)
		testing.expect(t, linalg.length(Vec3{0, 0, ST_L + 250} - pl.pos) > pl.r)
	}
	for _ in 0 ..< 50 { // hyperspace arrival must never land inside the planet
		arrive_by_jump()
		testing.expect(t, linalg.length(g.p.pos - g.planet.pos) > g.planet.r)
	}
	launch()
	g.p.pos = g.planet.pos
	flight_update(1.0 / 60)
	testing.expect_value(t, g.state, State.Dead)
}

@(test)
horizon_cut_keeps_facing_part :: proc(t: ^testing.T) {
	r: f32 = 100
	c := Vec3{0, 0, 300} // camera at the origin, sphere centre straight ahead
	// both points on the far side (+z beyond the centre): hidden
	_, _, ok := horizon_cut(c, {-30, 0, 95}, {30, 0, 95}, r)
	testing.expect(t, !ok)
	// near side to far side: cut where it crosses the horizon
	qa := Vec3{0, 0, -100}
	qb := linalg.normalize(Vec3{70, 0, 70}) * r
	a, b, ok2 := horizon_cut(c, qa, qb, r)
	testing.expect(t, ok2)
	testing.expect(t, a == qa)
	testing.expect(t, abs(linalg.dot(b, c) + r * r) < 1)
	testing.expect(t, abs(linalg.length(b) - r) < 0.01)
}
