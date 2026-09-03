package waveforms

import "../constants/"
import "../envelopes"
import "core:sync"
import rl "vendor:raylib"

@(private = "file")
noise_active := false

@(private = "file")
noise_volume: f32 = 0.2

@(private = "file")
noise_duty_cycle: f32 = 0.5

@(private = "file")
env: envelopes.Envelope

@(private = "file")
lfsr: u16 = 0xDEAD

@(private = "file")
noise_mode: u32 = 0

@(private = "file")
noise_counter: i32 = 0

@(private = "file")
noise_rate: f32 = 0.0

@(private = "file")
get_active :: #force_inline proc() -> bool {
	return sync.atomic_load(&noise_active)
}

@(private = "file")
get_volume :: #force_inline proc() -> f32 {
	return sync.atomic_load(&noise_volume)
}

@(private = "file")
get_mode :: #force_inline proc() -> u32 {
	return sync.atomic_load(&noise_mode)
}

@(private = "file")
get_rate :: #force_inline proc() -> f32 {
	return sync.atomic_load(&noise_rate)
}

noise_generate :: proc() -> f32 {
	amp := envelopes.envelope_update(&env, get_active(), 1.0 / constants.SAMPLE_RATE)
	if amp <= 0.0 {
		return 0.0
	}

	if get_rate() > 1.0 {
		noise_counter += 1
		if noise_counter >= i32(get_rate()) {
			noise_counter = 0
			noise_next()
		}
	} else {noise_next()}

	return ((lfsr & 1) == 1 ? 1.0 : -1.0) * amp * get_volume()
}

@(private = "file")
noise_next :: #force_inline proc() {
	feedback: u16
	bit0: u16 = lfsr & 1
	tap: u16 = (lfsr >> (6 - get_mode())) & 1
	feedback = bit0 ~ tap
	lfsr = (lfsr >> 1) | (feedback << 14)
}

noise_draw_gui :: proc() {
	rl.GuiCheckBox(rl.Rectangle{15, 310, 60, 20}, "Noise", &noise_active)
	rl.GuiSliderBar(rl.Rectangle{15, 330, 60, 15}, "", "Volume", &noise_volume, 0.0, 0.6)
	rl.GuiSliderBar(rl.Rectangle{15, 345, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar(rl.Rectangle{15, 360, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)
	rl.GuiSlider(rl.Rectangle{15, 375, 60, 15}, "", "Rate", &noise_rate, 10.0, 100.0)
	rl.GuiComboBox(rl.Rectangle{15, 390, 70, 15}, "6;5;4;3;2;1", (^i32)(&noise_mode))
}
