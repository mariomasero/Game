class_name LabCues
extends RefCounted

## Original short sine tones; editable source, no external audio assets.
const SAMPLE_RATE: int = 22050
const NOTE_SECONDS: float = 0.11
const GAP_SECONDS: float = 0.02

static func make_cue(kind: StringName) -> AudioStreamWAV:
	var notes: Array[float]
	match kind:
		&"cash": notes = [659.25, 783.99, 1046.5]
		&"ready": notes = [783.99, 1046.5, 783.99]
		&"upgrade": notes = [523.25, 659.25, 783.99, 1046.5]
		&"error": notes = [220.0, 164.81]
		&"start": notes = [392.0, 523.25]
		_: notes = [523.25, 659.25]
	var note_samples := int(NOTE_SECONDS * SAMPLE_RATE)
	var stride := note_samples + int(GAP_SECONDS * SAMPLE_RATE)
	var pcm := PackedByteArray()
	pcm.resize(stride * notes.size() * 2)
	for note in range(notes.size()):
		for sample_index in range(note_samples):
			var t := float(sample_index) / SAMPLE_RATE
			var envelope := minf(t / 0.006, 1.0) * pow(1.0 - float(sample_index) / note_samples, 2)
			var wave := sin(TAU * notes[note] * t) + 0.12 * sin(TAU * notes[note] * 2.0 * t)
			var sample_value := int(wave * envelope * 12000.0)
			var offset := (note * stride + sample_index) * 2
			pcm[offset] = sample_value & 255
			pcm[offset + 1] = (sample_value >> 8) & 255
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = pcm
	return stream
