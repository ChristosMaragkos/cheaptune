package waveforms

import "../constants/"
import "../envelopes"
import "core:sync"
import rl "vendor:raylib"

pulse_active := false
pulse_volume: f32 = 0.3
pulse_duty_cycle: f32 = 0.5

env: envelopes.Envelope

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
}
