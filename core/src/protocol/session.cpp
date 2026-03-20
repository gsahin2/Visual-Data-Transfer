#include "vdt/protocol/session.hpp"

#include <algorithm>

namespace vdt::protocol {

void SessionReassemblyBuffer::reset(const SessionDescriptor& desc) {
  desc_ = desc;
  slots_.assign(desc.chunk_count, std::nullopt);
  filled_ = 0;
}

bool SessionReassemblyBuffer::ingest_chunk(std::uint16_t index, ByteBuffer payload) {
  if (desc_.chunk_count == 0 || index >= desc_.chunk_count) {
    return false;
  }
  if (slots_[index].has_value()) {
    const auto& existing = *slots_[index];
    return existing.size() == payload.size() &&
           std::equal(existing.begin(), existing.end(), payload.begin(), payload.end());
  }
  slots_[index] = std::move(payload);
  ++filled_;
  return true;
}

bool SessionReassemblyBuffer::is_complete() const {
  return desc_.chunk_count > 0 && filled_ == desc_.chunk_count;
}

std::optional<ByteBuffer> SessionReassemblyBuffer::merged_payload() const {
  if (!is_complete()) {
    return std::nullopt;
  }
  std::size_t total = 0;
  for (const auto& s : slots_) {
    total += s->size();
  }
  ByteBuffer out;
  out.reserve(total);
  for (const auto& s : slots_) {
    out.insert(out.end(), s->begin(), s->end());
  }
  return out;
}

}  // namespace vdt::protocol
