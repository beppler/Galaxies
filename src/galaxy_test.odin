package main

import "core:testing"

@(test)
galaxy_is_deterministic :: proc(t: ^testing.T) {
	a := gen_galaxy(0)
	b := gen_galaxy(0)
	for i in 0 ..< 256 {
		testing.expect_value(t, a[i], b[i])
	}
}

@(test)
start_system_is_lave :: proc(t: ^testing.T) {
	g := gen_galaxy(0)
	testing.expect_value(t, sys_name(&g[START_SYSTEM]), "Lave")
}

@(test)
galaxies_differ :: proc(t: ^testing.T) {
	a := gen_galaxy(0)
	b := gen_galaxy(1)
	testing.expect(t, a[10] != b[10])
}

@(test)
market_is_deterministic :: proc(t: ^testing.T) {
	g := gen_galaxy(0)
	m1 := make_market(&g[7], 42)
	m2 := make_market(&g[7], 42)
	testing.expect_value(t, m1, m2)
	for q in m1.qty {
		testing.expect(t, q >= 0 && q <= 63)
	}
}
