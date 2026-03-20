#include <catch2/catch_test_macros.hpp>

#include "vdt/decode/frame_decoder.hpp"
#include "vdt/decode/session_assembler.hpp"
#include "vdt/encode/transfer_loop.hpp"

#include <vector>

TEST_CASE("transfer loop Normal + descriptor + CRC32 verify", "[loop]") {
  const std::vector<std::uint8_t> message = {0x01, 0x02, 0x03, 0x04, 0x05};
  const auto cycle =
      vdt::encode::build_transfer_loop_cycle(0xC0DEu, message, vdt::protocol::EncodingMode::Normal, 64);
  REQUIRE_FALSE(cycle.empty());
  vdt::decode::SessionAssembler asm_;
  for (const auto& f : cycle) {
    const auto dec = vdt::decode::decode_frame(f.wire);
    REQUIRE(dec.has_value());
    REQUIRE(asm_.push_frame(*dec));
  }
  REQUIRE(asm_.is_complete());
  const auto merged = asm_.take_merged_payload();
  REQUIRE(merged.has_value());
  REQUIRE(*merged == message);
}

TEST_CASE("duplicate payload chunk tolerated", "[loop]") {
  const std::vector<std::uint8_t> message = {0xAB, 0xCD};
  const auto cycle =
      vdt::encode::build_transfer_loop_cycle(1u, message, vdt::protocol::EncodingMode::Normal, 64);
  vdt::decode::SessionAssembler asm_;
  for (const auto& f : cycle) {
    const auto dec = vdt::decode::decode_frame(f.wire);
    REQUIRE(dec.has_value());
    REQUIRE(asm_.push_frame(*dec));
  }
  REQUIRE(asm_.is_complete());
  // Replay last payload frame (same chunk) — should still verify after merge once.
  for (int i = static_cast<int>(cycle.size()) - 1; i >= 0; --i) {
    if (cycle[static_cast<std::size_t>(i)].header.frame_type != vdt::protocol::FrameType::Payload) {
      continue;
    }
    const auto dec = vdt::decode::decode_frame(cycle[static_cast<std::size_t>(i)].wire);
    REQUIRE(dec.has_value());
    REQUIRE(asm_.push_frame(*dec));
    break;
  }
  const auto merged = asm_.take_merged_payload();
  REQUIRE(merged.has_value());
  REQUIRE(*merged == message);
}

TEST_CASE("Safe mode inserts more descriptor frames", "[loop]") {
  std::vector<std::uint8_t> msg(200);
  for (std::size_t i = 0; i < msg.size(); ++i) {
    msg[i] = static_cast<std::uint8_t>(i & 0xFF);
  }
  const auto normal = vdt::encode::build_transfer_loop_cycle(2u, msg, vdt::protocol::EncodingMode::Normal, 64);
  const auto safe = vdt::encode::build_transfer_loop_cycle(2u, msg, vdt::protocol::EncodingMode::Safe, 64);
  REQUIRE(safe.size() > normal.size());
}

TEST_CASE("Safe mode multi-chunk assembles with repeated descriptors", "[loop]") {
  std::vector<std::uint8_t> msg(200);
  for (std::size_t i = 0; i < msg.size(); ++i) {
    msg[i] = static_cast<std::uint8_t>(i & 0xFF);
  }
  const auto safe = vdt::encode::build_transfer_loop_cycle(2u, msg, vdt::protocol::EncodingMode::Safe, 64);
  vdt::decode::SessionAssembler asm_;
  for (const auto& f : safe) {
    const auto dec = vdt::decode::decode_frame(f.wire);
    REQUIRE(dec.has_value());
    REQUIRE(asm_.push_frame(*dec));
  }
  REQUIRE(asm_.is_complete());
  const auto merged = asm_.take_merged_payload();
  REQUIRE(merged.has_value());
  REQUIRE(*merged == msg);
}

TEST_CASE("Normal mode periodic descriptors still assembles", "[loop]") {
  std::vector<std::uint8_t> msg(200);
  for (std::size_t i = 0; i < msg.size(); ++i) {
    msg[i] = static_cast<std::uint8_t>(i & 0xFF);
  }
  vdt::encode::TransferLoopOptions opt{};
  opt.repeat_descriptor_every_k_payloads = 2;
  const auto cycle =
      vdt::encode::build_transfer_loop_cycle(3u, msg, vdt::protocol::EncodingMode::Normal, 64, opt);
  std::size_t desc_n = 0;
  for (const auto& f : cycle) {
    if (f.header.frame_type == vdt::protocol::FrameType::Descriptor) {
      ++desc_n;
    }
  }
  REQUIRE(desc_n >= 2);
  vdt::decode::SessionAssembler asm_;
  for (const auto& f : cycle) {
    const auto dec = vdt::decode::decode_frame(f.wire);
    REQUIRE(dec.has_value());
    REQUIRE(asm_.push_frame(*dec));
  }
  REQUIRE(asm_.is_complete());
  const auto merged = asm_.take_merged_payload();
  REQUIRE(merged.has_value());
  REQUIRE(*merged == msg);
}

TEST_CASE("Trailing descriptor Normal assembles", "[loop]") {
  const std::vector<std::uint8_t> message = {0x11, 0x22, 0x33};
  vdt::encode::TransferLoopOptions opt{};
  opt.trailing_descriptor = true;
  const auto cycle =
      vdt::encode::build_transfer_loop_cycle(9u, message, vdt::protocol::EncodingMode::Normal, 64, opt);
  REQUIRE_FALSE(cycle.empty());
  REQUIRE(cycle.back().header.frame_type == vdt::protocol::FrameType::Descriptor);
  vdt::decode::SessionAssembler asm_;
  for (const auto& f : cycle) {
    const auto dec = vdt::decode::decode_frame(f.wire);
    REQUIRE(dec.has_value());
    REQUIRE(asm_.push_frame(*dec));
  }
  REQUIRE(asm_.is_complete());
  const auto merged = asm_.take_merged_payload();
  REQUIRE(merged.has_value());
  REQUIRE(*merged == message);
}
