package main

import "core:math"

// Procedural galaxy using a 3x16-bit "twist" seed, in the spirit of the
// original Elite. 8 galaxies x 256 systems, fully deterministic.

Seed :: [3]u16

BASE_SEED :: Seed{0x5A4A, 0x0248, 0xB753}
START_SYSTEM :: 7

System :: struct {
	x, y:     int,
	gov, eco: int,
	tech:     int,
	pop:      int,
	prod:     int,
	name:     [10]u8,
	name_len: int,
}

GOV_NAMES := [8]string{
	"Anarchy", "Feudal", "Multi-Government", "Dictatorship",
	"Communist", "Confederacy", "Democracy", "Corporate State",
}
ECO_NAMES := [8]string{
	"Rich Industrial", "Average Industrial", "Poor Industrial", "Mainly Industrial",
	"Mainly Agricultural", "Rich Agricultural", "Average Agricultural", "Poor Agricultural",
}

PAIRS := "..LEXEGEZACEBISOUSESARMAINDIREA.ERATENBERALAVETIEDORQUANTEISRION"

sys_name :: proc(s: ^System) -> string {
	return string(s.name[:s.name_len])
}

tweak :: proc(s: ^Seed) {
	t := s[0] + s[1] + s[2]
	s[0] = s[1]
	s[1] = s[2]
	s[2] = t
}

@(private = "file")
rot8 :: proc(x: u8) -> u8 {
	return (x << 1) | (x >> 7)
}

@(private = "file")
rot16 :: proc(x: u16) -> u16 {
	return u16(rot8(u8(x >> 8))) << 8 | u16(rot8(u8(x & 0xFF)))
}

next_galaxy_seed :: proc(s: Seed) -> Seed {
	return {rot16(s[0]), rot16(s[1]), rot16(s[2])}
}

make_system :: proc(s: ^Seed) -> System {
	sys: System
	sys.x = int(s[1] >> 8)
	sys.y = int(s[0] >> 8)
	sys.gov = int((s[1] >> 3) & 7)
	sys.eco = int((s[0] >> 8) & 7)
	if sys.gov <= 1 {
		sys.eco |= 2
	}
	sys.tech = int((s[1] >> 8) & 3) + (sys.eco ~ 7)
	sys.tech += sys.gov >> 1
	if sys.gov & 1 == 1 {
		sys.tech += 1
	}
	sys.pop = 4 * sys.tech + sys.eco + sys.gov + 1
	sys.prod = ((sys.eco ~ 7) + 3) * (sys.gov + 4) * sys.pop * 8

	long := s[0] & 64 != 0
	pairs: [4]int
	for i in 0 ..< 4 {
		pairs[i] = int(2 * ((s[2] >> 8) & 31))
		tweak(s)
	}
	n := 4 if long else 3
	for i in 0 ..< n {
		for k in 0 ..< 2 {
			c := PAIRS[pairs[i] + k]
			if c == '.' {
				continue
			}
			if sys.name_len > 0 {
				c += 32 // to lowercase
			}
			sys.name[sys.name_len] = c
			sys.name_len += 1
		}
	}
	return sys
}

gen_galaxy :: proc(galaxy_no: int) -> (out: [256]System) {
	seed := BASE_SEED
	for _ in 0 ..< galaxy_no {
		seed = next_galaxy_seed(seed)
	}
	for i in 0 ..< 256 {
		out[i] = make_system(&seed)
	}
	return
}

// Distance in tenths of a light year.
sys_dist :: proc(a, b: ^System) -> int {
	dx := a.x - b.x
	dy := a.y - b.y
	return int(4 * math.sqrt(f32(dx * dx + dy * dy / 4)))
}
