package waveforms

import "../constants"
import "../envelopes"
import tfd "../tinyfiledialogs"
import "core:fmt"
import "core:io"
import "core:math"
import "core:mem"
import "core:os"
import "core:sync"
import rl "vendor:raylib"

WAVETABLE_GUI_HEIGHT :: 300
WAVE_SAMPLE_COUNT :: 64

@(private = "file")
file_ext := []cstring{"*.wvt"}

@(private = "file")
wavetable_active := false

@(private = "file")
wavetable_volume: f32 = 0.2

@(private = "file")
wavetable_pitch: f32 = 440.0

@(private = "file")
wavetable_phase: f32 = 0.0

@(private = "file")
data: [WAVE_SAMPLE_COUNT]u8

@(private = "file")
env: envelopes.Envelope

@(private = "file")
hex_buffer: [WAVE_SAMPLE_COUNT * 2 + 1]u8

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

// Parse the hex string (two chars per byte) into the data array.
// Reads only up to the NUL terminator; any shorter string zero-fills the rest.
@(private = "file")
pack_data :: proc() {
	hex_len := 0
	for hex_len < WAVE_SAMPLE_COUNT * 2 && hex_buffer[hex_len] != 0 {
		hex_len += 1
	}
	for byte_idx in 0 ..< WAVE_SAMPLE_COUNT {
		lo_ch := hex_buffer[byte_idx * 2 + 1] if byte_idx * 2 + 1 < hex_len else '0'
		hi_ch := hex_buffer[byte_idx * 2] if byte_idx * 2 < hex_len else '0'
		lo_nib, ok_lo := hex_to_nibble(lo_ch)
		hi_nib, ok_hi := hex_to_nibble(hi_ch)
		if !ok_lo do lo_nib = 0
		if !ok_hi do hi_nib = 0
		data[byte_idx] = (hi_nib << 4) | lo_nib
	}
}

// Refresh the hex buffer from the current data array.
@(private = "file")
unpack_data :: proc() {
	for byte_idx in 0 ..< WAVE_SAMPLE_COUNT {
		b := data[byte_idx]
		hex_buffer[byte_idx * 2] = nibble_to_hex((b >> 4) & 0xF)
		hex_buffer[byte_idx * 2 + 1] = nibble_to_hex(b & 0xF)
	}
	hex_buffer[WAVE_SAMPLE_COUNT * 2] = 0
}

// Fill the table from a hex string, then sync the buffer.
wavetable_load_hex :: proc(hex: string) {
	empty_data()
	copy(hex_buffer[:], hex[:min(len(hex), WAVE_SAMPLE_COUNT * 2)])
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
		byte := clamp(int((var + 1.0) * 0.5 * 255.0 + 0.5), 0, 255)
		data[i] = u8(byte)
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

// Read the sample at phase position [0,1) as an amplitude in [-1,1].
@(private = "file")
sample_at :: proc(phase: f32) -> f32 {
	idx := int(phase * WAVE_SAMPLE_COUNT) & (WAVE_SAMPLE_COUNT - 1)
	value := (f32(data[idx]) / 255.0) * 2.0 - 1.0
	return value
}

wavetable_generate :: proc() -> f32 {
	amp := envelopes.envelope_update(&env, get_active(), 1.0 / constants.SAMPLE_RATE)
	if amp <= 0.0 {
		return 0.0
	}
	advance_phase()

	return sample_at(get_phase()) * amp * get_volume()
}

wavetable_draw_gui :: proc() {
	rl.GuiCheckBox({150, 130, 60, 20}, "Wavetable", &wavetable_active)
	rl.GuiSliderBar({150, 150, 60, 15}, "", "Volume", &wavetable_volume, 0.0, 0.6)
	rl.GuiSliderBar({150, 165, 60, 15}, "", "Attack", &env.attack_time, 0.0, 0.5)
	rl.GuiSliderBar({150, 180, 60, 15}, "", "Release", &env.release_time, 0.0, 0.5)

	if rl.GuiButton({150, 200, 60, 20}, "Sine") {
		fill_preset(.Sine)
	}
	if rl.GuiButton({214, 200, 60, 20}, "Triangle") {
		fill_preset(.Triangle)
	}
	if rl.GuiButton({278, 200, 60, 20}, "Saw") {
		fill_preset(.Saw)
	}
	if rl.GuiButton({342, 200, 60, 20}, "Square") {
		fill_preset(.Square)
	}

	pack_data()

	rl.GuiSlider({150, 225, 60, 15}, "", "Pitch", &wavetable_pitch, 40.0, 4000.0)

	draw_wave_preview({150, 250, 268, 110})

	rl.GuiTextBox(
		{150, 395, 228, 20},
		cstring(&hex_buffer[0]),
		WAVE_SAMPLE_COUNT * 2 + 1,
		hex_edit_active,
	)
	if rl.GuiButton({390, 395, 28, 20}, "Clr") {
		fill_preset(.Empty)
	}
	rl.GuiCheckBox({150, 420, 70, 15}, "Edit Hex", &hex_edit_active)

	if rl.GuiButton({220, 420, 60, 20}, "Save") {
		save_path := tfd.saveFileDialog(
			"Save Wavetable Sample",
			nil,
			1,
			raw_data(file_ext),
			"Wavetable files",
		)

		err := os.write_entire_file_from_bytes(string(save_path), data[:])
		if err != os.General_Error.None do fmt.printfln("Error saving wavetable sample to file")
	}

	if rl.GuiButton({290, 420, 60, 20}, "Load") {
		load_path := tfd.openFileDialog(
			"Load Wavetable Sample",
			nil,
			1,
			raw_data(file_ext),
			"Wavetable files",
			0,
		)

		bytes, err := os.read_entire_file_from_path(string(load_path), context.temp_allocator)
		defer free_all(context.temp_allocator)
		if err != io.Error.None {
			fmt.printfln("Error loading wavetable sample from file")
			return
		} else {
			mem.copy(&data[0], &bytes[0], len(data))
			unpack_data()
		}
	}
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
	headroom := bounds.height * 0.05
	for i in 0 ..= WAVE_SAMPLE_COUNT {
		value := sample_at(f32(i) / f32(WAVE_SAMPLE_COUNT))
		x := bounds.x + f32(i) / f32(WAVE_SAMPLE_COUNT) * bounds.width
		y := bounds.y + bounds.height * 0.5 - value * 0.5 * (bounds.height - 2 * headroom)
		cur := rl.Vector2{x, y}
		if i > 0 {
			rl.DrawLineV(prev, cur, rl.GREEN)
		}
		prev = cur
	}
}

wavetable_init :: proc() {
	fill_preset(.Empty)
}
