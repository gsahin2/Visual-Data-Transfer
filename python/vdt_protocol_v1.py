"""
V1 wire format (aligned with C++ `vdt::protocol`).

Frame types: Payload=0, Descriptor=1.
Descriptor body: fixed 20 bytes (`TransferDescriptorV1`).
"""

from __future__ import annotations

import struct
from dataclasses import dataclass
from typing import List, Optional, Tuple

MAGIC0 = 0x56
MAGIC1 = 0x54
VERSION1 = 1
HEADER_BYTES = 18
MAX_PAYLOAD_PER_FRAME = 1024
MAX_TRANSFER_PAYLOAD = 20480

FRAME_PAYLOAD = 0
FRAME_DESCRIPTOR = 1


def crc16_ccitt_false(data: bytes) -> int:
    crc = 0xFFFF
    for byte in data:
        crc ^= byte << 8
        for _ in range(8):
            if crc & 0x8000:
                crc = ((crc << 1) ^ 0x1021) & 0xFFFF
            else:
                crc = (crc << 1) & 0xFFFF
    return crc


def crc32_ieee(data: bytes) -> int:
    crc = 0xFFFFFFFF
    for byte in data:
        crc ^= byte
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xEDB88320
            else:
                crc >>= 1
    return crc ^ 0xFFFFFFFF


@dataclass
class FrameHeader:
    version: int
    frame_type: int
    flags: int
    session_id: int
    chunk_index: int
    chunk_count: int
    payload_length: int


def build_frame(header: FrameHeader, payload: bytes) -> bytes:
    if len(payload) > MAX_PAYLOAD_PER_FRAME or len(payload) != header.payload_length:
        raise ValueError("payload length mismatch")
    hdr = bytearray(HEADER_BYTES)
    hdr[0] = MAGIC0
    hdr[1] = MAGIC1
    hdr[2] = header.version
    hdr[3] = header.frame_type
    hdr[4] = header.flags
    hdr[5] = 0
    struct.pack_into("<I", hdr, 6, header.session_id)
    struct.pack_into("<H", hdr, 10, header.chunk_index)
    struct.pack_into("<H", hdr, 12, header.chunk_count)
    struct.pack_into("<H", hdr, 14, header.payload_length)
    hdr[16] = 0
    hdr[17] = 0
    body = bytes(hdr) + payload
    crc = crc16_ccitt_false(body)
    return body + struct.pack("<H", crc)


def parse_frame(wire: bytes) -> Optional[Tuple[FrameHeader, bytes]]:
    if len(wire) < HEADER_BYTES + 2:
        return None
    if wire[0] != MAGIC0 or wire[1] != MAGIC1 or wire[2] != VERSION1:
        return None
    payload_length = struct.unpack_from("<H", wire, 14)[0]
    if payload_length > MAX_PAYLOAD_PER_FRAME:
        return None
    expected = HEADER_BYTES + payload_length + 2
    if len(wire) < expected:
        return None
    # Grid / optical paths often yield a fixed cell bit capacity with zero-padded tail;
    # only the first ``expected`` bytes participate in the frame.
    wire = wire[:expected]
    stored = struct.unpack_from("<H", wire, HEADER_BYTES + payload_length)[0]
    computed = crc16_ccitt_false(wire[: HEADER_BYTES + payload_length])
    if stored != computed:
        return None
    header = FrameHeader(
        version=wire[2],
        frame_type=wire[3],
        flags=wire[4],
        session_id=struct.unpack_from("<I", wire, 6)[0],
        chunk_index=struct.unpack_from("<H", wire, 10)[0],
        chunk_count=struct.unpack_from("<H", wire, 12)[0],
        payload_length=payload_length,
    )
    payload = wire[HEADER_BYTES : HEADER_BYTES + payload_length]
    return header, payload


@dataclass
class TransferDescriptorV1:
    layout_version: int = 1
    encoding_mode: int = 1  # 0 safe, 1 normal
    reserved0: int = 0
    transfer_id: int = 0
    payload_byte_length: int = 0
    payload_crc32: int = 0
    data_frame_count: int = 0
    reserved1: int = 0

    WIRE_BYTES = 20

    def serialize(self) -> bytes:
        return struct.pack(
            "<BBHIIIHH",
            self.layout_version,
            self.encoding_mode,
            self.reserved0,
            self.transfer_id,
            self.payload_byte_length,
            self.payload_crc32 & 0xFFFFFFFF,
            self.data_frame_count,
            self.reserved1,
        )

    @staticmethod
    def parse(payload: bytes) -> Optional["TransferDescriptorV1"]:
        if len(payload) != TransferDescriptorV1.WIRE_BYTES:
            return None
        lv, em, r0, tid, plen, pcrc, dfc, r1 = struct.unpack("<BBHIIIHH", payload)
        if lv != 1 or dfc == 0 or plen > MAX_TRANSFER_PAYLOAD:
            return None
        return TransferDescriptorV1(lv, em, r0, tid, plen, pcrc, dfc, r1)


def encode_session_wires(
    transfer_id: int,
    message: bytes,
    *,
    max_payload_per_chunk: int = MAX_PAYLOAD_PER_FRAME,
) -> List[bytes]:
    """
    Build one descriptor frame plus payload chunk wires (same chunking rules as the C++ encoder).

    Use a smaller ``max_payload_per_chunk`` when each wire must fit in a fixed grid
    (see ``optical_wire.max_optical_payload_bytes``).
    """
    if len(message) > MAX_TRANSFER_PAYLOAD:
        raise ValueError("message exceeds V1 max transfer size")
    tid = transfer_id & 0xFFFFFFFF
    mx = max(1, min(MAX_PAYLOAD_PER_FRAME, max_payload_per_chunk))
    chunks = [message[i : i + mx] for i in range(0, len(message), mx)]
    n = len(chunks)
    crc_full = crc32_ieee(message) & 0xFFFFFFFF
    desc = TransferDescriptorV1(
        transfer_id=tid,
        payload_byte_length=len(message),
        payload_crc32=crc_full,
        data_frame_count=n,
        encoding_mode=1,
    )
    desc_body = desc.serialize()
    dh = FrameHeader(VERSION1, FRAME_DESCRIPTOR, 0, tid, 0, 1, len(desc_body))
    out: List[bytes] = [build_frame(dh, desc_body)]
    for idx, chunk in enumerate(chunks):
        ph = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, tid, idx, n, len(chunk))
        out.append(build_frame(ph, chunk))
    return out


class SessionAssembler:
    """Python mirror of C++ `vdt::decode::SessionAssembler` (descriptor + payload + CRC32)."""

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self._chunks: dict[int, bytes] = {}
        self._descriptor_seen = False
        self._expect_chunks: Optional[int] = None
        self._expect_crc: Optional[int] = None
        self._expect_len: Optional[int] = None
        self._sid: Optional[int] = None

    def push_wire(self, wire: bytes) -> bool:
        parsed = parse_frame(wire)
        if not parsed:
            return False
        return self.push_decoded(parsed[0], parsed[1])

    def push_decoded(self, header: FrameHeader, payload: bytes) -> bool:
        """
        Ingest a logically decoded frame (same as after `parse_frame`), matching C `vdt_session_assembler_push_decoded`.
        `len(payload)` must equal `header.payload_length` and respect `MAX_PAYLOAD_PER_FRAME`.
        """
        if header.payload_length > MAX_PAYLOAD_PER_FRAME or len(payload) != header.payload_length:
            return False
        if header.version != VERSION1:
            return False
        hdr = header
        if hdr.frame_type == FRAME_DESCRIPTOR:
            desc = TransferDescriptorV1.parse(payload)
            if desc is None:
                return False
            if self._descriptor_seen and self._sid == desc.transfer_id and self._expect_chunks is not None:
                if (
                    self._expect_chunks == desc.data_frame_count
                    and self._expect_len == desc.payload_byte_length
                    and (self._expect_crc & 0xFFFFFFFF) == (desc.payload_crc32 & 0xFFFFFFFF)
                ):
                    return True
            self._descriptor_seen = True
            self._chunks = {}
            self._expect_chunks = desc.data_frame_count
            self._expect_crc = desc.payload_crc32 & 0xFFFFFFFF
            self._expect_len = desc.payload_byte_length
            self._sid = desc.transfer_id
            return True
        if hdr.frame_type != FRAME_PAYLOAD:
            return False
        if hdr.chunk_count == 0:
            return False
        if not self._descriptor_seen:
            if self._expect_chunks is None:
                self._expect_chunks = hdr.chunk_count
                self._sid = hdr.session_id
            elif hdr.session_id != self._sid or hdr.chunk_count != self._expect_chunks:
                return False
        else:
            if hdr.session_id != self._sid or hdr.chunk_count != self._expect_chunks:
                return False
        idx = hdr.chunk_index
        if idx in self._chunks:
            return self._chunks[idx] == payload
        self._chunks[idx] = payload
        return True

    def is_complete(self) -> bool:
        if self._expect_chunks is None:
            return False
        return len(self._chunks) == self._expect_chunks and all(
            i in self._chunks for i in range(self._expect_chunks)
        )

    def take_payload(self) -> Optional[bytes]:
        if not self.is_complete():
            return None
        assert self._expect_chunks is not None
        merged = b"".join(self._chunks[i] for i in range(self._expect_chunks))
        if self._descriptor_seen:
            if self._expect_len is None or self._expect_crc is None:
                self.reset()
                return None
            if len(merged) != self._expect_len:
                self.reset()
                return None
            if (crc32_ieee(merged) & 0xFFFFFFFF) != (self._expect_crc & 0xFFFFFFFF):
                self.reset()
                return None
        out = merged
        self.reset()
        return out
