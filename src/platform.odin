package main

import rl "vendor:raylib"

// Tests must not reference raylib procs: on Windows, linking raylib.lib clashes with the UCRT
// startup code, leaves os.args empty and crashes the test runner. Tests get inert stubs.
when ODIN_TEST {
	key_down :: proc(k: rl.KeyboardKey) -> bool { return false }
	test_key: rl.KeyboardKey // the one key tests report as just pressed; .KEY_NULL = none
	key_pressed :: proc(k: rl.KeyboardKey) -> bool { return k == test_key && k != .KEY_NULL }
	mouse_pressed :: proc(b: rl.MouseButton) -> bool { return false }
	mouse_pos :: proc() -> rl.Vector2 { return {} }
} else {
	key_down :: rl.IsKeyDown
	key_pressed :: rl.IsKeyPressed
	mouse_pressed :: rl.IsMouseButtonPressed
	mouse_pos :: rl.GetMousePosition
}
