#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Fail if any 64-bit native library in an .aab/.apk is not 16 KB page aligned.

Google Play refuses an update whose arm64/x86_64 libraries load on 4 KB
boundaries. The console only says "your app does not support 16 KB memory page
sizes" and never names the library, so this reads the ELF program headers and
names it.

    python3 tool/check_16kb.py build/app/outputs/bundle/release/app-release.aab
"""
import struct
import sys
import zipfile

NEEDED = 16384


def loads(data):
    """Minimum p_align across the PT_LOAD segments of a 64-bit little-endian ELF."""
    if data[:4] != b"\x7fELF" or data[4] != 2:
        return None
    e_phoff = struct.unpack_from("<Q", data, 0x20)[0]
    e_phentsize = struct.unpack_from("<H", data, 0x36)[0]
    e_phnum = struct.unpack_from("<H", data, 0x38)[0]
    aligns = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if struct.unpack_from("<I", data, off)[0] == 1:  # PT_LOAD
            aligns.append(struct.unpack_from("<Q", data, off + 0x30)[0])
    return min(aligns) if aligns else None


def main(path):
    z = zipfile.ZipFile(path)
    names = [n for n in z.namelist()
             if n.endswith(".so") and ("arm64" in n or "x86_64" in n)]
    if not names:
        print("no 64-bit native libraries found in", path)
        return 0
    bad = []
    for n in sorted(names):
        a = loads(z.read(n))
        if a is None:
            continue
        mark = "ok " if a >= NEEDED else "BAD"
        print("  %s %-48s align=%d" % (mark, n.split("/")[-1], a))
        if a < NEEDED:
            bad.append((n, a))
    print()
    if bad:
        print("NOT 16 KB aligned - Play will reject this update:")
        for n, a in bad:
            print("  %s (align=%d)" % (n, a))
        print("\nFix by naming a newer version of the library that ships it in")
        print("android/app/build.gradle.kts; see the dependencies block there.")
        return 1
    print("every 64-bit library is 16 KB aligned")
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(2)
    sys.exit(main(sys.argv[1]))
