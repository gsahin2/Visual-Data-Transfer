#pragma once

#include "vdt/common/types.hpp"
#include "vdt/decode/frame_decoder.hpp"
#include "vdt/protocol/session.hpp"

#include <cstdint>
#include <optional>

namespace vdt::decode {

/// Accepts decoded frames and reconstructs the transfer payload.
/// Descriptor frames (repeated in the loop) establish expected CRC32 and chunk count; payload frames fill slots.
/// Duplicate payload chunks with identical bytes are tolerated (loop redundancy).
class SessionAssembler {
 public:
  void reset();
  [[nodiscard]] bool push_frame(const DecodedFrame& frame);
  [[nodiscard]] bool is_complete() const;
  /// Byte length of merged payload when `is_complete()`, before CRC verification (for sizing output buffers).
  [[nodiscard]] std::optional<std::size_t> complete_payload_size() const;
  /// When a descriptor was seen, verifies assembled size and CRC32 before returning.
  [[nodiscard]] std::optional<ByteBuffer> take_merged_payload();

 private:
  protocol::SessionReassemblyBuffer buffer_{};
  std::optional<std::uint32_t> active_session_{};
  std::optional<std::uint16_t> expected_chunks_{};
  bool descriptor_seen_{false};
  std::optional<std::uint32_t> expected_payload_bytes_{};
  std::optional<std::uint32_t> expected_payload_crc32_{};
};

}  // namespace vdt::decode
