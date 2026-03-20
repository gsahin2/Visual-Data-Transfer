"""
Synthetic optical path: VT **wire** embedded in margin/gap grid PNGs → decode → assemble → 20 KiB payload.

Requires: Pillow, numpy. Quad homography test runs only if opencv-python is installed.
"""

from __future__ import annotations

import unittest

try:
    import cv2  # noqa: F401
    _HAS_CV2 = True
except ImportError:
    _HAS_CV2 = False

from grid_codec import (
    decode_grid_sampled,
    grid_symbols_full_bleed_from_ndarray_bgr,
    grid_symbols_from_ndarray_bgr,
    grid_symbols_quad_from_ndarray_bgr,
)
from numpy.testing import assert_array_equal

from optical_wire import max_optical_payload_bytes, render_wire_as_grid_png_rgb
from vdt_protocol_v1 import encode_session_wires, SessionAssembler


class TestOpticalSession20KiB(unittest.TestCase):
    def test_20480_byte_payload_roundtrip(self) -> None:
        rows, cols, w, h = 12, 20, 640, 480
        margin, gap = 8, 2
        mx = max_optical_payload_bytes(rows, cols)
        self.assertGreaterEqual(mx, 1)
        msg = bytes((i * 17 + 3) % 256 for i in range(20480))
        wires = encode_session_wires(4242, msg, max_payload_per_chunk=mx)
        asm = SessionAssembler()
        for wire in wires:
            self.assertLessEqual(len(wire), (rows * cols * 2) // 8)
            img = render_wire_as_grid_png_rgb(wire, rows, cols, w, h, margin, gap)
            iw, ih = img.size

            def sample(cx: int, cy: int) -> float:
                r, g, b = img.getpixel((cx, cy))
                return 0.299 * r + 0.587 * g + 0.114 * b

            blob = decode_grid_sampled(iw, ih, rows, cols, margin, gap, len(wire), sample, False)
            self.assertEqual(blob, wire, "grid decode must recover exact wire bytes")
            self.assertTrue(asm.push_wire(blob))
        out = asm.take_payload()
        self.assertEqual(out, msg)


class TestGridSamplingModes(unittest.TestCase):
    def test_full_bleed_vs_margin_on_solid(self) -> None:
        import numpy as np

        h, w = 48, 64
        g = np.zeros((h, w, 3), dtype=np.uint8)
        g[:] = (128, 128, 128)
        m_sym = grid_symbols_from_ndarray_bgr(g, 4, 4, 8, 2, False)
        f_sym = grid_symbols_full_bleed_from_ndarray_bgr(g, 4, 4, False)
        self.assertEqual(m_sym, f_sym)


@unittest.skipUnless(_HAS_CV2, "opencv-python required for quad homography sampling")
class TestQuadHomographyIdentity(unittest.TestCase):
    def test_quad_full_frame_matches_full_bleed(self) -> None:
        import numpy as np

        h, w = 24, 32
        arr = np.zeros((h, w, 3), dtype=np.uint8)
        arr[:] = (200, 100, 50)
        quad = [(0.0, 0.0), (w - 1.0, 0.0), (w - 1.0, h - 1.0), (0.0, h - 1.0)]
        syq = grid_symbols_quad_from_ndarray_bgr(arr, 3, 4, quad, False)
        syf = grid_symbols_full_bleed_from_ndarray_bgr(arr, 3, 4, False)
        assert_array_equal(syq, syf)


if __name__ == "__main__":
    unittest.main()
