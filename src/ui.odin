package main

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

EQUIP_NAMES := [4]cstring{"Fuel (fill tank)", "Missile", "Large cargo bay (+25t)", "Galactic hyperdrive"}
EQUIP_PRICE := [4]int{0, 300, 4000, 50000} // tenths of credits (fuel: per 0.1 LY = 2)

// ---------------------------------------------------------------- chart

chart_rect :: proc() -> (x, y, w, h: f32) {
	w = min(view.w - 40, 1024)
	h = w / 2
	if h > view.vh - 186 {
		h = view.vh - 186
		w = h * 2
	}
	x = (view.w - w) / 2
	y = 76
	return
}

chart_input :: proc() {
	dirs := [4]struct {
		key: rl.KeyboardKey,
		d:   [2]f32,
	}{{.LEFT, {-1, 0}}, {.RIGHT, {1, 0}}, {.UP, {0, -1}}, {.DOWN, {0, 1}}}
	for dd in dirs {
		if !rl.IsKeyPressed(dd.key) {
			continue
		}
		best := -1
		bs: f32 = 1e9
		c := &g.galaxy[g.cursor]
		for &s, i in g.galaxy {
			if i == g.cursor {
				continue
			}
			dx := f32(s.x - c.x)
			dy := f32(s.y - c.y) * 0.5
			l := math.sqrt(dx * dx + dy * dy)
			if l < 0.01 {
				continue
			}
			if (dx * dd.d.x + dy * dd.d.y) / l < 0.5 {
				continue
			}
			if l < bs {
				bs, best = l, i
			}
		}
		if best >= 0 {
			g.cursor = best
		}
	}
	if rl.IsMouseButtonPressed(.LEFT) {
		x, y, w, h := chart_rect()
		m := rl.GetMousePosition()
		bs: f32 = 400
		for &s, i in g.galaxy {
			sx := x + f32(s.x) / 256 * w
			sy := y + f32(s.y) / 256 * h
			d := (sx - m.x) * (sx - m.x) + (sy - m.y) * (sy - m.y)
			if d < bs {
				bs, g.cursor = d, i
			}
		}
	}
	if rl.IsKeyPressed(.ENTER) {
		g.target = g.cursor
		if g.target == g.cur {
			message("Destination cleared")
		} else {
			message("Destination: %s", sys_name(&g.galaxy[g.target]))
		}
	}
}

draw_chart :: proc() {
	x, y, w, h := chart_rect()
	text("GALACTIC CHART", x, 42, 24, COL_GREEN)
	text(fmt.ctprintf("Galaxy %d   Fuel %.1f LY", g.galaxy_no + 1, f32(g.p.fuel) / 10), x + 260, 48, 16, COL_AMBER)
	rl.DrawRectangleLines(i32(x), i32(y), i32(w), i32(h), COL_DIM)

	cur := cur_sys()
	// fuel range ellipse (distance = sqrt(dx^2 + dy^2/4) * 4 tenths of LY)
	rr := f32(g.p.fuel) / 4 // map units horizontally
	cxp := x + f32(cur.x) / 256 * w
	cyp := y + f32(cur.y) / 256 * h
	rl.DrawEllipseLines(i32(cxp), i32(cyp), rr / 256 * w, rr * 2 / 256 * h, COL_DIM)

	for &s, i in g.galaxy {
		sx := x + f32(s.x) / 256 * w
		sy := y + f32(s.y) / 256 * h
		rl.DrawCircleV({sx, sy}, 2, COL_GREEN)
		if w > 700 || i == g.cursor || i == g.target || i == g.cur {
			if i == g.cursor || i == g.cur || i == g.target || w > 900 {
				text(fmt.ctprintf("%s", sys_name(&s)), sx + 4, sy - 5, 10, COL_DIM if i != g.cursor else rl.WHITE)
			}
		}
	}
	rl.DrawCircleLinesV({cxp, cyp}, 6, COL_AMBER)
	if g.target != g.cur {
		t := &g.galaxy[g.target]
		tx := x + f32(t.x) / 256 * w
		ty := y + f32(t.y) / 256 * h
		rl.DrawLineV({tx - 6, ty - 6}, {tx + 6, ty + 6}, COL_RED)
		rl.DrawLineV({tx - 6, ty + 6}, {tx + 6, ty - 6}, COL_RED)
	}
	c := &g.galaxy[g.cursor]
	px := x + f32(c.x) / 256 * w
	py := y + f32(c.y) / 256 * h
	rl.DrawRectangleLines(i32(px) - 5, i32(py) - 5, 10, 10, rl.WHITE)

	iy := y + h + 10
	dist := sys_dist(cur, c)
	text(fmt.ctprintf("%s", sys_name(c)), x, iy, 22, rl.WHITE)
	reach := "IN RANGE" if dist <= g.p.fuel else "OUT OF RANGE"
	text(
		fmt.ctprintf("Distance %.1f LY  %s", f32(dist) / 10, reach),
		x + 220, iy + 4, 16, COL_GREEN if dist <= g.p.fuel else COL_RED,
	)
	text(
		fmt.ctprintf("%s  |  %s  |  Tech %d  |  Pop %.1fbn", GOV_NAMES[c.gov], ECO_NAMES[c.eco], c.tech + 1, f32(c.pop) / 10),
		x, iy + 30, 16, COL_CYAN,
	)
	text("Arrows/mouse: select   ENTER: set destination", x, iy + 56, 14, COL_DIM)
}

// ---------------------------------------------------------------- docked

docked_update :: proc() {
	if rl.IsKeyPressed(.F1) { g.screen = .Status }
	if rl.IsKeyPressed(.F2) { g.screen = .Market; g.sel = 0 }
	if rl.IsKeyPressed(.F3) { g.screen = .Chart; g.cursor = g.target }
	if rl.IsKeyPressed(.F4) { g.screen = .Equip; g.sel = 0 }
	if rl.IsKeyPressed(.F5) || rl.IsKeyPressed(.L) {
		launch()
		return
	}
	if rl.IsKeyPressed(.F9) {
		save_game()
		message("Game saved")
	}
	switch g.screen {
	case .Status:
	case .Chart:
		chart_input()
	case .Market:
		market_input()
	case .Equip:
		equip_input()
	}
}

market_input :: proc() {
	if rl.IsKeyPressed(.DOWN) { g.sel = (g.sel + 1) % NUM_COMM }
	if rl.IsKeyPressed(.UP) { g.sel = (g.sel + NUM_COMM - 1) % NUM_COMM }
	n := 10 if (rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT)) else 1
	if rl.IsKeyPressed(.B) || rl.IsKeyPressed(.RIGHT) {
		buy(g.sel, n)
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.LEFT) {
		sell(g.sel, n)
	}
}

buy :: proc(i, n: int) {
	p := &g.p
	for _ in 0 ..< n {
		if g.market.qty[i] <= 0 {
			message("None for sale")
			break
		}
		if p.cash < g.market.price[i] {
			message("Not enough cash")
			break
		}
		if cargo_used(p.cargo) >= p.cargo_cap {
			message("Cargo hold full")
			break
		}
		p.cash -= g.market.price[i]
		g.market.qty[i] -= 1
		p.cargo[i] += 1
	}
}

sell :: proc(i, n: int) {
	p := &g.p
	for _ in 0 ..< n {
		if p.cargo[i] <= 0 {
			message("None in hold")
			break
		}
		p.cash += g.market.price[i]
		g.market.qty[i] += 1
		p.cargo[i] -= 1
	}
}

equip_input :: proc() {
	if rl.IsKeyPressed(.DOWN) { g.sel = (g.sel + 1) % 4 }
	if rl.IsKeyPressed(.UP) { g.sel = (g.sel + 3) % 4 }
	if rl.IsKeyPressed(.ENTER) {
		buy_equip(g.sel)
	}
}

buy_equip :: proc(item: int) {
	p := &g.p
	switch item {
	case 0:
		need := MAX_FUEL - p.fuel
		cost := need * 2
		if need == 0 {
			message("Tank is full")
		} else if p.cash < cost {
			// buy as much as affordable
			can := p.cash / 2
			p.fuel += can
			p.cash -= can * 2
			message("Partial refuel")
		} else {
			p.fuel = MAX_FUEL
			p.cash -= cost
			message("Refuelled")
		}
	case 1:
		if p.missiles >= 4 {
			message("Missile rack full")
		} else if p.cash < EQUIP_PRICE[1] {
			message("Not enough cash")
		} else {
			p.cash -= EQUIP_PRICE[1]
			p.missiles += 1
		}
	case 2:
		if p.cargo_cap > 20 {
			message("Already fitted")
		} else if p.cash < EQUIP_PRICE[2] {
			message("Not enough cash")
		} else {
			p.cash -= EQUIP_PRICE[2]
			p.cargo_cap += 25
		}
	case 3:
		if p.gal_drive {
			message("Already fitted")
		} else if p.cash < EQUIP_PRICE[3] {
			message("Not enough cash")
		} else {
			p.cash -= EQUIP_PRICE[3]
			p.gal_drive = true
		}
	}
}

draw_docked :: proc() {
	s := cur_sys()
	rl.DrawRectangle(0, 0, i32(view.w), 36, {8, 14, 12, 255})
	text(
		fmt.ctprintf("%s  Station    F1 Status  F2 Market  F3 Chart  F4 Equip  F5/L Launch  F9 Save", sys_name(s)),
		12, 10, 16, COL_GREEN,
	)
	y: f32 = 60
	switch g.screen {
	case .Status:
		text("COMMANDER STATUS", 40, y, 28, COL_GREEN)
		p := &g.p
		lines := [?]cstring {
			fmt.ctprintf("System:   %s", sys_name(s)),
			fmt.ctprintf("Galaxy:   %d", g.galaxy_no + 1),
			fmt.ctprintf("Cash:     %d.%d cr", p.cash / 10, p.cash % 10),
			fmt.ctprintf("Fuel:     %.1f LY", f32(p.fuel) / 10),
			fmt.ctprintf("Rank:     %s  (%d kills)", rank_name(p.kills), p.kills),
			fmt.ctprintf("Missiles: %d", p.missiles),
			fmt.ctprintf("Cargo:    %d / %d t", cargo_used(p.cargo), p.cargo_cap),
			fmt.ctprintf("Gov:      %s", GOV_NAMES[s.gov]),
			fmt.ctprintf("Economy:  %s", ECO_NAMES[s.eco]),
			fmt.ctprintf("Tech:     %d", s.tech + 1),
		}
		for l, i in lines {
			text(l, 40, y + 50 + f32(i) * 26, 20, COL_CYAN)
		}
		yy := y + 50 + f32(len(lines)) * 26 + 10
		text("Hold:", 40, yy, 20, COL_GREEN)
		k := 0
		for n, i in p.cargo {
			if n > 0 {
				text(fmt.ctprintf("%dt %s", n, COMMODITIES[i].name), 60, yy + 26 + f32(k) * 20, 16, COL_AMBER)
				k += 1
			}
		}
		text("Launch (F5) and dock again with the slot: line up nose-in, match roll, slow below 220.", 40, view.h - 40, 14, COL_DIM)
	case .Market:
		text(fmt.ctprintf("%s MARKET", sys_name(s)), 40, y, 28, COL_GREEN)
		text("Item", 40, y + 44, 16, COL_DIM)
			text("Price", 230, y + 44, 16, COL_DIM)
			text("Stock", 330, y + 44, 16, COL_DIM)
			text("Hold", 450, y + 44, 16, COL_DIM)
		for c, i in COMMODITIES {
			col := COL_CYAN
			if i == g.sel {
				col = rl.WHITE
				rl.DrawRectangle(32, i32(y) + 66 + i32(i) * 24, 520, 22, {30, 60, 50, 255})
			}
			yy := y + 68 + f32(i) * 24
			text(fmt.ctprintf("%s", c.name), 40, yy, 18, col)
			pr := g.market.price[i]
			text(fmt.ctprintf("%d.%d", pr / 10, pr % 10), 230, yy, 18, col)
			text(fmt.ctprintf("%d%s", g.market.qty[i], c.unit), 330, yy, 18, col)
			text(fmt.ctprintf("%d", g.p.cargo[i]), 450, yy, 18, COL_AMBER)
		}
		text(
			fmt.ctprintf("Cash %d.%d cr    Hold %d/%dt", g.p.cash / 10, g.p.cash % 10, cargo_used(g.p.cargo), g.p.cargo_cap),
			40, y + 68 + 17 * 24 + 8, 18, COL_AMBER,
		)
		text("UP/DOWN select   B/Right buy   S/Left sell   (Shift = x10)", 40, view.h - 40, 14, COL_DIM)
	case .Chart:
		draw_chart()
	case .Equip:
		text("EQUIPMENT", 40, y, 28, COL_GREEN)
		for n, i in EQUIP_NAMES {
			col := rl.WHITE if i == g.sel else COL_CYAN
			price: string
			if i == 0 {
				price = fmt.tprintf("%d.%d cr", (MAX_FUEL - g.p.fuel) * 2 / 10, (MAX_FUEL - g.p.fuel) * 2 % 10)
			} else {
				price = fmt.tprintf("%d.%d cr", EQUIP_PRICE[i] / 10, EQUIP_PRICE[i] % 10)
			}
			text(fmt.ctprintf("%s    %s", n, price), 40, y + 60 + f32(i) * 34, 22, col)
		}
		text(fmt.ctprintf("Cash %d.%d cr", g.p.cash / 10, g.p.cash % 10), 40, y + 220, 20, COL_AMBER)
		text("UP/DOWN select   ENTER buy", 40, view.h - 40, 14, COL_DIM)
	}
	if g.msg_t > 0 {
		text_c(fmt.ctprintf("%s", msg_text()), view.cx, view.h - 70, 20, COL_AMBER)
	}
}
