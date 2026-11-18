package main

import "core:fmt"

NUM_COMM :: 17

Commodity :: struct {
	name:   string,
	base:   int, // base price (tenths of credits / 4)
	grad:   int, // economy sensitivity
	base_q: int,
	mask:   int,
	unit:   string,
}

COMMODITIES := [NUM_COMM]Commodity{
	{"Food", 19, -2, 6, 0x01, "t"},
	{"Textiles", 20, -1, 10, 0x03, "t"},
	{"Radioactives", 65, -3, 2, 0x07, "t"},
	{"Slaves", 40, -5, 226, 0x1F, "t"},
	{"Liquor/Wines", 83, -5, 251, 0x0F, "t"},
	{"Luxuries", 196, 8, 54, 0x03, "t"},
	{"Narcotics", 235, 29, 8, 0x78, "t"},
	{"Computers", 154, 14, 56, 0x03, "t"},
	{"Machinery", 117, 6, 40, 0x07, "t"},
	{"Alloys", 78, 1, 17, 0x1F, "t"},
	{"Firearms", 124, 13, 29, 0x07, "t"},
	{"Furs", 176, -9, 220, 0x3F, "t"},
	{"Minerals", 32, -1, 53, 0x03, "t"},
	{"Gold", 97, -1, 66, 0x07, "kg"},
	{"Platinum", 171, -2, 55, 0x1F, "kg"},
	{"Gem-Stones", 45, -1, 250, 0x0F, "g"},
	{"Alien Items", 53, 15, 192, 0x07, "t"},
}

Market :: struct {
	price: [NUM_COMM]int, // tenths of a credit per unit
	qty:   [NUM_COMM]int,
}

hash_byte :: proc(seed: u32, i: int) -> int {
	h := seed * 2654435761 + u32(i) * 40503 + 12345
	h ~= h >> 13
	h *= 0x85ebca6b
	h ~= h >> 16
	return int(h >> 8) & 0xFF
}

make_market :: proc(sys: ^System, seed: u32) -> (m: Market) {
	for c, i in COMMODITIES {
		fluct := hash_byte(seed, i)
		product := sys.eco * c.grad
		changing := fluct & c.mask

		q := (c.base_q + changing - product) & 0xFF
		if q & 0x80 != 0 {
			q = 0
		}
		m.qty[i] = q & 0x3F

		p := (c.base + changing + product) & 0xFF
		m.price[i] = p * 4
	}
	return
}

// Money is stored in tenths of a credit.
cr :: proc(tenths: int) -> string {
	return fmt.tprintf("%d.%d cr", tenths / 10, tenths % 10)
}

cargo_used :: proc(cargo: [NUM_COMM]int) -> (n: int) {
	for c in cargo {
		n += c
	}
	return
}

rank_name :: proc(kills: int) -> string {
	switch {
	case kills >= 6400: return "ELITE"
	case kills >= 2560: return "Deadly"
	case kills >= 512:  return "Dangerous"
	case kills >= 128:  return "Competent"
	case kills >= 64:   return "Above Average"
	case kills >= 32:   return "Average"
	case kills >= 16:   return "Poor"
	case kills >= 8:    return "Mostly Harmless"
	}
	return "Harmless"
}
