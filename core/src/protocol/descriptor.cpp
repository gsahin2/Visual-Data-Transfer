#include "vdt/protocol/descriptor.hpp"

#include "vdt/protocol/constants.hpp"

namespace vdt::protocol {

namespace {

void write_le16(std::uint8_t* p, const std::uint16_t v) noexcept {
  p[0] = static_cast<std::uint8_t>(v & 0xFFU);
  p[1] = static_cast<std::uint8_t>((v >> 8U) & 0xFFU);
}

void write_le32(std::uint8_t* p, const std::uint32_t v) noexcept {
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

ByteBuffer serialize_descriptor_v1(const TransferDescriptorV1& d) {
  ByteBuffer out(TransferDescriptorV1::kWireBytes);
  out[0] = d.layout_version;
  out[1] = static_cast<std::uint8_t>(d.encoding_mode);
  write_le16(out.data() + 2, d.reserved0);
  write_le32(out.data() + 4, d.transfer_id);
  write_le32(out.data() + 8, d.payload_byte_length);
  write_le32(out.data() + 12, d.payload_crc32);
  write_le16(out.data() + 16, d.data_frame_count);
  write_le16(out.data() + 18, d.reserved1);
  return out;
}

std::optional<TransferDescriptorV1> parse_descriptor_v1(const std::span<const std::uint8_t> payload) noexcept {
  if (payload.size() != TransferDescriptorV1::kWireBytes) {
    return std::nullopt;
  }
  TransferDescriptorV1 d{};
  d.layout_version = payload[0];
  if (d.layout_version != 1) {
    return std::nullopt;
  }
  d.encoding_mode = static_cast<EncodingMode>(payload[1]);
  d.reserved0 = read_le16(payload.data() + 2);
  d.transfer_id = read_le32(payload.data() + 4);
  d.payload_byte_length = read_le32(payload.data() + 8);
  d.payload_crc32 = read_le32(payload.data() + 12);
  d.data_frame_count = read_le16(payload.data() + 16);
  d.reserved1 = read_le16(payload.data() + 18);
  if (d.data_frame_count == 0) {
    return std::nullopt;
  }
  if (d.payload_byte_length > kMaxTransferPayloadBytes) {
    return std::nullopt;
  }
  return d;
}

}  // namespace vdt::protocol
