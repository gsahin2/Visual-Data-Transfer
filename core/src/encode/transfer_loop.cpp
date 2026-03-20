#include "vdt/encode/transfer_loop.hpp"

#include "vdt/common/crc32.hpp"
#include "vdt/protocol/frame.hpp"

namespace vdt::encode {

std::vector<EncodedFrame> build_transfer_loop_cycle(const std::uint32_t transfer_id,
                                                   const std::span<const std::uint8_t> message,
                                                   const protocol::EncodingMode mode,
                                                   const std::uint16_t max_payload_bytes,
                                                   const TransferLoopOptions& options) {
  if (message.size() > protocol::kMaxTransferPayloadBytes) {
    return {};
  }
  FrameEncoder enc(max_payload_bytes);
  auto data_frames = enc.encode_session(transfer_id, message, protocol::FrameType::Payload);
  if (data_frames.empty()) {
    return {};
  }

  protocol::TransferDescriptorV1 desc{};
  desc.transfer_id = transfer_id;
  desc.payload_byte_length = static_cast<std::uint32_t>(message.size());
  desc.payload_crc32 = crc32_ieee(message);
  desc.data_frame_count = static_cast<std::uint16_t>(data_frames.size());
  desc.encoding_mode = mode;

  const auto desc_body = protocol::serialize_descriptor_v1(desc);
  protocol::FrameHeader dh{};
  dh.version = protocol::kVersion1;
  dh.frame_type = protocol::FrameType::Descriptor;
  dh.flags = 0;
  dh.reserved = 0;
  dh.session_id = transfer_id;
  dh.chunk_index = 0;
  dh.chunk_count = 1;
  dh.payload_length = static_cast<std::uint16_t>(desc_body.size());

  auto make_descriptor_frame = [&]() {
    EncodedFrame ef;
    ef.header = dh;
    ef.wire = protocol::build_frame(dh, desc_body);
    return ef;
  };

  std::vector<EncodedFrame> out;
  if (mode == protocol::EncodingMode::Normal) {
    out.push_back(make_descriptor_frame());
    const std::uint16_t k = options.repeat_descriptor_every_k_payloads;
    for (std::size_t i = 0; i < data_frames.size(); ++i) {
      if (k > 0 && i > 0 && (i % static_cast<std::size_t>(k)) == 0) {
        out.push_back(make_descriptor_frame());
      }
      out.push_back(std::move(data_frames[i]));
    }
    if (options.trailing_descriptor) {
      out.push_back(make_descriptor_frame());
    }
    return out;
  }
  for (auto& f : data_frames) {
    out.push_back(make_descriptor_frame());
    out.push_back(std::move(f));
  }
  if (options.trailing_descriptor) {
    out.push_back(make_descriptor_frame());
  }
  return out;
}

}  // namespace vdt::encode
