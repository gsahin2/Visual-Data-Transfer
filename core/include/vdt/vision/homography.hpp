#pragma once

#include "vdt/vision/interfaces.hpp"

namespace vdt::vision {

/// Applies H (row-major 3x3) to (x,y) treating them as homogeneous 2D points.
void apply_homography(const std::array<float, 9>& h_row_major, float x, float y, float& ox, float& oy) noexcept;

/// Reference DLT implementation for four point correspondences (src -> dst).
[[nodiscard]] bool homography_from_four_points(std::span<const Point2f, 4> src, std::span<const Point2f, 4> dst,
                                               std::array<float, 9>& h_out);

class HomographyEstimator final : public IHomographyEstimator {
 public:
  [[nodiscard]] bool estimate(std::span<const Point2f, 4> src_norm, std::span<const Point2f, 4> dst_px,
                              std::array<float, 9>& h_row_major) override;
};

}  // namespace vdt::vision
