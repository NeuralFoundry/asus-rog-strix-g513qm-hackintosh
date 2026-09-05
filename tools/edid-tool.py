"""EDID analysis and patching for high-refresh laptop panels.
Usage:
  python edid-tool.py analyze <edid.bin | base64 string>
  python edid-tool.py patch   <edid.bin | base64 string>   -> edid-patched.bin
The patch swaps the first two detailed timing descriptors when the second one is the 60 Hz mode (so 60 Hz
becomes the preferred timing), restricts the colour encoding to RGB 4:4:4 and fixes the checksum.
On macOS the raw EDID can be read with:  ioreg -lw0 | grep IODisplayEDID
On Windows it lives under HKLM\\SYSTEM\\CurrentControlSet\\Enum\\DISPLAY\\...\\Device Parameters\\EDID."""
import sys, base64, struct

def load(s):
    s = s.strip()
    try:
        return open(s, "rb").read()
    except OSError:
        return base64.b64decode(s)

def dtd(b):
    pc = struct.unpack("<H", b[0:2])[0] * 10  # kHz
    if pc == 0:
        return None
    ha = b[2] | ((b[4] & 0xF0) << 4); hb = b[3] | ((b[4] & 0x0F) << 8)
    va = b[5] | ((b[7] & 0xF0) << 4); vb = b[6] | ((b[7] & 0x0F) << 8)
    hz = pc * 1000 / ((ha + hb) * (va + vb)) if (ha + hb) and (va + vb) else 0
    return ha, va, pc, hz

def analyze(e):
    print("length:", len(e), "| header ok:", e[:8] == b"\x00\xff\xff\xff\xff\xff\xff\x00")
    mfg = struct.unpack(">H", e[8:10])[0]
    print("manufacturer:", "".join(chr(((mfg >> s) & 0x1F) + 64) for s in (10, 5, 0)), "| product:", hex(struct.unpack("<H", e[10:12])[0]))
    enc = (e[24] >> 3) & 3
    print("feature byte 0x18:", hex(e[24]), "|", ["RGB 4:4:4", "RGB + YCbCr 4:4:4", "RGB + YCbCr 4:2:2", "RGB + YCbCr 4:4:4 + 4:2:2"][enc])
    for i in range(4):
        d = dtd(e[54 + 18 * i: 72 + 18 * i])
        if d:
            print(f"DTD{i + 1}: {d[0]}x{d[1]}  pixel clock {d[2] / 1000:.2f} MHz  ~{d[3]:.1f} Hz")
    print("checksum ok:", all(sum(e[128 * k:128 * k + 128]) % 256 == 0 for k in range(len(e) // 128)))

def patch(e):
    e = bytearray(e)
    d1, d2 = bytes(e[54:72]), bytes(e[72:90])
    if dtd(d2) and dtd(d1) and dtd(d1)[3] > 70 and 55 < dtd(d2)[3] < 65:
        e[54:72] = d2; e[72:90] = d1
        print("swapped DTD1/DTD2 so the 60 Hz mode is preferred")
    e[24] &= ~0x18  # RGB 4:4:4 only
    e[127] = (256 - sum(e[0:127]) % 256) % 256
    return bytes(e)

if __name__ == "__main__":
    e = load(sys.argv[2]); analyze(e)
    if sys.argv[1] == "patch":
        y = patch(e); open("edid-patched.bin", "wb").write(y)
        print("--- patched ---"); analyze(y)
        print("edid-patched.bin written, base64:", base64.b64encode(y).decode())
