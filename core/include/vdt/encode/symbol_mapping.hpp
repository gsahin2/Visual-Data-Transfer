#pragma once

#include <cstddef>
#include <cstdint>
#include <utility>

namespace vdt::encode {

/// Maps linear symbol indices to grid coordinates (row-major).
struct GridSpec {
  std::uint16_t rows{0};
  std::uint16_t cols{0};
};

[[nodiscard]] constexpr std::uint32_t symbol_count(const GridSpec& g) noexcept {
  return static_cast<std::uint32_t>(g.rows) * static_cast<std::uint32_t>(g.cols);
}

[[nodiscard]] constexpr bool valid_symbol_index(const GridSpec& g, std::uint32_t index) noexcept {
  return g.rows > 0 && g.cols > 0 && index < symbol_count(g);
}

[[nodiscard]] constexpr std::pair<std::uint16_t, std::uint16_t> index_to_cell(const GridSpec& g,
                                                                              std::uint32_t index) noexcept {
  const auto c = static_cast<std::uint16_t>(index % g.cols);
  const auto r = static_cast<std::uint16_t>(index / g.cols);
  return {r, c};
}

[[nodiscard]] constexpr std::uint32_t cell_to_index(const GridSpec& g, std::uint16_t row,
                                                    std::uint16_t col) noexcept {
  return static_cast<std::uint32_t>(row) * g.cols + col;
}

/// 16-level symbol id in [0,15] for 4-bit cells (payload packing).
[[nodiscard]] constexpr std::uint8_t nibble_from_symbol_id(std::uint8_t symbol_id) noexcept {
  return static_cast<std::uint8_t>(symbol_id & 0x0FU);
}

[[nodiscard]] constexpr std::uint8_t symbol_id_from_nibble(std::uint8_t nibble) noexcept {
  return static_cast<std::uint8_t>(nibble & 0x0FU);
}

}  // namespace vdt::encode
