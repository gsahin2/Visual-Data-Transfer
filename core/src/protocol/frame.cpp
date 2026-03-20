#include "vdt/protocol/frame.hpp"

#include "vdt/common/crc16.hpp"

#include <algorithm>
#include <cstring>

namespace vdt::protocol {

namespace {

void write_le16(std::uint8_t* p, std::uint16_t v) noexcept {
  p[0] = static_cast<std::uint8_t>(v & 0xFFU);
  p[1] = static_cast<std::uint8_t>((v >> 8U) & 0xFFU);
}

void write_le32(std::uint8_t* p, std::uint32_t v) noexcept {
  p[0] = static_cast<std::uint8_t>(v & 0xFFU);
  p[1] = static_cast<std::uint8_t>((v >> 8U) & 0xFFU);
  p[2] = static_cast<std::uint8_t>((v >> 16U) & 0xFFU);
  p[3] = static_cast<std::uint8_t>((v >> 24U) & 0xFFU);
}

[[nodiscard]] std::uint16_t read_le16(const std::uint8_t* p) noexcept {
  return static_cast<std::uint16_t>(p[0] | (static_cast<std::uint16_t>(p[1]) << 8U));
}

[[nodiscard]] std::uint32_t read_le32(const std::uint8_t* p) noexcept {
  return static_cast<std::uint32_t>(p[0]) | (static_cast<std::uint32_t>(p[1]) << 8U) |
         (static_cast<std::uint32_t>(p[2]) << 16U) | (static_cast<std::uint32_t>(p[3]) << 24U);
}

}  // namespace

bool serialize_header(const FrameHeader& h, std::span<std::uint8_t, kFrameHeaderBytes> out) noexcept {
  out[0] = kMagic0;
  out[1] = kMagic1;
  out[2] = h.version;
  out[3] = static_cast<std::uint8_t>(h.frame_type);
  out[4] = h.flags;
  out[5] = h.reserved;
  write_le32(out.data() + 6, h.session_id);
  write_le16(out.data() + 10, h.chunk_index);
  write_le16(out.data() + 12, h.chunk_count);
  write_le16(out.data() + 14, h.payload_length);
  out[16] = 0;
  out[17] = 0;
  return true;
}

bool parse_header(std::span<const std::uint8_t, kFrameHeaderBytes> in, FrameHeader& out) noexcept {
  if (in[0] != kMagic0 || in[1] != kMagic1) {
    return false;
  }
  if (in[2] != kVersion1) {
    return false;
  }
  out.version = in[2];
  out.frame_type = static_cast<FrameType>(in[3]);
  out.flags = in[4];
  out.reserved = in[5];
  out.session_id = read_le32(in.data() + 6);
  out.chunk_index = read_le16(in.data() + 10);
  out.chunk_count = read_le16(in.data() + 12);
  out.payload_length = read_le16(in.data() + 14);
  if (out.payload_length > kMaxPayloadBytesPerFrame) {
    return false;
  }
  return true;
}

std::vector<std::uint8_t> build_frame(const FrameHeader& header, std::span<const std::uint8_t> payload) {
  if (payload.size() > kMaxPayloadBytesPerFrame || payload.size() != header.payload_length) {
    return {};
  }
  std::vector<std::uint8_t> wire;
  wire.resize(kFrameHeaderBytes + payload.size() + 2);
  const auto hdr = std::span<std::uint8_t, kFrameHeaderBytes>(wire.data(), kFrameHeaderBytes);
  FrameHeader h = header;
  h.payload_length = static_cast<std::uint16_t>(payload.size());
  static_cast<void>(serialize_header(h, hdr));
  if (!payload.empty()) {
    std::memcpy(wire.data() + kFrameHeaderBytes, payload.data(), payload.size());
  }
  const std::uint16_t crc =
      crc16_ccitt_false(std::span<const std::uint8_t>(wire.data(), kFrameHeaderBytes + payload.size()));
  write_le16(wire.data() + kFrameHeaderBytes + payload.size(), crc);
  return wire;
}

bool parse_frame(std::span<const std::uint8_t> wire, FrameHeader& header, std::vector<std::uint8_t>& payload_out) {
  if (wire.size() < kFrameHeaderBytes + 2) {
    return false;
  }
  const std::span<const std::uint8_t, kFrameHeaderBytes> hdr_bytes(wire.data(), kFrameHeaderBytes);
  if (!parse_header(hdr_bytes, header)) {
    return false;
  }
  const std::size_t expected = kFrameHeaderBytes + header.payload_length + 2;
  if (wire.size() != expected) {
    return false;
  }
  const std::uint16_t stored_crc = read_le16(wire.data() + kFrameHeaderBytes + header.payload_length);
  const std::uint16_t computed =
      crc16_ccitt_false(std::span<const std::uint8_t>(wire.data(), kFrameHeaderBytes + header.payload_length));
  if (stored_crc != computed) {
    return false;
  }
  payload_out.resize(header.payload_length);
  if (header.payload_length > 0) {
    std::memcpy(payload_out.data(), wire.data() + kFrameHeaderBytes, header.payload_length);
  }
  return true;
}

}  // namespace vdt::protocol
