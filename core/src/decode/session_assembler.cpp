#include "vdt/decode/session_assembler.hpp"

#include "vdt/common/crc32.hpp"
#include "vdt/protocol/constants.hpp"
#include "vdt/protocol/descriptor.hpp"

#include <span>

namespace vdt::decode {

void SessionAssembler::reset() {
  buffer_ = protocol::SessionReassemblyBuffer{};
  active_session_.reset();
  expected_chunks_.reset();
  descriptor_seen_ = false;
  expected_payload_bytes_.reset();
  expected_payload_crc32_.reset();
}

bool SessionAssembler::push_frame(const DecodedFrame& frame) {
  using FT = protocol::FrameType;
  if (frame.header.frame_type == FT::Descriptor) {
    const auto parsed = protocol::parse_descriptor_v1(frame.payload);
    if (!parsed.has_value()) {
      return false;
    }
    protocol::SessionDescriptor desc{};
    desc.session_id = parsed->transfer_id;
    desc.chunk_count = parsed->data_frame_count;
    buffer_.reset(desc);
    active_session_ = parsed->transfer_id;
    expected_chunks_ = parsed->data_frame_count;
    expected_payload_bytes_ = parsed->payload_byte_length;
    expected_payload_crc32_ = parsed->payload_crc32;
    descriptor_seen_ = true;
    return true;
  }

  if (frame.header.frame_type != FT::Payload) {
    return false;
  }
  if (frame.header.chunk_count == 0) {
    return false;
  }

  if (!descriptor_seen_) {
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

std::optional<std::size_t> SessionAssembler::complete_payload_size() const {
  if (!buffer_.is_complete()) {
    return std::nullopt;
  }
  const auto merged = buffer_.merged_payload();
  if (!merged) {
    return std::nullopt;
  }
  return merged->size();
}

std::optional<ByteBuffer> SessionAssembler::take_merged_payload() {
  if (!buffer_.is_complete()) {
    return std::nullopt;
  }
  auto merged = buffer_.merged_payload();
  if (!merged.has_value()) {
    return std::nullopt;
  }
  if (descriptor_seen_) {
    if (!expected_payload_bytes_.has_value() || !expected_payload_crc32_.has_value()) {
      reset();
      return std::nullopt;
    }
    if (merged->size() != static_cast<std::size_t>(*expected_payload_bytes_)) {
      reset();
      return std::nullopt;
    }
    if (crc32_ieee(std::span<const std::uint8_t>(*merged)) != *expected_payload_crc32_) {
      reset();
      return std::nullopt;
    }
  }
  ByteBuffer out = std::move(*merged);
  reset();
  return out;
}

}  // namespace vdt::decode
