#!/usr/bin/env python3
"""Make a RISC OS sprite file (!Sprites) from a PNG.

   png2sprite.py <in.png> <out,ff9> name:WxH [name:WxH ...]

Each name:WxH is one sprite: the image scaled to W x H pixels. Sprites are
new-format 32bpp (type 6) at 90 x 90 dpi with a 1bpp mask (pixels with
alpha < 128 are transparent), which RISC OS 5 plots in any screen mode.
"""
import struct, sys
from PIL import Image

def sprite(img, name, w, h):
    im = img.convert('RGBA').resize((w, h), Image.LANCZOS)
    px = im.load()
    image = bytearray()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            image += bytes((r, g, b, 0))          # word &00BBGGRR
    mask_words = (w + 31) // 32
    mask = bytearray()
    for y in range(h):
        row = [0] * mask_words
        for x in range(w):
            if px[x, y][3] >= 128:
                row[x // 32] |= 1 << (x % 32)     # leftmost pixel = bit 0
        mask += struct.pack('<%dI' % mask_words, *row)
    mode = (6 << 27) | (90 << 14) | (90 << 1) | 1  # 32bpp, 90 x 90 dpi
    header_len = 44
    img_off = header_len
    mask_off = img_off + len(image)
    total = mask_off + len(mask)
    nm = name.lower().encode('latin-1')[:12].ljust(12, b'\0')
    hdr = struct.pack('<I12s7I', total, nm, w - 1, h - 1, 0, 31,
                      img_off, mask_off, mode)
    assert len(hdr) == header_len
    return hdr + bytes(image) + bytes(mask)

def main():
    src, out = sys.argv[1], sys.argv[2]
    img = Image.open(src)
    body = b''
    for spec in sys.argv[3:]:
        name, size = spec.split(':')
        w, h = (int(v) for v in size.lower().split('x'))
        body += sprite(img, name, w, h)
    n = len(sys.argv) - 3
    # A sprite file is a sprite area without its first word (the area size);
    # offsets count from the start of the area, i.e. 4 bytes before the file.
    area = struct.pack('<3I', n, 16, 16 + len(body)) + body
    open(out, 'wb').write(area)

if __name__ == '__main__':
    main()
