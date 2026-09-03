package waveforms

import "../constants/"
import "../envelopes"
import "core:sync"
import rl "vendor:raylib"

PULSE_GUI_HEIGHT :: 120

@(private = "file")
pulse_active := false

@(private = "file")
pulse_volume: f32 = 0.3

@(private = "file")
pulse_duty_cycle: f32 = 0.5

@(private = "file")
pulse_pitch: f32 = 440.0

@(private = "file")
env: envelopes.Envelope

@(private = "file")
pulse_is_active :: proc() -> bool {
	return sync.atomic_load(&pulse_active)
}

pulse_generate :: proc(phase: f32) -> f32 {
	amp := envelopes.envelope_update(&env, pulse_is_active(), 1.0 / constants.SAMPLE_RATE)
	return (phase < pulse_duty_cycle ? 1 : -1) * pulse_volume * amp
}

pulse_draw_gui :: proc() {
	rl.GuiCheckBox(rl.Rectangle{15, 25, 60, 20}, "Pulse", &pulse_active)
	rl.GuiSlider(rl.Rectangle{15, 45, 60, 15}, "", "Duty Cycle", &pulse_duty_cycle, 0.0, 1.0)
	rl.GuiSliderBar(rl.Rectangle{15, 60, 60, 15}, "", "Volume", &pulse_volume, 0.0, 0.6)
	rl.GuiSliderBar(rl.Rectangle{15, 75, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar(rl.Rectangle{15, 90, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)
	rl.GuiSlider(rl.Rectangle{15, 105, 60, 15}, "", "Pitch", &pulse_pitch, 40.0, 4000.0)
}
