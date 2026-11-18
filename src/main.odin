package main

import rl "vendor:raylib"

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(1024, 768, "ELITE")
	defer rl.CloseWindow()
	rl.SetWindowMinSize(800, 600)
	rl.SetTargetFPS(60)

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
		dt := min(rl.GetFrameTime(), 0.05)
		update_view()
		update(dt)

		rl.BeginDrawing()
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
