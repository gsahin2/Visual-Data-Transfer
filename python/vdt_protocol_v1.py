"""
V1 wire format (aligned with C++ `vdt::protocol`).

Frame types: Payload=0, Descriptor=1.
Descriptor body: fixed 20 bytes (`TransferDescriptorV1`).
"""

from __future__ import annotations

import struct
from dataclasses import dataclass
from typing import Optional, Tuple

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
    if len(wire) != expected:
        return None
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
