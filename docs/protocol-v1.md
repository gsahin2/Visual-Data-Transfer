# Protocol V1

Version 1 defines a compact binary frame for screen-to-camera transmission experiments. Integrity uses **CRC-16/CCITT-FALSE** (poly `0x1021`, init `0xFFFF`, no reflection).

## Frame format

All multi-byte fields are **little-endian**.

| Field | Size | Description |
|-------|------|-------------|
| `magic0` | 1 | `0x56` (`V`) |
| `magic1` | 1 | `0x54` (`T`) |
| `version` | 1 | Must be `1` |
| `frame_type` | 1 | `0` data, `1` session sync (extensible) |
| `flags` | 1 | Bit `0`: final-chunk hint |
| `reserved` | 1 | `0` |
| `session_id` | 4 | Logical session identifier |
| `chunk_index` | 2 | Zero-based chunk index |
| `chunk_count` | 2 | Total chunks in the session |
| `payload_length` | 2 | Length of payload in bytes |
| `padding` | 2 | Zeroed (alignment) |
| `payload` | `payload_length` | Opaque bytes |
| `crc16` | 2 | CRC over **header + payload** (excluding the CRC itself) |

`HEADER_BYTES = 18`. Maximum `payload_length` is `1024` (`kMaxPayloadBytesV1`).

## Session rules

- `chunk_count` must be consistent for every frame in a session.
- Chunks are **ordered** by `chunk_index` and concatenated without inserting separators.
- Duplicate indices are rejected by the assembler.

## Optional inner packet layout

`protocol/packet.hpp` defines an optional logical layout for payloads:

```
| stream_offset: u64 | stream_total: u64 | message... |
```

The reference encoder currently emits **raw chunk bytes** with metadata carried only in the frame header. The packet helpers exist for higher-level streaming without changing the wire envelope.

## Constants (C++)

See `core/include/vdt/protocol/constants.hpp` for authoritative values.
