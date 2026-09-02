package envelopes

Envelope_State :: enum {
	Idle,
	Attack,
	Decay,
	Sustain,
	Release,
}

Envelope :: struct {
	state:        Envelope_State,
	timer:        f32,
	level:        f32,
	attack_time:  f32,
	release_time: f32,
	was_on:       bool,
}

decay_time: f32 = 0.05 // time (in sec) to fall from peak to sustain level
sustain_level: f32 = 0.7 // held amplitude while a note stays on

// Advance the envelope by one sample. Returns the amplitude multiplier in [0,1].
envelope_update :: proc(e: ^Envelope, active: bool, delta: f32) -> f32 {
	if active && !e.was_on {
		e.state = .Attack
		e.timer = 0
	} else if !active && e.was_on {
		e.state = .Release
		e.timer = 0
	}
	e.was_on = active

	switch e.state {
		case .Attack:
			e.timer += delta
			e.level = e.timer / e.attack_time
			if e.timer >= e.attack_time {
				e.level = 1
				e.timer = 0
				e.state = .Decay
			}
		case .Decay:
			if decay_time <= 0 {
				e.level = sustain_level
				e.state = .Sustain
			} else {
				e.timer += delta
				e.level = sustain_level + (1 - sustain_level) * (1 - e.timer / decay_time)
				if e.timer >= decay_time {
					e.level = sustain_level
					e.state = .Sustain
				}
			}
		case .Sustain:
			e.level = sustain_level
		case .Release:
			e.timer += delta
			e.level = sustain_level * (1 - e.timer / e.release_time)
			if e.level < 0 do e.level = 0
			if e.timer >= e.release_time {
				e.level = 0
				e.state = .Idle
			}
		case .Idle:
			e.level = 0
	}

	return e.level
}
