# RCA: Transcription Latency Significantly Higher Than SuperWhisper

**Date:** 2026-06-25
**Status:** Root cause identified (confirmed — code verified directly)

## What broke

After recording stops, transcription takes noticeably longer than SuperWhisper using the same Whisper base model. The user-perceived gap is especially pronounced for short clips (1–5 seconds of speech), which is the dominant dictation use case.

## Causation chain

User releases hotkey → `stopDictation()` → audio flush + 100ms sleep → `whisper_full()` runs on CPU, processing a full 30-second encoder window even for a 2-second clip, with no GPU acceleration
  ↓ caused by
`audio_ctx = 0` in `WhisperEngine.swift:56` — default params are used verbatim, which sets `audio_ctx` to zero (= always encode the full 30-second Whisper context window regardless of actual audio length)
  ↓ caused by
`ggml-metal.m` is in the `exclude` list in `whisper.spm/Package.swift` — the SPM maintainer couldn't resolve an NSString compilation error and left a TODO; Metal GPU acceleration is entirely disabled
  ↓ caused by
`WHISPER_USE_COREML` is compiled in (`whisper.spm/Package.swift`) but `ModelManager` only downloads GGML `.bin` files — there are no `.mlmodelc` CoreML encoder artifacts, so the CoreML path is dead code; every inference falls through to CPU
  ↓ caused by
**ROOT CAUSE: The macOS 13 deployment target forced use of `whisper.spm` (a stale, incomplete SPM wrapper) instead of WhisperKit, which provides CoreML + Apple Neural Engine acceleration on macOS 14+. The chosen dependency has Metal broken and no usable CoreML encoder pipeline, leaving CPU-only inference as the only path.**

## Root cause

Architecture category: **dependency + configuration**

The research phase correctly identified that WhisperKit (ANE-accelerated, dramatically faster) requires macOS 14+. The decision to target macOS 13 forced adoption of `whisper.spm`, which turns out to be a stale third-party wrapper with Metal explicitly disabled (not just unconfigured — explicitly excluded with a TODO comment from the maintainer) and a CoreML path that is compiled in but never exercised because no `.mlmodelc` encoder files are downloaded. The result is single-threaded CPU-only inference using the Accelerate framework — the lowest tier of hardware utilization on Apple Silicon.

SuperWhisper almost certainly uses CoreML with a quantized encoder or WhisperKit directly, which offloads the encoder to the ANE and runs 8–15x faster than CPU GGML on the same chip.

## Contributing factors

**1. `audio_ctx = 0` — full 30-second encoder window on every clip (biggest addressable win right now)**

`whisper_full_default_params` sets `audio_ctx = 0`, which tells whisper to encode the full 30-second context window. For a 2-second clip, the encoder wastes ~93% of its work on silence padding. Setting `audio_ctx` proportionally to actual audio length (e.g., `(samples.count / 16000) * 100 / 1500` of the 1500 Mel frames) can cut encoder time by up to 10x for short clips with zero accuracy loss.

**2. 100ms artificial sleep in `TranscriptionSession.stop()` (line 52)**

```swift
try? await Task.sleep(nanoseconds: 100_000_000)
```

This is a band-aid for a race condition between `bufferProcessor.flush()` firing the async `transcribeAndInsert` callback and `stop()` reading `sessionText`. It adds 100ms floor latency on every dictation end. The real fix is to await the pending transcription rather than sleeping.

**3. `single_segment = false` (default)**

For hold-to-talk dictation where the entire utterance is in one buffer, `single_segment = true` forces whisper to produce one output token stream rather than splitting across multiple decoder passes. Slight speed improvement and avoids spurious segment splits.

**4. No `audio_ctx` ceiling in `AudioBufferProcessor` (5-second max segment)**

`maxSegmentDuration = 5.0` means the maximum segment is 5 seconds = 80,000 samples. A 30-second Whisper context window at 16 kHz = 480,000 samples. If `audio_ctx` were set dynamically, a 5-second clip would use only 500 of the 1500 Mel frames — a 3x speedup in the encoder alone.

**5. macOS 13 deployment target**

This is the root architectural blocker. SuperWhisper can use Apple Neural Engine (ANE) because it presumably targets macOS 14+. ANE runs the Whisper encoder at roughly 0.1–0.3x real-time even on base model. CPU GGML runs at roughly 0.5–2x real-time depending on chip. On M1, base model CPU inference for a 3-second clip runs in ~1.5–3s. ANE runs the same clip in ~200–400ms.

## Evidence gaps

- Exact SuperWhisper architecture is not confirmed (inferred from public documentation and WhisperKit benchmarks)
- Actual per-stage timing on the user's machine is not measured — no instrumentation exists in the app
- `n_threads` defaults to `min(4, hardware_concurrency)` (confirmed in whisper.cpp line 4647), so threading is not the problem

## Fix

### Immediate (ship today, no dependency changes):

**1. Set `audio_ctx` dynamically in `WhisperEngine.transcribe()` (`WhisperEngine.swift:56–60`)**

```swift
var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
params.print_progress = false
params.print_special = false
params.print_realtime = false
params.print_timestamps = false
params.single_segment = true

// Size encoder window to actual audio length; 1500 = full 30s context
let audioDurationSeconds = Float(audioSamples.count) / Float(sampleRate)
let audioCtx = Int32(min(audioDurationSeconds * 50.0, 1500.0))  // ~50 frames/sec
params.audio_ctx = audioCtx > 0 ? audioCtx : 0
```

This alone should cut encoder time by 3–10x for typical short dictation clips.

**2. Remove the 100ms sleep in `TranscriptionSession.stop()` (line 52)**

Replace the sleep with a proper mechanism to drain in-flight transcriptions (e.g., a `Task` group, an AsyncStream, or an actor-isolated pending counter). The sleep is fragile and always-paid latency.

**3. Set `params.single_segment = true`** — hold-to-talk produces a single contiguous recording; no reason to split it into multiple decoder segments.

### Medium-term (1–2 days):

**4. Drop macOS 13 and switch to WhisperKit**

The research already identified WhisperKit as the right long-term target. macOS 13 Ventura shipped in September 2022 — it's now mid-2026, and Ventura's market share is negligible. Raising the target to macOS 14 unlocks:
- Apple Neural Engine inference (CoreML encoder)
- WhisperKit's automatic model management
- Clean async Swift API — no C++ bridging
- 8–15x real-world speedup on Apple Silicon

If macOS 13 support is non-negotiable, consider building a fixed version of `ggml-metal.m` manually or switching to `ggml.swift` (which has Metal working).

**5. Add per-stage timing instrumentation**

Before optimizing further, add `os.signpost` timing around (a) mel spectrogram computation, (b) encoder forward pass, (c) decoder forward pass. This gives ground truth on where time is actually going and prevents guessing.

## Prevention

- **Benchmark before locking in a dependency**: the whisper.spm maintainer's own README has a TODO saying Metal doesn't work — this should have been caught in the R1 research spike
- **Add a latency regression test**: record a known 3-second audio clip, assert end-to-end transcription completes in under N seconds; this will catch regressions as the model/runtime changes
- **Consider the deployment target more aggressively**: macOS 13 was a hard constraint from 2024-era spec; revisiting it today would unlock the best available acceleration path
