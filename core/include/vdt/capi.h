#ifndef VDT_CAPI_H
#define VDT_CAPI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// CRC-16/CCITT-FALSE over the given bytes.
uint16_t vdt_crc16(const uint8_t* data, size_t length);

/// CRC-32 (IEEE / Ethernet) over the given bytes.
uint32_t vdt_crc32_ieee(const uint8_t* data, size_t length);

/// Maximum assembled transfer payload for V1 (20 KiB).
uint32_t vdt_max_transfer_payload_bytes(void);

typedef struct VDTFrameHeaderC {
  uint8_t version;
  uint8_t frame_type;
  uint8_t flags;
  uint32_t session_id;
  uint16_t chunk_index;
  uint16_t chunk_count;
  uint16_t payload_length;
} VDTFrameHeaderC;

/// Builds one wire frame into `out`. Returns wire length, or 0 on error.
size_t vdt_frame_build(const VDTFrameHeaderC* header, const uint8_t* payload, size_t payload_length, uint8_t* out,
                       size_t out_capacity);

/// Parses a full wire frame. On success returns 1 and fills `header` and `payload_out`.
int vdt_frame_parse(const uint8_t* wire, size_t wire_length, VDTFrameHeaderC* header, uint8_t* payload_out,
                    size_t payload_capacity, size_t* payload_written_out);

typedef struct VDTEncodedSession {
  uint8_t** frame_data;
  size_t* frame_sizes;
  size_t frame_count;
} VDTEncodedSession;

/// Encodes a logical message into one or more framed chunks (heap-allocated). Free with `vdt_encoded_session_free`.
VDTEncodedSession* vdt_encode_session(uint32_t session_id, const uint8_t* message, size_t message_length,
                                      uint16_t max_payload_bytes);

void vdt_encoded_session_free(VDTEncodedSession* session);

/// Builds one full loop cycle (descriptor + payload frames). `encoding_mode`: 0 = Safe, 1 = Normal.
VDTEncodedSession* vdt_transfer_loop_cycle(uint32_t transfer_id, const uint8_t* message, size_t message_length,
                                           uint8_t encoding_mode, uint16_t max_payload_bytes);

/// Pixel-space cell rectangle for a row-major grid inside the viewport.
void vdt_layout_cell_rect(uint32_t viewport_width, uint32_t viewport_height, uint16_t grid_rows, uint16_t grid_cols,
                          uint32_t margin_px, uint32_t gap_px, uint16_t row, uint16_t col, float* out_x0,
                          float* out_y0, float* out_x1, float* out_y1);

/// Row-major linear index from cell coordinates.
uint32_t vdt_symbol_cell_to_index(uint16_t grid_rows, uint16_t grid_cols, uint16_t row, uint16_t col);

/// Full-bleed marker corners + homography (`FullBleedMarkerDetector` → normalized quad → `GridSampler`) and bilinear
/// luma sample into `out_luma` (row-major, `rows * cols` bytes). Returns 1 on success.
int vdt_sample_grid_full_bleed(const uint8_t* gray, uint32_t width, uint32_t height, uint16_t rows, uint16_t cols,
                               uint8_t* out_luma, size_t out_capacity);

/// Opaque session reassembly state (V1 `SessionAssembler`).
typedef struct VDTSessionAssembler VDTSessionAssembler;

VDTSessionAssembler* vdt_session_assembler_create(void);
void vdt_session_assembler_destroy(VDTSessionAssembler* assembler);
void vdt_session_assembler_reset(VDTSessionAssembler* assembler);

/// Push one full wire frame (header + payload + CRC16). Returns 1 on success.
int vdt_session_assembler_push_wire(VDTSessionAssembler* assembler, const uint8_t* wire, size_t wire_length);

/// Push a decoded logical frame (same as after `vdt_frame_parse`). `header->payload_length` must match `payload_length`.
int vdt_session_assembler_push_decoded(VDTSessionAssembler* assembler, const VDTFrameHeaderC* header,
                                       const uint8_t* payload, size_t payload_length);

int vdt_session_assembler_is_complete(const VDTSessionAssembler* assembler);

/// Copies merged transfer bytes after CRC32 verify (when descriptor was seen). Returns 0 if not ready, CRC failed, or
/// `out_capacity` too small (assembler unchanged). On success returns byte count and resets the assembler.
size_t vdt_session_assembler_take_merged_payload(VDTSessionAssembler* assembler, uint8_t* out, size_t out_capacity);

#ifdef __cplusplus
}
#endif

#endif
