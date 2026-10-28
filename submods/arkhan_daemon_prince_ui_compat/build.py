#!/usr/bin/env python3
"""Build the confirmed one-file UI submod using Python's standard library."""
from pathlib import Path
import struct
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
PATH = "ui/campaign ui/province_info.twui.xml"
OUTPUT = ROOT / "!arkhan_daemon_prince_ui_compat.pack"


def main():
    data = (ROOT / PATH).read_bytes()
    ET.fromstring(data)
    index = struct.pack("<IB", len(data), 0) + PATH.replace("/", "\\").encode() + b"\0"
    header = bytearray.fromhex("50464835030000000000000000000000010000002b0000005b7fcf6a")
    struct.pack_into("<II", header, 16, 1, len(index))
    packed = bytes(header) + index + data
    OUTPUT.write_bytes(packed)
    saved = OUTPUT.read_bytes()
    assert saved[:4] == b"PFH5"
    assert struct.unpack_from("<II", saved, 16) == (1, len(index))
    assert saved[28:28 + len(index)] == index
    assert saved[28 + len(index):] == data
    print(f"Built and verified {OUTPUT} (one UI file)")


if __name__ == "__main__":
    main()
