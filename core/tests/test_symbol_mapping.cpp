#include <catch2/catch_test_macros.hpp>

#include "vdt/encode/symbol_mapping.hpp"

TEST_CASE("symbol grid index roundtrip", "[symbols]") {
  const vdt::encode::GridSpec g{12, 16};
  REQUIRE(vdt::encode::symbol_count(g) == 192);
  const std::uint32_t idx = vdt::encode::cell_to_index(g, 3, 4);
  REQUIRE(vdt::encode::valid_symbol_index(g, idx));
  const auto [r, c] = vdt::encode::index_to_cell(g, idx);
  REQUIRE(r == 3);
  REQUIRE(c == 4);
}

TEST_CASE("nibble symbol helpers", "[symbols]") {
  REQUIRE(vdt::encode::nibble_from_symbol_id(0x1F) == 0x0F);
  REQUIRE(vdt::encode::symbol_id_from_nibble(0x0C) == 0x0C);
}
