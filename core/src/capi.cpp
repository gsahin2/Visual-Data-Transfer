#include "vdt/capi.h"

#include "vdt/common/crc16.hpp"
#include "vdt/common/crc32.hpp"
#include "vdt/decode/frame_decoder.hpp"
#include "vdt/decode/session_assembler.hpp"
#include "vdt/encode/frame_encoder.hpp"
#include "vdt/encode/transfer_loop.hpp"
#include "vdt/encode/symbol_mapping.hpp"
#include "vdt/protocol/constants.hpp"
#include "vdt/protocol/frame.hpp"
#include "vdt/render/layout.hpp"
#include "vdt/vision/grid_sampler.hpp"
#include "vdt/vision/homography.hpp"
#include "vdt/vision/marker_detector.hpp"

#include <cstdlib>
#include <cstring>
#include <span>
#include <vector>

struct VDTSessionAssembler {
  vdt::decode::SessionAssembler inner;
};

extern "C" {

uint16_t vdt_crc16(const uint8_t* data, const size_t length) {
  return vdt::crc16_ccitt_false(data, length);
}

uint32_t vdt_crc32_ieee(const uint8_t* data, const size_t length) {
  return vdt::crc32_ieee(data, length);
}

uint32_t vdt_max_transfer_payload_bytes(void) {
  return vdt::protocol::kMaxTransferPayloadBytes;
}

size_t vdt_frame_build(const VDTFrameHeaderC* header, const uint8_t* payload, const size_t payload_length, uint8_t* out,
                       const size_t out_capacity) {
  if (header == nullptr || out == nullptr) {
    return 0;
  }
  if (payload_length > UINT16_MAX || payload_length != header->payload_length) {
    return 0;
  }
  vdt::protocol::FrameHeader h{};
  h.version = header->version;
  h.frame_type = static_cast<vdt::protocol::FrameType>(header->frame_type);
  h.flags = header->flags;
  h.reserved = 0;
  h.session_id = header->session_id;
  h.chunk_index = header->chunk_index;
  h.chunk_count = header->chunk_count;
  h.payload_length = header->payload_length;
  const std::span<const uint8_t> pay(payload, payload_length);
  const auto wire = vdt::protocol::build_frame(h, pay);
  if (wire.empty() || wire.size() > out_capacity) {
    return 0;
  }
  std::memcpy(out, wire.data(), wire.size());
  return wire.size();
}

int vdt_frame_parse(const uint8_t* wire, const size_t wire_length, VDTFrameHeaderC* header, uint8_t* payload_out,
                    const size_t payload_capacity, size_t* payload_written_out) {
  if (wire == nullptr || header == nullptr || payload_written_out == nullptr) {
    return 0;
  }
  vdt::protocol::FrameHeader h{};
  std::vector<uint8_t> payload;
  if (!vdt::protocol::parse_frame({wire, wire_length}, h, payload)) {
    return 0;
  }
  if (payload.size() > payload_capacity) {
    return 0;
  }
  if (!payload.empty() && payload_out == nullptr) {
    return 0;
  }
  header->version = h.version;
  header->frame_type = static_cast<uint8_t>(h.frame_type);
  header->flags = h.flags;
  header->session_id = h.session_id;
  header->chunk_index = h.chunk_index;
  header->chunk_count = h.chunk_count;
  header->payload_length = h.payload_length;
  if (!payload.empty()) {
    std::memcpy(payload_out, payload.data(), payload.size());
  }
  *payload_written_out = payload.size();
  return 1;
}

VDTEncodedSession* vdt_encode_session(const uint32_t session_id, const uint8_t* message, const size_t message_length,
                                      const uint16_t max_payload_bytes) {
  if (message == nullptr && message_length > 0) {
    return nullptr;
  }
  vdt::encode::FrameEncoder enc(max_payload_bytes);
  const std::span<const uint8_t> msg(message, message_length);
  const std::vector<vdt::encode::EncodedFrame> frames = enc.encode_session(session_id, msg);
  auto* session = static_cast<VDTEncodedSession*>(std::malloc(sizeof(VDTEncodedSession)));
  if (session == nullptr) {
    return nullptr;
  }
  session->frame_data = nullptr;
  session->frame_sizes = nullptr;
  session->frame_count = frames.size();
  if (session->frame_count == 0) {
    return session;
  }
  session->frame_data = static_cast<uint8_t**>(std::calloc(session->frame_count, sizeof(uint8_t*)));
  session->frame_sizes = static_cast<size_t*>(std::calloc(session->frame_count, sizeof(size_t)));
  if (session->frame_data == nullptr || session->frame_sizes == nullptr) {
    vdt_encoded_session_free(session);
    return nullptr;
  }
  for (size_t i = 0; i < session->frame_count; ++i) {
    session->frame_sizes[i] = frames[i].wire.size();
    session->frame_data[i] = static_cast<uint8_t*>(std::malloc(frames[i].wire.size()));
    if (session->frame_data[i] == nullptr) {
      vdt_encoded_session_free(session);
      return nullptr;
    }
    std::memcpy(session->frame_data[i], frames[i].wire.data(), frames[i].wire.size());
  }
  return session;
}

VDTEncodedSession* vdt_transfer_loop_cycle(const uint32_t transfer_id, const uint8_t* message,
                                           const size_t message_length, const uint8_t encoding_mode,
                                           const uint16_t max_payload_bytes) {
  if (message == nullptr && message_length > 0) {
    return nullptr;
  }
  const auto mode = encoding_mode == 0 ? vdt::protocol::EncodingMode::Safe : vdt::protocol::EncodingMode::Normal;
  const std::span<const uint8_t> msg(message, message_length);
  const auto frames = vdt::encode::build_transfer_loop_cycle(transfer_id, msg, mode, max_payload_bytes);
  auto* session = static_cast<VDTEncodedSession*>(std::malloc(sizeof(VDTEncodedSession)));
  if (session == nullptr) {
    return nullptr;
  }
  session->frame_data = nullptr;
  session->frame_sizes = nullptr;
  session->frame_count = frames.size();
  if (session->frame_count == 0) {
    return session;
  }
  session->frame_data = static_cast<uint8_t**>(std::calloc(session->frame_count, sizeof(uint8_t*)));
  session->frame_sizes = static_cast<size_t*>(std::calloc(session->frame_count, sizeof(size_t)));
  if (session->frame_data == nullptr || session->frame_sizes == nullptr) {
    vdt_encoded_session_free(session);
    return nullptr;
  }
  for (size_t i = 0; i < session->frame_count; ++i) {
    session->frame_sizes[i] = frames[i].wire.size();
    session->frame_data[i] = static_cast<uint8_t*>(std::malloc(frames[i].wire.size()));
    if (session->frame_data[i] == nullptr) {
      vdt_encoded_session_free(session);
      return nullptr;
    }
    std::memcpy(session->frame_data[i], frames[i].wire.data(), frames[i].wire.size());
  }
  return session;
}

void vdt_encoded_session_free(VDTEncodedSession* session) {
  if (session == nullptr) {
    return;
  }
  if (session->frame_data != nullptr) {
    for (size_t i = 0; i < session->frame_count; ++i) {
      std::free(session->frame_data[i]);
    }
    std::free(session->frame_data);
  }
  std::free(session->frame_sizes);
  std::free(session);
}

void vdt_layout_cell_rect(const uint32_t viewport_width, const uint32_t viewport_height, const uint16_t grid_rows,
                          const uint16_t grid_cols, const uint32_t margin_px, const uint32_t gap_px, const uint16_t row,
                          const uint16_t col, float* out_x0, float* out_y0, float* out_x1, float* out_y1) {
  if (out_x0 == nullptr || out_y0 == nullptr || out_x1 == nullptr || out_y1 == nullptr) {
    return;
  }
  vdt::render::LayoutSpec spec{};
  spec.grid.rows = grid_rows;
  spec.grid.cols = grid_cols;
  spec.viewport_width = viewport_width;
  spec.viewport_height = viewport_height;
  spec.margin_px = margin_px;
  spec.gap_px = gap_px;
  const auto r = vdt::render::cell_rect_pixels(spec, row, col);
  *out_x0 = r.x0;
  *out_y0 = r.y0;
  *out_x1 = r.x1;
  *out_y1 = r.y1;
}

uint32_t vdt_symbol_cell_to_index(const uint16_t grid_rows, const uint16_t grid_cols, const uint16_t row,
                                  const uint16_t col) {
  const vdt::encode::GridSpec g{grid_rows, grid_cols};
  return vdt::encode::cell_to_index(g, row, col);
}

int vdt_sample_grid_full_bleed(const uint8_t* gray, const uint32_t width, const uint32_t height, const uint16_t rows,
                               const uint16_t cols, uint8_t* out_luma, const size_t out_capacity) {
  if (gray == nullptr || out_luma == nullptr || width < 2 || height < 2 || rows == 0 || cols == 0) {
    return 0;
  }
  const std::size_t npix = static_cast<std::size_t>(width) * static_cast<std::size_t>(height);
  const std::size_t need_out = static_cast<std::size_t>(rows) * static_cast<std::size_t>(cols);
  if (out_capacity < need_out) {
    return 0;
  }
  const vdt::vision::GrayImageView img{width, height, std::span<const std::uint8_t>(gray, npix)};
  std::array<vdt::vision::Point2f, 4> corners_px{};
  vdt::vision::FullBleedMarkerDetector detector{};
  if (!detector.detect(img, corners_px)) {
    return 0;
  }
  const float inv_w = 1.0F / static_cast<float>(width - 1);
  const float inv_h = 1.0F / static_cast<float>(height - 1);
  const std::array<vdt::vision::Point2f, 4> src_norm{
      vdt::vision::Point2f{0.0F, 0.0F}, {1.0F, 0.0F}, {1.0F, 1.0F}, {0.0F, 1.0F}};
  std::array<vdt::vision::Point2f, 4> dst_norm{};
  for (std::size_t i = 0; i < 4; ++i) {
    dst_norm[i] = {corners_px[i].x * inv_w, corners_px[i].y * inv_h};
  }
  std::array<float, 9> h{};
  vdt::vision::HomographyEstimator estimator{};
  if (!estimator.estimate(std::span<const vdt::vision::Point2f, 4>(src_norm),
                          std::span<const vdt::vision::Point2f, 4>(dst_norm), h)) {
    return 0;
  }
  vdt::vision::GridSampler sampler{};
  sampler.set_homography(h);
  std::vector<std::uint8_t> tmp;
  if (!sampler.sample_grid(img, rows, cols, tmp) || tmp.size() != need_out) {
    return 0;
  }
  std::memcpy(out_luma, tmp.data(), tmp.size());
  return 1;
}

VDTSessionAssembler* vdt_session_assembler_create(void) {
  return new VDTSessionAssembler{};
}

void vdt_session_assembler_destroy(VDTSessionAssembler* assembler) {
  delete assembler;
}

void vdt_session_assembler_reset(VDTSessionAssembler* assembler) {
  if (assembler == nullptr) {
    return;
  }
  assembler->inner.reset();
}

int vdt_session_assembler_push_wire(VDTSessionAssembler* assembler, const uint8_t* wire, const size_t wire_length) {
  if (assembler == nullptr || wire == nullptr) {
    return 0;
  }
  const auto decoded = vdt::decode::decode_frame({wire, wire_length});
  if (!decoded) {
    return 0;
  }
  return assembler->inner.push_frame(*decoded) ? 1 : 0;
}

int vdt_session_assembler_push_decoded(VDTSessionAssembler* assembler, const VDTFrameHeaderC* header,
                                         const uint8_t* payload, const size_t payload_length) {
  if (assembler == nullptr || header == nullptr) {
    return 0;
  }
  if (payload_length > UINT16_MAX || header->payload_length != payload_length) {
    return 0;
  }
  if (payload_length > 0 && payload == nullptr) {
    return 0;
  }
  vdt::protocol::FrameHeader h{};
  h.version = header->version;
  h.frame_type = static_cast<vdt::protocol::FrameType>(header->frame_type);
  h.flags = header->flags;
  h.reserved = 0;
  h.session_id = header->session_id;
  h.chunk_index = header->chunk_index;
  h.chunk_count = header->chunk_count;
  h.payload_length = header->payload_length;
  vdt::ByteBuffer pay;
  pay.assign(payload, payload + payload_length);
  const vdt::decode::DecodedFrame df{h, std::move(pay)};
  return assembler->inner.push_frame(df) ? 1 : 0;
}

int vdt_session_assembler_is_complete(const VDTSessionAssembler* assembler) {
  if (assembler == nullptr) {
    return 0;
  }
  return assembler->inner.is_complete() ? 1 : 0;
}

size_t vdt_session_assembler_take_merged_payload(VDTSessionAssembler* assembler, uint8_t* out, const size_t out_capacity) {
  if (assembler == nullptr || out == nullptr || out_capacity == 0) {
    return 0;
  }
  const auto sz = assembler->inner.complete_payload_size();
  if (!sz || *sz > out_capacity) {
    return 0;
  }
  const auto merged = assembler->inner.take_merged_payload();
  if (!merged) {
    return 0;
  }
  std::memcpy(out, merged->data(), merged->size());
  return merged->size();
}

}
