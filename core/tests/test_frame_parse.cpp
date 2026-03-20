#include <catch2/catch_test_macros.hpp>

#include "vdt/protocol/frame.hpp"

#include <array>
#include <vector>

TEST_CASE("frame header serialization rejects bad magic", "[frame]") {
  std::array<std::uint8_t, vdt::protocol::kFrameHeaderBytes> buf{};
  vdt::protocol::FrameHeader h{};
  h.version = vdt::protocol::kVersion1;
  h.frame_type = vdt::protocol::FrameType::Data;
  h.session_id = 1;
  h.chunk_index = 0;
  h.chunk_count = 1;
  h.payload_length = 0;
  REQUIRE(vdt::protocol::serialize_header(h, buf));
  buf[0] = 0x00;
  vdt::protocol::FrameHeader out{};
  REQUIRE_FALSE(vdt::protocol::parse_header(buf, out));
}

TEST_CASE("build and parse frame with payload", "[frame]") {
  vdt::protocol::FrameHeader h{};
  h.version = vdt::protocol::kVersion1;
  h.frame_type = vdt::protocol::FrameType::Data;
  h.flags = 0;
  h.session_id = 42;
  h.chunk_index = 0;
  h.chunk_count = 1;
  const std::vector<std::uint8_t> payload = {0xAA, 0xBB};
  h.payload_length = static_cast<std::uint16_t>(payload.size());
  const auto wire = vdt::protocol::build_frame(h, payload);
  REQUIRE_FALSE(wire.empty());
  vdt::protocol::FrameHeader rh{};
  std::vector<std::uint8_t> out_payload;
  REQUIRE(vdt::protocol::parse_frame(wire, rh, out_payload));
  REQUIRE(rh.session_id == 42);
  REQUIRE(out_payload == payload);
}

TEST_CASE("parse_frame rejects corrupted CRC", "[frame]") {
  vdt::protocol::FrameHeader h{};
  h.version = vdt::protocol::kVersion1;
  h.frame_type = vdt::protocol::FrameType::Data;
  h.session_id = 7;
  h.chunk_index = 0;
  h.chunk_count = 1;
  std::vector<std::uint8_t> payload = {0x01};
  h.payload_length = static_cast<std::uint16_t>(payload.size());
  auto wire = vdt::protocol::build_frame(h, payload);
  REQUIRE(wire.size() >= 2);
  wire.back() ^= 0xFF;
  vdt::protocol::FrameHeader rh{};
  std::vector<std::uint8_t> out;
  REQUIRE_FALSE(vdt::protocol::parse_frame(wire, rh, out));
}
