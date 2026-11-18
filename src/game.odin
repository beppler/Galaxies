package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/rand"
import rl "vendor:raylib"

MAX_SPEED :: 400.0
LASER_RANGE :: 4000.0
SCAN_RANGE :: 6000.0
MAX_FUEL :: 70

State :: enum {
	Docked,
	Flight,
	Hyper,
	Dead,
}
Screen :: enum {
	Status,
	Market,
	Chart,
	Equip,
}
Kind :: enum u8 {
	Pirate,
	Trader,
	Police,
	Asteroid,
	Canister,
	Missile,
	Debris,
}

Entity :: struct {
	id:          int,
	kind:        Kind,
	model:       ModelId,
	pos, vel:    Vec3,
	b:           Basis,
	speed:       f32,
	max_speed:   f32,
	turn:        f32,
	hp:          f32,
	max_hp:      f32,
	timer:       f32,
	life:        f32,
	fire_cd:     f32,
	cargo:       int,
	angry:       bool,
	from_player: bool,
	target_id:   int,
	tgt:         Vec3,
	spin:        f32,
	alive:       bool,
}

Player :: struct {
	pos:                  Vec3,
	prev:                 Vec3,
	b:                    Basis,
	speed:                f32,
	shield, hull, temp:   f32,
	fuel:                 int, // tenths of a light year
	cash:                 int, // tenths of a credit
	missiles:             int,
	cargo:                [NUM_COMM]int,
	cargo_cap:            int,
	kills:                int,
	fugitive:             bool,
	gal_drive:            bool,
	laser_cd, missile_cd: f32,
}

Game :: struct {
	state:      State,
	screen:     Screen,
	galaxy_no:  int,
	galaxy:     [256]System,
	cur:        int,
	target:     int,
	cursor:     int,
	market:     Market,
	epoch:      u32,
	p:          Player,
	station:    Entity,
	ents:       [dynamic]Entity,
	pending:    [dynamic]Entity,
	next_id:    int,
	spawn_t:    f32,
	hyper_t:    f32,
	hyper_gal:  bool,
	dead_t:     f32,
	flash:      f32,
	flash_col:  rl.Color,
	laser_vis:  f32,
	spark:      Vec3,
	spark_t:    f32,
	msg_buf:    [96]u8,
	msg_len:    int,
	msg_t:      f32,
	sel:        int,
	chart_open: bool,
	stars:      [256]Vec3,
	time:       f32,
}

g: Game

rnd :: proc() -> f32 {
	return rand.float32()
}

message :: proc(format: string, args: ..any) {
	s := fmt.bprintf(g.msg_buf[:], format, ..args)
	g.msg_len = len(s)
	g.msg_t = 3.5
}

msg_text :: proc() -> string {
	return string(g.msg_buf[:g.msg_len])
}

cur_sys :: proc() -> ^System {
	return &g.galaxy[g.cur]
}

// ---------------------------------------------------------------- setup

new_game :: proc() {
	g.galaxy_no = 0
	g.galaxy = gen_galaxy(0)
	g.cur = START_SYSTEM
	g.target = START_SYSTEM
	g.cursor = START_SYSTEM
	g.p = Player {
		b         = basis_identity(),
		shield    = 100,
		hull      = 100,
		fuel      = MAX_FUEL,
		cash      = 1000,
		missiles  = 3,
		cargo_cap = 20,
	}
	g.state = .Docked
	g.screen = .Status
	g.epoch = 1
	setup_system()
	for &s in g.stars {
		s = {rnd() * 4000, rnd() * 4000, rnd() * 4000}
	}
}

setup_system :: proc() {
	g.market = make_market(cur_sys(), u32(g.cur) * 977 + u32(g.galaxy_no) * 31337 + g.epoch * 7919)
}

clear_world :: proc() {
	clear(&g.ents)
	clear(&g.pending)
	g.station = Entity {
		kind  = .Debris,
		model = .Station,
		b     = basis_identity(),
		spin  = 0.3,
		alive = true,
	}
}

spawn :: proc(e: Entity) {
	e := e
	g.next_id += 1
	e.id = g.next_id
	e.alive = true
	append(&g.pending, e)
}

flush_pending :: proc() {
	for e in g.pending {
		append(&g.ents, e)
	}
	clear(&g.pending)
}

find_ent :: proc(id: int) -> ^Entity {
	for &e in g.ents {
		if e.id == id && e.alive {
			return &e
		}
	}
	return nil
}

populate_space :: proc() {
	for _ in 0 ..< 4 {
		d := random_unit(rnd) * (1500 + rnd() * 3500)
		spawn(Entity {
			kind = .Asteroid, model = .Asteroid, pos = d,
			b = basis_identity(), hp = 60, max_hp = 60,
			vel = random_unit(rnd) * 15, spin = rnd() - 0.5,
		})
	}
	flush_pending()
}

launch :: proc() {
	clear_world()
	p := &g.p
	p.b = basis_identity()
	p.pos = {0, 0, ST_L + 250}
	p.speed = 120
	p.prev = p.pos
	p.laser_cd, p.missile_cd, p.temp = 0, 0, 0
	g.state = .Flight
	g.chart_open = false
	g.spawn_t = 8 + rnd() * 8
	populate_space()
	save_game()
	message("Launch! Good luck, Commander.")
}

arrive_by_jump :: proc() {
	clear_world()
	g.epoch += 1
	setup_system()
	p := &g.p
	p.fugitive = false
	dir := random_unit(rnd)
	p.pos = dir * 9000
	p.prev = p.pos
	p.b = basis_identity()
	p.b.f = -dir
	p.b.u = {0, 1, 0}
	if abs(linalg.dot(p.b.u, p.b.f)) > 0.95 {
		p.b.u = {1, 0, 0}
	}
	orthonormalize(&p.b)
	p.speed = 150
	g.state = .Flight
	g.spawn_t = 6 + rnd() * 6
	populate_space()
	message("Arrived at %s", sys_name(cur_sys()))
}

do_dock :: proc() {
	g.state = .Docked
	g.screen = .Status
	g.p.speed = 0
	g.p.shield = 100
	clear(&g.ents)
	clear(&g.pending)
	play(.Dock)
	save_game()
}

// ---------------------------------------------------------------- hyperspace

jump_cost :: proc(target: int) -> int {
	return sys_dist(cur_sys(), &g.galaxy[target])
}

can_jump :: proc() -> bool {
	return g.target != g.cur && jump_cost(g.target) <= g.p.fuel
}

start_jump :: proc() {
	if g.target == g.cur {
		message("Select a destination on the chart (F3)")
		return
	}
	if !can_jump() {
		message("Insufficient fuel / out of range")
		return
	}
	g.p.fuel -= jump_cost(g.target)
	g.hyper_t = 1.5
	g.hyper_gal = false
	g.state = .Hyper
	play(.Hyper)
}

start_galactic_jump :: proc() {
	if !g.p.gal_drive {
		message("No galactic hyperdrive fitted")
		return
	}
	g.p.gal_drive = false
	g.hyper_t = 2.0
	g.hyper_gal = true
	g.state = .Hyper
	play(.Hyper)
}

finish_jump :: proc() {
	if g.hyper_gal {
		g.galaxy_no = (g.galaxy_no + 1) % 8
		g.galaxy = gen_galaxy(g.galaxy_no)
		g.p.fuel = MAX_FUEL
		g.cur = g.cur // keep index: neighbouring region in new galaxy
		g.target = g.cur
	} else {
		g.cur = g.target
	}
	g.cursor = g.cur
	arrive_by_jump()
}

// ---------------------------------------------------------------- combat

damage_player :: proc(amount: f32) {
	p := &g.p
	rem := amount
	if p.shield > 0 {
		absorbed := min(p.shield, rem)
		p.shield -= absorbed
		rem -= absorbed
	}
	p.hull -= rem
	g.flash = 0.35
	g.flash_col = rl.RED
	play(.Hit)
}

explode :: proc(pos: Vec3, n: int) {
	for _ in 0 ..< n {
		bb := basis_identity()
		bb.f = random_unit(rnd)
		bb.u = random_unit(rnd)
		orthonormalize(&bb)
		spawn(Entity {
			kind = .Debris, model = .Shard, pos = pos, b = bb,
			vel = random_unit(rnd) * (80 + rnd() * 220), life = 0.8 + rnd() * 1.0,
		})
	}
	play(.Boom)
}

drop_canister :: proc(pos: Vec3, item: int) {
	spawn(Entity {
		kind = .Canister, model = .Canister, pos = pos, b = basis_identity(),
		vel = random_unit(rnd) * 40, cargo = item, life = 120, spin = 1,
	})
}

kill_entity :: proc(e: ^Entity, by_player: bool) {
	e.alive = false
	explode(e.pos, 8)
	#partial switch e.kind {
	case .Pirate:
		if by_player {
			g.p.kills += 1
			bounty := 1000 if e.model == .Sidewinder else 2500
			g.p.cash += bounty
			message("Pirate destroyed! Bounty %d.%d cr", bounty / 10, bounty % 10)
		}
		if rnd() < 0.5 {
			loot := [4]int{3, 6, 10, 7}
			drop_canister(e.pos, loot[rand.int_max(4)])
		}
	case .Trader:
		if by_player {
			g.p.fugitive = true
		}
		for _ in 0 ..< 1 + rand.int_max(3) {
			drop_canister(e.pos + random_unit(rnd) * 30, rand.int_max(NUM_COMM))
		}
	case .Police:
		if by_player {
			g.p.fugitive = true
			g.p.kills += 1
		}
	case .Asteroid:
		for _ in 0 ..< rand.int_max(3) {
			drop_canister(e.pos + random_unit(rnd) * 30, 12) // minerals
		}
	}
}

hit_entity :: proc(e: ^Entity, dmg: f32, by_player: bool) {
	e.hp -= dmg
	e.angry = true
	if by_player && (e.kind == .Police || e.kind == .Trader) {
		g.p.fugitive = true
	}
	if e.hp <= 0 {
		kill_entity(e, by_player)
	}
}

targetable :: proc(e: ^Entity) -> bool {
	return e.alive && (e.kind == .Pirate || e.kind == .Trader || e.kind == .Police || e.kind == .Asteroid)
}

fire_laser :: proc() {
	p := &g.p
	p.laser_cd = 0.2
	p.temp += 8
	g.laser_vis = 0.08
	play(.Laser)
	best := -1
	best_t: f32 = LASER_RANGE
	for &e, i in g.ents {
		if !targetable(&e) {
			continue
		}
		rel := e.pos - p.pos
		t := linalg.dot(rel, p.b.f)
		if t <= 0 || t >= best_t {
			continue
		}
		perp := linalg.length(rel - p.b.f * t)
		if perp < models[e.model].radius * 0.9 {
			best, best_t = i, t
		}
	}
	if best >= 0 {
		e := &g.ents[best]
		g.spark = e.pos - p.b.f * models[e.model].radius * 0.5
		g.spark_t = 0.12
		hit_entity(e, 14, true)
	}
}

fire_missile :: proc() {
	p := &g.p
	if p.missiles <= 0 {
		message("No missiles")
		return
	}
	// lock nearest hostile in front
	tid := 0
	bd: f32 = 8000
	for &e in g.ents {
		if !targetable(&e) || e.kind == .Asteroid {
			continue
		}
		rel := e.pos - p.pos
		d := linalg.length(rel)
		if d < bd && linalg.dot(rel / d, p.b.f) > 0.7 {
			bd, tid = d, e.id
		}
	}
	p.missiles -= 1
	p.missile_cd = 1
	spawn(Entity {
		kind = .Missile, model = .Missile, pos = p.pos + p.b.f * 60, b = p.b,
		speed = max(p.speed, 300), target_id = tid, life = 8, from_player = true,
		turn = 2.5,
	})
	play(.Laser)
}

detonate_missile :: proc(m: ^Entity) {
	m.alive = false
	explode(m.pos, 10)
	for &e, _ in g.ents {
		if targetable(&e) && linalg.length(e.pos - m.pos) < 250 + models[e.model].radius {
			hit_entity(&e, 120, m.from_player)
		}
	}
}

// ---------------------------------------------------------------- AI

steer :: proc(e: ^Entity, target: Vec3, dt: f32) {
	d := to_local(e.b, target - e.pos)
	l := linalg.length(d)
	if l < 0.001 {
		return
	}
	n := d / l
	py := clamp(n.y * 4, -1, 1)
	yw := clamp(n.x * 4, -1, 1)
	if n.z < 0 && abs(n.x) < 0.15 && abs(n.y) < 0.15 {
		yw = 1
	}
	pitch(&e.b, py * e.turn * dt)
	yaw(&e.b, yw * e.turn * dt)
	orthonormalize(&e.b)
}

enemy_fire :: proc(e: ^Entity) {
	p := &g.p
	e.fire_cd = 0.6 + rnd() * 0.8
	if rnd() < 0.55 {
		damage_player(5 if e.kind == .Pirate else 4)
	} else {
		play(.Laser)
	}
}

update_ship_ai :: proc(e: ^Entity, dt: f32) {
	p := &g.p
	hostile := e.kind == .Pirate || (e.kind == .Police && (p.fugitive || e.angry))
	e.fire_cd -= dt
	rel := p.pos - e.pos
	dist := linalg.length(rel)
	if hostile {
		if e.hp < e.max_hp * 0.25 {
			steer(e, e.pos - rel * 2, dt) // flee
			e.speed = e.max_speed
			e.timer += dt
			if e.timer > 12 {
				e.alive = false
			}
		} else {
			steer(e, p.pos, dt)
			if dist > 900 {
				e.speed = e.max_speed
			} else if dist > 350 {
				e.speed = e.max_speed * 0.6
			} else {
				e.speed = e.max_speed * 0.3
			}
			facing := linalg.dot(e.b.f, rel / max(dist, 1))
			if dist < 2500 && facing > 0.97 && e.fire_cd <= 0 {
				enemy_fire(e)
			}
		}
	} else {
		// wander between waypoints
		if linalg.length(e.tgt - e.pos) < 300 || e.tgt == {0, 0, 0} {
			e.tgt = random_unit(rnd) * 8000
		}
		steer(e, e.tgt, dt)
		e.speed = e.max_speed * 0.5
	}
	e.pos += e.b.f * e.speed * dt
	if dist > 20000 {
		e.alive = false
	}
}

spawn_enemy :: proc() {
	p := &g.p
	gov := cur_sys().gov
	pirate_table := [8]f32{0.65, 0.55, 0.45, 0.4, 0.3, 0.25, 0.15, 0.1}
	pirate_p := pirate_table[gov]
	r := rnd()
	pos := p.pos + random_unit(rnd) * 3500
	bb := basis_identity()
	bb.f = random_unit(rnd)
	bb.u = random_unit(rnd)
	orthonormalize(&bb)
	if r < pirate_p {
		n := 1 + rand.int_max(2)
		for _ in 0 ..< n {
			big := rnd() < 0.35
			hp: f32 = 120 if big else 60
			spawn(Entity {
				kind = .Pirate, model = .Cobra if big else .Sidewinder,
				pos = pos + random_unit(rnd) * 200, b = bb,
				hp = hp, max_hp = hp, max_speed = 300 if big else 340, turn = 1.6 if big else 2.0,
				speed = 200,
			})
		}
		play(.Beep)
	} else if r < pirate_p + 0.35 {
		spawn(Entity {
			kind = .Trader, model = .Cobra, pos = pos, b = bb,
			hp = 90, max_hp = 90, max_speed = 220, turn = 0.9, speed = 100,
		})
	} else {
		spawn(Entity {
			kind = .Police, model = .Viper, pos = pos, b = bb,
			hp = 150, max_hp = 150, max_speed = 380, turn = 1.8, speed = 200,
		})
	}
	if p.fugitive && rnd() < 0.6 {
		spawn(Entity {
			kind = .Police, model = .Viper, pos = p.pos + random_unit(rnd) * 2500, b = bb,
			hp = 150, max_hp = 150, max_speed = 380, turn = 1.8, speed = 200,
		})
	}
}

// ---------------------------------------------------------------- docking

// Player position/orientation relative to the station slot.
dock_check :: proc() -> (can_dock: bool, inside_hull: bool) {
	st := &g.station
	p := &g.p
	rel := p.pos - st.pos
	lx := linalg.dot(rel, st.b.r)
	ly := linalg.dot(rel, st.b.u)
	lz := linalg.dot(rel, st.b.f)
	radial := math.sqrt(lx * lx + ly * ly)
	in_hole_xy := abs(lx) < SLOT_W && abs(ly) < SLOT_H
	inside_hull = abs(lz) < ST_L + 15 && radial < ST_R && !(in_hole_xy && lz > ST_L - 10)
	aligned := linalg.dot(p.b.f, -st.b.f) > 0.9 && linalg.dot(p.b.u, st.b.u) > 0.88
	in_slot := abs(lx) < SLOT_W && abs(ly) < SLOT_H && lz < ST_L - 10 && lz > ST_L - SLOT_D
	can_dock = in_slot && aligned && p.speed < 220
	return
}

// ---------------------------------------------------------------- per-frame

flight_update :: proc(dt: f32) {
	p := &g.p
	if rl.IsKeyPressed(.F3) {
		g.chart_open = !g.chart_open
		g.cursor = g.target
	}
	if g.chart_open {
		chart_input()
		return
	}

	// controls
	ri, pi_, yi: f32
	if rl.IsKeyDown(.LEFT) { ri -= 1 }
	if rl.IsKeyDown(.RIGHT) { ri += 1 }
	if rl.IsKeyDown(.UP) { pi_ -= 1 }
	if rl.IsKeyDown(.DOWN) { pi_ += 1 }
	if rl.IsKeyDown(.Q) { yi -= 1 }
	if rl.IsKeyDown(.E) { yi += 1 }
	roll(&p.b, ri * 1.8 * dt)
	pitch(&p.b, pi_ * 1.2 * dt)
	yaw(&p.b, yi * 0.8 * dt)
	orthonormalize(&p.b)
	if rl.IsKeyDown(.W) { p.speed += 260 * dt }
	if rl.IsKeyDown(.S) { p.speed -= 260 * dt }
	p.speed = clamp(p.speed, 0, MAX_SPEED)

	p.laser_cd -= dt
	p.missile_cd -= dt
	if rl.IsKeyDown(.SPACE) && p.laser_cd <= 0 {
		if p.temp < 95 {
			fire_laser()
		} else if int(g.time * 4) % 2 == 0 {
			message("LASER OVERHEAT")
		}
	}
	if rl.IsKeyPressed(.M) && p.missile_cd <= 0 {
		fire_missile()
	}
	if rl.IsKeyPressed(.H) {
		start_jump()
		return
	}
	if rl.IsKeyPressed(.G) {
		start_galactic_jump()
		return
	}

	// player motion + systems
	p.prev = p.pos
	p.pos += p.b.f * p.speed * dt
	p.temp = max(0, p.temp - 12 * dt)
	p.shield = min(100, p.shield + 4 * dt)
	g.laser_vis = max(0, g.laser_vis - dt)
	g.spark_t = max(0, g.spark_t - dt)
	g.flash = max(0, g.flash - dt)

	// station
	st := &g.station
	roll(&st.b, st.spin * dt)
	orthonormalize(&st.b)
	can_dock, inside := dock_check()
	if can_dock {
		do_dock()
		return
	}
	if inside {
		damage_player(25 + p.speed * 0.08)
		p.pos = p.prev
		p.speed = 0
		message("Hull collision!")
	}

	// entities
	for i := 0; i < len(g.ents); i += 1 {
		e := &g.ents[i]
		if !e.alive {
			continue
		}
		switch e.kind {
		case .Pirate, .Trader, .Police:
			update_ship_ai(e, dt)
			if linalg.length(e.pos - p.pos) < models[e.model].radius + 20 {
				damage_player(15)
				hit_entity(e, 30, false)
				p.speed *= 0.6
			}
		case .Asteroid:
			e.pos += e.vel * dt
			roll(&e.b, e.spin * dt)
			orthonormalize(&e.b)
			if linalg.length(e.pos - p.pos) < models[e.model].radius + 15 {
				damage_player(20)
				hit_entity(e, 100, false)
			}
		case .Canister:
			e.pos += e.vel * dt
			roll(&e.b, e.spin * dt)
			pitch(&e.b, e.spin * 0.7 * dt)
			orthonormalize(&e.b)
			e.life -= dt
			if e.life <= 0 {
				e.alive = false
			}
			if linalg.length(e.pos - p.pos) < 70 {
				if cargo_used(p.cargo) < p.cargo_cap {
					p.cargo[e.cargo] += 1
					message("Scooped 1t %s", COMMODITIES[e.cargo].name)
					play(.Beep)
				} else {
					message("Cargo hold full")
					play(.Beep)
				}
				e.alive = false
			}
		case .Missile:
			e.life -= dt
			e.speed = min(e.speed + 500 * dt, 900)
			if t := find_ent(e.target_id); t != nil {
				steer(e, t.pos, dt)
				if linalg.length(t.pos - e.pos) < models[t.model].radius + 60 {
					detonate_missile(e)
					continue
				}
			}
			e.pos += e.b.f * e.speed * dt
			if e.life <= 0 {
				detonate_missile(e)
			}
		case .Debris:
			e.pos += e.vel * dt
			e.life -= dt
			if e.life <= 0 {
				e.alive = false
			}
		}
	}

	// spawning
	g.spawn_t -= dt
	if g.spawn_t <= 0 {
		g.spawn_t = 10 + rnd() * 15
		hostile_count := 0
		for &e in g.ents {
			if e.alive && (e.kind == .Pirate || e.kind == .Trader || e.kind == .Police) {
				hostile_count += 1
			}
		}
		if hostile_count < 4 {
			spawn_enemy()
		}
	}

	flush_pending()
	for i := len(g.ents) - 1; i >= 0; i -= 1 {
		if !g.ents[i].alive {
			unordered_remove(&g.ents, i)
		}
	}

	if p.hull <= 0 {
		explode(p.pos, 12)
		flush_pending()
		g.state = .Dead
		g.dead_t = 4
		play(.Boom)
	}
}

update :: proc(dt: f32) {
	g.time += dt
	g.msg_t = max(0, g.msg_t - dt)
	switch g.state {
	case .Docked:
		docked_update()
	case .Flight:
		flight_update(dt)
	case .Hyper:
		g.hyper_t -= dt
		if g.hyper_t <= 0 {
			finish_jump()
		}
	case .Dead:
		g.dead_t -= dt
		for &e in g.ents {
			e.pos += e.vel * dt
			e.life -= dt
		}
		if g.dead_t <= 0 && (rl.IsKeyPressed(.ENTER) || g.dead_t < -10) {
			if !load_game() {
				new_game()
			}
			g.state = .Docked
		}
	}
}
