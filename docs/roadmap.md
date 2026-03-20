# Roadmap

## Near term

- Harden receiver path: connect `GridSampler` output to bit reconstruction + frame parser.
- Add golden-vector tests shared between C++ and Python (`samples/` + CI step).
- Expand marker detection beyond full-bleed assumption.
- Document recommended camera exposure / focus settings for iOS.

## Medium term

- Optional forward-error correction (FEC) above the frame layer.
- Rate control: adaptive chunk sizing vs. display refresh.
- Android demo using the same C++ core via NDK + Kotlin.

## Longer term

- Pluggable symbol alphabets with contrast-aware palettes.
- Temporal redundancy (repeat frames) with decoder de-duplication policies.

## Non-goals

- Replacing general-purpose networking stacks.
- Obfuscating payloads for security through obscurity.
