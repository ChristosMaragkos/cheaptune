package waveforms

import "../constants/"
import "../envelopes"
import "core:sync"
import rl "vendor:raylib"

SAW_GUI_HEIGHT :: 105

@(private = "file")
saw_active := false

@(private = "file")
saw_volume: f32 = 0.2

@(private = "file")
saw_duty_cycle: f32 = 0.5

@(private = "file")
saw_pitch: f32 = 440.0

@(private = "file")
saw_phase: f32 = 0.0

@(private = "file")
env: envelopes.Envelope

@(private = "file")
get_active :: #force_inline proc() -> bool {
	return sync.atomic_load(&saw_active)
}

@(private = "file")
get_phase :: #force_inline proc() -> f32 {
	return sync.atomic_load(&saw_phase)
}

@(private = "file")
advance_phase :: #force_inline proc() {
	phase_new := get_phase() + get_pitch() / constants.SAMPLE_RATE
	if phase_new >= 1 {
		phase_new -= 1
	}
	sync.atomic_store(&saw_phase, phase_new)
}

@(private = "file")
get_volume :: #force_inline proc() -> f32 {
	return sync.atomic_load(&saw_volume)
}

@(private = "file")
get_pitch :: #force_inline proc() -> f32 {
	return sync.atomic_load(&saw_pitch)
}

saw_generate :: proc() -> f32 {
	amp := envelopes.envelope_update(&env, get_active(), 1.0 / constants.SAMPLE_RATE)
	if amp <= 0.0 {
		return 0.0
	}
	advance_phase()

	return (2.0 * get_phase() - 1.0) * amp * get_volume()
}

saw_draw_gui :: proc() {
	rl.GuiCheckBox(rl.Rectangle{150, 25, 60, 20}, "Saw", &saw_active)
	rl.GuiSliderBar(rl.Rectangle{150, 45, 60, 15}, "", "Volume", &saw_volume, 0.0, 0.6)
	rl.GuiSliderBar(rl.Rectangle{150, 60, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar(rl.Rectangle{150, 75, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)
	rl.GuiSlider(rl.Rectangle{150, 90, 60, 15}, "", "Pitch", &saw_pitch, 40.0, 4000.0)
}
