# Frame Layout (Visual Grid)

The **visual grid** is independent from the binary wire format but is designed to be easy to sample after homography normalization.

## Grid parameters

- `rows` × `cols` cells, **row-major** linear indexing.
- Each cell represents **4 bits** (16 discrete levels) in demo renderers.
- Bytes are expanded MSB-first within each byte; cells consume nibbles in order.

## Mapping helpers (C++)

- `encode/symbol_mapping.hpp` — `cell_to_index`, `index_to_cell`, nibble helpers.
- `render/layout.hpp` — maps grid + viewport to pixel rectangles and normalized centers for sampling.

## Margins and gaps

Layouts reserve a configurable **margin** (pixels) and **gap** between cells so real-world captures can separate symbols. Defaults: margin `8`, gap `2`.

## Determinism

Given the same payload bytes and grid dimensions, every platform must produce the **same** nibble sequence. Rendering may choose different palettes (grayscale vs. color) as long as luminance steps remain separable by the decoder.

## Markers

The reference `FullBleedMarkerDetector` assumes the entire image is the code area (corners at image bounds). Production systems can swap in corner markers or AprilTag-style anchors without changing the encoder API.
