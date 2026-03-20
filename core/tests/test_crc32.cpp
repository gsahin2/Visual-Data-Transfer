#include <catch2/catch_test_macros.hpp>

#include "vdt/common/crc32.hpp"

#include <cstring>

TEST_CASE("CRC32 IEEE reference vector", "[crc32]") {
  const char* s = "123456789";
  const auto crc = vdt::crc32_ieee(reinterpret_cast<const std::uint8_t*>(s), std::strlen(s));
  REQUIRE(crc == 0xCBF43926U);
}

TEST_CASE("CRC32 empty", "[crc32]") {
  REQUIRE(vdt::crc32_ieee(nullptr, 0) == 0x00000000U);
}
