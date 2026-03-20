#pragma once

#include "vdt/protocol/constants.hpp"

#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

namespace vdt::protocol {

struct FrameHeader {
  std::uint8_t version{kVersion1};
  FrameType frame_type{FrameType::Data};
  std::uint8_t flags{0};
  std::uint8_t reserved{0};
  std::uint32_t session_id{0};
  std::uint16_t chunk_index{0};
  std::uint16_t chunk_count{0};
  std::uint16_t payload_length{0};
};

/// Serializes header to 18 bytes (little-endian for multi-byte fields).
[[nodiscard]] bool serialize_header(const FrameHeader& h, std::span<std::uint8_t, kFrameHeaderBytes> out) noexcept;

/// Parses header; returns false if magic/version/payload bounds are invalid.
[[nodiscard]] bool parse_header(std::span<const std::uint8_t, kFrameHeaderBytes> in, FrameHeader& out) noexcept;

/// Full wire frame: header + payload + CRC16 (over header+payload, LE).
[[nodiscard]] std::vector<std::uint8_t> build_frame(const FrameHeader& header, std::span<const std::uint8_t> payload);

/// Validates CRC and extracts header + payload from a full frame.
[[nodiscard]] bool parse_frame(std::span<const std::uint8_t> wire, FrameHeader& header,
                               std::vector<std::uint8_t>& payload_out);

}  // namespace vdt::protocol
