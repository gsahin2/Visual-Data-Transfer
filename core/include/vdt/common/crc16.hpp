#pragma once

#include <cstddef>
#include <cstdint>
#include <span>

namespace vdt {

/// CRC-16/CCITT-FALSE: polynomial 0x1021, initial value 0xFFFF, no reflection.
[[nodiscard]] std::uint16_t crc16_ccitt_false(const std::uint8_t* data, std::size_t length) noexcept;

[[nodiscard]] inline std::uint16_t crc16_ccitt_false(std::span<const std::uint8_t> data) noexcept {
  return crc16_ccitt_false(data.data(), data.size());
}

}  // namespace vdt
