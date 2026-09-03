package waveforms

import "../constants/"
import "../envelopes"
import "core:math"
import "core:sync"
import rl "vendor:raylib"

SINE_GUI_HEIGHT :: 210

@(private = "file")
sine_active := false

@(private = "file")
sine_volume: f32 = 0.3

@(private = "file")
sine_duty_cycle: f32 = 0.5

@(private = "file")
sine_pitch: f32 = 440.0

@(private = "file")
sine_phase: f32 = 0.0

@(private = "file")
env: envelopes.Envelope

@(private = "file")
get_active :: #force_inline proc() -> bool {
	return sync.atomic_load(&sine_active)
}

@(private = "file")
get_phase :: #force_inline proc() -> f32 {
	return sync.atomic_load(&sine_phase)
}

@(private = "file")
advance_phase :: #force_inline proc() {
	phase_new := get_phase() + get_pitch() / constants.SAMPLE_RATE
	if phase_new >= 1 {
		phase_new -= 1
	}
	sync.atomic_store(&sine_phase, phase_new)

}

@(private = "file")
get_volume :: #force_inline proc() -> f32 {
	return sync.atomic_load(&sine_volume)
}

@(private = "file")
get_pitch :: #force_inline proc() -> f32 {
	return sync.atomic_load(&sine_pitch)
}

sine_generate :: proc() -> f32 {
	amp := envelopes.envelope_update(&env, get_active(), 1.0 / constants.SAMPLE_RATE)
	if amp <= 0.0 {
		return 0.0
	}
	advance_phase()

	return math.sin_f32(2.0 * math.PI * get_phase()) * get_volume() * amp
}

sine_draw_gui :: proc() {
	rl.GuiCheckBox(rl.Rectangle{15, 130, 60, 20}, "Sine", &sine_active)
	rl.GuiSliderBar(rl.Rectangle{15, 150, 60, 15}, "", "Volume", &sine_volume, 0.0, 0.6)
	rl.GuiSliderBar(rl.Rectangle{15, 165, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar(rl.Rectangle{15, 180, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)
	rl.GuiSlider(rl.Rectangle{15, 195, 60, 15}, "", "Pitch", &sine_pitch, 40.0, 4000.0)
}
