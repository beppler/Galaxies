package main

import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SoundId :: enum {
	Laser,
	Boom,
	Hit,
	Dock,
	Hyper,
	Beep,
}

sounds: [SoundId]rl.Sound
audio_ok: bool

@(private = "file")
synth :: proc(f0, f1, dur: f32, noise: bool, vol: f32) -> rl.Sound {
	RATE :: 22050
	n := int(dur * RATE)
	data := make([]i16, n)
	defer delete(data)
	phase: f32
	for i in 0 ..< n {
		t := f32(i) / f32(n)
		f := f0 + (f1 - f0) * t
		phase += 2 * math.PI * f / RATE
		s := math.sin(phase)
		if noise {
			s = rand.float32_range(-1, 1)
		}
		data[i] = i16(s * (1 - t) * vol * 32000)
	}
	w := rl.Wave {
		frameCount = u32(n),
		sampleRate = RATE,
		sampleSize = 16,
		channels   = 1,
		data       = raw_data(data),
	}
	return rl.LoadSoundFromWave(w)
}

init_audio :: proc() {
	rl.InitAudioDevice()
	audio_ok = rl.IsAudioDeviceReady()
	if !audio_ok {
		return
	}
	sounds[.Laser] = synth(1400, 300, 0.12, false, 0.3)
	sounds[.Boom] = synth(0, 0, 0.5, true, 0.5)
	sounds[.Hit] = synth(150, 60, 0.2, false, 0.6)
	sounds[.Dock] = synth(400, 900, 0.4, false, 0.4)
	sounds[.Hyper] = synth(200, 1800, 1.2, false, 0.4)
	sounds[.Beep] = synth(880, 880, 0.08, false, 0.3)
}

shutdown_audio :: proc() {
	if audio_ok {
		for s in sounds {
			rl.UnloadSound(s)
		}
	}
	rl.CloseAudioDevice()
}

play :: proc(id: SoundId) {
	when !ODIN_TEST { // see platform.odin
		if audio_ok {
			rl.PlaySound(sounds[id])
		}
	}
}
