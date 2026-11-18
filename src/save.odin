package main

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:path/filepath"

SaveData :: struct {
	galaxy:    int,
	system:    int,
	target:    int,
	cash:      int,
	fuel:      int,
	missiles:  int,
	cargo:     [NUM_COMM]int,
	cargo_cap: int,
	kills:     int,
	gal_drive: bool,
	epoch:     u32,
	fugitive:  bool,
}

// Tests set this to a temp dir; with it unset they must never touch a player's real save.
save_dir: string

@(private = "file")
save_path :: proc() -> (path: string, ok: bool) {
	folder := save_dir
	if folder == "" {
		when ODIN_TEST { // tests call launch()/do_dock()
			return "", false
		}
		dir, err := os.user_config_dir(context.temp_allocator)
		if err != nil {
			return "", false
		}
		joined, jerr := filepath.join({dir, "Galaxies"}, context.temp_allocator)
		if jerr != nil {
			return "", false
		}
		folder = joined
	}
	os.make_directory_all(folder)
	full, jerr2 := filepath.join({folder, "save.json"}, context.temp_allocator)
	return full, jerr2 == nil
}

// Returns false (after showing "Save failed!") when nothing was written.
save_game :: proc() -> bool {
	path, ok := save_path()
	if !ok {
		message("Save failed!")
		return false
	}
	d := SaveData {
		galaxy    = g.galaxy_no,
		system    = g.cur,
		target    = g.target,
		cash      = g.p.cash,
		fuel      = g.p.fuel,
		missiles  = g.p.missiles,
		cargo     = g.p.cargo,
		cargo_cap = g.p.cargo_cap,
		kills     = g.p.kills,
		gal_drive = g.p.gal_drive,
		epoch     = g.epoch,
		fugitive  = g.p.fugitive,
	}
	data, err := json.marshal(d, {pretty = true}, context.temp_allocator)
	if err != nil {
		message("Save failed!")
		return false
	}
	// write to a temp file and rename, so a crash never leaves a half-written save
	tmp := fmt.tprintf("%s.tmp", path)
	if os.write_entire_file(tmp, data) != nil || os.rename(tmp, path) != nil {
		message("Save failed!")
		return false
	}
	return true
}

// False when there is no save or it is unusable; an unusable file is renamed to save.json.bad so the
// next save does not overwrite it.
load_game :: proc() -> bool {
	path, ok := save_path()
	if !ok || !os.exists(path) {
		return false
	}
	if load_file(path) {
		return true
	}
	os.rename(path, fmt.tprintf("%s.bad", path))
	message("Save unreadable, kept as save.json.bad")
	return false
}

@(private = "file")
load_file :: proc(path: string) -> bool {
	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil {
		return false
	}
	d: SaveData
	if json.unmarshal(data, &d, allocator = context.temp_allocator) != nil {
		return false
	}
	return apply_save(d)
}

apply_save :: proc(d: SaveData) -> bool {
	if d.galaxy < 0 || d.galaxy > 7 || d.system < 0 || d.system > 255 {
		return false
	}
	new_game()
	g.galaxy_no = d.galaxy
	g.galaxy = gen_galaxy(d.galaxy)
	g.cur = d.system
	g.target = clamp(d.target, 0, 255)
	g.cursor = g.target
	g.p.cash = max(d.cash, 0)
	g.p.fuel = clamp(d.fuel, 0, MAX_FUEL)
	g.p.missiles = clamp(d.missiles, 0, 4)
	for c, i in d.cargo {
		g.p.cargo[i] = max(c, 0)
	}
	g.p.cargo_cap = 45 if d.cargo_cap > 20 else 20
	g.epoch = max(d.epoch, 1)
	g.p.kills = d.kills
	g.p.gal_drive = d.gal_drive
	g.p.fugitive = d.fugitive
	setup_system()
	return true
}
