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
COL_DIM :: rl.Color{120, 170, 145, 255}
COL_PLANET :: rl.Color{190, 140, 255, 255}

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

// Bitmask of faces facing the camera; b/cb are model/camera bases, pts are model vertices in camera space.
face_vis :: proc(id: ModelId, m: ^Model, b, cb: Basis, pts: []Vec3) -> (vis: u32) {
	for n, i in m.fnorm {
		// face is visible when the camera is on its outward side
		if linalg.dot(to_local(cb, to_world(b, n)), pts[m.fvert[i]]) < 0 {
			vis |= 1 << u32(i)
		}
	}
	// slot faces are only seen through the front opening (face 24); a face-only test can't occlude them
	if id == .Station && vis & (1 << 24) == 0 do vis &= ~u32(0xF << 20 | 1 << 25)
	return
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
	vis := face_vis(id, m, b, g.p.b, pts[:])
	for e, i in m.edges {
		if id == .Station && e[1] >= 20 { // slot interior: only the part seen through the opening
			cam := to_local(b, -rel) // camera in model space
			if cam.z <= ST_L { continue }
			a, c, ok := slot_clip(cam, m.verts[e[0]], m.verts[e[1]])
			if ok {
				draw_line3(to_local(g.p.b, rel + to_world(b, a)), to_local(g.p.b, rel + to_world(b, c)), col)
			}
		} else if m.emask[i] == 0 || m.emask[i] & vis != 0 {
			draw_line3(pts[e[0]], pts[e[1]], col)
		}
	}
}

// Clip a station-local segment to the pyramid from cam through the docking opening.
slot_clip :: proc(cam, p0, p1: Vec3) -> (a, b: Vec3, ok: bool) {
	sx := [4]f32{-SLOT_W, SLOT_W, SLOT_W, -SLOT_W}
	sy := [4]f32{-SLOT_H, -SLOT_H, SLOT_H, SLOT_H}
	mid := Vec3{0, 0, ST_L} - cam
	t0, t1: f32 = 0, 1
	for k in 0 ..< 4 {
		n := (k + 1) % 4
		nrm := linalg.cross(Vec3{sx[k], sy[k], ST_L} - cam, Vec3{sx[n], sy[n], ST_L} - cam)
		if linalg.dot(nrm, mid) < 0 { nrm = -nrm }
		f0, f1 := linalg.dot(nrm, p0 - cam), linalg.dot(nrm, p1 - cam)
		if f0 < 0 && f1 < 0 { return }
		if f0 < 0 { t0 = max(t0, f0 / (f0 - f1)) } else if f1 < 0 { t1 = min(t1, f0 / (f0 - f1)) }
	}
	if t1 - t0 < 1e-4 { return }
	return p0 + (p1 - p0) * t0, p0 + (p1 - p0) * t1, true
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

// Cut a sphere-surface segment (qa, qb: camera-space offsets from the centre c, radius r) to its
// camera-facing part. ok is false when none of it faces the camera.
horizon_cut :: proc(c, qa, qb: Vec3, r: f32) -> (a, b: Vec3, ok: bool) {
	a, b = qa, qb
	fa, fb := linalg.dot(qa, c) + r * r, linalg.dot(qb, c) + r * r // < 0: faces the camera
	if fa >= 0 && fb >= 0 { return }
	if fa >= 0 || fb >= 0 {
		// bisect on the sphere (a straight-line interpolation drifts off the horizon)
		on_sphere :: proc(qa, qb: Vec3, t, r: f32) -> Vec3 {
			return linalg.normalize(qa + (qb - qa) * t) * r
		}
		lo, hi: f32 = 0, 1 // lo stays on a's side of the horizon
		for _ in 0 ..< 20 {
			m := (lo + hi) / 2
			if (linalg.dot(on_sphere(qa, qb, m, r), c) + r * r >= 0) == (fa >= 0) { lo = m } else { hi = m }
		}
		cut := on_sphere(qa, qb, (lo + hi) / 2, r)
		if fa >= 0 { a = cut } else { b = cut }
	}
	return a, b, true
}

// Draw the camera-facing part of a polyline of sphere points.
planet_arc :: proc(c: Vec3, pts: []Vec3, r: f32) {
	for k in 0 ..< len(pts) - 1 {
		if a, b, ok := horizon_cut(c, pts[k], pts[k + 1], r); ok {
			draw_line3(c + a, c + b, COL_PLANET)
		}
	}
}

draw_planet :: proc() {
	pl := &g.planet
	c := to_local(g.p.b, pl.pos - g.p.pos)
	d := linalg.length(c)
	if d <= pl.r { return }
	N :: 32
	// outline: the horizon circle, drawn in 3D so perspective makes it the right ellipse off-axis
	n := c / d
	ax := linalg.normalize(linalg.cross(n, Vec3{0, 1, 0} if abs(n.y) < 0.9 else Vec3{1, 0, 0}))
	ay := linalg.cross(n, ax)
	hc, hr := c * (1 - pl.r * pl.r / (d * d)), pl.r * math.sqrt(1 - pl.r * pl.r / (d * d))
	for k in 0 ..< N * 2 {
		a0, a1 := 2 * math.PI * f32(k) / (N * 2), 2 * math.PI * f32(k + 1) / (N * 2)
		draw_line3(
			hc + hr * (math.cos(a0) * ax + math.sin(a0) * ay),
			hc + hr * (math.cos(a1) * ax + math.sin(a1) * ay),
			COL_PLANET,
		)
	}
	pt :: proc(lat, lon: f32) -> Vec3 {
		return to_local(g.p.b, g.planet.r * Vec3{math.cos(lat) * math.cos(lon), math.sin(lat), math.cos(lat) * math.sin(lon)})
	}
	ring: [N + 1]Vec3
	for i in 1 ..= pl.parallels {
		lat := -math.PI / 2 + math.PI * f32(i) / f32(pl.parallels + 1)
		for k in 0 ..= N { ring[k] = pt(lat, 2 * math.PI * f32(k) / N) }
		planet_arc(c, ring[:], pl.r)
	}
	for j in 0 ..< pl.meridians {
		lon := 2 * math.PI * f32(j) / f32(pl.meridians)
		for k in 0 ..= N / 2 { ring[k] = pt(-math.PI / 2 + math.PI * f32(k) / (N / 2), lon) }
		planet_arc(c, ring[:N / 2 + 1], pl.r)
	}
}

draw_world :: proc() {
	draw_stars()
	draw_planet()
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

font: rl.Font
FONT_DATA :: #load("../assets/JetBrainsMono-Regular.ttf")

init_font :: proc() {
	font = rl.LoadFontFromMemory(".ttf", raw_data(FONT_DATA), i32(len(FONT_DATA)), 48, nil, 0)
	rl.SetTextureFilter(font.texture, .BILINEAR)
}

text :: proc(s: cstring, x, y: f32, size: i32, col: rl.Color) {
	rl.DrawTextEx(font, s, {x, y}, f32(max(size, 14)), 0, col)
}

text_c :: proc(s: cstring, cx, y: f32, size: i32, col: rl.Color) {
	sz := max(size, 14)
	w := rl.MeasureTextEx(font, s, f32(sz), 0).x
	rl.DrawTextEx(font, s, {cx - w / 2, y}, f32(sz), 0, col)
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
	scan_dot(g.planet.pos, COL_PLANET, scx, scy, rx, ry)
	for &e in g.ents {
		if e.alive && (e.kind == .Pirate || e.kind == .Trader || e.kind == .Police || e.kind == .Missile) {
			scan_dot(e.pos, kind_color(&e), scx, scy, rx, ry)
		}
	}

	// compass (station or planet direction, T toggles)
	tgt, tgt_name, tgt_col, tgt_off := g.station.pos, cstring("STATION"), COL_CYAN, f32(0)
	if g.compass_planet {
		tgt, tgt_name, tgt_col, tgt_off = g.planet.pos, "PLANET", COL_PLANET, g.planet.r
	}
	ccx := scx + rx + 60
	ccy := scy
	rl.DrawCircleLines(i32(ccx), i32(ccy), 34, COL_DIM)
	dir := to_local(p.b, tgt - p.pos)
	dl := linalg.length(dir)
	if dl > 1 {
		n := dir / dl
		pt := rl.Vector2{ccx + n.x * 30, ccy - n.y * 30}
		if n.z > 0 {
			rl.DrawCircleV(pt, 4, tgt_col)
		} else {
			rl.DrawCircleLinesV(pt, 4, tgt_col)
		}
	}
	text(tgt_name, ccx - 26, ccy + 38, 12, COL_DIM)
	text(fmt.ctprintf("%.1fkm", max(dl - tgt_off, 0) / 1000), ccx - 20, ccy + 52, 12, tgt_col)

	// right: info
	rxp := view.w - 230
	text(fmt.ctprintf("%s", sys_name(cur_sys())), rxp, top + 14, 18, COL_GREEN)
	text(fmt.ctprintf("Cash  %d.%d cr", p.cash / 10, p.cash % 10), rxp, top + 40, 16, COL_AMBER)
	text(fmt.ctprintf("Rank  %s", rank_name(p.kills)), rxp, top + 60, 16, COL_GREEN)
	text(fmt.ctprintf("Kills %d", p.kills), rxp, top + 80, 16, COL_GREEN)
	text(fmt.ctprintf("Cargo %d/%dt", cargo_used(p.cargo), p.cargo_cap), rxp, top + 100, 16, COL_GREEN)
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
	if linalg.length(g.station.pos - p.pos) < 3500 {
		can, _ := dock_check()
		if can {
			text_c("DOCKING", view.cx, 20, 20, COL_GREEN)
		}
	}
}

draw_flight :: proc() {
	if g.screen == .Chart {
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
