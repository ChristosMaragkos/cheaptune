package main

import "base:runtime"
import "constants"
import "core:c"
import "core:math"
import rl "vendor:raylib"
import "waveforms"

WIDTH :: 448
HEIGHT :: 512

global_volume: f32 = 1.0

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(WIDTH, HEIGHT, "Cheaptune")
	defer rl.CloseWindow()

	rl.SetWindowMinSize(WIDTH, HEIGHT)
	rl.SetWindowMonitor(0)
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	stream := rl.LoadAudioStream(u32(constants.SAMPLE_RATE), 32, 1)
	defer rl.UnloadAudioStream(stream)

	rl.SetAudioStreamCallback(stream, audio_generate)
	rl.PlayAudioStream(stream)
	defer rl.StopAudioStream(stream)

	waveforms.wavetable_init()

	canvas := rl.LoadRenderTexture(WIDTH, HEIGHT)
	defer rl.UnloadRenderTexture(canvas)

	for !rl.WindowShouldClose() {
		// Render the UI at the fixed design resolution (WIDTH x HEIGHT).
		rl.BeginTextureMode(canvas)
		rl.ClearBackground(rl.Color{15, 15, 15, 255})
		rl.DrawRectangleLines(10, 15, 428, 477, rl.RAYWHITE)

		rl.GuiSliderBar(rl.Rectangle{50, 472, 383, 15}, "Volume", "", &global_volume, 0.0, 2.0)

		waveforms.pulse_draw_gui()
		waveforms.sine_draw_gui()
		waveforms.triangle_draw_gui()
		waveforms.noise_draw_gui()
		waveforms.saw_draw_gui()
		waveforms.wavetable_draw_gui()

		rl.EndTextureMode()

		win_w := f32(rl.GetScreenWidth())
		win_h := f32(rl.GetScreenHeight())
		scale := min(win_w / WIDTH, win_h / HEIGHT)
		dst_w := WIDTH * scale
		dst_h := HEIGHT * scale
		off_x := (win_w - dst_w) * 0.5
		off_y := (win_h - dst_h) * 0.5
		dest := rl.Rectangle{off_x, off_y, dst_w, dst_h}

		sc := 1.0 / scale
		rl.SetMouseScale(sc, sc)
		rl.SetMouseOffset(i32(-off_x), i32(-off_y))

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)

		src := rl.Rectangle{0, 0, f32(canvas.texture.width), -f32(canvas.texture.height)}
		rl.DrawTexturePro(canvas.texture, src, dest, rl.Vector2{0, 0}, 0, rl.WHITE)

		rl.EndDrawing()
	}
}

audio_generate :: proc "c" (data: rawptr, frames: c.uint) {
	context = runtime.default_context()
	samples := transmute([^]f32)data
	for i in 0 ..< frames {
		pulse := waveforms.pulse_generate()
		sine := waveforms.sine_generate()
		tri := waveforms.triangle_generate()
		noise := waveforms.noise_generate()
		saw := waveforms.saw_generate()
		wavetable := waveforms.wavetable_generate()

		voices := 0

		if pulse != 0 do voices += 1
		if sine != 0 do voices += 1
		if tri != 0 do voices += 1
		if noise != 0 do voices += 1
		if saw != 0 do voices += 1
		if wavetable != 0 do voices += 1

		mix := (pulse + sine + tri + noise + saw + wavetable) / math.sqrt(f32(math.max(voices, 2)))

		samples[i] = mix * global_volume}
}
