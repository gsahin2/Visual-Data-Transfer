#pragma once

#include "vdt/encode/frame_encoder.hpp"
#include "vdt/protocol/constants.hpp"
#include "vdt/protocol/descriptor.hpp"

#include <cstdint>
#include <span>
#include <vector>

namespace vdt::encode {

/// One full loop cycle: descriptor(s) + all payload frames, in transmit order.
/// Repeat this sequence on the sender for loop redundancy (see `docs/protocol-v1.md`).
[[nodiscard]] std::vector<EncodedFrame> build_transfer_loop_cycle(
    std::uint32_t transfer_id, std::span<const std::uint8_t> message, protocol::EncodingMode mode,
    std::uint16_t max_payload_bytes = protocol::kMaxPayloadBytesPerFrame);

}  // namespace vdt::encode
