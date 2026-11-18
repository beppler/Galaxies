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
}

@(private = "file")
save_path :: proc() -> (path: string, ok: bool) {
	dir, err := os.user_config_dir(context.temp_allocator)
	if err != nil {
		return "", false
	}
	folder, jerr := filepath.join({dir, "odin-elite"}, context.temp_allocator)
	if jerr != nil {
		return "", false
	}
	os.make_directory_all(folder)
	full, jerr2 := filepath.join({folder, "save.json"}, context.temp_allocator)
	return full, jerr2 == nil
}

save_game :: proc() {
	path, ok := save_path()
	if !ok {
		return
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
	}
	data, err := json.marshal(d, {pretty = true}, context.temp_allocator)
	if err != nil {
		return
	}
	// write to a temp file and rename, so a crash never leaves a half-written save
	tmp := fmt.tprintf("%s.tmp", path)
	if os.write_entire_file(tmp, data) != nil || os.rename(tmp, path) != nil {
		message("Save failed!")
	}
}

load_game :: proc() -> bool {
	path, ok := save_path()
	if !ok {
		return false
	}
	data, err := os.read_entire_file(path, context.temp_allocator)
	if err != nil {
		return false
	}
	d: SaveData
	if json.unmarshal(data, &d, allocator = context.temp_allocator) != nil {
		return false
	}
	if d.galaxy < 0 || d.galaxy > 7 || d.system < 0 || d.system > 255 {
		return false
	}
	new_game()
	g.galaxy_no = d.galaxy
	g.galaxy = gen_galaxy(d.galaxy)
	g.cur = d.system
	g.target = clamp(d.target, 0, 255)
	g.cursor = g.target
	g.p.cash = d.cash
	g.p.fuel = clamp(d.fuel, 0, MAX_FUEL)
	g.p.missiles = d.missiles
	g.p.cargo = d.cargo
	g.p.cargo_cap = d.cargo_cap
	g.p.kills = d.kills
	g.p.gal_drive = d.gal_drive
	setup_system()
	return true
}
