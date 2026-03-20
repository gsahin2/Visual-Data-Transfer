#include "vdt/common/crc16.hpp"

namespace vdt {

std::uint16_t crc16_ccitt_false(const std::uint8_t* data, std::size_t length) noexcept {
  std::uint16_t crc = 0xFFFFU;
  for (std::size_t i = 0; i < length; ++i) {
    crc ^= static_cast<std::uint16_t>(data[i]) << 8U;
    for (int b = 0; b < 8; ++b) {
      if ((crc & 0x8000U) != 0U) {
        crc = static_cast<std::uint16_t>((crc << 1U) ^ 0x1021U);
      } else {
        crc = static_cast<std::uint16_t>(crc << 1U);
      }
    }
  }
  return crc;
}

}  // namespace vdt
