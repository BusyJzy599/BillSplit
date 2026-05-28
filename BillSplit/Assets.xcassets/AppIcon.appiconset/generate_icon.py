#!/usr/bin/env python3
"""BillSplit icon: dark rounded rect, split circle in teal/blue, white accent."""
import struct, zlib, math, os

def create_png(width, height):
    pixels = []
    cx, cy = width/2, height/2
    size = width
    cr = size * 0.22     # corner radius of background
    circle_r = size * 0.28  # radius of the split circle
    gap = size * 0.03      # gap between halves

    for y in range(height):
        row = []
        for x in range(width):
            # Rounded rect mask
            dx = max(0, abs(x - cx) - (size/2 - cr))
            dy = max(0, abs(y - cy) - (size/2 - cr))
            dist = math.sqrt(dx*dx + dy*dy)

            if dist <= cr:
                # Background: rich navy gradient
                t = y / height
                r_bg = int(22 + t * 8)
                g_bg = int(32 + t * 6)
                b_bg = int(62 + t * 10)

                # Split circle
                cd = math.sqrt((x - cx)**2 + (y - cy)**2)
                in_circle = cd < circle_r

                if in_circle:
                    # Left half: teal (#00D2B0), right half: blue (#5B9BD5)
                    if x < cx - gap/2:
                        # Left half - teal
                        row.append((0, 210, 176, 255))
                    elif x > cx + gap/2:
                        # Right half - blue
                        row.append((91, 155, 213, 255))
                    else:
                        # Gap - background
                        row.append((r_bg, g_bg, b_bg, 255))
                else:
                    # Outside circle - small white accent dots at top and bottom
                    # Top dot
                    top_dot_dist = math.sqrt((x - cx)**2 + (y - (cy - circle_r))**2)
                    if top_dot_dist < size * 0.025:
                        row.append((255, 255, 255, 255))
                    # Bottom dot
                    elif math.sqrt((x - cx)**2 + (y - (cy + circle_r))**2) < size * 0.025:
                        row.append((255, 255, 255, 255))
                    else:
                        row.append((r_bg, g_bg, b_bg, 255))
            else:
                row.append((0, 0, 0, 0))
        pixels.append(row)
    return pixels

def write_png(filename, width, height):
    pixels = create_png(width, height)
    raw = b''
    for row in pixels:
        raw += b'\x00'
        for px in row:
            raw += struct.pack('BBBB', px[0], px[1], px[2], px[3])

    def chunk(ctype, data):
        c = ctype + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)
    with open(filename, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', zlib.compress(raw)))
        f.write(chunk(b'IEND', b''))

sizes = [20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024]
base_dir = os.path.dirname(os.path.abspath(__file__))

for s in sizes:
    write_png(os.path.join(base_dir, f'icon-{s}.png'), s, s)
    print(f'icon-{s}.png ({s}x{s})')
print('Done!')
