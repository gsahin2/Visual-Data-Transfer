#pragma once

#include "vdt/common/types.hpp"

#include <cstdint>
#include <optional>
#include <vector>

namespace vdt::protocol {

struct SessionDescriptor {
  std::uint32_t session_id{0};
  std::uint16_t chunk_count{0};
};

/// Ordered reassembly of logical stream segments keyed by chunk index.
class SessionReassemblyBuffer {
 public:
  void reset(const SessionDescriptor& desc);
  [[nodiscard]] bool ingest_chunk(std::uint16_t index, ByteBuffer payload);
  [[nodiscard]] bool is_complete() const;
  [[nodiscard]] std::optional<ByteBuffer> merged_payload() const;

 private:
  SessionDescriptor desc_{};
  std::vector<std::optional<ByteBuffer>> slots_{};
  std::uint16_t filled_{0};
};

}  // namespace vdt::protocol
