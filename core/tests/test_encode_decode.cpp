#include <catch2/catch_test_macros.hpp>

#include "vdt/common/bit_packing.hpp"
#include "vdt/decode/frame_decoder.hpp"
#include "vdt/decode/session_assembler.hpp"
#include "vdt/encode/frame_encoder.hpp"

#include <vector>

TEST_CASE("encode/decode session roundtrip", "[encode][decode]") {
  const std::vector<std::uint8_t> message = {0xDE, 0xAD, 0xBE, 0xEF};
  vdt::encode::FrameEncoder enc(64);
  const auto frames = enc.encode_session(0xA01u, message);
  REQUIRE_FALSE(frames.empty());
  vdt::decode::SessionAssembler asm_;
  for (const auto& f : frames) {
    const auto decoded = vdt::decode::decode_frame(f.wire);
    REQUIRE(decoded.has_value());
    REQUIRE(asm_.push_frame(*decoded));
  }
  REQUIRE(asm_.is_complete());
  const auto merged = asm_.take_merged_payload();
  REQUIRE(merged.has_value());
  REQUIRE(*merged == message);
}

TEST_CASE("bit packing roundtrip", "[bitpack]") {
  vdt::BitWriter w;
  w.write_bits(0b101, 3);
  w.write_bits(0b11, 2);
  w.flush();
  const auto& bytes = w.bytes();
  REQUIRE(bytes.size() == 1);
  vdt::BitReader r(bytes.data(), bytes.size());
  std::uint32_t a = 0;
  std::uint32_t b = 0;
  REQUIRE(r.read_bits(3, a));
  REQUIRE(r.read_bits(2, b));
  REQUIRE(a == 0b101);
  REQUIRE(b == 0b11);
}
