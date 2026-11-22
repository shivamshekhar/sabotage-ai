"""Draws the player's sprite sheet: the blocky Kenney character (CC0, tools/art/sources/kenney_platformer_player/) with the detail added on top, and new poses made from it.

The shapes, proportions and flat colours of the original are kept. Every frame is the original picture (or a copy of it moved, stretched or with the eyes changed) plus
details found automatically in it: strands and highlights in the hair, glints in the eyes, a collar rim, goggles hanging round the neck, a yellow stripe on the sleeves, a
belt with a power-button buckle, fingerless gloves with glowing wristbands, cargo pockets, laces and soles on the shoes, and the outlines. The details are drawn at 4 times
the size and shrunk, clipped to the original's own shapes.

The frames (each 128 x 110 px: the 80 px wide original in the middle, room at the sides for the gun; feet on the bottom edge; facing right, the game flips them):
    idle1..3    breathing (the chest and head rise a little and fall)        blink1..3   the same with the eyes shut        look   a glance up and aside
    walk1, walk2   the two original walk poses
    jump, fall, hurt, action1, action2, climb1, climb2     the original poses
    shoot       the EMP gun held out in the fist (the pose of the throw, action2)

Usage (from the repo root; needs Pillow, numpy, opencv):
    python tools/art/generate_player.py      writes
        assets/characters/saboteur/player/player_<pose>.png     the frames above
        tmp/art_previews/player_sheet.png                       every frame side by side, for looking at only
    and prints where the gun's muzzle is, to copy into PlayerSprite.GUN_MUZZLE when the shoot pose changes.
"""
import os
import sys

import cv2
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_lib  # noqa: E402
from art_lib import S, mk, poly, ell, line, solid, inside, blur  # noqa: E402

SRC = os.path.join(HERE, "sources", "kenney_platformer_player")
OUT = os.path.join(art_lib.ROOT, "assets", "characters", "saboteur", "player")
ART_W, H = 80, 110                  # the size of an original frame, in px
PAD = 24                            # the room added at each side
W = ART_W + 2 * PAD                 # the size of a frame we draw

# The colours of the original art (used to find its parts) and the colours of the details.
SKIN = (255, 224, 177)
NECK = (215, 189, 147)
SHIRT = (46, 204, 113)
SLEEVE = (37, 168, 92)
HAIR = (196, 138, 81)
HAIR_SHADE = (184, 130, 77)
PANTS = (52, 152, 219)
PANTS_SHADE = (42, 125, 180)
PUPIL = (127, 112, 88)
HAIR_DARK = (150, 100, 56)
HAIR_LIGHT = (222, 168, 108)
SHIRT_DARK = (30, 150, 86)
SHIRT_LIGHT = (96, 226, 150)
BROW = (146, 98, 54)
STRAP = (255, 198, 26)
STRAP_DARK = (206, 146, 12)
STEEL = (170, 180, 202)
STEEL_DARK = (84, 92, 114)
GLOVE = (98, 106, 130)
GLOVE_LIGHT = (130, 140, 166)
GLOVE_DARK = (38, 42, 58)
CYAN = (70, 200, 255)
CYAN_LIGHT = (214, 244, 255)
INK = (52, 40, 40)
OUTLINE = (50, 34, 40)
SOLE = (126, 84, 46)

OUTER_WIDTH = 2.0                   # the outline round the whole figure (art_lib.outline width: 2.0 is one px of the final picture)
INNER_WIDTH = 1.2                   # the thinner lines where two parts meet (hair and face, shirt and arm, ...)
INNER_ALPHA = 0.6                   # how dark those thinner lines are (0 = none, 1 = as dark as the outer one)
WRIST_FROM, WRIST_TO = 6.0, 9.0     # a wrist is the arm this far (px) along it from the sleeve; further is the hand, nearer is the upper arm
JAW_BELOW_EYES = 14.8               # the face ends this far (px) below its eyes: the flat jaw
FACE_LEFT, FACE_RIGHT = 15.5, 12.5  # and this far (px) to the left of its left pupil and to the right of its right pupil
MUZZLE = [0.0, 0.0]                 # filled in when the shoot pose is drawn: where the muzzle is in its frame (px)
REF = None                          # the parts of the idle pose, found once: every pose's details are placed by comparing it with this


# ----------------------------------------------------------------------------------------------------------------------
# finding the parts of a frame
# ----------------------------------------------------------------------------------------------------------------------
class Comp:
    """One connected piece of a colour: its mask (at the big size) and where it is (px of the final picture)."""

    def __init__(self, mask, area, cx, cy, box):
        self.mask, self.area, self.cx, self.cy, self.box = mask, area, cx, cy, box


def to_l(arr):
    return Image.fromarray((arr * 255).astype(np.uint8), "L")


def grow(arr, px):
    """The boolean array grown by `px` (final px) in every direction."""
    k = int(px * S) * 2 + 1
    return cv2.dilate(arr.astype(np.uint8), np.ones((k, k), np.uint8)).astype(bool)


def path_distance(region, seeds, max_px=60):
    """How far (px, walking inside `region`) every pixel of `region` is from the pixels `seeds`; infinite where it cannot be reached."""
    dist = np.full(region.shape, np.inf, np.float32)
    reached = seeds & region
    dist[reached] = 0.0
    kernel = np.ones((3, 3), np.uint8)
    for step in range(1, max_px * S):
        grown = cv2.dilate(reached.astype(np.uint8), kernel).astype(bool) & region & ~reached
        if not grown.any():
            break
        dist[grown] = step / S
        reached |= grown
    return dist


def pupil_of(p, eye):
    """The pupil inside the eye `eye` (a piece), or None."""
    pieces = components(p.pupil & grow(eye.mask, 1), 1)
    return pieces[0] if pieces else None


def components(arr, min_area=0.0):
    """The connected pieces of the boolean array `arr` (at the big size), largest first."""
    n, labels, stats, cents = cv2.connectedComponentsWithStats(arr.astype(np.uint8), connectivity=8)
    out = []
    for k in range(1, n):
        x, y, w, h, count = stats[k]
        area = count / (S * S)
        if area >= min_area:
            out.append(Comp(labels == k, area, cents[k][0] / S, cents[k][1] / S, (x / S, y / S, (x + w) / S, (y + h) / S)))
    return sorted(out, key=lambda c: -c.area)


class Parts:
    """Everything the detail pass needs to know about a frame: masks of its colours and the pieces it found (the face, the eyes, the belt, the hands, ...)."""

    def __init__(self, up):
        a = np.asarray(up, dtype=np.int16)
        opaque = a[..., 3] > 200

        def like(rgb, tol=14):
            return np.all(np.abs(a[..., :3] - np.array(rgb, dtype=np.int16)) <= tol, axis=-1) & opaque

        self.body = np.asarray(up.getchannel("A")) > 8
        self.skin, self.neck, self.shirt, self.sleeve = like(SKIN), like(NECK, 12), like(SHIRT), like(SLEEVE)
        self.hair_all = like(HAIR) | like(HAIR_SHADE)
        self.pants = like(PANTS, 20) | like(PANTS_SHADE, 20)
        self.white, self.pupil = like((255, 255, 255), 4), like(PUPIL, 22)
        self.cloth = self.shirt | self.sleeve
        self.from_cloth = cv2.distanceTransform((~self.cloth).astype(np.uint8), cv2.DIST_L2, 5) / S
        # the head's hair: the piece of hair colour with the highest point
        pieces = components(self.hair_all, 4)
        self.hair = max(pieces, key=lambda c: -c.box[1]) if pieces else None
        self.hair_mask = self.hair.mask if self.hair else np.zeros_like(self.body)
        # the face: the skin piece with the eyes in it
        whites = [c for c in components(self.white, 3) if c.area < 70]
        self.face, self.eyes, self.tooth = None, [], None
        best, face_whites = 0, []
        for sk in components(self.skin, 20):
            near = grow(sk.mask, 1)
            found = [w for w in whites if (w.mask & near).any()]
            if len(found) > best:
                best, self.face, face_whites = len(found), sk, found
        if self.face:
            y0, y1 = self.face.box[1], self.face.box[3]
            eyes = [w for w in face_whites if w.cy < y0 + 0.62 * (y1 - y0)]
            self.eyes = sorted(sorted(eyes, key=lambda c: -c.area)[:2], key=lambda c: c.cx)
            teeth = [w for w in face_whites if w not in self.eyes]
            self.tooth = teeth[0] if teeth else None
        necks = components(self.neck, 6)
        self.neck_piece = necks[0] if necks else None
        # the belt (hair-coloured, against the shirt), the shoes (hair-coloured, low down) and the brows (small, above the eyes)
        near_cloth = grow(self.cloth, 2.5)
        self.belt, self.shoes, self.brows = None, [], []
        for c in components(self.hair_all & ~self.hair_mask, 3):
            if self.face and self.eyes and c.area < 45 and c.cy < self.eyes[0].cy - 2:
                self.brows.append(c)
            elif c.area > 600 or c.cy < 55:
                continue
            elif (c.mask & near_cloth).any() and self.belt is None and c.area > 30:
                self.belt = c
            elif c.cy > 60 and c.area > 5:
                self.shoes.append(c)
        # the arms: skin that is not the face (the face ends at the jaw, a fixed way below the eyes); a hand is the arm far, along the arm, from the sleeve
        rows = np.arange(H * S)[:, None] / S
        cols = np.arange(W * S)[None, :] / S
        self.eye_centres = []
        for eye in self.eyes:
            pup = pupil_of(self, eye)
            self.eye_centres.append((pup.cx, pup.cy) if pup else (eye.cx, eye.cy))
        if self.face and self.eyes:       # the face is the skin between the sides of the head and down to the jaw: an arm raised beside the head is not part of it
            left, right = self.eye_centres[0][0], self.eye_centres[-1][0]
            self.face_mask = self.face.mask & (rows <= self.eyes[0].cy + JAW_BELOW_EYES) & (cols >= left - FACE_LEFT) & (cols <= right + FACE_RIGHT)
        else:
            self.face_mask = np.zeros_like(self.body)
        self.arm_skin = self.skin & ~self.face_mask
        seeds = self.arm_skin & grow(self.sleeve, 0.6)
        if not seeds.any():
            seeds = self.arm_skin & grow(self.cloth, 0.6)
        self.along_arm = path_distance(self.arm_skin, seeds)
        self.hands = self.arm_skin & (self.along_arm > WRIST_TO)
        self.wrists = self.arm_skin & (self.along_arm > WRIST_FROM) & (self.along_arm <= WRIST_TO)
        self.hand_pieces = components(self.hands, 8)
        self.pants_pieces = components(self.pants, 25)


def box_mask(x0, y0, x1, y1):
    m = mk(W, H)
    poly(m, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)])
    return m


def put(c, mask, color, clip=None, alpha=1.0):
    """Paints `color` where `mask` is (and `clip` allows)."""
    c.alpha_composite(solid(mask if clip is None else inside(mask, clip), color, alpha))


def strokes(paths, width):
    m = mk(W, H)
    for pts in paths:
        for a, b in zip(pts, pts[1:]):
            line(m, a, b, width)
        for p in (pts[0], pts[-1]):
            ell(m, p[0], p[1], width / 2)
    return m


def curve_pts(points, per=8):
    """A smooth curve through `points` (Catmull-Rom)."""
    ext = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for k in range(per):
            t = k / per
            out.append(tuple(0.5 * (2 * p1[a] + (-p0[a] + p2[a]) * t + (2 * p0[a] - 5 * p1[a] + 4 * p2[a] - p3[a]) * t * t + (-p0[a] + 3 * p1[a] - 3 * p2[a] + p3[a]) * t ** 3) for a in (0, 1)))
    out.append(points[-1])
    return out


def fit(ref_box, box):
    """A function that moves a point written for the idle pose (px of the 80 x 110 original) into the same place of `box` in the pose being drawn (`ref_box` is its box in idle)."""
    rw, rh = max(1e-6, ref_box[2] - ref_box[0]), max(1e-6, ref_box[3] - ref_box[1])
    sx, sy = (box[2] - box[0]) / rw, (box[3] - box[1]) / rh
    return lambda p: (box[0] + (p[0] + PAD - ref_box[0]) * sx, box[1] + (p[1] - ref_box[1]) * sy)


# ----------------------------------------------------------------------------------------------------------------------
# the details
# ----------------------------------------------------------------------------------------------------------------------
def detail_hair(c, p):
    if p.hair is None:
        return
    f = fit(REF.hair.box, p.hair.box)
    hair, skin = to_l(p.hair_mask), to_l(p.skin)
    if p.face:                                     # a few locks over the forehead break the hard hairline, and throw a shadow on it
        locks = mk(W, H)
        for x0, x1, tip in ((23, 29, 44), (30, 36, 41), (46, 52, 41), (53, 59, 42), (59, 63, 44)):
            poly(locks, [f((x0, 38)), f((x1, 38)), f(((x0 + x1) / 2 + 1, tip))])
        put(c, locks, HAIR_SHADE, clip=ImageChops.lighter(skin, hair))
        put(c, blur(ImageChops.offset(ImageChops.lighter(hair, locks), 0, 2 * S), 1.0), (206, 156, 112), clip=skin, alpha=0.55)
    paths = [[(26, 40), (30, 31), (40, 24), (52, 19), (61, 16)], [(23, 44), (26, 34), (35, 27), (47, 22), (58, 19)], [(32, 38), (38, 31), (48, 26), (58, 24)], [(22, 52), (22, 42), (25, 36)]]
    put(c, strokes([curve_pts([f(q) for q in path]) for path in paths], 0.8), HAIR_DARK, clip=hair, alpha=0.85)
    put(c, strokes([curve_pts([f(q) for q in [(33, 29), (42, 23), (53, 19), (60, 17.5)]])], 1.5), HAIR_LIGHT, clip=hair, alpha=0.8)
    put(c, strokes([curve_pts([f(q) for q in [(60, 24), (62, 32), (61, 40)]])], 1.2), HAIR_DARK, clip=hair, alpha=0.55)


def detail_face(c, p, stern, blink):
    if not p.face or len(p.eyes) < 2:
        return
    for eye in ([] if blink else p.eyes):           # a glint in each pupil
        pup = pupil_of(p, eye)
        if pup:
            glint = mk(W, H)
            ell(glint, pup.cx - 0.8, pup.cy - 0.8, 1.0)
            put(c, glint, (255, 255, 255))
    (lx, ly), (rx, ry) = p.eye_centres[0], p.eye_centres[-1]
    if stern:                                       # the calm poses: firm brows slanting down to the nose
        put(c, strokes([[(lx - 4.2, ly - 8.6), (lx + 3.8, ly - 7.0)]], 2.0), BROW)
        put(c, strokes([[(rx - 4.2, ry - 7.0), (rx + 3.8, ry - 8.6)]], 2.0), BROW)
    elif p.brows:                                   # the other poses keep the brows of the original, drawn a little thicker
        brows = np.zeros_like(p.body)
        for b in p.brows:
            brows |= b.mask
        thick = grow(brows, 0.45)
        put(c, to_l(thick), BROW, clip=to_l(thick & (p.skin | brows)))
    if p.tooth:                                     # a grin: a pink tongue under the tooth
        t = p.tooth
        tongue = mk(W, H)
        ell(tongue, t.cx + 2.0, t.cy + 3.0, 3.0, 1.2)
        put(c, tongue, (232, 112, 122))


def detail_shirt(c, p):
    if not p.shirt.any():
        return
    shirt, cloth, body, skin = to_l(p.shirt), to_l(p.cloth), to_l(p.body), to_l(p.skin)
    main = components(p.shirt, 30)[0]
    y0, y1 = main.box[1], main.box[3]               # light from the upper left: a gradient down the shirt and a highlight on the shoulder
    g = np.clip((np.arange(H * S)[:, None] / S - y0) / max(1.0, y1 - y0), 0.0, 1.0) * np.ones((1, W * S))
    put(c, ImageChops.multiply(to_l(g), shirt), (30, 160, 92), alpha=0.45)
    put(c, strokes([[(main.box[0] + 4, main.box[1] + 3), (main.box[0] + 10, main.box[1] + 1.6)]], 1.2), SHIRT_LIGHT, clip=shirt, alpha=0.8)
    if p.neck_piece:                                # a collar rim hugging the lower edge of the neck (the darker half circle under the flat jaw)
        neck = to_l(p.neck_piece.mask)
        rim = ImageChops.subtract(neck.filter(ImageFilter.MaxFilter(int(1.6 * S) // 2 * 2 + 1)), neck)
        put(c, rim, SHIRT_DARK, clip=shirt)
    f = fit(REF.shirt_main.box, main.box)           # folds at the waist
    put(c, strokes([curve_pts([f(q) for q in path]) for path in ([(27, 84), (31, 82.5), (34, 85)], [(53, 85), (49, 83), (46, 86.5)])], 0.9), SHIRT_DARK, clip=shirt, alpha=0.9)
    put(c, to_l(p.sleeve & grow(p.arm_skin, 0.4)), STRAP, clip=body)     # a yellow stripe where the sleeves meet the arms
    if not (p.neck_piece and p.face):
        return
    n = p.neck_piece                                # goggles on a cord round the neck, resting on the chest
    cx, top, bottom = n.cx, n.box[1], n.box[3]
    put(c, strokes([curve_pts([(cx - 13, top), (cx - 11, top + 5), (cx - 7, bottom + 3.5)]), curve_pts([(cx + 13, top), (cx + 11, top + 5), (cx + 7, bottom + 3.5)])], 0.9), GLOVE_DARK, clip=ImageChops.lighter(cloth, skin))
    for lx in (cx - 6, cx + 6):
        for r, dx, col in ((5.4, 0.0, STRAP_DARK), (5.0, -0.3, STRAP)):
            m = mk(W, H)
            ell(m, lx + dx, bottom + 6.5 + dx, r)
            put(c, m, col)
        glass = mk(W, H)
        ell(glass, lx, bottom + 6.5, 3.6)
        put(c, glass, (30, 60, 92))
        put(c, glass, CYAN, alpha=0.75)
        put(c, strokes([curve_pts([(lx - 2.4, bottom + 7.0), (lx - 2.0, bottom + 5.0), (lx - 0.4, bottom + 4.2)])], 0.8), CYAN_LIGHT, alpha=0.95)
    put(c, strokes([[(cx - 1.6, bottom + 6.0), (cx + 1.6, bottom + 6.0)]], 1.4), STEEL_DARK)


def detail_belt(c, p):
    if p.belt is None or not p.face:                # (seen from behind there is no buckle)
        return
    x0, _, x1, _ = p.belt.box
    cx, cy = p.belt.cx, p.belt.cy
    put(c, strokes([[(x, cy + 0.2), (x + 1.2, cy + 0.2)] for x in np.arange(x0 + 2, x1 - 2, 3.0) if abs(x - cx) > 7], 0.6), HAIR_DARK, clip=to_l(p.belt.mask), alpha=0.9)
    if p.belt.area < 45:
        return
    buckle = mk(W, H)
    poly(buckle, [(cx - 5.5, cy - 3.0), (cx + 5.5, cy - 3.0), (cx + 5.5, cy + 3.0), (cx - 5.5, cy + 3.0)])
    put(c, buckle, STEEL_DARK)
    face = mk(W, H)
    poly(face, [(cx - 4.5, cy - 2.2), (cx + 4.5, cy - 2.2), (cx + 4.5, cy + 2.2), (cx - 4.5, cy + 2.2)])
    put(c, face, STEEL)
    icon = mk(W, H)                                 # the power symbol (the saboteur's mark)
    ImageDraw.Draw(icon).arc([(cx - 2.6) * S, (cy - 1.4) * S, (cx + 2.6) * S, (cy + 3.0) * S], -50, 230, fill=255, width=int(0.9 * S))
    line(icon, (cx, cy - 1.6), (cx, cy + 0.4), 0.9)
    put(c, icon, (226, 48, 58))


def detail_arms(c, p):
    put(c, to_l(p.wrists), GLOVE_DARK)              # a dark wristband with a glowing cyan line
    mid = (WRIST_FROM + WRIST_TO) / 2
    glow_line = to_l(p.arm_skin & (p.along_arm > mid - 0.5) & (p.along_arm <= mid + 0.5))
    put(c, glow_line, CYAN)
    put(c, blur(glow_line, 0.8), CYAN, alpha=0.5)
    put(c, to_l(p.hands), GLOVE)                    # the fists become fingerless gloves, with knuckles at the end furthest from the shirt
    for piece in p.hand_pieces:
        ys, xs = np.nonzero(piece.mask)
        reach = np.where(np.isfinite(p.along_arm[ys, xs]), p.along_arm[ys, xs], -1.0)
        far = np.array([xs[np.argmax(reach)], ys[np.argmax(reach)]]) / S
        direction = far - np.array([piece.cx, piece.cy])
        n = np.linalg.norm(direction)
        direction = direction / n if n > 1e-3 else np.array([0.0, 1.0])
        side = np.array([-direction[1], direction[0]])
        base = np.array([piece.cx, piece.cy]) + direction * 1.5
        mask = to_l(piece.mask)
        for k in (-1, 0, 1):
            a = base + side * 3.6 * k
            put(c, strokes([[tuple(a), tuple(a + direction * 3.6)]], 0.7), GLOVE_DARK, clip=mask)
        put(c, to_l(piece.mask & (np.arange(H * S)[:, None] < (piece.box[1] + 5.5) * S)), GLOVE_LIGHT, alpha=0.5)


def detail_legs(c, p):
    pants = to_l(p.pants)
    for piece in (p.pants_pieces if p.face else []):     # a cargo pocket (flap and button) near the top of each leg (not seen from behind)
        near_top = piece.mask & (p.from_cloth < 9)
        if near_top.sum() < 5 * S * S:
            continue
        ys, xs = np.nonzero(near_top)
        px, py = xs.mean() / S, ys.mean() / S
        flap = box_mask(px - 3.4, py - 0.6, px + 3.4, py + 2.6)
        put(c, flap, (36, 118, 176), clip=ImageChops.multiply(pants, to_l(piece.mask)))
        btn = mk(W, H)
        ell(btn, px, py + 0.2, 0.8)
        put(c, btn, STRAP, clip=pants)
    for shoe in p.shoes:                            # a darker sole on the underside of each shoe and yellow laces on top
        m = to_l(shoe.mask)
        put(c, ImageChops.subtract(m, ImageChops.offset(m, 0, -int(1.6 * S))), SOLE)
        put(c, ImageChops.subtract(m, ImageChops.offset(m, 0, int(1.6 * S))), STRAP, clip=box_mask(shoe.cx - 3.5, 0, shoe.cx + 3.5, H))


def detail_gun(c, p):
    """The EMP gun in the fist that is held out furthest forward: a blocky pistol in the flat style of the rest, with the fist wrapped round its grip. Returns the muzzle."""
    if not p.hand_pieces:
        return None
    fist = max(p.hand_pieces, key=lambda q: q.cx)
    gx, gy = fist.cx, fist.cy

    def box(x0, y0, x1, y1):
        return box_mask(gx + x0, gy + y0, gx + x1, gy + y1)

    below = c.copy()
    for m, col in ((box(-3, 0, 2.5, 8), STEEL_DARK), (box(-3, -5.5, 15, 2.5), STEEL), (box(-3, -2.0, 15, 2.5), (126, 136, 160)), (box(0, -9, 11, -5.5), STEEL_DARK),
                   (box(1.5, -8.2, 9.5, -6.6), CYAN), (box(4, -3.2, 12.5, -0.6), (24, 30, 44)), (box(5, -2.8, 6.6, -1.0), CYAN), (box(7.4, -2.8, 9.0, -1.0), CYAN),
                   (box(9.8, -2.8, 11.4, -1.0), CYAN), (box(-3, 2.5, 15, 4.0), STRAP)):
        put(c, m, col)
    dish = mk(W, H)
    poly(dish, [(gx + 15, gy - 5.5), (gx + 21, gy - 9), (gx + 22, gy - 9), (gx + 22, gy + 7), (gx + 21, gy + 7), (gx + 15, gy + 4)])
    put(c, dish, STEEL_DARK)
    mouth = mk(W, H)
    ell(mouth, gx + 22.0, gy - 1.0, 1.6, 6.5)
    put(c, mouth, CYAN)
    put(c, blur(mouth, 1.4), CYAN, alpha=0.7)
    whole = ImageChops.lighter(ImageChops.lighter(box(-3, -9, 15, 8), dish), box(15, -9, 22, 7))
    c.alpha_composite(art_lib.outline(whole, 1.6, OUTLINE))
    fist_layer = below.copy()                       # the fist goes over the grip again
    fist_layer.putalpha(ImageChops.multiply(below.getchannel("A"), to_l(p.hands)))
    c.alpha_composite(fist_layer)
    return (gx + 22.0, gy - 1.0)


def outline_parts(c, p):
    """The outlines on the finished picture: thin lines where the parts meet, a strong one under the flat jaw, then one dark line round the whole figure."""
    body = c.getchannel("A")
    mouth_zone = np.asarray(box_mask(0, 54, W, 64)) > 127
    parts = [p.hair_mask & ~mouth_zone, p.shirt, p.pants, p.hands | p.wrists, p.neck]
    parts += [comp.mask for comp in (p.belt, *p.shoes) if comp is not None]
    for m in parts:
        ring = art_lib.outline(to_l(m), INNER_WIDTH, OUTLINE)
        ring.putalpha(ImageChops.multiply(ring.getchannel("A"), body).point(lambda v: int(v * INNER_ALPHA)))
        c.alpha_composite(ring)
    if p.face and p.eyes:                           # the underside of the face (its flat jaw), as dark as the outer line, but not round the mouth
        jaw = art_lib.outline(to_l(p.face_mask), OUTER_WIDTH, OUTLINE)
        jaw.putalpha(ImageChops.multiply(ImageChops.multiply(jaw.getchannel("A"), body), box_mask(0, p.eyes[0].cy + JAW_BELOW_EYES - 1.6, W, H)))
        c.alpha_composite(jaw)
    c.alpha_composite(art_lib.outline(body, OUTER_WIDTH, OUTLINE))


def detailed(up, stern=True, gun=False, blink=False):
    """The frame `up` (the original's pixels at the big size, the eyes open) with all the details and outlines drawn on; `blink` shuts the eyes."""
    p = Parts(up)
    c = eyes_shut(up, p) if blink else up.copy()
    detail_hair(c, p)
    detail_face(c, p, stern, blink)
    detail_shirt(c, p)
    detail_belt(c, p)
    detail_arms(c, p)
    detail_legs(c, p)
    muzzle = detail_gun(c, p) if gun else None
    outline_parts(c, p)
    if muzzle:
        MUZZLE[0], MUZZLE[1] = muzzle
    return c


# ----------------------------------------------------------------------------------------------------------------------
# the frames: pictures moved, stretched or with the eyes changed, before the details are drawn
# ----------------------------------------------------------------------------------------------------------------------
def source(name):
    return Image.open(os.path.join(SRC, "player_%s.png" % name)).convert("RGBA")


def widen(img):
    """The original frame in the middle of a wider, empty one, scaled up to the big size (each pixel a 4 x 4 block)."""
    wide = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    wide.alpha_composite(img, (PAD, 0))
    return wide.resize((W * S, H * S), Image.NEAREST)


def stretch_upper(up, anchor, k):
    """Everything above the row `anchor` (px) stretched up by the factor k about that row: the chest and head rise, the lower body stays (breathing)."""
    cut = int(anchor * S)
    taller = up.crop((0, 0, up.width, cut)).resize((up.width, int(round(cut * k))), Image.NEAREST)
    out = up.copy()
    out.paste(Image.new("RGBA", (up.width, cut), (0, 0, 0, 0)), (0, 0))
    out.alpha_composite(taller, (0, cut - taller.height))
    return out


def eyes_shut(up, p):
    """The frame `up` with the eyes closed: the whites and pupils painted over with skin and a curved line drawn where each eye was (`p` are its parts, found with the eyes open)."""
    c = up.copy()
    for eye in p.eyes:
        c.alpha_composite(solid(to_l(grow(eye.mask | (p.pupil & grow(eye.mask, 1)), 0.6)), SKIN))
    for ex, ey in p.eye_centres:
        c.alpha_composite(solid(strokes([curve_pts([(ex - 3.6, ey - 0.5), (ex, ey + 1.4), (ex + 3.6, ey - 0.5)])], 1.1), INK))
    return c

def eyes_look(up, dx, dy):
    """The pupils moved by (dx, dy) px: a glance."""
    p = Parts(up)
    c = up.copy()
    for eye in p.eyes:
        pup = pupil_of(p, eye)
        if pup is None:
            continue
        c.alpha_composite(solid(to_l(pup.mask), (255, 255, 255)))
        m = mk(W, H)
        ell(m, pup.cx + dx, pup.cy + dy, 1.5, 2.1)
        c.alpha_composite(solid(inside(m, to_l(grow(eye.mask, 0.8))), PUPIL))
    return c


def frames():
    """Every frame to draw: name -> (the picture at the big size, whether the brows are the firm, calm ones, whether the gun is in the fist, whether the eyes are shut)."""
    idle, walk1, walk2 = widen(source("idle")), widen(source("walk1")), widen(source("walk2"))
    out = {}
    for k, b in enumerate((1.0, 1.015, 1.03)):          # (the breath goes in, then out through the middle picture again)
        base = stretch_upper(idle, 90, b)
        out["idle%d" % (k + 1)] = (base, True, False, False)
        out["blink%d" % (k + 1)] = (base, True, False, True)
    out["look"] = (eyes_look(stretch_upper(idle, 90, 1.015), -1.0, -1.2), True, False, False)
    out["walk1"], out["walk2"] = (walk1, True, False, False), (walk2, True, False, False)
    for name in ("jump", "fall", "hurt", "action1", "action2", "climb1", "climb2"):
        out[name] = (widen(source(name)), False, False, False)
    out["shoot"] = (widen(source("action2")), False, True, False)
    return out


def contact_sheet(images, cols=7):
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * W, rows * H), (40, 48, 70, 255))
    for i, im in enumerate(images):
        sheet.alpha_composite(im, ((i % cols) * W, (i // cols) * H))
    return sheet


def main():
    global REF
    REF = Parts(widen(source("idle")))
    REF.shirt_main = components(REF.shirt, 30)[0]
    os.makedirs(OUT, exist_ok=True)
    images = []
    for name, (up, stern, gun, blink) in frames().items():
        images.append(art_lib.finish(detailed(up, stern, gun, blink), os.path.join(OUT, "player_%s.png" % name)))
    sheet = contact_sheet(images)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(art_lib.preview_path("player_sheet.png"))
    print("frames: %d   muzzle at (%.1f, %.1f) in a %dx%d frame" % (len(images), MUZZLE[0], MUZZLE[1], W, H))


if __name__ == "__main__":
    main()
