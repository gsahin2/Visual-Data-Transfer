#ifndef VDT_CAPI_H
#define VDT_CAPI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// CRC-16/CCITT-FALSE over the given bytes.
uint16_t vdt_crc16(const uint8_t* data, size_t length);

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

/// Pixel-space cell rectangle for a row-major grid inside the viewport.
void vdt_layout_cell_rect(uint32_t viewport_width, uint32_t viewport_height, uint16_t grid_rows, uint16_t grid_cols,
                          uint32_t margin_px, uint32_t gap_px, uint16_t row, uint16_t col, float* out_x0,
                          float* out_y0, float* out_x1, float* out_y1);

/// Row-major linear index from cell coordinates.
uint32_t vdt_symbol_cell_to_index(uint16_t grid_rows, uint16_t grid_cols, uint16_t row, uint16_t col);

#ifdef __cplusplus
}
#endif

#endif
