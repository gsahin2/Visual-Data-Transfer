#include <catch2/catch_test_macros.hpp>

#include "vdt/common/crc16.hpp"

TEST_CASE("CRC16 empty input yields 0xFFFF", "[crc16]") {
  REQUIRE(vdt::crc16_ccitt_false(nullptr, 0) == 0xFFFF);
}

TEST_CASE("CRC16 is stable for a short payload", "[crc16]") {
  const std::uint8_t data[] = {0x01, 0x02, 0x03, 0x04};
  const std::uint16_t a = vdt::crc16_ccitt_false(data, sizeof(data));
  const std::uint16_t b = vdt::crc16_ccitt_false(data, sizeof(data));
  REQUIRE(a == b);
  REQUIRE(a != 0);
}
