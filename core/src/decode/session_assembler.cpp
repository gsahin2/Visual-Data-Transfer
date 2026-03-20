#include "vdt/decode/session_assembler.hpp"

namespace vdt::decode {

void SessionAssembler::reset() {
  buffer_ = protocol::SessionReassemblyBuffer{};
  active_session_.reset();
  expected_chunks_.reset();
}

bool SessionAssembler::push_frame(const DecodedFrame& frame) {
  if (frame.header.chunk_count == 0) {
    return false;
  }
  if (!active_session_.has_value()) {
    protocol::SessionDescriptor desc{};
    desc.session_id = frame.header.session_id;
    desc.chunk_count = frame.header.chunk_count;
    buffer_.reset(desc);
    active_session_ = frame.header.session_id;
    expected_chunks_ = frame.header.chunk_count;
  } else {
    if (frame.header.session_id != *active_session_) {
      return false;
    }
    if (frame.header.chunk_count != *expected_chunks_) {
      return false;
    }
  }
  return buffer_.ingest_chunk(frame.header.chunk_index, ByteBuffer(frame.payload));
}

bool SessionAssembler::is_complete() const {
  return buffer_.is_complete();
}

std::optional<ByteBuffer> SessionAssembler::take_merged_payload() {
  if (!buffer_.is_complete()) {
    return std::nullopt;
  }
  auto merged = buffer_.merged_payload();
  reset();
  return merged;
}

}  // namespace vdt::decode
