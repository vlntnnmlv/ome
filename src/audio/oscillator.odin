package omeaudio

Oscillator :: struct {
	phase:     f32,
	frequency: f32,
	amplitude: f32,
}

EnvelopeAD :: struct {
	attack: f32,
	decay:  f32,
}

EnvelopeADSR :: struct {
	attack:  f32,
	decay:   f32,
	sustain: f32,
	release: f32,
}
