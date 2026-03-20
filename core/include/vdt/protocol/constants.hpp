#pragma once

#include <cstddef>
#include <cstdint>

namespace vdt::protocol {

inline constexpr std::uint8_t kMagic0 = 0x56;  // 'V'
inline constexpr std::uint8_t kMagic1 = 0x54;  // 'T'
inline constexpr std::uint8_t kVersion1 = 1;

inline constexpr std::size_t kFrameHeaderBytes = 18;

/// Maximum bytes in a single frame payload (wire chunk size).
inline constexpr std::uint16_t kMaxPayloadBytesPerFrame = 1024;
/// Legacy alias — prefer `kMaxPayloadBytesPerFrame`.
inline constexpr std::uint16_t kMaxPayloadBytesV1 = kMaxPayloadBytesPerFrame;

/// V1 product target: maximum assembled transfer payload (20 KiB).
inline constexpr std::uint32_t kMaxTransferPayloadBytes = 20480;

enum class FrameType : std::uint8_t {
  Payload = 0,     ///< Data chunk of the transfer payload.
  Descriptor = 1,  ///< Metadata: size, frame count, payload CRC32, encoding mode.
  Reserved = 255,
};

enum class FrameFlags : std::uint8_t {
  None = 0,
  FinalChunkHint = 1 << 0,
};

[[nodiscard]] constexpr std::uint8_t to_underlying(FrameFlags f) noexcept {
  return static_cast<std::uint8_t>(f);
}

[[nodiscard]] constexpr FrameFlags operator|(FrameFlags a, FrameFlags b) noexcept {
  return static_cast<FrameFlags>(to_underlying(a) | to_underlying(b));
}

[[nodiscard]] constexpr bool has_flag(std::uint8_t flags, FrameFlags f) noexcept {
  return (flags & to_underlying(f)) != 0;
}

}  // namespace vdt::protocol
