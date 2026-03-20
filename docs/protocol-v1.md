# Protocol V1 (20 KiB transfer target)

V1 supports **loop-based** optical transfer: the sender repeats a structured sequence so a receiver can recover up to **20,480 bytes** over several seconds. Authoritative constants live in `core/include/vdt/protocol/constants.hpp`.

## Transfer session model

| Concept | Description |
|---------|-------------|
| **Transfer ID** | `session_id` in the frame header (32-bit); identifies one logical transfer. |
| **Payload size** | Total application bytes (≤ `kMaxTransferPayloadBytes` = 20 KiB). |
| **Data frames** | `FrameType::Payload` chunks carrying sequential payload segments. |
| **Descriptor frames** | `FrameType::Descriptor` — repeat metadata so late-joining receivers can sync. |
| **Encoding mode** | `Safe` (high descriptor redundancy) vs `Normal` (balanced); stored in descriptor body. |
| **Per-frame integrity** | **CRC-16/CCITT-FALSE** over `header || payload`. |
| **End-to-end integrity** | **CRC-32 (IEEE / Ethernet)** over the **full assembled payload**, stored in the descriptor. |

### Descriptor payload (`TransferDescriptorV1`, 20 bytes LE)

| Offset | Size | Field |
|--------|------|--------|
| 0 | 1 | `layout_version` (= 1) |
| 1 | 1 | `encoding_mode` (0 Safe, 1 Normal) |
| 2 | 2 | `reserved0` (0) |
| 4 | 4 | `transfer_id` |
| 8 | 4 | `payload_byte_length` |
| 12 | 4 | `payload_crc32` |
| 16 | 2 | `data_frame_count` (number of Payload frames in one cycle) |
| 18 | 2 | `reserved1` (0) |

Descriptor frames use the same outer header as payload frames: `chunk_index = 0`, `chunk_count = 1`, `frame_type = Descriptor`.

## Frame envelope (unchanged octet layout)

| Field | Size | Description |
|-------|------|-------------|
| `magic0` | 1 | `0x56` (`V`) |
| `magic1` | 1 | `0x54` (`T`) |
| `version` | 1 | `1` |
| `frame_type` | 1 | `0` Payload, `1` Descriptor |
| `flags` | 1 | Bit 0: final-chunk hint (payload path) |
| `reserved` | 1 | `0` |
| `session_id` | 4 | Transfer ID |
| `chunk_index` | 2 | Zero-based payload chunk index (descriptors use `0`) |
| `chunk_count` | 2 | Total payload chunks in session (descriptors use `1`) |
| `payload_length` | 2 | Bytes following header |
| `padding` | 2 | `0` |
| `payload` | `payload_length` | Descriptor body or raw chunk bytes |
| `crc16` | 2 | CRC16 over header + payload |

`kFrameHeaderBytes = 18`. **`payload_length` ≤ `kMaxPayloadBytesPerFrame` (1024).**

## Loop strategy (sender)

One **loop cycle** is built by `vdt::encode::build_transfer_loop_cycle` (and `vdt_transfer_loop_cycle` / `vdt_transfer_loop_cycle_ex` in the C API):

| Mode | Order within a cycle |
|------|----------------------|
| **Normal** | `[Descriptor] [Payload₀ … Payloadₙ₋₁]` |
| **Safe** | `[Descriptor][Payload₀][Descriptor][Payload₁]…` |

**Phase 5 options** (`TransferLoopOptions` / `vdt_transfer_loop_cycle_ex`):

- **Normal:** `repeat_descriptor_every_k_payloads = K` (`K > 0`) inserts an extra descriptor before payload index `i` when `i > 0 && (i % K) == 0` (e.g. `K = 2` → `D P₀ P₁ D P₂ P₃ …`). `K = 0` keeps the single leading descriptor.
- **Normal / Safe:** `trailing_descriptor` appends a duplicate descriptor after the last payload (wrap / late-join).

The UI / scheduler **repeats** this cycle for the target wall-clock duration (Phase 2). Decoders treat repeated identical chunk indices as **redundant** (same bytes → success; conflicting bytes → error).

## Receiver assembly

1. Parse **Descriptor** whenever seen. If a descriptor’s `(transfer_id, data_frame_count, payload_byte_length, payload_crc32)` matches the **already accepted** descriptor for this session, the frame is a **no-op** (partial slots are kept). Otherwise `SessionReassemblyBuffer` resets from the new descriptor.
2. Ingest **Payload** frames in any order **by chunk index** until all slots filled.
3. When a descriptor was processed, `SessionAssembler::take_merged_payload` checks **byte length** and **CRC-32** before returning data.
4. If no descriptor was seen (legacy path), assembly uses header `chunk_count` only and **skips** CRC32 verification at take time.

## Symbol mapping (visual channel)

The **on-screen grid** is separate from the wire chunking. V1 product default: **2 bits per cell** (4 luminance levels). See `docs/frame-layout.md` and `docs/constraints.md`.

## Bit packing

MSB-first bit streams for dense packing live in `vdt::common::BitWriter` / `BitReader`.

## Optional inner packet layout

`protocol/packet.hpp` still defines an optional `stream_offset` / `stream_total` wrapper for future streaming APIs; the reference loop encoder uses **raw payload chunks** in Payload frames.

## Reference code

| Area | Location |
|------|-----------|
| Constants | `core/include/vdt/protocol/constants.hpp` |
| Descriptor | `core/include/vdt/protocol/descriptor.hpp` |
| Loop cycle | `core/include/vdt/encode/transfer_loop.hpp` |
| Assembler | `core/include/vdt/decode/session_assembler.hpp` |
| C API | `core/include/vdt/capi.h` (`vdt_session_assembler_push_wire` / `push_decoded`, `take_merged_payload`) |
| Python mirror | `python/vdt_protocol_v1.py` — `SessionAssembler.push_wire` / `push_decoded`, `take_payload` |
