"""Tiny software renderer for map previews (flat shading + numpy z-buffer).

Usage:
  python3 tools/preview/render.py build/parts.json out.png camX camY camZ lookX lookY lookZ [fov]

Cylinders and balls are approximated with polygons. It is only meant to sanity
check layout/colours without opening Roblox Studio.
"""
import json
import math
import sys

import numpy as np
from PIL import Image

W, H = 1600, 900


def norm(v):
    m = math.sqrt(sum(x * x for x in v)) or 1
    return [x / m for x in v]


def cross(a, b):
    return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def sub(a, b):
    return [x - y for x, y in zip(a, b)]


def part_faces(prt):
    p, r, u, l, s = prt["p"], prt["r"], prt["u"], prt["l"], prt["s"]
    back = [-x for x in l]  # +Z axis of the part
    hx, hy, hz = s[0] / 2, s[1] / 2, s[2] / 2
    sh = prt["sh"]
    faces = []

    def pt(a, b, c):
        return [p[i] + r[i] * a + u[i] * b + back[i] * c for i in range(3)]

    if sh == "Cylinder":
        n = 16
        rad = min(hy, hz)

        def ring(x):
            return [pt(x, rad * math.cos(2 * math.pi * k / n), rad * math.sin(2 * math.pi * k / n)) for k in range(n)]

        a, b = ring(-hx), ring(hx)
        faces.append((a[::-1], [-x for x in r]))
        faces.append((b, r))
        for k in range(n):
            k2 = (k + 1) % n
            ang = 2 * math.pi * (k + 0.5) / n
            nrm = [u[i] * math.cos(ang) + back[i] * math.sin(ang) for i in range(3)]
            faces.append(([a[k], a[k2], b[k2], b[k]], nrm))
    elif sh == "Ball":
        n, m = 12, 6
        for k in range(n):
            for j in range(m):
                t0 = math.pi * j / m - math.pi / 2
                t1 = math.pi * (j + 1) / m - math.pi / 2
                a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n

                def sp(t, a):
                    return pt(hx * math.cos(t) * math.cos(a), hy * math.sin(t), hz * math.cos(t) * math.sin(a))

                quad = [sp(t0, a0), sp(t1, a0), sp(t1, a1), sp(t0, a1)]
                tm, am = (t0 + t1) / 2, (a0 + a1) / 2
                nrm = [
                    r[i] * math.cos(tm) * math.cos(am) + u[i] * math.sin(tm) + back[i] * math.cos(tm) * math.sin(am)
                    for i in range(3)
                ]
                faces.append((quad, nrm))
    elif sh == "Wedge":
        # Roblox wedge: full face at back (+Z) bottom, slope from top-back to bottom-front
        A = pt(-hx, -hy, -hz)
        B = pt(hx, -hy, -hz)
        C = pt(hx, -hy, hz)
        D = pt(-hx, -hy, hz)
        E = pt(-hx, hy, hz)
        F = pt(hx, hy, hz)
        slope_n = norm([u[i] * hz - back[i] * hy for i in range(3)])
        faces.append(([A, B, C, D][::-1], [-x for x in u]))
        faces.append(([D, C, F, E], back))
        faces.append(([A, E, F, B], slope_n))
        faces.append(([A, D, E], [-x for x in r]))
        faces.append(([B, F, C], r))
    else:
        def c(sx, sy, sz):
            return pt(sx * hx, sy * hy, sz * hz)

        faces = [
            ([c(1, -1, -1), c(1, 1, -1), c(1, 1, 1), c(1, -1, 1)], r),
            ([c(-1, -1, 1), c(-1, 1, 1), c(-1, 1, -1), c(-1, -1, -1)], [-x for x in r]),
            ([c(-1, 1, -1), c(-1, 1, 1), c(1, 1, 1), c(1, 1, -1)], u),
            ([c(-1, -1, 1), c(-1, -1, -1), c(1, -1, -1), c(1, -1, 1)], [-x for x in u]),
            ([c(-1, -1, 1), c(1, -1, 1), c(1, 1, 1), c(-1, 1, 1)], back),
            ([c(1, -1, -1), c(-1, -1, -1), c(-1, 1, -1), c(1, 1, -1)], l),
        ]
    return faces


def render(parts, cam, look, fov, out):
    fwd = norm(sub(look, cam))
    right = norm(cross(fwd, [0, 1, 0]))
    up = cross(right, fwd)
    f = (H / 2) / math.tan(math.radians(fov) / 2)
    sun = norm([0.35, 0.85, -0.4])

    NEAR = 0.5

    def to_view(v):
        d = sub(v, cam)
        return (dot(d, right), dot(d, up), dot(d, fwd))

    def clip(poly):
        # Sutherland-Hodgman against the near plane z >= NEAR
        out = []
        n = len(poly)
        for i in range(n):
            a, b = poly[i], poly[(i + 1) % n]
            ina, inb = a[2] >= NEAR, b[2] >= NEAR
            if ina:
                out.append(a)
            if ina != inb:
                t = (NEAR - a[2]) / (b[2] - a[2])
                out.append(tuple(a[k] + (b[k] - a[k]) * t for k in range(3)))
        return out

    polys = []
    for prt in parts:
        col = prt["c"]
        neon = prt["m"] == "Neon"
        alpha = 1 - prt["t"]
        if prt["m"] == "ForceField":
            alpha = min(alpha, 0.45)
        if prt["m"] == "Glass":
            alpha = min(alpha, 0.8)
        for verts, nrm in part_faces(prt):
            center = [sum(v[i] for v in verts) / len(verts) for i in range(3)]
            if dot(nrm, sub(cam, center)) <= 0:
                continue
            view = clip([to_view(v) for v in verts])
            if len(view) < 3:
                continue
            pts = [(W / 2 + x / z * f, H / 2 - y / z * f) for x, y, z in view]
            zs = [z for _, _, z in view]
            depth = sum(zs) / len(zs)
            light = 1.0 if neon else 0.55 + 0.45 * max(0, dot(norm(nrm), sun))
            haze = min(0.5, depth / 3000)
            rgb = [min(1, x * light) * (1 - haze) + h * haze for x, h in zip(col, (0.78, 0.86, 1.0))]
            polys.append((depth, pts, rgb, alpha, zs))

    zbuf = np.zeros((H, W), dtype=np.float32)  # 1/z, bigger = closer
    img = np.zeros((H, W, 3), dtype=np.float32)
    t = np.linspace(0, 1, H, dtype=np.float32)[:, None]
    img[:, :, 0] = (110 + 90 * t) / 255
    img[:, :, 1] = (170 + 60 * t) / 255
    img[:, :, 2] = 1.0
    ys_all, xs_all = np.mgrid[0:H, 0:W].astype(np.float32)

    def raster(tri, invz, rgb, alpha, write_z):
        (x0, y0), (x1, y1), (x2, y2) = tri
        minx = max(int(min(x0, x1, x2)), 0)
        maxx = min(int(max(x0, x1, x2)) + 1, W)
        miny = max(int(min(y0, y1, y2)), 0)
        maxy = min(int(max(y0, y1, y2)) + 1, H)
        if minx >= maxx or miny >= maxy:
            return
        area = (x1 - x0) * (y2 - y0) - (x2 - x0) * (y1 - y0)
        if abs(area) < 1e-7:
            return
        xs = xs_all[miny:maxy, minx:maxx] + 0.5
        ys = ys_all[miny:maxy, minx:maxx] + 0.5
        w0 = ((x1 - xs) * (y2 - ys) - (x2 - xs) * (y1 - ys)) / area
        w1 = ((x2 - xs) * (y0 - ys) - (x0 - xs) * (y2 - ys)) / area
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-5) & (w1 >= -1e-5) & (w2 >= -1e-5)
        if not inside.any():
            return
        iz = w0 * invz[0] + w1 * invz[1] + w2 * invz[2]
        zb = zbuf[miny:maxy, minx:maxx]
        vis = inside & (iz > zb * 1.0001)
        if not vis.any():
            return
        region = img[miny:maxy, minx:maxx]
        col = np.array(rgb, dtype=np.float32)
        if alpha >= 0.999:
            region[vis] = col
        else:
            region[vis] = region[vis] * (1 - alpha) + col * alpha
        if write_z:
            zb[vis] = iz[vis]

    opaque = [q for q in polys if q[3] >= 0.999]
    trans = sorted([q for q in polys if q[3] < 0.999], key=lambda q: -q[0])
    for group, write in ((opaque, True), (trans, False)):
        for _depth, pts, rgb, alpha, zs in group:
            for k in range(1, len(pts) - 1):
                raster((pts[0], pts[k], pts[k + 1]), (1 / zs[0], 1 / zs[k], 1 / zs[k + 1]), rgb, alpha, write)
    Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(out)
    print("rendered", len(polys), "faces ->", out)


def main():
    parts = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    cam = [float(x) for x in sys.argv[3:6]]
    look = [float(x) for x in sys.argv[6:9]]
    fov = float(sys.argv[9]) if len(sys.argv) > 9 else 70
    render(parts, cam, look, fov, out)


if __name__ == "__main__":
    main()
