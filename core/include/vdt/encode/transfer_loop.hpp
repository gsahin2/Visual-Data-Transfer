#pragma once

#include "vdt/encode/frame_encoder.hpp"
#include "vdt/protocol/constants.hpp"
#include "vdt/protocol/descriptor.hpp"

#include <cstdint>
#include <span>
#include <vector>

namespace vdt::encode {

/// Optional tuning for descriptor placement within one cycle (Normal mode). Safe mode keeps one descriptor before
/// each payload; `trailing_descriptor` still appends a final descriptor when set.
struct TransferLoopOptions {
  /// Normal mode: emit an extra descriptor before payload index `i` when `i > 0 && (i % k) == 0`. `0` = legacy
  /// (single leading descriptor only). Example `k = 2` → `D P0 P1 D P2 P3 …`.
  std::uint16_t repeat_descriptor_every_k_payloads{0};
  /// Normal / Safe: append a duplicate descriptor after the last payload (helps receivers joining at loop wrap).
  bool trailing_descriptor{false};
};

/// One full loop cycle: descriptor(s) + all payload frames, in transmit order.
/// Repeat this sequence on the sender for loop redundancy (see `docs/protocol-v1.md`).
[[nodiscard]] std::vector<EncodedFrame> build_transfer_loop_cycle(
    std::uint32_t transfer_id, std::span<const std::uint8_t> message, protocol::EncodingMode mode,
    std::uint16_t max_payload_bytes = protocol::kMaxPayloadBytesPerFrame,
    const TransferLoopOptions& options = {});

}  // namespace vdt::encode
