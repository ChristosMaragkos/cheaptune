package waveforms

import "../constants/"
import "../envelopes"
import "core:math"
import "core:sync"
import rl "vendor:raylib"

WAVETABLE_GUI_HEIGHT :: 300

WAVE_SAMPLE_COUNT :: 64

@(private = "file")
wavetable_active := false

@(private = "file")
wavetable_volume: f32 = 0.2

@(private = "file")
wavetable_pitch: f32 = 440.0

@(private = "file")
wavetable_phase: f32 = 0.0

@(private = "file")
data: [32]u8

@(private = "file")
env: envelopes.Envelope

@(private = "file")
hex_buffer: [WAVE_SAMPLE_COUNT + 1]u8

@(private = "file")
hex_edit_active := false

@(private = "file")
get_active :: #force_inline proc() -> bool {
	return sync.atomic_load(&wavetable_active)
}

@(private = "file")
get_phase :: #force_inline proc() -> f32 {
	return sync.atomic_load(&wavetable_phase)
}

@(private = "file")
advance_phase :: #force_inline proc() {
	phase_new := get_phase() + get_pitch() / constants.SAMPLE_RATE
	if phase_new >= 1 {
		phase_new -= 1
	}
	sync.atomic_store(&wavetable_phase, phase_new)
}

@(private = "file")
get_volume :: #force_inline proc() -> f32 {
	return sync.atomic_load(&wavetable_volume)
}

@(private = "file")
get_pitch :: #force_inline proc() -> f32 {
	return sync.atomic_load(&wavetable_pitch)
}

@(private = "file")
nibble_to_hex :: proc(nib: u8) -> u8 {
	return nib < 10 ? '0' + nib : 'A' + (nib - 10)
}

@(private = "file")
hex_to_nibble :: proc(ch: u8) -> (u8, bool) {
	switch {
		case ch >= '0' && ch <= '9':
			return ch - '0', true
		case ch >= 'A' && ch <= 'F':
			return ch - 'A' + 10, true
		case ch >= 'a' && ch <= 'f':
			return ch - 'a' + 10, true
	}
	return 0, false
}

// Pack 64 nibbles (from a 64-char hex string) into the 32-byte data array.
@(private = "file")
pack_data :: proc() {
	for byte_idx in 0 ..< 32 {
		lo_nib, ok_lo := hex_to_nibble(hex_buffer[byte_idx * 2 + 1])
		hi_nib, ok_hi := hex_to_nibble(hex_buffer[byte_idx * 2])
		if !ok_lo do lo_nib = 0
		if !ok_hi do hi_nib = 0
		data[byte_idx] = (hi_nib << 4) | lo_nib
	}
}

// Refresh the hex buffer from the current data array.
@(private = "file")
unpack_data :: proc() {
	for byte_idx in 0 ..< 32 {
		b := data[byte_idx]
		hex_buffer[byte_idx * 2] = nibble_to_hex((b >> 4) & 0xF)
		hex_buffer[byte_idx * 2 + 1] = nibble_to_hex(b & 0xF)
	}
	hex_buffer[WAVE_SAMPLE_COUNT] = 0
}

// Fill the table from a 64-char hex string, then sync the buffer.
wavetable_load_hex :: proc(hex: string) {
	empty_data()
	copy(hex_buffer[:], hex[:min(len(hex), WAVE_SAMPLE_COUNT)])
	pack_data()
	unpack_data()
}

empty_data :: proc() {
	for i in 0 ..< len(data) {
		data[i] = 0
	}
}

@(private = "file")
fill_preset :: proc(kind: Preset_Kind) {
	loop: for i in 0 ..< WAVE_SAMPLE_COUNT {
		p := f32(i) / f32(WAVE_SAMPLE_COUNT)
		var: f32
		switch kind {
			case .Empty:
				hex_buffer[0] = 0
				empty_data()
				break loop
			case .Sine:
				var = math.sin_f32(2.0 * math.PI * p)
			case .Triangle:
				var = 4.0 * math.abs(p - 0.5) - 1.0
			case .Saw:
				var = 2.0 * p - 1.0
			case .Square:
				var = p < 0.5 ? 1.0 : -1.0
		}
		nib := clamp(int((var + 1.0) * 0.5 * 15.0 + 0.5), 0, 15)
		// store packed: even i -> high nibble, odd i -> low nibble
		byte_idx := i >> 1
		if i & 1 == 0 {
			data[byte_idx] = (data[byte_idx] & 0x0F) | (u8(nib) << 4)
		} else {
			data[byte_idx] = (data[byte_idx] & 0xF0) | u8(nib)
		}
	}
	unpack_data()
}

Preset_Kind :: enum {
	Empty,
	Sine,
	Triangle,
	Saw,
	Square,
}

wavetable_generate :: proc() -> f32 {
	amp := envelopes.envelope_update(&env, get_active(), 1.0 / constants.SAMPLE_RATE)
	if amp <= 0.0 {
		return 0.0
	}
	advance_phase()

	idx := int(get_phase() * WAVE_SAMPLE_COUNT) & (WAVE_SAMPLE_COUNT - 1)
	byte_idx := idx >> 1
	b := data[byte_idx]
	nib: u8
	if idx & 1 == 0 {
		nib = (b >> 4) & 0xF
	} else {
		nib = b & 0xF
	}

	value := (f32(nib) / 15.0) * 2.0 - 1.0
	return value * amp * get_volume()
}

wavetable_draw_gui :: proc() {
	rl.GuiCheckBox(rl.Rectangle{150, 130, 60, 20}, "Wavetable", &wavetable_active)
	rl.GuiSliderBar(rl.Rectangle{150, 150, 60, 15}, "", "Volume", &wavetable_volume, 0.0, 0.6)
	rl.GuiSliderBar(rl.Rectangle{150, 165, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar(rl.Rectangle{150, 180, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)

	rl.GuiTextBox(
		rl.Rectangle{150, 200, 268, 20},
		cstring(&hex_buffer[0]),
		WAVE_SAMPLE_COUNT,
		hex_edit_active,
	)
	pack_data()

	rl.GuiCheckBox(rl.Rectangle{150, 225, 60, 15}, "Edit Hex", &hex_edit_active)
	if rl.GuiButton(rl.Rectangle{265, 225, 40, 15}, "Clear") { fill_preset(.Empty) }

	if rl.GuiButton(rl.Rectangle{150, 245, 60, 20}, "Sine") { fill_preset(.Sine) }
	if rl.GuiButton(rl.Rectangle{214, 245, 60, 20}, "Triangle") { fill_preset(.Triangle) }
	if rl.GuiButton(rl.Rectangle{278, 245, 60, 20}, "Saw") { fill_preset(.Saw) }
	if rl.GuiButton(rl.Rectangle{342, 245, 60, 20}, "Square") { fill_preset(.Square) }

	rl.GuiSlider(rl.Rectangle{150, 270, 60, 15}, "", "Pitch", &wavetable_pitch, 40.0, 4000.0)

	draw_wave_preview(rl.Rectangle{150, 290, 268, 120})
}

@(private = "file")
draw_wave_preview :: proc(bounds: rl.Rectangle) {
	rl.DrawRectangleLines(
		i32(bounds.x),
		i32(bounds.y),
		i32(bounds.width),
		i32(bounds.height),
		rl.RAYWHITE,
	)
	prev := rl.Vector2{}
	for i in 0 ..= WAVE_SAMPLE_COUNT {
		idx := i & (WAVE_SAMPLE_COUNT - 1)
		byte_idx := idx >> 1
		b := data[byte_idx]
		nib: u8
		if idx & 1 == 0 {
			nib = (b >> 4) & 0xF
		} else {
			nib = b & 0xF
		}
		value := (f32(nib) / 15.0) * 2.0 - 1.0
		x := bounds.x + f32(i) / f32(WAVE_SAMPLE_COUNT) * bounds.width
		y := bounds.y + bounds.height * 0.5 - value * 0.5 * bounds.height
		cur := rl.Vector2{x, y}
		if i > 0 {
			rl.DrawLineV(prev, cur, rl.RAYWHITE)
		}
		prev = cur
	}
}

wavetable_init :: proc() {
	fill_preset(.Empty)
}
