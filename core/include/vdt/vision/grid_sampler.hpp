#pragma once

#include "vdt/vision/homography.hpp"
#include "vdt/vision/interfaces.hpp"

#include <vector>

namespace vdt::vision {

/// Bilinear sampling from a grayscale image (row-major).
[[nodiscard]] std::uint8_t sample_bilinear(const GrayImageView& img, float px, float py) noexcept;

/// Maps normalized grid coordinates through H and samples luminance.
class GridSampler {
 public:
  void set_homography(const std::array<float, 9>& h_row_major) { h_ = h_row_major; }

  [[nodiscard]] bool sample_grid(const GrayImageView& image, std::uint16_t rows, std::uint16_t cols,
                                 std::vector<std::uint8_t>& out_luma) const;

 private:
  std::array<float, 9> h_{1, 0, 0, 0, 1, 0, 0, 0, 1};
};

}  // namespace vdt::vision
