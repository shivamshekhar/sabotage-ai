"""Draws the player's sprites as layers: the blocky Kenney character (CC0, tools/art/sources/kenney_platformer_player/) with the detail added on top, split into parts so
the wardrobe (scripts/player/outfit.gd) can change them one by one.

The shapes, proportions and flat colours of the original are kept. Every frame is cut into parts, each a picture of its own, 128 x 110 px like the frame (the 80 px wide original
in the middle, room at the sides for the gun; feet on the bottom edge; facing right, the game flips them), named  player_<pose>_<part>.png  (the look the character has to begin
with) and  player_<pose>_<part>_<style>.png  (another style of that part):
    boots  pants  arms  torso  gun  gloves  head  hair  goggles     from the bottom up: the order they are drawn in. head (the face, the neck) and arms (bare, hands too)
    are the body, which does not change; the gun is only in the shooting pose. A part with nothing to show in a frame has no file (the back of the head has no goggles).
Styles: hair crop (bald and the rest: no picture), goggles glasses visor, torso tank long, pants plain, boots plain. The game recolours the parts (see WardrobeCatalog).
The details are found in each frame automatically (the face, eyes, neck, belt, hands, shoes, found by colour) and drawn at 4 times the size: strands and a highlight in the hair,
glints in the eyes, goggles on a cord round the neck, a belt with a power-button buckle, fingerless gloves with glowing wristbands, cargo pockets, laces and soles, and the
outlines (each part is outlined all round: strong where nothing is under it, fine where it lies on another part, strong under the flat jaw).

The frames: idle1..3 (breathing), blink1..3 and look (only the head: the rest is that of idle1..3 / idle2), walk1 and walk2, jump, fall, hurt, action1, action2, climb1, climb2, and
shoot (the EMP gun held in the fist of the throw pose).

Usage (from the repo root; needs Pillow, numpy, opencv):
    python tools/art/generate_player.py      writes
        assets/characters/saboteur/player/<part>/<part>/<style>/player_<pose>_<part>.png     the pictures above (<part>/ alone for a part with no styles: head, arms, gun)
        tmp/art_previews/player_sheet.png                                         every frame put together, for looking at only
        tmp/art_previews/player_styles.png                                        the standing pose in every style, for looking at only
    and prints where the gun's muzzle is, to copy into PlayerSprite.GUN_MUZZLE when the shoot pose changes.
"""
import hashlib
import json
import os
import sys
from collections import namedtuple

import cv2
import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import art_lib  # noqa: E402
from art_lib import S, mk, poly, ell, rr, line, solid, inside, blur  # noqa: E402

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
SKIN_TOLERANCE = 30                 # how far a colour may be from the original skin colour and still be skin: it takes in the faint creases drawn across the wrists (but not the darker neck)
WRIST_FROM, WRIST_TO = 6.0, 9.0     # a wrist is the arm this far (px) along it from the sleeve; further is the hand, nearer is the upper arm
JAW_BELOW_EYES = 14.8               # the face ends this far (px) below its eyes: the flat jaw
FACE_LEFT, FACE_RIGHT = 15.5, 12.5  # and this far (px) to the left of its left pupil and to the right of its right pupil
HEAD_RIM = 1.0                      # the outermost ring of the face (px) is plain skin: the original's shaded or dark rim pixels would show as ragged bumps next to the outline
UNDERSHIRT = (52, 104, 214)         # the blue of the martial-arts outfit's undershirt, cuffs and sash (far from the shirt's green, so dyeing the shirt leaves it)
UNDERSHIRT_LIGHT = (108, 156, 255)
UNDERSHIRT_DARK = (30, 62, 150)
SASH_HEIGHT = 5.0                   # how tall the sash is (px)
# SPIKES: the spiky hair's crown, one (where across the face, 0 = left side and 1 = right side; how tall in px; how far it leans, px, + is right; how thick at the base) each
# SPIKY_TEMPLATE: the spiky hair, drawn by hand for the standing pose (the whole picture, outline and shading included). Every other pose gets it moved onto its head (spiky_hair()).
GI_ORANGE = (236, 138, 36)          # the orange of the martial-arts outfit, for the pieces that are not dyed with the shirt
REAR_MARGIN = 1.2                   # the rear arm is cut out with this much (px) round it, so none of its soft edge pixels stays
WAVE_ARM_BACK, WAVE_ARM_DROP, WAVE_ARM_FORWARD, WAVE_ARM_WIDTH = 24.0, 5.0, 7.0, 5.4   # the second arm of the martial-arts shooting pose: where it starts (px behind the first fist), how far below the first arm it is, where its hand ends (px in front of the first fist), how thick it is
ORB_FORWARD, ORB_RADIUS, ORB_RAYS = 13.5, 8.5, 8   # the ball of energy in the martial-arts shooting pose: how far (px) in front of the fist its middle is, how big it is, how many rays
SPIKY_TEMPLATE = os.path.join(HERE, "sources", "spiky_hair_idle1.png")
SPIKY_SCALE_LOWEST, SPIKY_SCALE_HIGHEST = 0.92, 1.12   # the template is never scaled further than this (a hurt flinch squashes the hair: it must not shrink the spikes to nothing)
SPIKY_RESCALE = 0.04                # a pose whose hair is this much wider or narrower (a fraction) than in the standing pose gets the template scaled to match; below that it is only moved
HEAD_SIDE_FROM, HEAD_SIDE_TO = 6.0, 3.0   # the head's left side is straight from this far (px) above the eyes to this far above the flat jaw
HEAD_ZONE = 7.0                   # the smoothing below changes the picture only this close (px) to the face (not the neck)
HEAD_FILL = 4.5                   # dents in the face's outline (the cheek) narrower than twice this (px) are filled (larger: a smoother side; smaller: the original's dents stay)
HEAD_SMOOTH = 2.5                  # spikes in it (the jag at the jaw corner) narrower than twice this are shaved (larger: a rounder head)
SHIRT_TINT = 8                     # a head pixel whose green is this much above its red is the shirt's colour leaking over the jaw (a soft edge): it is cut away
MUZZLE = [0.0, 0.0]               # filled in when the shoot pose is drawn: where the muzzle is in its frame (px)
SPIKY_REF = None                    # where the eyes are in the standing pose (see eyes_anchor) and how wide its hair is, found once: the template was drawn for it
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
        self.skin, self.neck, self.shirt, self.sleeve = like(SKIN, SKIN_TOLERANCE), like(NECK, 12), like(SHIRT), like(SLEEVE)
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
            eyes_y = np.mean([e.cy for e in self.eyes]) if self.eyes else y0
            teeth = [w for w in face_whites if w not in self.eyes and w.cy > eyes_y + 4.0]      # (a tooth is below the eyes)
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
# the parts a frame is split into
# ----------------------------------------------------------------------------------------------------------------------
# PARTS: the parts of the figure, bottom to top (the order the game draws them in). The head and the arms are the body that never changes; the others are what the
# player can change in the wardrobe (`gun` is only in the shooting pose). Every part has its own picture per frame: player_<pose>_<part>.png.
PARTS = ("boots", "pants", "arms", "torso", "gun", "gloves", "head", "hair", "goggles")

# CAP: the scalp under the hair, an ellipse as wide as the face plus CAP_SIDE px each side and CAP_HEIGHT * the face's width tall, whose middle is CAP_DROP px below the
# top of the face. The head picture has it in skin colour, so a hairstyle that is shorter than the original (or none) shows a head and not a hole.
CAP_SIDE = 2.0
CAP_HEIGHT = 0.42
CAP_DROP = 3.0


def blank():
    return Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))


def cut(up, mask):
    """The picture `up` with only the pixels inside the boolean array `mask` kept."""
    part = up.copy()
    part.putalpha(ImageChops.multiply(up.getchannel("A"), to_l(mask)))
    return part


def partition(p):
    """The part every pixel of the original frame belongs to: a dict part -> boolean mask. The masks do not overlap and together cover the whole figure."""
    zero = np.zeros_like(p.body)
    brows, shoes = zero.copy(), zero.copy()
    for b in p.brows:
        brows |= b.mask
    for s in p.shoes:
        shoes |= s.mask
    belt = p.belt.mask if p.belt is not None else zero
    neck = p.neck_piece.mask if p.neck_piece is not None else zero       # (only the neck itself: the same colour is in the creases of the hands)
    face_area = grow(p.face_mask, 4) if p.face_mask.any() else zero
    wanted = (("hair", p.hair_mask & ~brows), ("head", p.face_mask | neck | brows | (face_area & (p.white | p.pupil))), ("gloves", p.hands | p.wrists),
              ("arms", p.arm_skin), ("torso", p.shirt | p.sleeve), ("pants", p.pants | belt), ("boots", shoes))
    masks = {part: zero.copy() for part in PARTS}
    taken = zero.copy()
    for part, m in wanted:
        masks[part] = m & ~taken & p.body
        taken |= masks[part]
    left = p.body & ~taken
    if left.any() and taken.any():      # the pixels no colour rule caught (the soft edges) go to the nearest part
        _, labels = cv2.distanceTransformWithLabels((~taken).astype(np.uint8), cv2.DIST_L2, 5, labelType=cv2.DIST_LABEL_PIXEL)
        owner = np.zeros(labels.max() + 1, np.int8)
        for i, (part, _) in enumerate(wanted):
            owner[np.unique(labels[masks[part]])] = i + 1
        nearest = owner[labels]
        for i, (part, _) in enumerate(wanted):
            masks[part] |= left & (nearest == i + 1)
    return masks


def cranium(p, extra=0.0):
    """The scalp under the hair (see CAP) as a boolean array; empty if the frame has no face."""
    ys, xs = np.nonzero(p.face_mask)
    if len(xs) == 0:
        return np.zeros_like(p.body)
    x0, x1, y0 = xs.min() / S, xs.max() / S, ys.min() / S
    m = mk(W, H)
    ell(m, (x0 + x1) / 2, y0 + CAP_DROP, (x1 - x0) / 2 + CAP_SIDE + extra, CAP_HEIGHT * (x1 - x0) + extra)
    return np.asarray(m) > 127


# ----------------------------------------------------------------------------------------------------------------------
# the details, part by part
# ----------------------------------------------------------------------------------------------------------------------
def tidy_head(head, p):
    """The head picture with a clean rim, so its outline is one solid even line all round: the green of the shirt that tints the soft edge under the jaw is cut away, and
    the outer ring of the face (not its eyes, brows or mouth) is plain skin, so no shaded or dark rim pixel makes a bump beside the outline."""
    arr = np.array(head)
    solid = arr[..., 3] > 40
    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(HEAD_RIM * S) * 2 + 1,) * 2)
    rim = solid & ~cv2.erode(solid.astype(np.uint8), kernel).astype(bool)
    red, green = arr[..., 0].astype(np.int16), arr[..., 1].astype(np.int16)
    tinted = (arr[..., 3] > 0) & (green > red + SHIRT_TINT)
    features = grow(p.white | p.pupil | p.tooth.mask if p.tooth else p.white | p.pupil, 1)
    for brow in p.brows:
        features |= grow(brow.mask, 1)
    plain = rim & ~tinted & ~features & grow(p.face_mask, 2) & (red > green)
    arr[plain, :3] = SKIN
    arr[tinted, 3] = 0
    # a smooth silhouette: dents (the cheek) are filled and spikes (the jag at the jaw corner) are shaved, in the face only
    face_zone = grow(p.face_mask, HEAD_ZONE)
    solid = arr[..., 3] > 40
    fill = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(HEAD_FILL * S) * 2 + 1,) * 2)
    shave = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (int(HEAD_SMOOTH * S) * 2 + 1,) * 2)
    smooth = cv2.morphologyEx(cv2.morphologyEx(solid.astype(np.uint8), cv2.MORPH_CLOSE, fill), cv2.MORPH_OPEN, shave).astype(bool)
    added = smooth & ~solid & face_zone
    arr[added, :3] = SKIN
    arr[added, 3] = 255
    arr[solid & ~smooth & face_zone, 3] = 0
    # a flat left side: from the eyes' height down to the jaw the head's left edge is one straight line (every dent is filled out to the leftmost column)
    if p.eye_centres:
        top = int((p.eye_centres[0][1] - HEAD_SIDE_FROM) * S)
        bottom = int((p.eye_centres[0][1] + JAW_BELOW_EYES - HEAD_SIDE_TO) * S)
        solid = arr[..., 3] > 40
        rows = [y for y in range(max(top, 0), min(bottom, solid.shape[0])) if solid[y].any()]
        if rows:
            edge = {y: int(np.argmax(solid[y])) for y in rows}
            line = min(edge.values())
            for y in rows:
                arr[y, line:edge[y], :3] = SKIN
                arr[y, line:edge[y], 3] = 255
    # the flat jaw: a dark line where the face ends and the neck begins
    if p.neck_piece is not None and p.face_mask.any():
        jaw = p.neck_piece.mask & grow(p.face_mask, HEAD_RIM) & ~p.face_mask & (arr[..., 3] > 0)
        arr[jaw, :3] = OUTLINE
        arr[jaw, 3] = 255
    return Image.fromarray(arr, "RGBA")


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


def hair_crop(up, p, masks):
    """The short hairstyle: the original hair cut to the scalp (a rounded cap), with a highlight and a few strands. None if the frame has no face."""
    cap = cranium(p, 1.5)
    keep = masks["hair"] & cap
    if not keep.any():
        return None
    c = cut(up, keep)
    ys, xs = np.nonzero(keep)
    x0, x1, y0 = xs.min() / S, xs.max() / S, ys.min() / S
    mask = to_l(keep)
    put(c, blur(ImageChops.offset(mask, 0, 2 * S), 1.0), (206, 156, 112), clip=to_l(p.skin), alpha=0.55)
    put(c, strokes([curve_pts([(x0 + 6, y0 + 9), ((x0 + x1) / 2, y0 + 4), (x1 - 7, y0 + 6)])], 1.5), HAIR_LIGHT, clip=mask, alpha=0.8)
    put(c, strokes([curve_pts([(x0 + 3 + k * (x1 - x0 - 6) / 3.0, y0 + 4), (x0 + 2 + k * (x1 - x0 - 6) / 3.0, y0 + 14)]) for k in range(1, 4)], 0.8), HAIR_DARK, clip=mask, alpha=0.8)
    return c


def eyes_anchor(p):
    """Where the eyes are in a frame: (the middle between them x, y), px of the final picture. None if it has fewer than two."""
    if len(p.eye_centres) < 2:
        return None
    (lx, ly), (rx, ry) = p.eye_centres[0], p.eye_centres[-1]
    return (lx + rx) / 2, (ly + ry) / 2


def spiky_hair(p, masks):
    """The spiky hairstyle for this frame: the hand-drawn picture (SPIKY_TEMPLATE) moved so it sits on the face as it does in the standing pose (the eyes are the anchor, since the
    hair's own top moves differently from the face in some poses: a hurt flinch, a fall) and scaled to the width of this frame's own hair if that is clearly different. Already outlined and shaded, at the big size. None if the frame has no face (the back of the head keeps the original hair)."""
    here = eyes_anchor(p)
    if here is None or not (p.face and p.hair and masks["hair"].any()):
        return None
    ref_x, ref_y, ref_width = SPIKY_REF
    ys, xs = np.nonzero(masks["hair"])
    scale = float(np.clip((xs.max() - xs.min()) / S / ref_width, SPIKY_SCALE_LOWEST, SPIKY_SCALE_HIGHEST))
    if abs(scale - 1.0) < SPIKY_RESCALE:
        scale = 1.0
    template = Image.open(SPIKY_TEMPLATE).convert("RGBA").resize((W * S, H * S), Image.NEAREST)
    ox, oy = ref_x * S, ref_y * S                                         # (where the eyes are in the template, and where they are in this frame, at the big size)
    nx, ny = here[0] * S, here[1] * S
    ny = max(ny, (oy - template.getchannel("A").getbbox()[1]) * scale)       # (never higher than the top of the picture: a raised head must not cut the spikes off)
    return template.transform(template.size, Image.AFFINE, (1 / scale, 0, ox - nx / scale, 0, 1 / scale, oy - ny / scale), resample=Image.NEAREST)


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


def detail_torso(c, p, style="tee"):
    """The shirt: a gradient and a highlight, a collar rim, folds and (on a tee) a yellow stripe where the sleeves meet the arms. Styles: tee, tank (no sleeves)."""
    if not p.shirt.any():
        return
    shirt, body = to_l(p.shirt), to_l(p.body)
    main = components(p.shirt, 30)[0]
    y0, y1 = main.box[1], main.box[3]
    g = np.clip((np.arange(H * S)[:, None] / S - y0) / max(1.0, y1 - y0), 0.0, 1.0) * np.ones((1, W * S))
    put(c, ImageChops.multiply(to_l(g), shirt), (30, 160, 92), alpha=0.45)
    put(c, strokes([[(main.box[0] + 4, main.box[1] + 3), (main.box[0] + 10, main.box[1] + 1.6)]], 1.2), SHIRT_LIGHT, clip=shirt, alpha=0.8)
    if p.neck_piece:                                # a collar rim hugging the lower edge of the neck (the darker half circle under the flat jaw)
        neck = to_l(p.neck_piece.mask)
        rim = ImageChops.subtract(neck.filter(ImageFilter.MaxFilter(int(1.6 * S) // 2 * 2 + 1)), neck)
        put(c, rim, SHIRT_DARK, clip=shirt)
    f = fit(REF.shirt_main.box, main.box)           # folds at the waist
    put(c, strokes([curve_pts([f(q) for q in path]) for path in ([(27, 84), (31, 82.5), (34, 85)], [(53, 85), (49, 83), (46, 86.5)])], 0.9), SHIRT_DARK, clip=shirt, alpha=0.9)
    if style == "tee":
        put(c, to_l(p.sleeve & grow(p.arm_skin, 0.4)), STRAP, clip=body)


def torso_long(content, p):
    """The long-sleeved shirt: the tee with the sleeves carried on over the arms to the wrists, and a darker cuff."""
    c = content.copy()
    reach = p.arm_skin & (p.along_arm <= WRIST_FROM)
    put(c, to_l(reach), SLEEVE)
    put(c, ImageChops.multiply(to_l(reach), blur(to_l(reach), 1.2).point(lambda v: 255 - v // 2)), SHIRT_DARK, alpha=0.5)
    cuff = p.arm_skin & (p.along_arm > WRIST_FROM - 1.0) & (p.along_arm <= WRIST_FROM)
    put(c, to_l(cuff), SHIRT_DARK)
    return c


def torso_gi(content, p):
    """The martial-arts top: the tee with a crossed collar over a blue undershirt and a blue sash round the waist (the blue is not the shirt's colour, so it stays when the shirt
    is dyed)."""
    c = content.copy()
    if not p.shirt.any():
        return c
    shirt = to_l(p.shirt)
    main = components(p.shirt, 30)[0]
    if p.neck_piece:
        n = p.neck_piece
        cx, bottom = n.cx, n.box[3]
        vee = mk(W, H)
        poly(vee, [(cx - 5.5, bottom - 1.0), (cx + 5.5, bottom - 1.0), (cx, bottom + 9.0)])
        put(c, vee, UNDERSHIRT, clip=shirt)
        put(c, strokes([[(cx - 7.0, bottom - 1.0), (cx + 1.5, bottom + 10.0)], [(cx + 7.0, bottom - 1.0), (cx - 1.5, bottom + 10.0)]], 0.9), SHIRT_DARK, clip=shirt)
    x0, x1, y1 = main.box[0], main.box[2], main.box[3]
    sash = mk(W, H)
    rr(sash, (x0, y1 - SASH_HEIGHT - 0.5, x1, y1 + 0.2), 0.6)
    put(c, sash, UNDERSHIRT, clip=shirt)
    put(c, strokes([[(x0 + 1, y1 - SASH_HEIGHT - 0.2), (x1 - 1, y1 - SASH_HEIGHT - 0.2)]], 0.7), UNDERSHIRT_LIGHT, clip=shirt, alpha=0.9)
    put(c, strokes([[(x0 + 1, y1 - 0.6), (x1 - 1, y1 - 0.6)]], 0.8), UNDERSHIRT_DARK, clip=shirt)
    return c


def pants_gi(p, up, masks):
    """The baggy trousers of the martial-arts outfit: the pants with the belt filled in (the sash is on the top), a few deep folds and a gather above the boots."""
    c = cut(up, masks["pants"])
    legs = to_l(masks["pants"])
    if p.belt is not None:
        put(c, to_l(p.belt.mask), PANTS)
    for piece in p.pants_pieces:
        x0, y0, x1, y1 = piece.box
        if y1 - y0 < 12:
            continue
        put(c, strokes([[(x0 + (x1 - x0) * 0.3, y0 + 2), (x0 + (x1 - x0) * 0.25, y1 - 5)]], 0.9), PANTS_SHADE, clip=legs, alpha=0.9)
        put(c, strokes([[(x0 + 1, y1 - 3.5), (x1 - 1, y1 - 3.5)]], 1.0), PANTS_SHADE, clip=legs)
    return c


def boots_trimmed(p, up, masks):
    """Tall-looking boots with a yellow band round the top and a darker toe cap, in the original boot colour (so they can be dyed; the trim stays yellow)."""
    c = cut(up, masks["boots"])
    boots = to_l(masks["boots"])
    for piece in p.shoes:
        x0, y0, x1, y1 = piece.box
        put(c, strokes([[(x0, y0 + 1.0), (x1, y0 + 1.0)]], 1.6), STRAP, clip=boots)
        put(c, strokes([[(x0, y1 - 1.2), (x1, y1 - 1.2)]], 1.4), HAIR_DARK, clip=boots, alpha=0.9)
    return c


def gloves_wristbands(p, masks):
    """Only the wristbands: the hands are bare (the picture of the arms shows through) and a band is round each wrist. None if the frame has none."""
    wrists = masks["gloves"] & grow(p.wrists, 0.5)
    if not wrists.any():
        return None
    c = blank()
    put(c, to_l(wrists), GLOVE)
    return c


def detail_goggles(c, p):
    """The goggles on a cord round the neck, resting on the chest."""
    if not (p.neck_piece and p.face):
        return
    n = p.neck_piece
    cx, top, bottom = n.cx, n.box[1], n.box[3]
    put(c, strokes([curve_pts([(cx - 13, top), (cx - 11, top + 5), (cx - 7, bottom + 3.5)]), curve_pts([(cx + 13, top), (cx + 11, top + 5), (cx + 7, bottom + 3.5)])], 0.9), GLOVE_DARK)
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


def goggles_worn(p):
    """The other eyewear, on the face: round glasses and a visor, each a picture (a dict style -> picture); empty if the frame has no face."""
    if not (p.face and len(p.eye_centres) >= 2):
        return {}
    (lx, ly), (rx, ry) = p.eye_centres[0], p.eye_centres[-1]
    glasses = blank()
    for ex, ey in ((lx, ly), (rx, ry)):
        rim, hole = mk(W, H), mk(W, H)
        ell(rim, ex, ey, 6.4)
        ell(hole, ex, ey, 5.0)
        put(glasses, ImageChops.subtract(rim, hole), STRAP)
        put(glasses, hole, CYAN_LIGHT, alpha=0.16)
        put(glasses, strokes([curve_pts([(ex - 3.6, ey + 1.0), (ex - 3.0, ey - 2.6), (ex - 0.4, ey - 3.8)])], 0.7), CYAN_LIGHT, alpha=0.9)
    put(glasses, strokes([[(lx + 6.2, ly - 0.6), (rx - 6.2, ry - 0.6)]], 1.0), STRAP)
    put(glasses, strokes([[(lx - 6.2, ly - 0.4), (lx - 11.0, ly - 1.4)], [(rx + 6.2, ry - 0.4), (rx + 10.0, ry - 1.4)]], 0.9), STRAP_DARK)
    visor = blank()
    band, inner = mk(W, H), mk(W, H)
    rr(band, (lx - 9.0, ly - 5.6, rx + 9.0, ry + 5.2), 4.0)
    rr(inner, (lx - 7.8, ly - 4.4, rx + 7.8, ry + 4.0), 3.2)
    put(visor, ImageChops.subtract(band, inner), STRAP)
    put(visor, inner, (30, 60, 92), alpha=0.5)
    put(visor, inner, CYAN, alpha=0.32)
    put(visor, strokes([[(lx - 5.5, ly - 2.6), (lx + 2.0, ly - 3.2)]], 0.9), CYAN_LIGHT, alpha=0.95)
    return {"glasses": glasses, "visor": visor}


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


def detail_pockets(c, p):
    """A cargo pocket (flap and button) near the top of each leg (not seen from behind)."""
    if not p.face:
        return
    pants = to_l(p.pants)
    for piece in p.pants_pieces:
        near_top = piece.mask & (p.from_cloth < 9)
        if near_top.sum() < 5 * S * S:
            continue
        ys, xs = np.nonzero(near_top)
        px, py = xs.mean() / S, ys.mean() / S
        put(c, box_mask(px - 3.4, py - 0.6, px + 3.4, py + 2.6), (36, 118, 176), clip=ImageChops.multiply(pants, to_l(piece.mask)))
        btn = mk(W, H)
        ell(btn, px, py + 0.2, 0.8)
        put(c, btn, STRAP, clip=pants)


def detail_gloves(c, p):
    """A dark wristband with a glowing cyan line, and the fists as fingerless gloves with knuckles at the end furthest from the shirt."""
    put(c, to_l(p.wrists), GLOVE_DARK)
    mid = (WRIST_FROM + WRIST_TO) / 2
    glow_line = to_l(p.arm_skin & (p.along_arm > mid - 0.5) & (p.along_arm <= mid + 0.5))
    put(c, glow_line, CYAN)
    put(c, blur(glow_line, 0.8), CYAN, alpha=0.5)
    put(c, to_l(p.hands), GLOVE)
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


def detail_boots(c, p):
    """A darker sole on the underside of each shoe and yellow laces on top."""
    for shoe in p.shoes:
        m = to_l(shoe.mask)
        put(c, ImageChops.subtract(m, ImageChops.offset(m, 0, -int(1.6 * S))), SOLE)
        put(c, ImageChops.subtract(m, ImageChops.offset(m, 0, int(1.6 * S))), STRAP, clip=box_mask(shoe.cx - 3.5, 0, shoe.cx + 3.5, H))


def detail_gun(c, p):
    """The EMP gun in the fist that is held out furthest forward: a blocky pistol in the flat style of the rest. Returns the muzzle."""
    if not p.hand_pieces:
        return None
    fist = max(p.hand_pieces, key=lambda q: q.cx)
    gx, gy = fist.cx, fist.cy

    def box(x0, y0, x1, y1):
        return box_mask(gx + x0, gy + y0, gx + x1, gy + y1)

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
    return (gx + 22.0, gy - 1.0)


def rear_arm(p):
    """A boolean mask of the arm that hangs behind the one held out (its skin, its hand and its sleeve), for the pose that holds the ball of energy in both hands: the pictures of
    every part lose it (the second hand is drawn by energy_hands()). Empty if the frame has fewer than two hands."""
    rear = np.zeros_like(p.body)
    if len(p.hand_pieces) < 2:
        return rear
    behind = min(p.hand_pieces, key=lambda q: q.cx)                  # (the hand furthest back: its arm hangs behind the body)
    for arm in components(p.arm_skin, 6):
        if (arm.mask & behind.mask).any():
            rear |= arm.mask
    rows = np.arange(H * S)[:, None] / S
    cols = np.arange(W * S)[None, :] / S
    for sleeve in components(p.sleeve, 4):
        if (sleeve.mask & grow(rear, 1.5)).any():
            rear |= sleeve.mask | (p.shirt & (cols <= sleeve.box[2]) & (rows <= sleeve.box[3]))     # (and the shoulder above it, that was covered by the arm)
    return grow(rear, REAR_MARGIN)


def energy_hands(p):
    """The shooting pose for the martial-arts outfit: no gun, a ball of energy held between both hands (the fist that is out furthest forward, and a second arm and hand under the ball).
    Its front is where the gun's muzzle is, so the energy wave leaves from the same place. None if the frame has no fist."""
    if not p.hand_pieces:
        return None
    fist = max(p.hand_pieces, key=lambda q: q.cx)
    gx, gy = fist.cx, fist.cy
    c = blank()
    arm_end = (gx + WAVE_ARM_FORWARD, gy + WAVE_ARM_DROP + 1.0)                                  # the second arm, under the first: both hands push the energy forward
    put(c, strokes([[(gx - WAVE_ARM_BACK, gy + WAVE_ARM_DROP), arm_end]], WAVE_ARM_WIDTH), SKIN)
    put(c, strokes([[(gx - WAVE_ARM_BACK - 3.0, gy + WAVE_ARM_DROP), (gx - WAVE_ARM_BACK + 6.0, gy + WAVE_ARM_DROP + 0.4)]], WAVE_ARM_WIDTH + 2.0), GI_ORANGE)       # (its sleeve)
    put(c, box_mask(arm_end[0] - 4.5, arm_end[1] - WAVE_ARM_WIDTH / 2, arm_end[0] - 2.0, arm_end[1] + WAVE_ARM_WIDTH / 2), UNDERSHIRT)      # (its wristband)
    hand = mk(W, H)
    ell(hand, arm_end[0] + 0.5, arm_end[1], 3.8, 3.5)
    put(c, hand, SKIN)
    cx, cy = gx + ORB_FORWARD, gy - 1.0
    for radius, color in ((ORB_RADIUS, (36, 84, 196)), (ORB_RADIUS - 1.6, (62, 150, 240)), (ORB_RADIUS - 3.2, (120, 214, 255)), (ORB_RADIUS - 5.2, (220, 246, 255)), (ORB_RADIUS - 6.8, (255, 255, 255))):
        ball = mk(W, H)
        ell(ball, cx, cy, radius)
        put(c, ball, color)
    for k in range(ORB_RAYS):                                       # short rays of light round the ball
        angle = 2 * np.pi * k / ORB_RAYS + 0.3
        a = (cx + np.cos(angle) * (ORB_RADIUS - 0.5), cy + np.sin(angle) * (ORB_RADIUS - 0.5))
        b = (cx + np.cos(angle) * (ORB_RADIUS + 2.5), cy + np.sin(angle) * (ORB_RADIUS + 2.5))
        put(c, strokes([[a, b]], 1.3), (150, 226, 255))
    return c


# ----------------------------------------------------------------------------------------------------------------------
# a frame as layers
# ----------------------------------------------------------------------------------------------------------------------
def build(up, stern=True, gun=None, blink=False):
    """The frame `up` (the original's pixels at the big size, the eyes open) as its layers. Returns (the parts found, {part: picture}, {part: {style: picture}}): the first is
    the original look of every part, the second the other styles of the parts that have any; `blink` shuts the eyes; `gun` is "emp" (the EMP gun in the fist) or "wave" (the martial-arts
    pose: a ball of energy in both hands) in the shooting poses and None in the others."""
    p = Parts(up)
    masks = partition(p)
    content = {part: cut(up, masks[part]) for part in PARTS}
    skin_under = to_l(p.sleeve | p.hands | p.wrists)               # what is under a sleeve or a glove: the bare arm
    put(content["arms"], skin_under, SKIN)
    scalp = cranium(p) & (p.hair_mask | grow(p.hair_mask, 1.2))       # (a little beyond the hair too: its soft edge pixels are a brown that must not show on a bald head)
    put(content["head"], to_l(scalp), SKIN)
    if not p.face_mask.any():                                        # seen from behind: the whole head is where the hair is, bare under it
        put(content["head"], to_l(p.hair_mask), SKIN)
    if blink:
        content["head"] = eyes_shut(content["head"], p)
    detail_hair(content["hair"], p)
    content["head"] = tidy_head(content["head"], p)
    detail_face(content["head"], p, stern, blink)
    detail_torso(content["torso"], p, "tee")
    detail_goggles(content["goggles"], p)
    detail_belt(content["pants"], p)
    detail_pockets(content["pants"], p)
    detail_gloves(content["gloves"], p)
    detail_boots(content["boots"], p)
    muzzle = detail_gun(content["gun"], p) if gun == "emp" else None
    wave_hands = energy_hands(p) if gun == "wave" else None
    if muzzle:
        MUZZLE[0], MUZZLE[1] = muzzle
    others = {"hair": {}, "goggles": goggles_worn(p), "torso": {}, "pants": {}, "boots": {}, "gloves": {}}
    crop = hair_crop(up, p, masks)
    if crop is not None:
        others["hair"]["crop"] = crop
    spiky = spiky_hair(p, masks)
    if spiky is not None:
        others["hair"]["spiky"] = spiky
    others["torso"]["gi"] = torso_gi(content["torso"], p)
    others["pants"]["gi"] = pants_gi(p, up, masks)
    others["boots"]["gi"] = boots_trimmed(p, up, masks)
    bands = gloves_wristbands(p, masks)
    if bands is not None:
        others["gloves"]["wristbands"] = bands
    tank = cut(up, masks["torso"] & ~p.sleeve)
    detail_torso(tank, p, "tank")
    others["torso"]["tank"] = tank
    others["torso"]["long"] = torso_long(content["torso"], p)
    plain_pants = cut(up, masks["pants"])
    detail_belt(plain_pants, p)
    others["pants"]["plain"] = plain_pants
    others["boots"]["plain"] = cut(up, masks["boots"])
    if gun == "wave":                                                # (the martial-arts shooting pose: the arm behind is gone, the ball is held in both hands)
        keep = to_l(~rear_arm(p))
        for part in content:
            content[part] = cut(content[part], np.asarray(keep) > 127)
        for styles in others.values():
            for style in styles:
                styles[style] = cut(styles[style], np.asarray(keep) > 127)
        if wave_hands is not None:
            content["gun"] = wave_hands
    return p, content, others


def outlined(p, content, others):
    """Every picture with its outlines: {(part, style or None): picture}. A layer is outlined all round; the line is thin where there is another layer under it (so parts
    meet in a fine line) and strong where there is nothing (the outside of the figure); under the flat jaw it is strong too. Pictures with nothing in them are left out."""
    out = {}
    below = np.zeros((H * S, W * S), bool)
    for part in PARTS:
        for style, picture in [(None, content[part])] + list(others.get(part, {}).items()):
            if picture.getchannel("A").getbbox() is None:
                continue
            strong_zone = ImageChops.invert(to_l(below))
            if part == "head":                 # (the head has a strong outline all round, over an arm raised beside it too; under the flat jaw as well)
                strong_zone = Image.new("L", strong_zone.size, 255)
            if (part, style) == ("hair", "spiky"):                    # (drawn by hand with its outline)
                out[(part, style)] = picture
                continue
            alpha = picture.getchannel("A")
            thin = art_lib.outline(alpha, INNER_WIDTH, OUTLINE)
            thin.putalpha(ImageChops.multiply(thin.getchannel("A"), ImageChops.invert(strong_zone)).point(lambda v: int(v * INNER_ALPHA)))
            strong = art_lib.outline(alpha, OUTER_WIDTH, OUTLINE)
            strong.putalpha(ImageChops.multiply(strong.getchannel("A"), strong_zone))
            layer = picture.copy()
            layer.alpha_composite(thin)
            layer.alpha_composite(strong)
            out[(part, style)] = layer
        below |= np.asarray(content[part].getchannel("A")) > 40
    return out


def stack(layers, swap=None):
    """The layers drawn one over the other (the original look of every part, but `swap` = (part, style) uses that style of that part): the whole figure."""
    figure = blank()
    for part in PARTS:
        key = swap if swap is not None and swap[0] == part else (part, None)
        if key in layers:
            figure.alpha_composite(layers[key])
    return figure



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


# Frame: what to draw for one pose. `up` the original's pixels at the big size, `stern` firm calm brows (else the original's), `gun` the EMP gun in the fist, `blink` the
# eyes shut, `base` for a pose that only has its own head: the pose whose other parts it shares (else None).
Frame = namedtuple("Frame", "up stern gun blink base")


def frames():
    """Every pose to draw: name -> Frame."""
    idle, walk1, walk2 = widen(source("idle")), widen(source("walk1")), widen(source("walk2"))
    out = {}
    for k, b in enumerate((1.0, 1.015, 1.03)):          # (the breath goes in, then out through the middle picture again)
        base = stretch_upper(idle, 90, b)
        out["idle%d" % (k + 1)] = Frame(base, True, False, False, None)
        out["blink%d" % (k + 1)] = Frame(base, True, False, True, "idle%d" % (k + 1))
    out["look"] = Frame(eyes_look(stretch_upper(idle, 90, 1.015), -1.0, -1.2), True, False, False, "idle2")
    out["walk1"], out["walk2"] = Frame(walk1, True, False, False, None), Frame(walk2, True, False, False, None)
    for name in ("jump", "fall", "hurt", "action1", "action2", "climb1", "climb2"):
        out[name] = Frame(widen(source(name)), False, False, False, None)
    out["shoot"] = Frame(widen(source("action2")), False, "emp", False, None)
    out["wave"] = Frame(widen(source("action2")), False, "wave", False, None)
    return out


def contact_sheet(images, cols=7):
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * W, rows * H), (40, 48, 70, 255))
    for i, im in enumerate(images):
        sheet.alpha_composite(im, ((i % cols) * W, (i // cols) * H))
    return sheet



# STYLE_FOLDERS: the folder name of each style of a part with styles, keyed by the style's name in this script (None is the original style). The wardrobe lists a part's
# styles by looking at these folders (WardrobeCatalog), so the folder name is what the player's screen shows (upper case, "_" as a space). A part with no styles (head, arms,
# gun) has its pictures straight in its folder.
STYLE_FOLDERS = {
    "hair": {None: "quiff", "crop": "crop", "spiky": "spiky"},
    "goggles": {None: "on_chest", "glasses": "glasses", "visor": "visor"},
    "torso": {None: "t_shirt", "long": "long_sleeves", "tank": "sleeveless", "gi": "martial_gi"},
    "gloves": {None: "fingerless", "wristbands": "wristbands"},
    "pants": {None: "cargo", "plain": "plain", "gi": "martial_gi"},
    "boots": {None: "sneakers", "plain": "plain", "gi": "martial_boots"},
}


# MANIFEST: the fingerprint (SHA-1) of every picture this script wrote, last time. A picture whose file no longer has its fingerprint was edited by hand, and the script leaves it alone
# (`--force` draws everything again). Without this, running the generator would wipe every manual touch-up of the pictures.
MANIFEST = os.path.join(HERE, "player_pictures.json")


def file_hash(path):
    with open(path, "rb") as f:
        return hashlib.sha1(f.read()).hexdigest()


def load_manifest():
    if not os.path.exists(MANIFEST):
        return {}
    with open(MANIFEST, encoding="utf8") as f:
        return json.load(f)


def save_manifest(entries):
    with open(MANIFEST, "w", encoding="utf8") as f:
        json.dump(entries, f, indent=1, sort_keys=True)
        f.write("\n")


def hand_edited(target, expected):
    """True if the file exists and is not what this script wrote last time (`expected` is that fingerprint, None if the script never wrote it)."""
    return expected is not None and os.path.exists(target) and file_hash(target) != expected


def file_name(pose, part, style):
    """The picture's path below the player's folder: <part>/<style folder>/player_<pose>_<part>.png (<part>/player_<pose>_<part>.png for a part with no styles)."""
    folder = part if part not in STYLE_FOLDERS else "%s/%s" % (part, STYLE_FOLDERS[part][style])
    return "%s/player_%s_%s.png" % (folder, pose, part)


def main():
    global REF
    REF = Parts(widen(source("idle")))
    REF.shirt_main = components(REF.shirt, 30)[0]
    global SPIKY_REF
    ref_hair = np.nonzero(partition(REF)["hair"])[1]
    SPIKY_REF = eyes_anchor(REF) + ((ref_hair.max() - ref_hair.min()) / S,)
    force = "--force" in sys.argv
    manifest = load_manifest()
    written, kept = {}, []
    layered = {}
    for name, frame in frames().items():
        p, content, others = build(frame.up, frame.stern, frame.gun, frame.blink)
        layered[name] = outlined(p, content, others)
        for (part, style), picture in layered[name].items():
            if frame.base is None or (part == "head" and style is None):
                relative = file_name(name, part, style)
                target = os.path.join(OUT, relative)
                os.makedirs(os.path.dirname(target), exist_ok=True)
                if not force and hand_edited(target, manifest.get(relative)):
                    kept.append(relative)
                    written[relative] = manifest[relative]
                    continue
                if (part, style) == ("hair", "spiky"):                  # (the hand-drawn hair: one pixel taken from every block, so its pixels come out exactly as drawn)
                    Image.fromarray(np.array(picture)[S // 2::S, S // 2::S]).save(target)
                else:
                    art_lib.finish(picture, target)
                written[relative] = file_hash(target)
    for relative in sorted(set(manifest) - set(written)):                        # (pictures of a style or pose that is no more: removed, unless they were edited by hand)
        target = os.path.join(OUT, relative)
        if os.path.exists(target) and not hand_edited(target, manifest[relative]):
            os.remove(target)
    save_manifest(written)
    if kept:
        print("kept %d hand-edited pictures (run with --force to redraw them): %s" % (len(kept), ", ".join(kept)))
    previews = []
    for name, frame in frames().items():
        layers = dict(layered[frame.base]) if frame.base else {}
        layers.update({k: v for k, v in layered[name].items() if frame.base is None or k == ("head", None)})
        previews.append(stack(layers).resize((W, H), Image.LANCZOS))
    sheet = contact_sheet(previews)
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(art_lib.preview_path("player_sheet.png"))
    standing = layered["idle1"]
    swaps = [(part, style) for (part, style) in standing if style is not None] + [("hair", "none"), ("goggles", "none"), ("gloves", "none")]
    styles = contact_sheet([stack(standing).resize((W, H), Image.LANCZOS)] + [stack(standing, swap).resize((W, H), Image.LANCZOS) for swap in swaps], cols=5)
    styles.resize((styles.width * 2, styles.height * 2), Image.NEAREST).save(art_lib.preview_path("player_styles.png"))
    print("frames: %d   muzzle at (%.1f, %.1f) in a %dx%d frame   styles shown: %s" % (len(previews), MUZZLE[0], MUZZLE[1], W, H, swaps))


if __name__ == "__main__":
    main()
