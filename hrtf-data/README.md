# HRTF impulse responses

cinema-engine convolves the stereo stream with a pair of head-related impulse responses so the image sits in front of you (screen-like) instead of inside your head.

## Expected files

Put 16-bit or float WAV files in this directory. Sample rate is resampled at load time.

Preferred:

```
hrtf-data/front_left.wav
hrtf-data/front_right.wav
```

Also recognized:

- `H10e000a.wav` — MIT KEMAR naming for elevation +10°, azimuth 0° (in front, slightly above)
- `H0e000a.wav` — elevation 0°, azimuth 0°
- `left.wav` / `right.wav`
- `front.wav` / `kemar_front.wav` (mono, copied to both ears)

You can also copy the same files to `~/.cinema-engine/hrtf-data/`.

## MIT KEMAR

The [MIT KEMAR HRTF dataset](https://sound.media.mit.edu/resources/KEMAR.html) is free for research and personal use. The compact archive is not WAV; convert a front measurement, or use a WAV mirror of the full set.

A typical “screen in front” pair is azimuth 0° and elevation +10° or +20°.

cinema-engine does **not** bundle the dataset (keep the repo small and respect dataset terms). If this folder is empty, the HRTF node falls back to a short synthetic front IR so the rest of the cinema chain still works.

## License note

KEMAR data remains under the MIT Media Lab dataset terms. This folder is only a place to drop files you obtained yourself.
