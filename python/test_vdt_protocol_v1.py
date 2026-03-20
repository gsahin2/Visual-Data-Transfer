"""Smoke tests for `vdt_protocol_v1` (SessionAssembler, push_decoded, parse_frame)."""

from __future__ import annotations

import unittest
from typing import Tuple

from grid_codec import majority_symbols

from vdt_protocol_v1 import (
    FRAME_DESCRIPTOR,
    FRAME_PAYLOAD,
    VERSION1,
    FrameHeader,
    SessionAssembler,
    TransferDescriptorV1,
    build_frame,
    crc32_ieee,
    parse_frame,
)


def _single_chunk_session(sid: int, msg: bytes) -> Tuple[FrameHeader, bytes, FrameHeader, bytes]:
    crc = crc32_ieee(msg) & 0xFFFFFFFF
    desc = TransferDescriptorV1(
        transfer_id=sid,
        payload_byte_length=len(msg),
        payload_crc32=crc,
        data_frame_count=1,
    )
    body = desc.serialize()
    h_desc = FrameHeader(VERSION1, FRAME_DESCRIPTOR, 0, sid, 0, 1, len(body))
    h_pay = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, sid, 0, 1, len(msg))
    return h_desc, body, h_pay, msg


class TestParseFrame(unittest.TestCase):
    def test_rejects_bad_crc(self) -> None:
        msg = b"x"
        h = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, 1, 0, 1, len(msg))
        wire = build_frame(h, msg)
        bad = bytearray(wire)
        bad[-1] ^= 0xFF
        self.assertIsNone(parse_frame(bytes(bad)))

    def test_roundtrip_build_parse(self) -> None:
        msg = b"payload-bytes"
        h = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, 99, 0, 1, len(msg))
        wire = build_frame(h, msg)
        got = parse_frame(wire)
        self.assertIsNotNone(got)
        hdr, pl = got
        self.assertEqual(hdr.session_id, 99)
        self.assertEqual(pl, msg)


class TestSessionAssemblerPushDecoded(unittest.TestCase):
    def test_descriptor_plus_payload_delivers(self) -> None:
        msg = b"hello-push-decoded"
        h_desc, body, h_pay, _ = _single_chunk_session(42, msg)
        asm = SessionAssembler()
        self.assertTrue(asm.push_decoded(h_desc, body))
        self.assertFalse(asm.is_complete())
        self.assertTrue(asm.push_decoded(h_pay, msg))
        self.assertTrue(asm.is_complete())
        out = asm.take_payload()
        self.assertEqual(out, msg)

    def test_push_wire_same_as_push_decoded(self) -> None:
        msg = b"parity"
        h_desc, body, h_pay, _ = _single_chunk_session(7, msg)
        w_d = build_frame(h_desc, body)
        w_p = build_frame(h_pay, msg)
        a1 = SessionAssembler()
        self.assertTrue(a1.push_wire(w_d))
        self.assertTrue(a1.push_wire(w_p))
        self.assertEqual(a1.take_payload(), msg)

        a2 = SessionAssembler()
        p_d = parse_frame(w_d)
        p_p = parse_frame(w_p)
        assert p_d and p_p
        self.assertTrue(a2.push_decoded(p_d[0], p_d[1]))
        self.assertTrue(a2.push_decoded(p_p[0], p_p[1]))
        self.assertEqual(a2.take_payload(), msg)

    def test_rejects_wrong_version(self) -> None:
        msg = b"a"
        h = FrameHeader(99, FRAME_PAYLOAD, 0, 1, 0, 1, len(msg))
        asm = SessionAssembler()
        self.assertFalse(asm.push_decoded(h, msg))

    def test_rejects_payload_length_mismatch(self) -> None:
        h = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, 1, 0, 1, 5)
        asm = SessionAssembler()
        self.assertFalse(asm.push_decoded(h, b"ab"))

    def test_duplicate_identical_chunk_accepted(self) -> None:
        msg = b"dup"
        h_desc, body, h_pay, _ = _single_chunk_session(3, msg)
        asm = SessionAssembler()
        asm.push_decoded(h_desc, body)
        self.assertTrue(asm.push_decoded(h_pay, msg))
        self.assertTrue(asm.push_decoded(h_pay, msg))
        self.assertTrue(asm.is_complete())
        self.assertEqual(asm.take_payload(), msg)

    def test_duplicate_conflicting_chunk_rejected(self) -> None:
        msg = b"one"
        h_desc, body, h_pay, _ = _single_chunk_session(3, msg)
        asm = SessionAssembler()
        asm.push_decoded(h_desc, body)
        self.assertTrue(asm.push_decoded(h_pay, msg))
        h_pay2 = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, 3, 0, 1, 3)
        self.assertFalse(asm.push_decoded(h_pay2, b"two"))

    def test_duplicate_descriptor_preserves_partial_chunks(self) -> None:
        a, b = b"abcd", b"efgh"
        msg = a + b
        crc = crc32_ieee(msg) & 0xFFFFFFFF
        sid = 99
        desc = TransferDescriptorV1(
            transfer_id=sid,
            payload_byte_length=len(msg),
            payload_crc32=crc,
            data_frame_count=2,
        )
        body = desc.serialize()
        h_desc = FrameHeader(VERSION1, FRAME_DESCRIPTOR, 0, sid, 0, 1, len(body))
        h_p0 = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, sid, 0, 2, len(a))
        h_p1 = FrameHeader(VERSION1, FRAME_PAYLOAD, 0, sid, 1, 2, len(b))
        asm = SessionAssembler()
        self.assertTrue(asm.push_decoded(h_desc, body))
        self.assertTrue(asm.push_decoded(h_p0, a))
        self.assertTrue(asm.push_decoded(h_desc, body))
        self.assertFalse(asm.is_complete())
        self.assertTrue(asm.push_decoded(h_p1, b))
        self.assertTrue(asm.is_complete())
        self.assertEqual(asm.take_payload(), msg)


class TestMajoritySymbols(unittest.TestCase):
    def test_plurality_per_cell(self) -> None:
        a = [0, 1, 2, 3]
        b = [0, 1, 2, 0]
        c = [0, 2, 2, 3]
        self.assertEqual(majority_symbols([a, b, c]), [0, 1, 2, 3])


if __name__ == "__main__":
    unittest.main()
