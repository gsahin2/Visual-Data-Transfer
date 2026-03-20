#pragma once

#include <cstddef>
#include <cstdint>
#include <vector>

namespace vdt {

/// Packs bit streams into bytes (MSB of each byte first).
class BitWriter {
 public:
  void write_bits(std::uint32_t value, int bit_count);
  void flush();
  [[nodiscard]] const std::vector<std::uint8_t>& bytes() const { return bytes_; }

 private:
  std::vector<std::uint8_t> bytes_;
  std::uint8_t current_{0};
  int filled_bits_{0};
};

/// Reads bit streams from bytes (MSB of each byte first).
class BitReader {
 public:
  explicit BitReader(const std::uint8_t* data, std::size_t length) noexcept;
  [[nodiscard]] bool read_bits(int bit_count, std::uint32_t& out);
  [[nodiscard]] std::size_t bits_remaining() const noexcept;

 private:
  const std::uint8_t* data_;
  std::size_t length_;
  std::size_t byte_index_{0};
  int bit_index_{0};  // 0 = MSB of current byte
};

}  // namespace vdt
