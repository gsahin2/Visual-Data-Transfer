#include "vdt/encode/session_chunker.hpp"

#include <algorithm>

namespace vdt::encode {

std::vector<ByteBuffer> split_payload(std::span<const std::uint8_t> data, std::uint16_t max_payload_bytes) {
  std::vector<ByteBuffer> out;
  if (max_payload_bytes == 0) {
    return out;
  }
  std::size_t offset = 0;
  while (offset < data.size()) {
    const std::size_t take = std::min<std::size_t>(max_payload_bytes, data.size() - offset);
    ByteBuffer chunk;
    chunk.assign(data.begin() + static_cast<std::ptrdiff_t>(offset),
                 data.begin() + static_cast<std::ptrdiff_t>(offset + take));
    out.push_back(std::move(chunk));
    offset += take;
  }
  return out;
}

}  // namespace vdt::encode
