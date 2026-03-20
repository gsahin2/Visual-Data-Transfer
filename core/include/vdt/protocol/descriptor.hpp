#pragma once

#include "vdt/common/types.hpp"

#include <cstdint>
#include <optional>
#include <span>

namespace vdt::protocol {

/// 0 = Safe (high descriptor redundancy), 1 = Normal (balanced).
enum class EncodingMode : std::uint8_t {
  Safe = 0,
  Normal = 1,
};

/// Fixed 20-byte descriptor body (V1) carried inside a Descriptor frame payload.
struct TransferDescriptorV1 {
  static constexpr std::size_t kWireBytes = 20;

  std::uint8_t layout_version{1};
  EncodingMode encoding_mode{EncodingMode::Normal};
  std::uint16_t reserved0{0};
  std::uint32_t transfer_id{0};
  std::uint32_t payload_byte_length{0};
  std::uint32_t payload_crc32{0};
  std::uint16_t data_frame_count{0};
  std::uint16_t reserved1{0};
};

[[nodiscard]] ByteBuffer serialize_descriptor_v1(const TransferDescriptorV1& d);

[[nodiscard]] std::optional<TransferDescriptorV1> parse_descriptor_v1(std::span<const std::uint8_t> payload) noexcept;

}  // namespace vdt::protocol
