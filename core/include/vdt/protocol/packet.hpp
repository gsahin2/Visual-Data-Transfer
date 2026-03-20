#pragma once

#include "vdt/common/types.hpp"

#include <cstddef>
#include <cstdint>
#include <span>

namespace vdt::protocol {

/// Logical payload layout for V1 data frames (after framing and CRC).
/// | stream_offset:8 | stream_total:8 | message_bytes... |
struct DataPacketView {
  std::uint64_t stream_offset{0};
  std::uint64_t stream_total{0};
  std::span<const std::uint8_t> message{};
};

[[nodiscard]] bool parse_data_packet(std::span<const std::uint8_t> payload, DataPacketView& out) noexcept;

[[nodiscard]] ByteBuffer build_data_packet(std::uint64_t stream_offset, std::uint64_t stream_total,
                                           std::span<const std::uint8_t> message);

}  // namespace vdt::protocol
