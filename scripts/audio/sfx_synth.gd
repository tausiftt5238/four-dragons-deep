# SfxSynth
# Builds a sound effect from a recipe in data/sfx_recipes.json, so no audio
# file has to exist anywhere. The tuning page the recipes were dialled in on
# runs the same synth in JavaScript; keep the two in step, or what was tuned
# by ear is not what plays.
#
# A recipe is a few layers mixed together. Each layer is a waveform sliding
# from one pitch to another, optionally stepping through notes (an arpeggio,
# each note its own voice), shaped by an attack-then-decay envelope and damped
# by a two-pole low-pass, which is what keeps them soft rather than buzzy.
class_name SfxSynth

const SR: int = 22050


static func render(snd: Dictionary, master: Dictionary) -> AudioStreamWAV:
	var lp_scale: float = float(master.get("lp_scale", 1.0))
	var layers: Array = snd.get("layers", [])
	var total: float = 0.0
	for L: Dictionary in layers:
		var notes: Array = _notes(L)
		total = maxf(total, float(L.get("delay", 0.0)) \
				+ (notes.size() - 1) * float(L.get("step", 0.0)) + float(L["a"]) + float(L["d"]))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(ceili((total + 0.02) * SR))

	for li: int in layers.size():
		var L: Dictionary = layers[li]
		var notes: Array = _notes(L)
		var step: float = float(L.get("step", 0.0))
		var a: float = maxf(float(L["a"]), 0.0005)
		var d: float = maxf(float(L["d"]), 0.005)
		var voice_len: float = a + d
		var layer_len: float = (notes.size() - 1) * step + voice_len
		var lp: float = minf(float(L.get("lp", 20000.0)) * lp_scale, SR * 0.45)
		var c: float = 1.0 - exp(-TAU * lp / SR)
		var f0: float = float(L["f0"])
		var f1: float = float(L.get("f1", f0))
		var ratio: float = f1 / f0 if f0 > 0.0 and f1 > 0.0 else 1.0
		var vib: float = float(L.get("vib", 0.0))
		var vrate: float = float(L.get("vrate", 0.0))
		var vol: float = float(L["vol"])
		var wave: String = String(L["wave"])
		# The slide, stepped by one multiply a sample rather than a pow.
		var f_mul: float = pow(ratio, 1.0 / (layer_len * SR))
		var a_n: int = int(a * SR)
		var decay_mul: float = exp(-3.0 / (d * SR))

		for k: int in notes.size():
			var start: int = int((float(L.get("delay", 0.0)) + k * step) * SR)
			var f: float = f0 * pow(2.0, float(notes[k]) / 12.0) * pow(ratio, k * step / layer_len)
			var ph: float = 0.0
			var held: float = 0.0
			var last: int = -1
			var y1: float = 0.0
			var y2: float = 0.0
			var seed: int = (2463534242 + li * 7919 + k * 104729) & 0xFFFFFFFF
			var decay_e: float = 1.0
			var count: int = int(voice_len * SR)
			for i: int in count:
				var j: int = start + i
				if j >= buf.size():
					break
				var fi: float = f
				if vib != 0.0:
					fi *= pow(2.0, vib * sin(TAU * vrate * (k * step + float(i) / SR)) / 12.0)
				f *= f_mul
				ph += fi / SR
				var x: float
				match wave:
					"sine":
						x = sin(TAU * ph)
					"tri":
						x = 4.0 * absf(ph - floorf(ph) - 0.5) - 1.0
					"square":
						x = 1.0 if ph - floorf(ph) < 0.5 else -1.0
					_:
						var cyc: int = int(ph)
						if cyc != last:
							last = cyc
							seed = (seed ^ (seed << 13)) & 0xFFFFFFFF
							seed = seed ^ (seed >> 17)
							seed = (seed ^ (seed << 5)) & 0xFFFFFFFF
							held = float(seed) / 4294967295.0 * 2.0 - 1.0
						x = held
				y1 += c * (x - y1)
				y2 += c * (y1 - y2)
				var env: float
				if i < a_n:
					env = float(i) / (a * SR)
				else:
					var u: float = minf(float(i - a_n) / (d * SR), 1.0)
					env = (1.0 - u) * decay_e
					decay_e *= decay_mul
				buf[j] += y2 * env * vol

	var g: float = float(snd.get("gain", 1.0)) * float(master.get("gain", 1.0))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(buf.size() * 2)
	for i: int in buf.size():
		pcm.encode_s16(i * 2, int(tanh(buf[i] * g) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SR
	stream.stereo = false
	stream.data = pcm
	return stream


static func _notes(L: Dictionary) -> Array:
	var n: Array = L.get("notes", [])
	return n if not n.is_empty() else [0]
