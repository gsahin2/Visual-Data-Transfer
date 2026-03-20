#include "vdt/common/crc32.hpp"

namespace vdt {

std::uint32_t crc32_ieee(const std::uint8_t* data, const std::size_t length) noexcept {
  std::uint32_t crc = 0xFFFFFFFFU;
  for (std::size_t i = 0; i < length; ++i) {
    crc ^= static_cast<std::uint32_t>(data[i]);
    for (int b = 0; b < 8; ++b) {
      if ((crc & 1U) != 0U) {
        crc = (crc >> 1U) ^ 0xEDB88320U;
      } else {
        crc >>= 1U;
      }
    }
  }
  return crc ^ 0xFFFFFFFFU;
}

}  // namespace vdt
