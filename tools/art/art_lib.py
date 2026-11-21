"""Drawing helpers shared by the art generators (tools/art/generate_*.py).

Everything is drawn at S times the final size and shrunk, so edges are smooth. Parts are masks (PIL "L" images); `lit()` turns a mask into a
bevelled, lit surface (it blurs the mask into a height map, takes its slope as a surface normal and lights it from the upper left, with a
specular glint), `outline()` / `solid()` / `paste()` / `glow()` compose them. Each generator imports what it needs from here instead of
carrying its own copy.
"""
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter
import cv2

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))

# PREVIEW_DIR: where the generators put pictures made only for people to look at (sprite sheets, previews). It is the repo's scratch folder (git-ignored),
# so nothing that is not used by the game gets checked in. Use preview_path() to build a file name in it.
PREVIEW_DIR = os.path.join(ROOT, "tmp", "art_previews")

S = 4                      # supersampling
INK = (38, 38, 48)         # the dark outline colour
LIGHT = np.array([-0.55, -0.65, 0.52])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def preview_path(name):
    """The path of a look-at-only picture named `name` (the folder is made if it is missing)."""
    os.makedirs(PREVIEW_DIR, exist_ok=True)
    return os.path.join(PREVIEW_DIR, name)


def s(v):
    return int(round(v * S))


def blur(img, r):
    return img.filter(ImageFilter.GaussianBlur(r * S))


def arr(img):
    return np.asarray(img, dtype=np.float32) / 255.0


def to_img(a):
    return Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8))


def lit(mask, base, radius=6.0, bump=2.2, spec=0.35, ambient=0.55, tint=None):
    """A bevelled, lit surface for `mask` (an L image): returns RGBA. `base` is an (r,g,b) colour or a function (x,y arrays)->rgb array."""
    m = arr(mask)
    h = cv2.GaussianBlur(m, (0, 0), radius * S)      # a float blur: an 8-bit one leaves contour bands in the shading
    gy, gx = np.gradient(h)
    k = bump * radius * S
    nx, ny, nz = -gx * k, -gy * k, np.ones_like(h)
    n = np.sqrt(nx * nx + ny * ny + nz * nz)
    nx, ny, nz = nx / n, ny / n, nz / n
    lam = np.clip(nx * LIGHT[0] + ny * LIGHT[1] + nz * LIGHT[2], 0, 1)
    hh = np.array([LIGHT[0], LIGHT[1], LIGHT[2] + 1.0])
    hh = hh / np.linalg.norm(hh)
    sp = np.clip(nx * hh[0] + ny * hh[1] + nz * hh[2], 0, 1) ** 38 * spec
    if callable(base):
        yy, xx = np.mgrid[0:m.shape[0], 0:m.shape[1]]
        col = base(xx, yy)
    else:
        col = np.zeros(m.shape + (3,), np.float32) + np.array(base, np.float32)
    shade = (ambient + (1.0 - ambient) * 1.25 * lam)[..., None]
    rgb = col * shade + sp[..., None] * 255.0
    if tint is not None:
        rgb = rgb * np.array(tint)
    out = np.dstack([np.clip(rgb, 0, 255), m * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def outline(mask, width, color=INK):
    """An RGBA outline (just the ring) `width` px wide around `mask`."""
    big = mask.filter(ImageFilter.MaxFilter(max(3, s(width) // 2 * 2 + 1)))
    big = blur(big, 0.25) if width >= 1 else big
    ring = ImageChops.subtract(big, mask)
    layer = Image.new("RGBA", mask.size, color + (0,))
    layer.putalpha(ring)
    return layer


def solid(mask, color, alpha=1.0):
    layer = Image.new("RGBA", mask.size, tuple(color) + (255,))
    layer.putalpha(mask.point(lambda v: int(v * alpha)))
    return layer


def paste(base, layer, clip=None):
    if clip is not None:
        a = ImageChops.multiply(layer.getchannel("A"), clip)
        layer = layer.copy()
        layer.putalpha(a)
    base.alpha_composite(layer)


def glow(base, mask, color, radii=(2, 6, 16), strengths=(0.9, 0.6, 0.45), clip=None):
    """Bloom: blurred copies of `mask` added over `base` in `color`."""
    for r, st in zip(radii, strengths):
        g = blur(mask, r).point(lambda v, st=st: int(min(255, v * st)))
        layer = Image.new("RGBA", mask.size, color + (255,))
        layer.putalpha(g)
        paste(base, layer, clip)


def gradient_x(x0, x1, stops):
    """A colour function: horizontal gradient between x0..x1 (final px) through `stops` [(t, rgb), ...]."""
    ts = np.array([t for t, _ in stops], np.float32)
    cs = np.array([c for _, c in stops], np.float32)

    def fn(xx, yy):
        t = np.clip((xx / S - x0) / (x1 - x0), 0, 1)
        return np.stack([np.interp(t, ts, cs[:, i]) for i in range(3)], -1)
    return fn


def gradient_y(y0, y1, stops):
    ts = np.array([t for t, _ in stops], np.float32)
    cs = np.array([c for _, c in stops], np.float32)

    def fn(xx, yy):
        t = np.clip((yy / S - y0) / (y1 - y0), 0, 1)
        return np.stack([np.interp(t, ts, cs[:, i]) for i in range(3)], -1)
    return fn


def poly_mask(points, size):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).polygon([(x, y) for x, y in points], fill=255)
    return m


def rrect_mask(size, box, r):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle(box, radius=r, fill=255)
    return m


# ----------------------------------------------------------------------------------------------------------------------
# shapes at the supersampled size: a picture is drawn as masks of `w x h` final pixels (coordinates are final pixels), lit with part() and shrunk with finish()
# ----------------------------------------------------------------------------------------------------------------------
def mk(w, h):
    return Image.new("L", (w * S, h * S), 0)


def P(x, y):
    return (x * S, y * S)


def pl(points):
    return [P(x, y) for x, y in points]


def poly(m, points, v=255):
    ImageDraw.Draw(m).polygon(pl(points), fill=v)
    return m


def rr(m, box, r, v=255):
    x0, y0, x1, y1 = box
    ImageDraw.Draw(m).rounded_rectangle([P(x0, y0), P(x1, y1)], radius=r * S, fill=v)
    return m


def ell(m, cx, cy, rx, ry=None, v=255):
    ry = rx if ry is None else ry
    ImageDraw.Draw(m).ellipse([P(cx - rx, cy - ry), P(cx + rx, cy + ry)], fill=v)
    return m


def line(m, a, b, width, v=255):
    ImageDraw.Draw(m).line([P(*a), P(*b)], fill=v, width=max(1, int(width * S)))
    return m


def vgrad(y0, y1, top, bottom):
    def fn(xx, yy):
        t = np.clip((yy / S - y0) / max(1e-6, (y1 - y0)), 0, 1)[..., None]
        return np.array(top, np.float32) * (1 - t) + np.array(bottom, np.float32) * t
    return fn


def part(canvas, m, base, outline_w=1.1, **kw):
    """Light the mask `m` with `base` (colour or function) and paste it with a dark outline."""
    kw.setdefault("radius", 2.4)
    kw.setdefault("bump", 2.0)
    canvas.alpha_composite(lit(m, base, **kw))
    if outline_w:
        canvas.alpha_composite(outline(m, outline_w))


def finish(canvas, path):
    w, h = canvas.size[0] // S, canvas.size[1] // S
    out = canvas.resize((w, h), Image.LANCZOS)
    out.save(path)
    return out


def inside(m, clip):
    return ImageChops.multiply(m, clip)
