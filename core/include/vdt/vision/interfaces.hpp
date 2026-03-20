#pragma once

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <vector>

namespace vdt::vision {

struct Point2f {
  float x{0};
  float y{0};
};

struct Rgb8 {
  std::uint8_t r{0};
  std::uint8_t g{0};
  std::uint8_t b{0};
};

/// Grayscale 8-bit image, row-major.
struct GrayImageView {
  std::uint32_t width{0};
  std::uint32_t height{0};
  std::span<const std::uint8_t> pixels{};
};

/// Detects alignment markers (e.g., corners of the code area) in image space.
class IMarkerDetector {
 public:
  virtual ~IMarkerDetector() = default;
  /// Returns four points in pixel coordinates: TL, TR, BR, BL of the data region.
  [[nodiscard]] virtual bool detect(const GrayImageView& image, std::array<Point2f, 4>& out_corners) = 0;
};

/// Estimates a homography from normalized source square to destination quad in image pixels.
class IHomographyEstimator {
 public:
  virtual ~IHomographyEstimator() = default;
  [[nodiscard]] virtual bool estimate(std::span<const Point2f, 4> src_norm, std::span<const Point2f, 4> dst_px,
                                     std::array<float, 9>& h_row_major) = 0;
};

}  // namespace vdt::vision
