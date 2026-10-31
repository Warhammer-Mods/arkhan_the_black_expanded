#!/usr/bin/env python3
"""Build the confirmed script-only independence submod with standard Python."""
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent
PATH = "script/campaign/mod/zz_arkhan_independent_option.lua"
OUTPUT = ROOT / "arkhan_keep_ai_independent.pack"


def main():
    data = (ROOT / "src" / PATH).read_bytes()
    index = struct.pack("<IB", len(data), 0) + PATH.replace("/", "\\").encode() + b"\0"
    header = bytearray.fromhex("50464835030000000000000000000000010000003a0000005b7fcf6a")
    struct.pack_into("<II", header, 16, 1, len(index))
    OUTPUT.write_bytes(bytes(header) + index + data)
    saved = OUTPUT.read_bytes()
    assert saved[:4] == b"PFH5"
    assert struct.unpack_from("<II", saved, 16) == (1, len(index))
    assert saved[28:28 + len(index)] == index
    assert saved[28 + len(index):] == data
    print(f"Built and verified {OUTPUT} (one campaign script)")


if __name__ == "__main__":
    main()
