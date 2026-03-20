#pragma once

#include "vdt/common/types.hpp"
#include "vdt/protocol/constants.hpp"

#include <cstdint>
#include <span>
#include <vector>

namespace vdt::encode {

/// Splits a byte stream into payloads that respect the V1 maximum frame payload size.
[[nodiscard]] std::vector<ByteBuffer> split_payload(std::span<const std::uint8_t> data,
                                                    std::uint16_t max_payload_bytes =
                                                        protocol::kMaxPayloadBytesPerFrame);

}  // namespace vdt::encode
