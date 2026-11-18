package main

import "core:os"
import "core:path/filepath"
import "core:testing"

@(test)
save_round_trip_and_bad_file :: proc(t: ^testing.T) {
	dir, err := os.make_directory_temp("", "galaxies-save-*", context.temp_allocator)
	if !testing.expect(t, err == nil) {
		return
	}
	defer os.remove_all(dir)
	save_dir = dir
	defer save_dir = ""

	new_game()
	defer free_game()
	g.cur = 3
	g.p.cash = 1234
	g.p.cargo[3] = 5
	g.p.fugitive = true
	testing.expect(t, save_game())

	new_game()
	testing.expect(t, load_game())
	testing.expect_value(t, g.cur, 3)
	testing.expect_value(t, g.p.cash, 1234)
	testing.expect_value(t, g.p.cargo[3], 5)
	testing.expect(t, g.p.fugitive)

	// an unreadable save is kept as save.json.bad, not overwritten
	path, _ := filepath.join({dir, "save.json"}, context.temp_allocator)
	bad := transmute([]byte)string("{not json")
	testing.expect(t, os.write_entire_file(path, bad) == nil)
	testing.expect(t, !load_game())
	testing.expect(t, !os.exists(path))
	bad_path, _ := filepath.join({dir, "save.json.bad"}, context.temp_allocator)
	testing.expect(t, os.exists(bad_path))
}

@(test)
cr_formats_tenths :: proc(t: ^testing.T) {
	testing.expect_value(t, cr(1005), "100.5 cr")
	testing.expect_value(t, cr(0), "0.0 cr")
}
