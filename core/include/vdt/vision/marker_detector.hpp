#pragma once

#include "vdt/vision/interfaces.hpp"

namespace vdt::vision {

/// Uses image borders as the data region (useful for synthetic tests and full-bleed UI).
class FullBleedMarkerDetector final : public IMarkerDetector {
 public:
  [[nodiscard]] bool detect(const GrayImageView& image, std::array<Point2f, 4>& out_corners) override;
};

}  // namespace vdt::vision
