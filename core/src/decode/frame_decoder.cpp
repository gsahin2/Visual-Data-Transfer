#include "vdt/decode/frame_decoder.hpp"

#include <span>

namespace vdt::decode {

std::optional<DecodedFrame> decode_frame(const std::span<const std::uint8_t> wire) {
  protocol::FrameHeader header{};
  ByteBuffer payload;
  if (!protocol::parse_frame(wire, header, payload)) {
    return std::nullopt;
  }
  return DecodedFrame{header, std::move(payload)};
}

}  // namespace vdt::decode
