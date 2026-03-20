#pragma once

#include "vdt/common/types.hpp"
#include "vdt/protocol/frame.hpp"

#include <optional>
#include <span>

namespace vdt::decode {

struct DecodedFrame {
  protocol::FrameHeader header;
  ByteBuffer payload;
};

[[nodiscard]] std::optional<DecodedFrame> decode_frame(std::span<const std::uint8_t> wire);

}  // namespace vdt::decode
