package main

import "base:runtime"
import "constants"
import "core:c"
import "envelopes"
import rl "vendor:raylib"
import "waveforms"

phase: f32 = 0.0
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

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{15, 15, 15, 255})
		rl.DrawRectangleLines(10, 15, 428, 477, rl.RAYWHITE)

		rl.GuiSliderBar(rl.Rectangle{383, 20, 40, 467}, "Volume", "", &global_volume, 0.0, 2.0)

		waveforms.pulse_draw_gui()
		envelopes.envelope_draw_gui()

		rl.EndDrawing()
	}
}

audio_generate :: proc "c" (data: rawptr, frames: c.uint) {
	context = runtime.default_context()
	samples := transmute([^]f32)data
	if global_volume != 0.0 {
		for i in 0 ..< frames {
			phase += constants.FREQUENCY / constants.SAMPLE_RATE
			if phase >= 1 do phase -= 1
			samples[i] = waveforms.pulse_generate(phase) * global_volume
		}
	} else {
		phase = 0.0
	}
}
