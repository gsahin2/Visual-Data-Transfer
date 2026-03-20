#include "vdt/encode/frame_encoder.hpp"

#include "vdt/encode/session_chunker.hpp"

namespace vdt::encode {

FrameEncoder::FrameEncoder(std::uint16_t max_payload_bytes) : max_payload_(max_payload_bytes) {}

std::vector<EncodedFrame> FrameEncoder::encode_session(const std::uint32_t session_id,
                                                       const std::span<const std::uint8_t> message,
                                                       const protocol::FrameType type) {
  if (message.size() > protocol::kMaxTransferPayloadBytes) {
    return {};
  }
  const auto chunks = split_payload(message, max_payload_);
  std::vector<EncodedFrame> out;
  if (chunks.empty()) {
    protocol::FrameHeader h{};
    h.version = protocol::kVersion1;
    h.frame_type = type;
    h.flags = 0;
    h.reserved = 0;
    h.session_id = session_id;
    h.chunk_index = 0;
    h.chunk_count = 1;
    h.payload_length = 0;
    EncodedFrame ef;
    ef.header = h;
    ef.wire = protocol::build_frame(h, {});
    if (!ef.wire.empty()) {
      out.push_back(std::move(ef));
    }
    return out;
  }
  const std::uint16_t count = static_cast<std::uint16_t>(chunks.size());
  out.reserve(chunks.size());
  for (std::uint16_t i = 0; i < count; ++i) {
    protocol::FrameHeader h{};
    h.version = protocol::kVersion1;
    h.frame_type = type;
    h.flags = (i + 1 == count) ? protocol::to_underlying(protocol::FrameFlags::FinalChunkHint) : 0;
    h.reserved = 0;
    h.session_id = session_id;
    h.chunk_index = i;
    h.chunk_count = count;
    h.payload_length = static_cast<std::uint16_t>(chunks[i].size());
    EncodedFrame ef;
    ef.header = h;
    ef.wire = protocol::build_frame(h, chunks[i]);
    if (ef.wire.empty()) {
      return {};
    }
    out.push_back(std::move(ef));
  }
  return out;
}

}  // namespace vdt::encode
