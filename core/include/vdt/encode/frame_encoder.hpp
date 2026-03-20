#pragma once

#include "vdt/common/types.hpp"
#include "vdt/protocol/constants.hpp"
#include "vdt/protocol/frame.hpp"

#include <cstdint>
#include <span>
#include <vector>

namespace vdt::encode {

struct EncodedFrame {
  protocol::FrameHeader header;
  ByteBuffer wire;
};

/// Builds wire frames for a session from a single logical payload (chunked automatically).
class FrameEncoder {
 public:
  explicit FrameEncoder(std::uint16_t max_payload_bytes = protocol::kMaxPayloadBytesV1);

  [[nodiscard]] std::vector<EncodedFrame> encode_session(std::uint32_t session_id,
                                                         std::span<const std::uint8_t> message,
                                                         protocol::FrameType type = protocol::FrameType::Data);

 private:
  std::uint16_t max_payload_{protocol::kMaxPayloadBytesV1};
};

}  // namespace vdt::encode
