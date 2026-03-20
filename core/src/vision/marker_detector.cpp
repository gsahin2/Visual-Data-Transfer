#include "vdt/vision/marker_detector.hpp"

namespace vdt::vision {

bool FullBleedMarkerDetector::detect(const GrayImageView& image, std::array<Point2f, 4>& out_corners) {
  if (image.width < 2 || image.height < 2) {
    return false;
  }
  const float w = static_cast<float>(image.width - 1);
  const float h = static_cast<float>(image.height - 1);
  out_corners[0] = {0.0F, 0.0F};
  out_corners[1] = {w, 0.0F};
  out_corners[2] = {w, h};
  out_corners[3] = {0.0F, h};
  return true;
}

}  // namespace vdt::vision
