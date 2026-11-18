package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import rl "vendor:raylib"

HUD_H :: 170.0
NEAR :: 5.0

COL_GREEN :: rl.Color{80, 255, 120, 255}
COL_CYAN :: rl.Color{80, 220, 255, 255}
COL_AMBER :: rl.Color{255, 190, 60, 255}
COL_RED :: rl.Color{255, 70, 70, 255}
COL_DIM :: rl.Color{70, 110, 90, 255}

View :: struct {
	w, h:  f32, // full window
	vh:    f32, // 3D viewport height
	cx, cy, focal: f32,
}

view: View

update_view :: proc() {
	view.w = f32(rl.GetScreenWidth())
	view.h = f32(rl.GetScreenHeight())
	view.vh = view.h - HUD_H
	view.cx = view.w * 0.5
	view.cy = view.vh * 0.5
	view.focal = view.w * 0.5 / math.tan(math.to_radians(f32(36)))
}

project :: proc(c: Vec3) -> rl.Vector2 {
	return {view.cx + c.x / c.z * view.focal, view.cy - c.y / c.z * view.focal}
}

draw_line3 :: proc(a, b: Vec3, col: rl.Color) {
	a, b := a, b
	if a.z < NEAR && b.z < NEAR {
		return
	}
	if a.z < NEAR {
		t := (NEAR - a.z) / (b.z - a.z)
		a = a + (b - a) * t
	} else if b.z < NEAR {
		t := (NEAR - b.z) / (a.z - b.z)
		b = b + (a - b) * t
	}
	rl.DrawLineV(project(a), project(b), col)
}

draw_model :: proc(id: ModelId, pos: Vec3, b: Basis, col: rl.Color) {
	m := &models[id]
	rel := pos - g.p.pos
	// cull anything entirely behind the camera
	if linalg.dot(rel, g.p.b.f) < -m.radius {
		return
	}
	pts: [32]Vec3
	for v, i in m.verts {
		w := rel + to_world(b, v)
		pts[i] = to_local(g.p.b, w)
	}
	for e in m.edges {
		draw_line3(pts[e[0]], pts[e[1]], col)
	}
}

kind_color :: proc(e: ^Entity) -> rl.Color {
	switch e.kind {
	case .Pirate:   return COL_RED
	case .Trader:   return COL_GREEN
	case .Police:   return COL_CYAN
	case .Asteroid: return {160, 140, 110, 255}
	case .Canister: return COL_AMBER
	case .Missile:  return rl.WHITE
	case .Debris:   return COL_AMBER
	}
	return rl.WHITE
}

draw_stars :: proc() {
	B :: 4000.0
	p := &g.p
	for s in g.stars {
		d := s - p.pos
		rel := Vec3 {
			d.x - B * math.floor(d.x / B + 0.5),
			d.y - B * math.floor(d.y / B + 0.5),
			d.z - B * math.floor(d.z / B + 0.5),
		}
		c := to_local(p.b, rel)
		if c.z < NEAR {
			continue
		}
		shade := u8(clamp(255 - linalg.length(rel) * 0.06, 60, 255))
		col := rl.Color{shade, shade, shade, 255}
		a := project(c)
		if p.speed > 30 {
			c2 := to_local(p.b, rel + p.b.f * (-p.speed * 0.05))
			if c2.z > NEAR {
				rl.DrawLineV(a, project(c2), col)
				continue
			}
		}
		rl.DrawPixelV(a, col)
	}
}

draw_world :: proc() {
	draw_stars()
	draw_model(.Station, g.station.pos, g.station.b, COL_CYAN)
	for &e in g.ents {
		if e.alive {
			draw_model(e.model, e.pos, e.b, kind_color(&e))
		}
	}
	// laser beams
	if g.laser_vis > 0 {
		cx, cy := view.cx, view.cy
		rl.DrawLineV({view.w * 0.2, view.vh}, {cx, cy}, COL_RED)
		rl.DrawLineV({view.w * 0.8, view.vh}, {cx, cy}, COL_RED)
	}
	if g.spark_t > 0 {
		c := to_local(g.p.b, g.spark - g.p.pos)
		if c.z > NEAR {
			pt := project(c)
			rl.DrawCircleLinesV(pt, 8 + g.spark_t * 80, rl.WHITE)
		}
	}
	// crosshair
	cx, cy := view.cx, view.cy
	rl.DrawLineV({cx - 14, cy}, {cx - 5, cy}, COL_GREEN)
	rl.DrawLineV({cx + 5, cy}, {cx + 14, cy}, COL_GREEN)
	rl.DrawLineV({cx, cy - 14}, {cx, cy - 5}, COL_GREEN)
	rl.DrawLineV({cx, cy + 5}, {cx, cy + 14}, COL_GREEN)
}

text :: proc(s: cstring, x, y: f32, size: i32, col: rl.Color) {
	rl.DrawText(s, i32(x), i32(y), size, col)
}

text_c :: proc(s: cstring, cx, y: f32, size: i32, col: rl.Color) {
	w := rl.MeasureText(s, size)
	rl.DrawText(s, i32(cx) - w / 2, i32(y), size, col)
}

bar :: proc(label: cstring, x, y, w: f32, v, vmax: f32, col: rl.Color) {
	text(label, x, y, 12, COL_DIM)
	bx := x + 62
	rl.DrawRectangleLines(i32(bx), i32(y), i32(w), 12, COL_DIM)
	fw := clamp(v / vmax, 0, 1) * (w - 4)
	rl.DrawRectangle(i32(bx) + 2, i32(y) + 2, i32(fw), 8, col)
}

draw_hud :: proc() {
	p := &g.p
	top := view.vh
	rl.DrawRectangle(0, i32(top), i32(view.w), i32(HUD_H), {8, 14, 12, 255})
	rl.DrawLine(0, i32(top), i32(view.w), i32(top), COL_DIM)

	// left: bars
	x: f32 = 16
	y := top + 14
	bar("SHIELD", x, y, 140, p.shield, 100, COL_CYAN)
	bar("HULL", x, y + 22, 140, p.hull, 100, COL_RED if p.hull < 35 else COL_GREEN)
	bar("FUEL", x, y + 44, 140, f32(p.fuel), MAX_FUEL, COL_AMBER)
	bar("LASER", x, y + 66, 140, p.temp, 100, COL_RED if p.temp > 80 else COL_GREEN)
	bar("SPEED", x, y + 88, 140, p.speed, MAX_SPEED, COL_GREEN)
	text(fmt.ctprintf("MISSILES %d", p.missiles), x, y + 112, 14, COL_AMBER)

	// scanner
	scx := view.w * 0.5
	scy := top + HUD_H * 0.5 + 8
	rx, ry: f32 = 150, 55
	rl.DrawEllipseLines(i32(scx), i32(scy), rx, ry, COL_DIM)
	rl.DrawEllipseLines(i32(scx), i32(scy), rx * 0.5, ry * 0.5, {40, 70, 55, 255})
	rl.DrawLine(i32(scx - rx), i32(scy), i32(scx + rx), i32(scy), {40, 70, 55, 255})
	rl.DrawLine(i32(scx), i32(scy - ry), i32(scx), i32(scy + ry), {40, 70, 55, 255})
	scan_dot :: proc(world: Vec3, col: rl.Color, scx, scy, rx, ry: f32) {
		l := to_local(g.p.b, world - g.p.pos)
		// horizontal plane: x right, z forward
		ph := Vec3{l.x, 0, l.z}
		d := linalg.length(ph)
		if d > SCAN_RANGE {
			ph *= SCAN_RANGE / d
		}
		sx := scx + ph.x / SCAN_RANGE * rx
		sy := scy - ph.z / SCAN_RANGE * ry
		h := clamp(l.y / SCAN_RANGE, -1, 1) * ry
		rl.DrawLineV({sx, sy}, {sx, sy - h}, col)
		rl.DrawRectangle(i32(sx) - 2, i32(sy - h) - 2, 4, 4, col)
	}
	scan_dot(g.station.pos, COL_CYAN, scx, scy, rx, ry)
	for &e in g.ents {
		if e.alive && (e.kind == .Pirate || e.kind == .Trader || e.kind == .Police || e.kind == .Missile) {
			scan_dot(e.pos, kind_color(&e), scx, scy, rx, ry)
		}
	}

	// compass (station direction)
	ccx := scx + rx + 60
	ccy := scy
	rl.DrawCircleLines(i32(ccx), i32(ccy), 34, COL_DIM)
	dir := to_local(p.b, g.station.pos - p.pos)
	dl := linalg.length(dir)
	if dl > 1 {
		n := dir / dl
		pt := rl.Vector2{ccx + n.x * 30, ccy - n.y * 30}
		if n.z > 0 {
			rl.DrawCircleV(pt, 4, COL_CYAN)
		} else {
			rl.DrawCircleLinesV(pt, 4, COL_CYAN)
		}
	}
	text("STATION", ccx - 26, ccy + 38, 12, COL_DIM)
	text(fmt.ctprintf("%.1fkm", dl / 1000), ccx - 20, ccy + 52, 12, COL_CYAN)

	// right: info
	rxp := view.w - 230
	text(fmt.ctprintf("%s", sys_name(cur_sys())), rxp, top + 14, 18, COL_GREEN)
	text(fmt.ctprintf("Cash  %d.%d cr", p.cash / 10, p.cash % 10), rxp, top + 40, 14, COL_AMBER)
	text(fmt.ctprintf("Rank  %s", rank_name(p.kills)), rxp, top + 60, 14, COL_GREEN)
	text(fmt.ctprintf("Kills %d", p.kills), rxp, top + 80, 14, COL_GREEN)
	text(fmt.ctprintf("Cargo %d/%dt", cargo_used(p.cargo), p.cargo_cap), rxp, top + 100, 14, COL_GREEN)
	if p.fugitive {
		text("FUGITIVE", rxp, top + 122, 16, COL_RED)
	} else {
		text("CLEAN", rxp, top + 122, 16, COL_GREEN)
	}
	if g.target != g.cur {
		text(
			fmt.ctprintf("Dest %s (%.1f LY)", sys_name(&g.galaxy[g.target]), f32(jump_cost(g.target)) / 10),
			rxp - 20, top + 146, 12, COL_DIM,
		)
	}

	// docking hint
	if dl < 3500 {
		can, _ := dock_check()
		if can {
			text_c("DOCKING", view.cx, 20, 20, COL_GREEN)
		}
	}
}

draw_flight :: proc() {
	if g.chart_open {
		draw_chart()
	} else {
		draw_world()
	}
	draw_hud()
	if g.msg_t > 0 {
		text_c(fmt.ctprintf("%s", msg_text()), view.cx, 40, 20, COL_AMBER)
	}
	if g.flash > 0 {
		c := g.flash_col
		c.a = u8(clamp(g.flash * 300, 0, 120))
		rl.DrawRectangle(0, 0, i32(view.w), i32(view.vh), c)
	}
	text("F3 chart  H jump  SPACE fire  M missile  W/S speed  arrows roll/pitch  Q/E yaw", 10, 6, 12, COL_DIM)
}

draw_hyper :: proc() {
	t := 1 - g.hyper_t / (2.0 if g.hyper_gal else 1.5)
	for i in 0 ..< 120 {
		a := f32(i) * 2.39996
		r0 := (f32(i % 7) * 0.05 + t * t * 1.2) * view.w * 0.4
		r1 := r0 + (20 + t * 400)
		dx, dy := math.cos(a), math.sin(a)
		rl.DrawLineV(
			{view.cx + dx * r0, view.cy + dy * r0},
			{view.cx + dx * r1, view.cy + dy * r1},
			rl.WHITE if i % 3 == 0 else COL_CYAN,
		)
	}
	text_c("HYPERSPACE", view.cx, view.vh - 60, 24, COL_CYAN)
}

draw_dead :: proc() {
	draw_stars()
	for &e in g.ents {
		if e.alive || e.kind == .Debris {
			if e.life > 0 || e.kind != .Debris {
				draw_model(e.model, e.pos, e.b, kind_color(&e))
			}
		}
	}
	text_c("GAME OVER", view.cx, view.vh * 0.4, 48, COL_RED)
	if g.dead_t <= 0 {
		text_c("Press ENTER to continue from last save", view.cx, view.vh * 0.4 + 70, 20, COL_GREEN)
	}
}
