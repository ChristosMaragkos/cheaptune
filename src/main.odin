package main

import "base:runtime"
import "constants"
import "core:c"
import "core:math"
import rl "vendor:raylib"
import "waveforms"

global_volume: f32 = 1.0

main :: proc() {
	rl.InitWindow(448, 512, "Cheaptune")
	defer rl.CloseWindow()

	rl.SetWindowMonitor(0)
	rl.SetTargetFPS(60)

	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	stream := rl.LoadAudioStream(u32(constants.SAMPLE_RATE), 32, 1)
	defer rl.UnloadAudioStream(stream)

	rl.SetAudioStreamCallback(stream, audio_generate)
	rl.PlayAudioStream(stream)
	defer rl.StopAudioStream(stream)

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{15, 15, 15, 255})
		rl.DrawRectangleLines(10, 15, 428, 477, rl.RAYWHITE)

		rl.GuiSliderBar(rl.Rectangle{383, 20, 40, 467}, "Volume", "", &global_volume, 0.0, 2.0)

		waveforms.pulse_draw_gui()
		waveforms.sine_draw_gui()
		waveforms.triangle_draw_gui()

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

		voices := 0

		if pulse != 0 do voices += 1
		if sine != 0 do voices += 1
		if tri != 0 do voices += 1

		mix := (pulse + sine + tri) / math.sqrt(f32(math.max(voices, 1)))

		samples[i] = mix * global_volume
	}
}
