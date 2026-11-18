package main

import rl "vendor:raylib"
import "vendor:raylib/rlgl"
import "core:os"
import "core:strconv"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	// GLFW often reports 1.0 on X11, so GALAXIES_UI_SCALE overrides; it is read before the window
	// exists so the window is created at the right size.
	env, has_env := strconv.parse_f32(os.get_env("GALAXIES_UI_SCALE", context.temp_allocator))
	ui_scale = clamp(env, 1, 4) if has_env else 1
	rl.InitWindow(i32(1024 * ui_scale), i32(768 * ui_scale), "Galaxies")
	defer rl.CloseWindow()
	if !has_env {
		ui_scale = detect_scale()
		rl.SetWindowSize(i32(1024 * ui_scale), i32(768 * ui_scale))
	}
	rl.SetMouseScale(1 / ui_scale, 1 / ui_scale)
	rl.ToggleBorderlessWindowed() // start fullscreen; F11 toggles back
	rl.SetWindowMinSize(i32(800 * ui_scale), i32(600 * ui_scale))
	rl.SetTargetFPS(60)

	init_font()
	defer rl.UnloadFont(font)
	init_models()
	init_audio()
	defer shutdown_audio()

	if !load_game() {
		new_game()
	}

	for !rl.WindowShouldClose() {
		if rl.IsKeyPressed(.F11) {
			rl.ToggleBorderlessWindowed()
		}
		if !has_env && rl.IsWindowResized() { // window may have moved to a monitor with another DPI
			ui_scale = detect_scale()
			rl.SetMouseScale(1 / ui_scale, 1 / ui_scale)
		}
		dt := min(rl.GetFrameTime(), 0.05)
		update_view()
		update(dt)

		rl.BeginDrawing()
		rlgl.Scalef(ui_scale, ui_scale, 1)
		rl.ClearBackground(rl.BLACK)
		switch g.state {
		case .Docked: draw_docked()
		case .Flight: draw_flight()
		case .Hyper:  draw_hyper()
		case .Dead:   draw_dead()
		}
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}

// Linux/Wayland and Windows often report a DPI scale of 1, so also scale by monitor height; macOS keeps the DPI value.
detect_scale :: proc() -> f32 {
	s := rl.GetWindowScaleDPI().y
	when ODIN_OS != .Darwin {
		s = max(s, f32(rl.GetMonitorHeight(rl.GetCurrentMonitor())) / 1280)
	}
	return clamp(s, 1, 4)
}
