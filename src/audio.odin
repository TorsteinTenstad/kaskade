package main

import "core:strings"
import rl "vendor:raylib"

Audio_Id :: enum {
	move,
	capture,
	your_turn,
}

Audio :: struct {
	sounds: map[Audio_Id]rl.Sound,
}

Audio_Paths := [Audio_Id]string {
	.move      = "move.wav",
	.capture   = "move.wav",
	.your_turn = "your_turn.wav",
}

audio_load :: proc(audio: ^Audio) {
	rl.InitAudioDevice()
	for path, id in Audio_Paths {
		full_path := strings.concatenate({ASSETS_PATH, path})
		sound := rl.LoadSound(cstr(full_path))
		if !rl.IsSoundValid(sound) {
			log_red("Could not load sound", full_path)
			continue
		}
		audio.sounds[id] = sound
	}
}

audio_play :: proc(audio: ^Audio, id: Audio_Id) {
	rl.PlaySound(audio.sounds[id])
}
