#include "vdt/render/layout.hpp"

#include <algorithm>

namespace vdt::render {

CellRect cell_rect_pixels(const LayoutSpec& spec, const std::uint16_t row, const std::uint16_t col) noexcept {
  CellRect r{};
  if (spec.grid.rows == 0 || spec.grid.cols == 0) {
    return r;
  }
  const float vw = static_cast<float>(std::max<std::uint32_t>(1, spec.viewport_width));
  const float vh = static_cast<float>(std::max<std::uint32_t>(1, spec.viewport_height));
  const float m = static_cast<float>(spec.margin_px);
  const float gap = static_cast<float>(spec.gap_px);
  const float rows = static_cast<float>(spec.grid.rows);
  const float cols = static_cast<float>(spec.grid.cols);
  const float inner_w = vw - 2.0F * m;
  const float inner_h = vh - 2.0F * m;
  const float cell_w = (inner_w - gap * (cols - 1.0F)) / cols;
  const float cell_h = (inner_h - gap * (rows - 1.0F)) / rows;
  const float x0 = m + static_cast<float>(col) * (cell_w + gap);
  const float y0 = m + static_cast<float>(row) * (cell_h + gap);
  r.x0 = x0;
  r.y0 = y0;
  r.x1 = x0 + cell_w;
  r.y1 = y0 + cell_h;
  return r;
}

void cell_center_normalized(const LayoutSpec& spec, const std::uint16_t row, const std::uint16_t col, float& nx,
                            float& ny) noexcept {
  const CellRect px = cell_rect_pixels(spec, row, col);
  const float vw = static_cast<float>(std::max<std::uint32_t>(1, spec.viewport_width));
  const float vh = static_cast<float>(std::max<std::uint32_t>(1, spec.viewport_height));
  nx = ((px.x0 + px.x1) * 0.5F) / vw;
  ny = ((px.y0 + px.y1) * 0.5F) / vh;
}

}  // namespace vdt::render
