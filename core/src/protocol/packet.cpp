#include "vdt/protocol/packet.hpp"

#include <cstring>

namespace vdt::protocol {

namespace {

void read_u64_le(const std::uint8_t* p, std::uint64_t& v) noexcept {
  v = static_cast<std::uint64_t>(p[0]) | (static_cast<std::uint64_t>(p[1]) << 8U) |
      (static_cast<std::uint64_t>(p[2]) << 16U) | (static_cast<std::uint64_t>(p[3]) << 24U) |
      (static_cast<std::uint64_t>(p[4]) << 32U) | (static_cast<std::uint64_t>(p[5]) << 40U) |
      (static_cast<std::uint64_t>(p[6]) << 48U) | (static_cast<std::uint64_t>(p[7]) << 56U);
}

void write_u64_le(std::uint8_t* p, std::uint64_t v) noexcept {
  for (int i = 0; i < 8; ++i) {
    p[i] = static_cast<std::uint8_t>((v >> (8U * static_cast<unsigned>(i))) & 0xFFU);
  }
}

}  // namespace

bool parse_data_packet(std::span<const std::uint8_t> payload, DataPacketView& out) noexcept {
  constexpr std::size_t kPrefix = 16;
  if (payload.size() < kPrefix) {
    return false;
  }
  std::uint64_t off{};
  std::uint64_t tot{};
  read_u64_le(payload.data(), off);
  read_u64_le(payload.data() + 8, tot);
  out.stream_offset = off;
  out.stream_total = tot;
  out.message = payload.subspan(kPrefix);
  return true;
}

ByteBuffer build_data_packet(std::uint64_t stream_offset, std::uint64_t stream_total,
                             std::span<const std::uint8_t> message) {
  constexpr std::size_t kPrefix = 16;
  ByteBuffer out;
  out.resize(kPrefix + message.size());
  write_u64_le(out.data(), stream_offset);
  write_u64_le(out.data() + 8, stream_total);
  if (!message.empty()) {
    std::memcpy(out.data() + kPrefix, message.data(), message.size());
  }
  return out;
}

}  // namespace vdt::protocol
