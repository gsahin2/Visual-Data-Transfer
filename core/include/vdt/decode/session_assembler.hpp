#pragma once

#include "vdt/common/types.hpp"
#include "vdt/decode/frame_decoder.hpp"
#include "vdt/protocol/session.hpp"

#include <optional>

namespace vdt::decode {

/// Accepts decoded frames and reconstructs the original session payload.
class SessionAssembler {
 public:
  void reset();
  [[nodiscard]] bool push_frame(const DecodedFrame& frame);
  [[nodiscard]] bool is_complete() const;
  [[nodiscard]] std::optional<ByteBuffer> take_merged_payload();

 private:
  protocol::SessionReassemblyBuffer buffer_{};
  std::optional<std::uint32_t> active_session_{};
  std::optional<std::uint16_t> expected_chunks_{};
};

}  // namespace vdt::decode
