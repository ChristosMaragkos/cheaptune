package waveforms

import "../constants/"
import "../envelopes"
import "core:math"
import "core:sync"
import rl "vendor:raylib"

TRIANGLE_GUI_HEIGHT :: 300

@(private = "file")
triangle_active := false

@(private = "file")
triangle_volume: f32 = 0.3

@(private = "file")
triangle_duty_cycle: f32 = 0.5

@(private = "file")
triangle_pitch: f32 = 440.0

@(private = "file")
triangle_phase: f32 = 0.0

@(private = "file")
env: envelopes.Envelope

@(private = "file")
get_active :: #force_inline proc() -> bool {
	return sync.atomic_load(&triangle_active)
}

@(private = "file")
get_phase :: #force_inline proc() -> f32 {
	return sync.atomic_load(&triangle_phase)
}

@(private = "file")
advance_phase :: #force_inline proc() {
	phase_new := get_phase() + get_pitch() / constants.SAMPLE_RATE
	if phase_new >= 1 {
		phase_new -= 1
	}
	sync.atomic_store(&triangle_phase, phase_new)

}

@(private = "file")
get_volume :: #force_inline proc() -> f32 {
	return sync.atomic_load(&triangle_volume)
}

@(private = "file")
get_pitch :: #force_inline proc() -> f32 {
	return sync.atomic_load(&triangle_pitch)
}

triangle_generate :: proc() -> f32 {
	amp := envelopes.envelope_update(&env, get_active(), 1.0 / constants.SAMPLE_RATE)
	if amp <= 0.0 {
		return 0.0
	}
	advance_phase()

	return (4.0 * math.abs(get_phase() - 0.5) - 1.0) * amp * get_volume()
}

triangle_draw_gui :: proc() {
	rl.GuiCheckBox(rl.Rectangle{15, 220, 60, 20}, "Triangle", &triangle_active)
	rl.GuiSliderBar(rl.Rectangle{15, 240, 60, 15}, "", "Volume", &triangle_volume, 0.0, 0.6)
	rl.GuiSliderBar(rl.Rectangle{15, 255, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar(rl.Rectangle{15, 270, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)
	rl.GuiSlider(rl.Rectangle{15, 285, 60, 15}, "", "Pitch", &triangle_pitch, 40.0, 4000.0)
}
