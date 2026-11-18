package main

import "core:testing"
import "core:math/linalg"

@(test)
flight_simulation_runs :: proc(t: ^testing.T) {
	init_models()
	new_game()
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
