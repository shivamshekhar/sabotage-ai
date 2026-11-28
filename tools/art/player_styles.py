"""The pieces of the four themed outfits (painter, rocker, tropical, masked ninja) for tools/art/generate_player.py: the hairstyles beret, mohawk, slick and swept, the face gear
shades and mask_band, the tops smock, vest, aloha and shinobi, the gloves stained, studded and guards, the pants splattered, ripped, slacks and wrapped, the boots work, combat
and sandals. Each piece is a function that draws one frame's picture of its part at the big size, found from the frame's parts exactly as the original styles are (see
generate_player.py); `add_styles()` puts them all in the dictionary of a frame's other styles.

The generator hands its own drawing helpers over with `bind()` (this module cannot import it: the generator runs as the main script, so an import would load a second copy).
All sizes are px of the final picture, as in the generator. Each piece is drawn in the colours of the original part it replaces (hair auburn, shirt green, pants blue, boots brown,
gloves slate, goggles yellow), so the wardrobe can recolour it (WardrobeCatalog.recolor); a detail that must keep its colour (a paint splash, a stud, a bandage) is drawn in a colour
the recolouring does not touch (see WardrobeCatalog.RULES: the hue and saturation windows).
"""
import numpy as np
from PIL import ImageChops, ImageFilter

_BOUND = ("S", "W", "H", "mk", "poly", "ell", "rr", "to_l", "put", "strokes", "curve_pts", "blank", "cut", "components",
          "HAIR", "HAIR_SHADE", "HAIR_DARK", "HAIR_LIGHT", "SKIN", "STRAP", "STRAP_DARK", "STEEL_DARK", "GLOVE", "GLOVE_DARK", "SHIRT_DARK", "SHIRT_LIGHT", "PANTS_SHADE", "SOLE",
          "CYAN_LIGHT", "WRIST_FROM", "WRIST_TO", "JAW_BELOW_EYES", "torso_long", "detail_torso")


def bind(module):
    """Take the generator's helpers and colours (the names in _BOUND) into this module."""
    for name in _BOUND:
        globals()[name] = getattr(module, name)


# ----------------------------------------------------------------------------------------------------------------------
# colours that the wardrobe's recolouring leaves alone (their hue or saturation is outside the windows of WardrobeCatalog.RULES)
# ----------------------------------------------------------------------------------------------------------------------
RED_PAINT = (226, 48, 58)
BLUE_PAINT = (52, 120, 235)
YELLOW_PAINT = (255, 214, 40)
SPLASH_COLORS = (RED_PAINT, BLUE_PAINT, YELLOW_PAINT)
WHITE = (244, 246, 250)
METAL = (214, 220, 234)                 # studs, buckles and plates: pale and nearly grey, so no recolouring touches them
METAL_DARK = (120, 128, 150)
PLATE = (172, 176, 188)                 # a guard's plate: a mid grey with almost no colour in it
NAVY = (36, 50, 96)
NAVY_LIGHT = (74, 92, 150)
VEST_OLIVE = (92, 118, 72)
VEST_OLIVE_DARK = (64, 86, 52)
VEST_OLIVE_LIGHT = (128, 156, 100)
BANDAGE = (236, 232, 218)
BANDAGE_SHADE = (196, 190, 172)
TAN = (176, 142, 96)
TAN_DARK = (132, 104, 66)
PINK_FLOWER = (255, 120, 170)
BERET_TUFT = (92, 82, 80)
BERET_TUFT_DARK = (58, 50, 50)

# REF_FACE_WIDTH: the width (px) of the face in the standing pose. A style scales its shapes by the width of the face in the frame being drawn (a head turned away is narrower),
# between SCALE_LOWEST and SCALE_HIGHEST.
REF_FACE_WIDTH = 40.8

# BACK_SIDE / BACK_TOP: on a head seen from behind the face's sides are this far (px) inside the hair's, and its top this far under the hair's top (found by comparing the standing pose with
# the climbing one).
BACK_SIDE = 4.0
BACK_TOP = 27.0

# BACK_HEAD_RISE: how far (px) above the "top of the face" the back of the head reaches (the skull is round: its top is higher than the forehead).
BACK_HEAD_RISE = 12.0

# BACK_NAPE_EXTRA: how far (px) the round back of the head reaches below the bottom of the original hair, so it meets the neck.
BACK_NAPE_EXTRA = 2.5
SCALE_LOWEST = 0.8
SCALE_HIGHEST = 1.05

# BAND_SLOPE: how much lower (px) the ninja's headband is at the right end of the face than at the left (it is slipped down over the right eye). BAND_HEIGHT: its width (px).
BAND_SLOPE = 15.0
BAND_HEIGHT = 7.5


class Head:
    """Where the head is in a frame: the middle of the face (cx), the top of the face (top), the face's half width (half) and the scale against the standing pose (s)."""

    def __init__(self, p):
        self.back = not p.face_mask.any()
        if self.back:                                   # (seen from behind there is no face: the head is where the hair is; the top of the "face" is as far under the top of the hair as in the standing pose)
            ys, xs = np.nonzero(p.hair_mask)
            self.x0, self.x1, self.top = xs.min() / S + BACK_SIDE, xs.max() / S - BACK_SIDE, ys.min() / S + BACK_TOP
            self.nape = ys.max() / S
        else:
            ys, xs = np.nonzero(p.face_mask)
            self.x0, self.x1, self.top = xs.min() / S, xs.max() / S, ys.min() / S
            self.nape = self.top + 26.0
        self.cx = (self.x0 + self.x1) / 2
        self.s = float(np.clip((self.x1 - self.x0) / REF_FACE_WIDTH, SCALE_LOWEST, SCALE_HIGHEST))
        self.half = (self.x1 - self.x0) / 2

    def at(self, dx, dy):
        """A point `dx`, `dy` px (as in the standing pose) from the middle of the top of the face."""
        return (self.cx + dx * self.s, self.top + dy * self.s)


def _head(p):
    """The Head of the frame, or None if it shows neither a face nor hair."""
    if p.face_mask.any() and len(p.eye_centres) >= 2:
        return Head(p)
    return Head(p) if (not p.face_mask.any() and p.hair_mask.any()) else None


def back_head(p):
    """The round back of the head, as a boolean array, for a frame seen from behind (empty for a frame with a face): where the generator paints the bald head's skin."""
    h = _head(p)
    if h is None or not h.back:
        return np.zeros((H * S, W * S), bool)
    return np.asarray(_back_ellipse(h, 0.0)) > 127


def _back_ellipse(h, grow_by):
    top = h.top - BACK_HEAD_RISE
    m = mk(W, H)
    bottom = h.nape + BACK_NAPE_EXTRA
    ell(m, h.cx, (top + bottom) / 2, h.half + 2.0 + grow_by, (bottom - top) / 2 + grow_by)
    return m


def _back_fill(c, h, color, strand=None):
    """From behind, the hair covers the whole round back of the head, with a few strands running down it (nothing in a front view)."""
    if h.back:
        back = _back_ellipse(h, 0.4)
        put(c, back, color)
        top = h.top - BACK_HEAD_RISE
        for k in range(-2, 3):
            put(c, strokes([curve_pts([(h.cx + k * 1.5, top + 3.0), (h.cx + k * 5.0, (top + h.nape) / 2), (h.cx + k * 6.5, h.nape - 2.0)])], 0.8), strand or HAIR_DARK, clip=back, alpha=0.7)


def _dot(c, x, y, r, color, clip=None):
    m = mk(W, H)
    ell(m, x, y, r)
    put(c, m, color, clip=clip)


def _rect(c, box, radius, color, clip=None, alpha=1.0):
    m = mk(W, H)
    rr(m, box, radius)
    put(c, m, color, clip=clip, alpha=alpha)


def _above(h, y):
    """A mask of everything higher than `y` px below the top of the face."""
    m = mk(W, H)
    poly(m, [h.at(-80, -90), h.at(80, -90), h.at(80, y), h.at(-80, y)])
    return m


# ----------------------------------------------------------------------------------------------------------------------
# hair
# ----------------------------------------------------------------------------------------------------------------------
def hair_mohawk(p):
    """A rocker's mohawk: a crest of five tall spikes down the middle of the head, the sides shaved (a faint shadow of stubble). None if the frame has no face."""
    h = _head(p)
    if h is None:
        return None
    c = blank()
    crest = mk(W, H)
    half = 10.0
    tips = [(-7.0, -22), (-3.5, -29), (0.0, -34), (3.5, -29), (7.0, -22)]       # (the tips of the five spikes, the middle one the tallest)
    pts = [h.at(-half, -2)]
    for k, (dx, dy) in enumerate(tips):
        pts.append(h.at(dx - 1.5, dy))
        if k < len(tips) - 1:
            pts.append(h.at((dx + tips[k + 1][0]) / 2 - 1.0, -10))
    pts += [h.at(half, -2), (h.cx + half * h.s, (h.nape - 1.0) if h.back else h.top + 4 * h.s), (h.cx - half * h.s, (h.nape - 1.0) if h.back else h.top + 4 * h.s)]
    poly(crest, pts)
    cap = mk(W, H)
    ell(cap, h.cx, h.top + 3.0, h.half + 1.5, 0.42 * 2 * h.half + 1.0)
    if not h.back:
        put(c, ImageChops.multiply(ImageChops.subtract(cap, crest), _above(h, 0.5)), HAIR_SHADE, alpha=0.28)
    put(c, crest, HAIR)
    for dx in (-4.0, 0.0, 4.0):
        put(c, strokes([[h.at(dx - 1.0, 1), h.at(dx - 1.5, -12)]], 0.8), HAIR_DARK, clip=crest, alpha=0.8)
    put(c, strokes([[h.at(-5.5, -4), h.at(-4.5, -17)]], 1.2), HAIR_LIGHT, clip=crest, alpha=0.8)
    return c


def hair_beret(p):
    """A painter's beret: a flat round cap tilted over one side of the head with a small stalk on top, and a little hair at the sides. None if the frame has no face."""
    h = _head(p)
    if h is None:
        return None
    c = blank()
    tufts = mk(W, H)
    edge = h.half / h.s
    for side in (-1, 1):
        poly(tufts, [h.at(side * (edge + 0.5), 2), h.at(side * (edge - 3.5), 1), h.at(side * (edge - 1.0), 14), h.at(side * (edge + 1.0), 12)])
    put(c, tufts, BERET_TUFT)
    _back_fill(c, h, BERET_TUFT, BERET_TUFT_DARK)
    dome = mk(W, H)
    ell(dome, h.cx + 3.0 * h.s, h.top - 4.0 * h.s, h.half + 6.0 * h.s, 13.5 * h.s)
    dome = ImageChops.multiply(dome, _above(h, 3.5))
    put(c, dome, HAIR)
    shade = mk(W, H)
    ell(shade, h.cx + 7.0 * h.s, h.top - 1.0 * h.s, h.half + 4.0 * h.s, 9.0 * h.s)
    put(c, ImageChops.multiply(shade, dome), HAIR_DARK, alpha=0.5)
    put(c, strokes([curve_pts([h.at(-14, -9), h.at(-4, -15), h.at(8, -15.5)])], 1.6), HAIR_LIGHT, clip=dome, alpha=0.8)
    band = mk(W, H)
    poly(band, [h.at(-edge - 5, 0.6), h.at(edge + 9, 0.6), h.at(edge + 9, 3.6), h.at(-edge - 5, 3.6)])
    put(c, band, HAIR_DARK, clip=dome)
    _rect(c, (h.cx + 5.5 * h.s, h.top - 20.5 * h.s, h.cx + 9.0 * h.s, h.top - 16.0 * h.s), 0.8, HAIR_DARK)
    return c


def hair_slick(p):
    """Short hair brushed back with a lifted front: a low dome with a rise over the forehead (to the right, where the hero faces) and combed lines running back. None if the frame has no face."""
    h = _head(p)
    if h is None:
        return None
    c = blank()
    dome = mk(W, H)
    ell(dome, h.cx - 2.0 * h.s, h.top + 3.0 * h.s, h.half + 2.5 * h.s, 16.5 * h.s)
    ell(dome, h.cx + 6.0 * h.s, h.top - 5.0 * h.s, 15.0 * h.s, 11.0 * h.s)
    keep = mk(W, H)
    poly(keep, [h.at(-80, -90), h.at(80, -90), h.at(80, 2.5), h.at(-80, 5.5)])
    dome = ImageChops.multiply(dome, keep)
    for side in (-1, 1):
        sideburn = mk(W, H)
        x = h.cx + side * (h.half + 1.6 * h.s)
        rr(sideburn, (x - 1.6, h.top, x + 1.6, h.top + 10.0 * h.s), 0.8)
        dome = ImageChops.lighter(dome, sideburn)
    _back_fill(c, h, HAIR)
    put(c, dome, HAIR)
    for k in range(6):
        y = -2 - k * 2.6
        put(c, strokes([curve_pts([h.at(22 - k * 1.8, y + 6), h.at(8, y + 1), h.at(-16, y + 1.5)])], 0.7), HAIR_DARK, clip=dome, alpha=0.7)
    put(c, strokes([curve_pts([h.at(16, -12), h.at(4, -16.5), h.at(-10, -13)])], 1.5), HAIR_LIGHT, clip=dome, alpha=0.8)
    return c


def hair_swept(p):
    """Long spikes swept up and back (to the left), over a snug cap: wild, but combed one way. None if the frame has no face."""
    h = _head(p)
    if h is None:
        return None
    c = blank()
    cap = mk(W, H)
    ell(cap, h.cx - 1.0 * h.s, h.top + 3.0 * h.s, h.half + 2.5 * h.s, 15.0 * h.s)
    cap = ImageChops.multiply(cap, _above(h, 6.0))
    for side in (-1, 1):
        sideburn = mk(W, H)
        x = h.cx + side * (h.half + 2.0 * h.s)
        rr(sideburn, (x - 2.2, h.top, x + 2.2, h.top + 13.0 * h.s), 1.0)
        cap = ImageChops.lighter(cap, sideburn)
    spikes = mk(W, H)
    layout = [(15, -4, (7, -20)), (10, -6, (0, -25)), (4, -8, (-8, -27)), (-2, -8, (-15, -25)), (-8, -7, (-21, -19)), (-13, -4, (-24, -10)), (-17, 0, (-26, -1))]
    for bx, by, (tx, ty) in layout:
        poly(spikes, [h.at(bx - 4.5, by + 4), h.at(bx + 4.5, by + 2), h.at(tx, ty)])
    hair = ImageChops.lighter(cap, spikes)
    _back_fill(c, h, HAIR)
    put(c, hair, HAIR)
    for bx, by, (tx, ty) in layout:
        put(c, strokes([curve_pts([h.at(bx, by + 2), h.at((bx + tx) / 2 + 0.5, (by + ty) / 2), h.at(tx * 0.92 + bx * 0.08, ty * 0.9 + by * 0.1)])], 0.7), HAIR_DARK, clip=hair, alpha=0.8)
    put(c, strokes([curve_pts([h.at(10, -6), h.at(-3, -15), h.at(-14, -17)])], 1.5), HAIR_LIGHT, clip=hair, alpha=0.8)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# face gear (the goggles slot)
# ----------------------------------------------------------------------------------------------------------------------
def face_shades(p):
    """Dark sunglasses: two wide lenses with a bridge and arms, and a glint on each. None if the frame has no face."""
    if not (p.face and len(p.eye_centres) >= 2):
        return None
    (lx, ly), (rx, ry) = p.eye_centres[0], p.eye_centres[-1]
    c = blank()
    for ex, ey in ((lx, ly), (rx, ry)):
        _rect(c, (ex - 8.4, ey - 5.6, ex + 8.4, ey + 5.8), 3.2, STRAP_DARK)
        _rect(c, (ex - 7.2, ey - 4.6, ex + 7.2, ey + 4.8), 2.6, (18, 22, 36))
        put(c, strokes([[(ex - 5.6, ey - 2.4), (ex - 1.8, ey - 3.4)]], 0.9), CYAN_LIGHT, alpha=0.85)
    put(c, strokes([[(lx + 8.0, ly - 1.8), (rx - 8.0, ry - 1.8)]], 1.2), STRAP_DARK)
    put(c, strokes([[(lx - 8.0, ly - 1.0), (lx - 12.5, ly - 2.0)], [(rx + 8.0, ry - 1.0), (rx + 11.5, ry - 2.0)]], 1.0), STRAP_DARK)
    return c


def face_mask_and_band(p):
    """A masked ninja's face gear: a cloth mask over the lower half of the face and a headband across the forehead, slipped down over the right eye, with a metal plate."""
    if not (p.face and len(p.eye_centres) >= 2):
        return None
    (lx, ly), (rx, ry) = p.eye_centres[0], p.eye_centres[-1]
    ys, xs = np.nonzero(p.face_mask)
    x0, x1 = xs.min() / S, xs.max() / S
    jaw = p.eyes[0].cy + JAW_BELOW_EYES
    span = max(1.0, x1 - x0)
    c = blank()
    mask_top = min(ly, ry) + 3.0
    _rect(c, (x0 - 0.5, mask_top, x1 + 0.5, jaw), 0.4, NAVY)
    put(c, strokes([[(x0 + 1, mask_top + 1.0), (x1 - 1, mask_top + 1.0)]], 0.9), NAVY_LIGHT, alpha=0.9)

    def centre(x):                                                       # (the middle of the band at x)
        return ly - 12.5 + (x - x0) / span * BAND_SLOPE

    band = mk(W, H)
    poly(band, [(x0 - 2.0, centre(x0 - 2.0) - BAND_HEIGHT / 2), (x1 + 2.0, centre(x1 + 2.0) - BAND_HEIGHT / 2), (x1 + 2.0, centre(x1 + 2.0) + BAND_HEIGHT / 2),
                (x0 - 2.0, centre(x0 - 2.0) + BAND_HEIGHT / 2)])
    put(c, band, NAVY)
    put(c, strokes([[(x0 - 2.0, centre(x0 - 2.0) - BAND_HEIGHT / 2 + 0.6), (x1 + 2.0, centre(x1 + 2.0) - BAND_HEIGHT / 2 + 0.6)]], 0.8), NAVY_LIGHT, alpha=0.9)
    px = x0 + span * 0.38
    _rect(c, (px - 8.0, centre(px) - 3.7, px + 8.0, centre(px) + 3.9), 1.0, STEEL_DARK)
    _rect(c, (px - 7.0, centre(px) - 2.8, px + 7.0, centre(px) + 3.0), 0.8, METAL)
    put(c, strokes([[(px - 3.8, centre(px) + 0.2), (px + 0.4, centre(px) + 0.2), (px + 3.8, centre(px) - 1.6)], [(px + 0.4, centre(px) + 0.2), (px + 0.4, centre(px) + 2.0)]], 0.7), STEEL_DARK)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# helpers for the clothes
# ----------------------------------------------------------------------------------------------------------------------
def _main_piece(p):
    pieces = components(p.shirt, 30)
    return pieces[0] if pieces else None


def _spot(box, u, v):
    """The point a fraction `u` across and `v` down a box (x0, y0, x1, y1)."""
    return (box[0] + (box[2] - box[0]) * u, box[1] + (box[3] - box[1]) * v)


def _splash(c, clip, box, spots):
    """Paint splashes over `clip`: each spot (u, v, radius, colour number) is a blob with a droplet beside it, placed by fractions of `box` so it moves with the body."""
    for u, v, radius, which in spots:
        x, y = _spot(box, u, v)
        blob = mk(W, H)
        ell(blob, x, y, radius, radius * 0.8)
        ell(blob, x + radius * 1.0, y - radius * 0.5, radius * 0.45)
        put(c, blob, SPLASH_COLORS[which % len(SPLASH_COLORS)], clip=clip)


# ----------------------------------------------------------------------------------------------------------------------
# tops
# ----------------------------------------------------------------------------------------------------------------------
def torso_smock(p, content):
    """A painter's smock: the tee in a light colour with big paint splashes and two straps of the apron crossing the chest. A paint brush pokes out of the chest."""
    main = _main_piece(p)
    if main is None:
        return None
    c = content["torso"].copy()
    body = to_l(p.shirt)
    _splash(c, to_l(p.shirt | p.sleeve), main.box, [(0.20, 0.30, 2.4, 0), (0.72, 0.22, 1.8, 1), (0.82, 0.60, 2.2, 2), (0.30, 0.66, 1.6, 1), (0.52, 0.82, 1.4, 0)])
    if p.face and p.neck_piece:
        n = p.neck_piece
        for side in (-1, 1):
            put(c, strokes([[(n.cx + side * 6.0, n.box[3] - 1.5), (main.box[0] + (main.box[2] - main.box[0]) * (0.5 + side * 0.22), main.box[3] - 1.0)]], 1.1), TAN_DARK, clip=body)
    return c


def torso_vest(p, up, masks):
    """A rocker's leather vest: sleeveless and open at the chest, with studs down the opening, a zip and a stitched hem."""
    main = _main_piece(p)
    if main is None:
        return None
    c = cut(up, masks["torso"] & ~p.sleeve)
    detail_torso(c, p, "tank")
    body = to_l(p.shirt)
    if p.face and p.neck_piece:
        n = p.neck_piece
        cx, bottom = n.cx, n.box[3]
        opening = mk(W, H)
        poly(opening, [(cx - 7.0, bottom - 1.5), (cx + 7.0, bottom - 1.5), (cx + 1.0, bottom + 13.0), (cx - 1.0, bottom + 13.0)])
        put(c, opening, SKIN, clip=body)
        for side in (-1, 1):
            put(c, strokes([[(cx + side * 7.0, bottom - 1.5), (cx + side * 1.0, bottom + 13.0)]], 0.9), SHIRT_DARK, clip=body)
            for k in range(4):
                f = (k + 0.6) / 4
                _dot(c, cx + side * (7.0 - 6.0 * f) - side * 0.3, bottom - 1.5 + 14.5 * f, 0.8, METAL, clip=body)
        put(c, strokes([[(cx, bottom + 13.0), (cx, main.box[3] - 1.2)]], 0.9), METAL, clip=body)
    for u in (0.10, 0.90):
        for k in range(3):
            x, y = _spot(main.box, u, 0.12 + 0.13 * k)
            _dot(c, x, y, 0.8, METAL, clip=body)
    put(c, strokes([[(main.box[0] + 1, main.box[3] - 1.6), (main.box[2] - 1, main.box[3] - 1.6)]], 0.6), SHIRT_LIGHT, clip=body, alpha=0.55)
    return c


def torso_aloha(p, content):
    """A tropical shirt: the short-sleeved tee worn open over a white undershirt, with big collar flaps and pink flowers printed on it."""
    main = _main_piece(p)
    if main is None:
        return None
    c = content["torso"].copy()
    shirt = to_l(p.shirt | p.sleeve)
    if p.face and p.neck_piece:
        n = p.neck_piece
        cx, bottom = n.cx, n.box[3]
        under = mk(W, H)
        poly(under, [(cx - 7.0, bottom - 1.5), (cx + 7.0, bottom - 1.5), (cx + 3.0, main.box[3] - 1.0), (cx - 3.0, main.box[3] - 1.0)])
        put(c, under, WHITE, clip=to_l(p.shirt))
        put(c, strokes([[(cx - 7.0, bottom - 1.5), (cx - 3.0, main.box[3] - 1.0)], [(cx + 7.0, bottom - 1.5), (cx + 3.0, main.box[3] - 1.0)]], 0.9), SHIRT_DARK, clip=shirt)
        for side in (-1, 1):
            flap = mk(W, H)
            poly(flap, [(cx + side * 6.0, bottom - 2.5), (cx + side * 13.0, bottom - 2.5), (cx + side * 8.0, bottom + 5.5)])
            put(c, flap, SHIRT_LIGHT, clip=shirt)
            put(c, strokes([[(cx + side * 13.0, bottom - 2.5), (cx + side * 8.0, bottom + 5.5), (cx + side * 4.5, bottom - 1.5)]], 0.7), SHIRT_DARK, clip=shirt)
    for u, v in ((0.15, 0.38), (0.34, 0.74), (0.76, 0.42), (0.86, 0.80), (0.58, 0.90)):
        x, y = _spot(main.box, u, v)
        for k in range(5):
            a = k * 2 * np.pi / 5
            _dot(c, x + 1.3 * np.cos(a), y + 1.3 * np.sin(a), 1.0, PINK_FLOWER, clip=shirt)
        _dot(c, x, y, 0.9, YELLOW_PAINT, clip=shirt)
    return c


def torso_shinobi(p, content):
    """A shinobi's top: a long-sleeved shirt with a flak vest over it: two pockets on the chest, a zip down the middle and a high collar."""
    main = _main_piece(p)
    if main is None:
        return None
    c = torso_long(content["torso"], p)
    x0, y0, x1, y1 = main.box
    body = to_l(main.mask)
    _rect(c, (x0 + 1.5, y0, x1 - 1.5, y1), 0.4, VEST_OLIVE, clip=body)
    put(c, strokes([[(x0 + 2, y0 + 1.5), (x1 - 2, y0 + 1.5)]], 1.0), VEST_OLIVE_LIGHT, clip=body, alpha=0.9)
    put(c, strokes([[(x0 + 1.0, y1 - 1.0), (x1 - 1.0, y1 - 1.0)]], 1.2), VEST_OLIVE_DARK, clip=body)
    cx = (x0 + x1) / 2
    if p.face and p.neck_piece:
        n = p.neck_piece
        cx = n.cx
        opening = mk(W, H)
        poly(opening, [(cx - 5.5, n.box[3] - 1.5), (cx + 5.5, n.box[3] - 1.5), (cx + 0.8, n.box[3] + 6.5), (cx - 0.8, n.box[3] + 6.5)])
        put(c, opening, NAVY, clip=body)
    put(c, strokes([[(cx, (y0 + y1) / 2 - 2), (cx, y1 - 1.0)]], 0.9), VEST_OLIVE_DARK, clip=body)
    for side in (-1, 1):
        px, py = _spot(main.box, 0.5 + side * 0.24, 0.62)
        _rect(c, (px - 4.4, py - 3.4, px + 4.4, py + 3.4), 0.7, VEST_OLIVE_DARK, clip=body)
        _rect(c, (px - 4.4, py - 3.4, px + 4.4, py - 0.8), 0.5, VEST_OLIVE_LIGHT, clip=body)
        _dot(c, px, py + 0.4, 0.7, STRAP, clip=body)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# gloves
# ----------------------------------------------------------------------------------------------------------------------
def _fingertip_direction(p, piece):
    """The unit vector from the middle of a hand towards its fingers (away from the sleeve), and the one across it."""
    ys, xs = np.nonzero(piece.mask)
    reach = np.where(np.isfinite(p.along_arm[ys, xs]), p.along_arm[ys, xs], -1.0)
    far = np.array([xs[np.argmax(reach)], ys[np.argmax(reach)]]) / S
    direction = far - np.array([piece.cx, piece.cy])
    n = np.linalg.norm(direction)
    direction = direction / n if n > 1e-3 else np.array([0.0, 1.0])
    return direction, np.array([-direction[1], direction[0]])


def gloves_stained(p):
    """Bare hands smeared with paint: the skin of the hands and wrists with red, blue and yellow dabs. None if the frame has no hands."""
    hands = p.hands | p.wrists
    if not hands.any():
        return None
    c = blank()
    put(c, to_l(hands), SKIN)
    for piece in p.hand_pieces:
        _splash(c, to_l(hands), piece.box, [(0.30, 0.35, 1.8, 0), (0.70, 0.65, 1.6, 1), (0.50, 0.85, 1.2, 2)])
    return c


def gloves_studded(p):
    """A rocker's gloves: fingerless leather with a stud on every knuckle and a spiked cuff. None if the frame has no hands."""
    hands = p.hands | p.wrists
    if not hands.any():
        return None
    c = blank()
    put(c, to_l(p.hands), GLOVE)
    put(c, to_l(p.wrists), GLOVE_DARK)
    for piece in p.hand_pieces:
        direction, side = _fingertip_direction(p, piece)
        base = np.array([piece.cx, piece.cy]) + direction * 2.4
        for k in (-1, 0, 1):
            a = base + side * 3.2 * k
            _dot(c, a[0], a[1], 1.0, METAL, clip=to_l(piece.mask))
    cuff = p.arm_skin & (p.along_arm > WRIST_FROM - 0.5) & (p.along_arm <= WRIST_TO)
    ys, xs = np.nonzero(cuff)
    for k in range(0, len(xs), max(1, len(xs) // 3)):
        x, y = xs[k] / S, ys[k] / S
        spike = mk(W, H)
        poly(spike, [(x - 1.0, y + 0.8), (x + 1.0, y + 0.8), (x, y - 1.4)])
        put(c, spike, METAL)
    return c


def gloves_guards(p):
    """A shinobi's arm guards: dark fingerless gloves and a metal plate over the wrist and a short way up the forearm. None if the frame has no hands."""
    hands = p.hands | p.wrists
    if not hands.any():
        return None
    c = blank()
    put(c, to_l(p.hands), GLOVE)
    plate = to_l(p.arm_skin & (p.along_arm > WRIST_FROM - 2.2) & (p.along_arm <= WRIST_TO))
    put(c, plate, PLATE)
    put(c, ImageChops.subtract(plate, plate.filter(ImageFilter.MinFilter(5))), STEEL_DARK, alpha=0.9)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# pants
# ----------------------------------------------------------------------------------------------------------------------
def pants_splattered(p, plain):
    """Work trousers: the plain pants with paint splashes and a patch on each knee."""
    if plain.getchannel("A").getbbox() is None:
        return None
    c = plain.copy()
    clip = to_l(p.pants)
    for piece in p.pants_pieces:
        x0, y0, x1, y1 = piece.box
        if y1 - y0 > 14:
            _rect(c, (x0 + (x1 - x0) * 0.2, y0 + (y1 - y0) * 0.55, x0 + (x1 - x0) * 0.8, y0 + (y1 - y0) * 0.82), 0.6, PANTS_SHADE, clip=clip)
        _splash(c, clip, piece.box, [(0.30, 0.25, 1.8, 2), (0.65, 0.45, 1.6, 0), (0.40, 0.88, 1.4, 1)])
    return c


def pants_ripped(p, plain):
    """A rocker's jeans: the plain pants with a rip across each knee: a patch of skin showing through with a jagged lower edge."""
    if plain.getchannel("A").getbbox() is None:
        return None
    c = plain.copy()
    clip = to_l(p.pants)
    for piece in p.pants_pieces:
        x0, y0, x1, y1 = piece.box
        if y1 - y0 < 18:
            continue
        ry = y0 + (y1 - y0) * 0.45
        left, right = x0 + (x1 - x0) * 0.28, x0 + (x1 - x0) * 0.72
        teeth = 4
        edge = [(left + (right - left) * k / teeth, ry + 2.6 - (k % 2) * 1.2) for k in range(teeth + 1)]
        rip = mk(W, H)
        poly(rip, [(left, ry), (right, ry - 0.5)] + edge[::-1])
        put(c, rip, SKIN, clip=clip)
    return c


def pants_slacks(p, plain):
    """Pressed slacks: the plain pants with a crease down the front of each leg."""
    if plain.getchannel("A").getbbox() is None:
        return None
    c = plain.copy()
    clip = to_l(p.pants)
    for piece in p.pants_pieces:
        x0, y0, x1, y1 = piece.box
        if y1 - y0 < 12:
            continue
        mid = x0 + (x1 - x0) * 0.5
        put(c, strokes([[(mid, y0 + 3.0), (mid, y1 - 1.0)]], 0.7), PANTS_SHADE, clip=clip, alpha=0.8)
    return c


def pants_wrapped(p, plain):
    """A shinobi's trousers: the plain pants with two bandage wraps above each ankle and a weapon pouch strapped to the right thigh."""
    if plain.getchannel("A").getbbox() is None:
        return None
    c = plain.copy()
    clip = to_l(p.pants)
    for piece in p.pants_pieces:
        x0, y0, x1, y1 = piece.box
        if y1 - y0 < 12:
            continue
        for k in range(2):
            y = y1 - 6.5 + k * 2.6
            put(c, strokes([[(x0, y), (x1, y - 0.5)]], 1.5), BANDAGE, clip=clip)
            put(c, strokes([[(x0, y + 1.0), (x1, y + 0.5)]], 0.5), BANDAGE_SHADE, clip=clip, alpha=0.9)
    if p.face and p.pants_pieces:
        leg = max(p.pants_pieces, key=lambda q: q.cx)
        near_top = leg.mask & (p.from_cloth < 12)
        if near_top.sum() > 4 * S * S:
            ys, xs = np.nonzero(near_top)
            px, py = xs.mean() / S + 1.0, ys.mean() / S + 2.0
            _rect(c, (px - 3.8, py - 3.2, px + 3.8, py + 4.2), 0.8, TAN, clip=clip)
            put(c, strokes([[(px - 3.8, py - 0.4), (px + 3.8, py - 0.4)]], 0.7), TAN_DARK, clip=clip)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# boots
# ----------------------------------------------------------------------------------------------------------------------
def boots_work(p, up, masks):
    """Painter's work boots: leather with a dark top band, a heavy sole and a dab of paint on each."""
    c = cut(up, masks["boots"])
    clip = to_l(masks["boots"])
    for shoe in p.shoes:
        x0, y0, x1, y1 = shoe.box
        put(c, strokes([[(x0, y0 + 0.9), (x1, y0 + 0.9)]], 1.8), HAIR_DARK, clip=clip)
        put(c, strokes([[(x0, y1 - 1.1), (x1, y1 - 1.1)]], 1.9), SOLE, clip=clip)
        _splash(c, clip, shoe.box, [(0.30, 0.55, 1.0, 0), (0.75, 0.6, 0.9, 1)])
    return c


def boots_combat(p, up, masks):
    """A rocker's combat boots: heavy and dark, a steel toe cap, two buckled straps and a thick sole."""
    c = cut(up, masks["boots"])
    clip = to_l(masks["boots"])
    for shoe in p.shoes:
        x0, y0, x1, y1 = shoe.box
        put(c, strokes([[(x0, y1 - 1.3), (x1, y1 - 1.3)]], 2.2), SOLE, clip=clip)
        _rect(c, (x1 - 5.5, y0 + 1.0, x1 + 1.0, y1 - 2.2), 1.2, METAL_DARK, clip=clip, alpha=0.9)
        for k in range(2):
            bx = x0 + 3.0 + k * 5.5
            put(c, strokes([[(bx, y0 - 0.2), (bx, y1 - 2.4)]], 1.2), HAIR_DARK, clip=clip)
            _rect(c, (bx - 1.0, y0 + 0.4, bx + 1.0, y0 + 2.4), 0.3, METAL, clip=clip)
    return c


def boots_sandals(p, up, masks):
    """Shinobi sandals: a bandage wrap round the ankle and the toes split off at the front."""
    c = cut(up, masks["boots"])
    clip = to_l(masks["boots"])
    for shoe in p.shoes:
        x0, y0, x1, y1 = shoe.box
        put(c, strokes([[(x0, y0 + 1.0), (x1 - 4.0, y0 + 1.0)]], 1.8), BANDAGE, clip=clip)
        put(c, strokes([[(x0, y0 + 2.3), (x1 - 4.0, y0 + 2.3)]], 0.6), BANDAGE_SHADE, clip=clip, alpha=0.9)
        put(c, strokes([[(x1 - 3.5, y0 + 2.6), (x1 - 3.5, y1 - 0.8)]], 0.6), HAIR_DARK, clip=clip)
        put(c, strokes([[(x0, y1 - 1.0), (x1, y1 - 1.0)]], 1.2), SOLE, clip=clip)
    return c


# ----------------------------------------------------------------------------------------------------------------------
# putting them in a frame
# ----------------------------------------------------------------------------------------------------------------------
def add_styles(others, p, up, masks, content):
    """Add the pictures of this module's pieces to `others` (the generator's dictionary part -> {style: picture} of a frame's other styles); a piece the frame has no room for
    (a hairstyle on a back view) is left out, and the wardrobe then shows the original style's picture there."""
    plain_pants = others["pants"]["plain"]
    pieces = (("hair", "mohawk", lambda: hair_mohawk(p)), ("hair", "beret", lambda: hair_beret(p)), ("hair", "slick", lambda: hair_slick(p)), ("hair", "swept", lambda: hair_swept(p)),
              ("goggles", "shades", lambda: face_shades(p)), ("goggles", "mask_band", lambda: face_mask_and_band(p)),
              ("torso", "smock", lambda: torso_smock(p, content)), ("torso", "vest", lambda: torso_vest(p, up, masks)), ("torso", "aloha", lambda: torso_aloha(p, content)),
              ("torso", "shinobi", lambda: torso_shinobi(p, content)),
              ("gloves", "stained", lambda: gloves_stained(p)), ("gloves", "studded", lambda: gloves_studded(p)), ("gloves", "guards", lambda: gloves_guards(p)),
              ("pants", "splattered", lambda: pants_splattered(p, plain_pants)), ("pants", "ripped", lambda: pants_ripped(p, plain_pants)),
              ("pants", "slacks", lambda: pants_slacks(p, plain_pants)), ("pants", "wrapped", lambda: pants_wrapped(p, plain_pants)),
              ("boots", "work", lambda: boots_work(p, up, masks)), ("boots", "combat", lambda: boots_combat(p, up, masks)), ("boots", "sandals", lambda: boots_sandals(p, up, masks)))
    for part, style, make in pieces:
        picture = make()
        if picture is not None:
            others[part][style] = picture
