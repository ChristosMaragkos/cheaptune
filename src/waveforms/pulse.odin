package waveforms

import "../constants/"
import "../envelopes"
import "core:sync"
import rl "vendor:raylib"

PULSE_GUI_HEIGHT :: 120

@(private = "file")
pulse_active := false

@(private = "file")
pulse_volume: f32 = 0.15

@(private = "file")
pulse_duty_cycle: f32 = 0.5

@(private = "file")
pulse_pitch: f32 = 440.0

@(private = "file")
pulse_phase: f32 = 0.0

@(private = "file")
env: envelopes.Envelope

@(private = "file")
get_active :: #force_inline proc() -> bool {
	return sync.atomic_load(&pulse_active)
}

@(private = "file")
get_phase :: #force_inline proc() -> f32 {
	return sync.atomic_load(&pulse_phase)
}

@(private = "file")
advance_phase :: #force_inline proc() {
	phase_new := get_phase() + get_pitch() / constants.SAMPLE_RATE
	if phase_new >= 1 {
		phase_new -= 1
	}
	sync.atomic_store(&pulse_phase, phase_new)
}

@(private = "file")
get_volume :: #force_inline proc() -> f32 {
	return sync.atomic_load(&pulse_volume)
}

@(private = "file")
get_pitch :: #force_inline proc() -> f32 {
	return sync.atomic_load(&pulse_pitch)
}

pulse_generate :: proc() -> f32 {
	amp := envelopes.envelope_update(&env, get_active(), 1.0 / constants.SAMPLE_RATE)
	if amp <= 0.0 {
		return 0.0
	}
	advance_phase()

	return (get_phase() < pulse_duty_cycle ? 1 : -1) * get_volume() * amp
}

pulse_draw_gui :: proc() {
	rl.GuiCheckBox(rl.Rectangle{15, 25, 60, 20}, "Pulse", &pulse_active)
	rl.GuiSlider(rl.Rectangle{15, 45, 60, 15}, "", "Duty Cycle", &pulse_duty_cycle, 0.0, 1.0)
	rl.GuiSliderBar(rl.Rectangle{15, 60, 60, 15}, "", "Volume", &pulse_volume, 0.0, 0.6)
	rl.GuiSliderBar(rl.Rectangle{15, 75, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar(rl.Rectangle{15, 90, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)
	rl.GuiSlider(rl.Rectangle{15, 105, 60, 15}, "", "Pitch", &pulse_pitch, 40.0, 4000.0)
}
