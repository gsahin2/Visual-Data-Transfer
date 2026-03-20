#pragma once

#include "vdt/encode/symbol_mapping.hpp"

#include <cstdint>

namespace vdt::render {

struct LayoutSpec {
  encode::GridSpec grid{};
  std::uint32_t viewport_width{0};
  std::uint32_t viewport_height{0};
  std::uint32_t margin_px{8};
  std::uint32_t gap_px{2};
};

struct CellRect {
  float x0{0};
  float y0{0};
  float x1{0};
  float y1{0};
};

/// Computes axis-aligned cell rectangles in pixel space for the data grid (excluding finder margin).
[[nodiscard]] CellRect cell_rect_pixels(const LayoutSpec& spec, std::uint16_t row, std::uint16_t col) noexcept;

/// Normalized center of a cell in [0,1] x [0,1] image coordinates (for vision sampling).
void cell_center_normalized(const LayoutSpec& spec, std::uint16_t row, std::uint16_t col, float& nx,
                            float& ny) noexcept;

}  // namespace vdt::render
