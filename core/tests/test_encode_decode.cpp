#include <catch2/catch_test_macros.hpp>

#include "vdt/capi.h"
#include "vdt/common/bit_packing.hpp"
#include "vdt/decode/frame_decoder.hpp"
#include "vdt/decode/session_assembler.hpp"
#include "vdt/encode/frame_encoder.hpp"
#include "vdt/vision/grid_sampler.hpp"
#include "vdt/vision/interfaces.hpp"

#include <cstring>
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

TEST_CASE("capi session assembler push_wire transfer loop", "[capi][assembler]") {
  const char msg[] = "Hello, VDT";
  VDTEncodedSession* sess =
      vdt_transfer_loop_cycle(42, reinterpret_cast<const uint8_t*>(msg), std::strlen(msg), 1, 1024);
  REQUIRE(sess != nullptr);
  REQUIRE(sess->frame_count > 0);

  VDTSessionAssembler* a = vdt_session_assembler_create();
  REQUIRE(a != nullptr);
  for (size_t i = 0; i < sess->frame_count; ++i) {
    REQUIRE(vdt_session_assembler_push_wire(a, sess->frame_data[i], sess->frame_sizes[i]) == 1);
  }
  REQUIRE(vdt_session_assembler_is_complete(a) == 1);
  std::vector<uint8_t> out(vdt_max_transfer_payload_bytes());
  const size_t n = vdt_session_assembler_take_merged_payload(a, out.data(), out.size());
  REQUIRE(n == std::strlen(msg));
  REQUIRE(std::memcmp(out.data(), msg, n) == 0);

  vdt_session_assembler_destroy(a);
  vdt_encoded_session_free(sess);
}

TEST_CASE("capi full-bleed grid sample identity", "[capi][vision]") {
  constexpr int w = 32;
  constexpr int h = 24;
  std::vector<uint8_t> gray(static_cast<std::size_t>(w * h));
  for (int y = 0; y < h; ++y) {
    for (int x = 0; x < w; ++x) {
      gray[static_cast<std::size_t>(y * w + x)] = static_cast<std::uint8_t>((x + y) & 0xFF);
    }
  }
  constexpr uint16_t rows = 2;
  constexpr uint16_t cols = 2;
  std::vector<uint8_t> out(static_cast<std::size_t>(rows) * cols);
  REQUIRE(vdt_sample_grid_full_bleed(gray.data(), static_cast<uint32_t>(w), static_cast<uint32_t>(h), rows, cols,
                                     out.data(), out.size()) == 1);
  vdt::vision::GrayImageView view{static_cast<uint32_t>(w), static_cast<uint32_t>(h), std::span(gray)};
  vdt::vision::GridSampler sampler{};
  std::vector<std::uint8_t> ref;
  REQUIRE(sampler.sample_grid(view, rows, cols, ref));
  REQUIRE(ref == out);
}
