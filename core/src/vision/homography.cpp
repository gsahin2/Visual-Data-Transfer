#include "vdt/vision/homography.hpp"

#include <array>
#include <cmath>
namespace vdt::vision {

namespace {

[[nodiscard]] bool solve_linear_8(std::array<std::array<float, 9>, 8>& aug) noexcept {
  constexpr int n = 8;
  for (int col = 0; col < n; ++col) {
    int pivot = col;
    float best = std::fabs(aug[static_cast<std::size_t>(col)][static_cast<std::size_t>(col)]);
    for (int r = col + 1; r < n; ++r) {
      const float v = std::fabs(aug[static_cast<std::size_t>(r)][static_cast<std::size_t>(col)]);
      if (v > best) {
        best = v;
        pivot = r;
      }
    }
    if (best < 1e-8F) {
      return false;
    }
    if (pivot != col) {
      std::swap(aug[static_cast<std::size_t>(pivot)], aug[static_cast<std::size_t>(col)]);
    }
    const float div = aug[static_cast<std::size_t>(col)][static_cast<std::size_t>(col)];
    for (int c = col; c <= n; ++c) {
      aug[static_cast<std::size_t>(col)][static_cast<std::size_t>(c)] /= div;
    }
    for (int r = 0; r < n; ++r) {
      if (r == col) {
        continue;
      }
      const float f = aug[static_cast<std::size_t>(r)][static_cast<std::size_t>(col)];
      if (f == 0.0F) {
        continue;
      }
      for (int c = col; c <= n; ++c) {
        aug[static_cast<std::size_t>(r)][static_cast<std::size_t>(c)] -=
            f * aug[static_cast<std::size_t>(col)][static_cast<std::size_t>(c)];
      }
    }
  }
  return true;
}

}  // namespace

void apply_homography(const std::array<float, 9>& h, const float x, const float y, float& ox, float& oy) noexcept {
  const float w = h[6] * x + h[7] * y + h[8];
  if (std::fabs(w) < 1e-8F) {
    ox = x;
    oy = y;
    return;
  }
  ox = (h[0] * x + h[1] * y + h[2]) / w;
  oy = (h[3] * x + h[4] * y + h[5]) / w;
}

bool homography_from_four_points(const std::span<const Point2f, 4> src, const std::span<const Point2f, 4> dst,
                                 std::array<float, 9>& h_out) {
  std::array<std::array<float, 9>, 8> aug{};
  for (int i = 0; i < 4; ++i) {
    const float x = src[static_cast<std::size_t>(i)].x;
    const float y = src[static_cast<std::size_t>(i)].y;
    const float u = dst[static_cast<std::size_t>(i)].x;
    const float v = dst[static_cast<std::size_t>(i)].y;
    const std::size_t r0 = static_cast<std::size_t>(2 * i);
    const std::size_t r1 = r0 + 1;
    aug[r0][0] = x;
    aug[r0][1] = y;
    aug[r0][2] = 1.0F;
    aug[r0][3] = 0.0F;
    aug[r0][4] = 0.0F;
    aug[r0][5] = 0.0F;
    aug[r0][6] = -u * x;
    aug[r0][7] = -u * y;
    aug[r0][8] = u;

    aug[r1][0] = 0.0F;
    aug[r1][1] = 0.0F;
    aug[r1][2] = 0.0F;
    aug[r1][3] = x;
    aug[r1][4] = y;
    aug[r1][5] = 1.0F;
    aug[r1][6] = -v * x;
    aug[r1][7] = -v * y;
    aug[r1][8] = v;
  }
  if (!solve_linear_8(aug)) {
    return false;
  }
  h_out[0] = aug[0][8];
  h_out[1] = aug[1][8];
  h_out[2] = aug[2][8];
  h_out[3] = aug[3][8];
  h_out[4] = aug[4][8];
  h_out[5] = aug[5][8];
  h_out[6] = aug[6][8];
  h_out[7] = aug[7][8];
  h_out[8] = 1.0F;
  return true;
}

bool HomographyEstimator::estimate(const std::span<const Point2f, 4> src_norm,
                                   const std::span<const Point2f, 4> dst_px,
                                   std::array<float, 9>& h_row_major) {
  return homography_from_four_points(src_norm, dst_px, h_row_major);
}

}  // namespace vdt::vision
