#pragma once

#include <cstddef>
#include <cstdint>
#include <span>

namespace vdt {

/// CRC-32 (IEEE / Ethernet / PNG): polynomial 0xEDB88320 reflected, init 0xFFFFFFFF, xorout 0xFFFFFFFF.
[[nodiscard]] std::uint32_t crc32_ieee(const std::uint8_t* data, std::size_t length) noexcept;

[[nodiscard]] inline std::uint32_t crc32_ieee(std::span<const std::uint8_t> data) noexcept {
  return crc32_ieee(data.data(), data.size());
}

}  // namespace vdt
