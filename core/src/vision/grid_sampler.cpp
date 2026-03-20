#include "vdt/vision/grid_sampler.hpp"

#include <cmath>

namespace vdt::vision {

namespace {

[[nodiscard]] std::uint8_t clamp_byte(float v) noexcept {
  if (v <= 0.0F) {
    return 0;
  }
  if (v >= 255.0F) {
    return 255;
  }
  return static_cast<std::uint8_t>(v + 0.5F);
}

}  // namespace

std::uint8_t sample_bilinear(const GrayImageView& img, float px, float py) noexcept {
  if (img.width == 0 || img.height == 0 || img.pixels.size() < static_cast<std::size_t>(img.width) * img.height) {
    return 0;
  }
  const float max_x = static_cast<float>(img.width - 1);
  const float max_y = static_cast<float>(img.height - 1);
  const float x = std::min(max_x, std::max(0.0F, px));
  const float y = std::min(max_y, std::max(0.0F, py));
  const int x0 = static_cast<int>(std::floor(x));
  const int y0 = static_cast<int>(std::floor(y));
  const int x1 = std::min<int>(static_cast<int>(img.width) - 1, x0 + 1);
  const int y1 = std::min<int>(static_cast<int>(img.height) - 1, y0 + 1);
  const float tx = x - static_cast<float>(x0);
  const float ty = y - static_cast<float>(y0);
  const auto idx = [&](int xi, int yi) -> std::size_t {
    return static_cast<std::size_t>(yi) * img.width + static_cast<std::size_t>(xi);
  };
  const float p00 = static_cast<float>(img.pixels[idx(x0, y0)]);
  const float p10 = static_cast<float>(img.pixels[idx(x1, y0)]);
  const float p01 = static_cast<float>(img.pixels[idx(x0, y1)]);
  const float p11 = static_cast<float>(img.pixels[idx(x1, y1)]);
  const float v0 = p00 * (1.0F - tx) + p10 * tx;
  const float v1 = p01 * (1.0F - tx) + p11 * tx;
  return clamp_byte(v0 * (1.0F - ty) + v1 * ty);
}

bool GridSampler::sample_grid(const GrayImageView& image, const std::uint16_t rows, const std::uint16_t cols,
                              std::vector<std::uint8_t>& out_luma) const {
  if (rows == 0 || cols == 0) {
    return false;
  }
  out_luma.resize(static_cast<std::size_t>(rows) * cols);
  std::size_t k = 0;
  for (std::uint16_t r = 0; r < rows; ++r) {
    for (std::uint16_t c = 0; c < cols; ++c) {
      const float nx = (static_cast<float>(c) + 0.5F) / static_cast<float>(cols);
      const float ny = (static_cast<float>(r) + 0.5F) / static_cast<float>(rows);
      float px = 0;
      float py = 0;
      apply_homography(h_, nx, ny, px, py);
      const float sx = px * static_cast<float>(image.width - 1);
      const float sy = py * static_cast<float>(image.height - 1);
      out_luma[k++] = sample_bilinear(image, sx, sy);
    }
  }
  return true;
}

}  // namespace vdt::vision
