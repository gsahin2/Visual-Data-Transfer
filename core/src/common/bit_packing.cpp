#include "vdt/common/bit_packing.hpp"

#include <cassert>

namespace vdt {

void BitWriter::write_bits(std::uint32_t value, int bit_count) {
  assert(bit_count >= 0 && bit_count <= 32);
  for (int i = bit_count - 1; i >= 0; --i) {
    const bool bit = ((value >> static_cast<unsigned>(i)) & 1U) != 0U;
    current_ = static_cast<std::uint8_t>((current_ << 1U) | (bit ? 1U : 0U));
    ++filled_bits_;
    if (filled_bits_ == 8) {
      bytes_.push_back(current_);
      current_ = 0;
      filled_bits_ = 0;
    }
  }
}

void BitWriter::flush() {
  if (filled_bits_ > 0) {
    current_ = static_cast<std::uint8_t>(current_ << static_cast<unsigned>(8 - filled_bits_));
    bytes_.push_back(current_);
    current_ = 0;
    filled_bits_ = 0;
  }
}

BitReader::BitReader(const std::uint8_t* data, std::size_t length) noexcept : data_(data), length_(length) {}

bool BitReader::read_bits(int bit_count, std::uint32_t& out) {
  if (bit_count < 0 || bit_count > 32) {
    return false;
  }
  out = 0;
  for (int i = 0; i < bit_count; ++i) {
    if (byte_index_ >= length_) {
      return false;
    }
    const std::uint8_t b = data_[byte_index_];
    const int shift = 7 - bit_index_;
    const bool bit = ((b >> shift) & 1U) != 0U;
    out = (out << 1U) | (bit ? 1U : 0U);
    ++bit_index_;
    if (bit_index_ == 8) {
      bit_index_ = 0;
      ++byte_index_;
    }
  }
  return true;
}

std::size_t BitReader::bits_remaining() const noexcept {
  if (byte_index_ >= length_) {
    return 0;
  }
  const std::size_t whole = (length_ - byte_index_ - 1U) * 8U;
  return whole + static_cast<std::size_t>(8 - bit_index_);
}

}  // namespace vdt
