#!/usr/bin/env python3
"""Compare le MOTIF des gommes du stage 4 entre deux sources.

    # extraire le motif d'une capture (arcade ou TO8) et l'ecrire en .txt
    python3 ci/toje-bench/gum_pattern.py extract arcade.png --out arcade.txt

    # comparer deux motifs, quelle que soit leur origine
    python3 ci/toje-bench/gum_pattern.py compare arcade.txt nous.txt

    # extraire le motif depuis la carte du jeu (dump RAM de pscroll.gum.map)
    python3 ci/toje-bench/gum_pattern.py frommap gum.bin --out nous.txt

Pourquoi comparer des MOTIFS et pas des pixels : une tuile de gomme arcade
(8 x 8 px) vaut EXACTEMENT une cellule v2 (3 x 6 px) — c'est la coincidence
d'echelle sur laquelle tout le stage 4 est construit. Les deux mondes ont donc
la meme grille logique, et leurs motifs sont directement superposables une fois
ramenes en matrices de booleens. Ce qui reste apres alignement est un vrai
ecart de trace, pas une difference de resolution.

L'extraction depuis une image ne suppose ni l'echelle ni le cadrage : le pas de
grille et la phase sont trouves par autocorrelation des projections, donc une
capture arcade 4x, un emulateur 2x ou une photo d'ecran passent pareil.
"""
import argparse
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit("Pillow requis : python3 -m pip install pillow")


# --- detection des pixels "gomme" ------------------------------------------
def is_gum(rgb, core_only=False):
    """Une gomme est verte, souvent avec un coeur clair/orange.

    --core ne garde que le COEUR AMBRE : c'est la signature propre de la perle
    arcade, et elle ne se confond pas avec le decor organique vert du stage,
    qui sinon pollue la detection (mesure : 44 detectees pour 32 reelles sur
    une capture TO8 en mode vert).
    """
    r, g, b = rgb
    amber = r > 150 and 90 < g < 210 and b < 100
    if core_only:
        return amber
    green = g > 90 and g > b + 40 and g >= r - 40
    return green or amber


def mask(im, core_only=False):
    w, h = im.size
    px = im.load()
    return [[is_gum(px[x, y], core_only) for x in range(w)] for y in range(h)]


def period_and_phase(counts, lo=8, hi=64):
    """Pas de grille et phase, par autocorrelation de la projection.

    PLANCHER A 8 : sous ce seuil on accroche les harmoniques du rendu (le TO8
    double ses pixels en x, l'arcade est affichee 3 a 4 fois trop grande) et
    on prend un pas de 4 px pour une grille qui en fait 13.
    """
    n = len(counts)
    mean = sum(counts) / max(1, n)
    sig = [c - mean for c in counts]
    best_p, best_score = None, 0.0
    for p in range(lo, hi):
        s = sum(sig[i] * sig[i + p] for i in range(n - p))
        s /= (n - p)
        if s > best_score:
            best_p, best_score = p, s
    if best_p is None:
        return None, None
    # phase : le decalage qui maximise la somme des projections
    best_ph, best_sum = 0, -1
    for ph in range(best_p):
        t = sum(counts[i] for i in range(ph, n, best_p))
        if t > best_sum:
            best_ph, best_sum = ph, t
    return best_p, best_ph


def extract(path, verbose=True, pitch=None, core=False):
    im = Image.open(path).convert("RGB")
    m = mask(im, core)
    h, w = len(m), len(m[0])
    colcount = [sum(1 for y in range(h) if m[y][x]) for x in range(w)]
    rowcount = [sum(1 for x in range(w) if m[y][x]) for y in range(h)]
    total = sum(colcount)
    if total < 200:
        sys.exit("%s : seulement %d pixels de gomme detectes — mauvais mode ?\n"
                 "  --core ne convient qu'aux perles ARCADE (coeur ambre) ;\n"
                 "  un rendu TO8 se lit sans --core." % (path, total))
    if pitch:
        pw, ph = pitch
        _, phx = period_and_phase(colcount, pw, pw + 1)
        _, phy = period_and_phase(rowcount, ph, ph + 1)
    else:
        pw, phx = period_and_phase(colcount)
        ph, phy = period_and_phase(rowcount)
    if not pw or not ph:
        sys.exit("grille introuvable : pas assez de gommes dans %s" % path)
    if verbose:
        print("%s : %dx%d, pas de grille %d x %d px, phase (%d,%d)"
              % (path, w, h, pw, ph, phx, phy))
    # echantillonnage au centre de chaque cellule, vote majoritaire
    cols, rows = (w - phx) // pw, (h - phy) // ph
    grid = []
    for r in range(rows):
        line = []
        for c in range(cols):
            x0, y0 = phx + c * pw, phy + r * ph
            hits = sum(1 for yy in range(y0 + ph // 4, y0 + 3 * ph // 4)
                       for xx in range(x0 + pw // 4, x0 + 3 * pw // 4)
                       if 0 <= yy < h and 0 <= xx < w and m[yy][xx])
            area = max(1, (ph // 2) * (pw // 2))
            line.append(hits * 2 > area)
        grid.append(line)
    return grid


def from_map(path, width_bytes=48):
    raw = open(path, "rb").read()
    rows = len(raw) // width_bytes
    return [[bool((raw[r * width_bytes + (c >> 3)] >> (7 - (c & 7))) & 1)
             for c in range(width_bytes * 8)] for r in range(rows)]


def dump(grid, out):
    with open(out, "w") as f:
        for line in grid:
            f.write("".join("#" if v else "." for v in line) + "\n")
    live = sum(sum(1 for v in l if v) for l in grid)
    print("-> %s : %d x %d cellules, %d pleines"
          % (out, len(grid[0]), len(grid), live))


def load(path):
    return [[ch == "#" for ch in line.rstrip("\n")]
            for line in open(path) if line.strip()]


def compare(a, b, span=12):
    """Aligne b sur a et rend le meilleur score + la carte des ecarts.

    Le balayage en x couvre TOUTE la difference de largeur : une capture ne
    montre qu'une fenetre du niveau, alors qu'un dump de pscroll.gum.map
    couvre les 384 colonnes — il faut retrouver ou la fenetre se pose.
    """
    ha, wa = len(a), len(a[0])
    hb, wb = len(b), len(b[0])
    spanx = max(span, abs(wb - wa) + span)
    spany = max(span, abs(hb - ha) + span)
    best = None
    for dy in range(-spany, spany + 1):
        for dx in range(-spanx, spanx + 1):
            same = union = 0
            for y in range(ha):
                yy = y + dy
                if not (0 <= yy < hb):
                    continue
                ra, rb = a[y], b[yy]
                for x in range(wa):
                    xx = x + dx
                    if not (0 <= xx < wb):
                        continue
                    va, vb = ra[x], rb[xx]
                    if va or vb:
                        union += 1
                        if va and vb:
                            same += 1
            if union and (best is None or same / union > best[0]):
                best = (same / union, dx, dy, same, union)
    if best is None:
        sys.exit("aucun recouvrement")
    score, dx, dy, same, union = best
    print("meilleur alignement : dx=%+d dy=%+d" % (dx, dy))
    print("recouvrement : %.1f %%  (%d cellules communes sur %d)"
          % (100 * score, same, union))
    only_a = only_b = 0
    for y in range(ha):
        yy = y + dy
        if not (0 <= yy < hb):
            continue
        for x in range(wa):
            xx = x + dx
            if not (0 <= xx < wb):
                continue
            if a[y][x] and not b[yy][xx]:
                only_a += 1
            elif b[yy][xx] and not a[y][x]:
                only_b += 1
    print("presentes seulement dans A : %d" % only_a)
    print("presentes seulement dans B : %d" % only_b)
    return best


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("extract", help="image -> motif")
    e.add_argument("image"); e.add_argument("--out", required=True)
    e.add_argument("--pitch", nargs=2, type=int, metavar=("W", "H"),
                   help="forcer le pas de grille en px image")
    e.add_argument("--core", action="store_true",
                   help="ne detecter que le coeur ambre (perles arcade)")
    m = sub.add_parser("frommap", help="dump de pscroll.gum.map -> motif")
    m.add_argument("bin"); m.add_argument("--out", required=True)
    m.add_argument("--width", type=int, default=48)
    c = sub.add_parser("compare", help="deux motifs")
    c.add_argument("a"); c.add_argument("b")
    c.add_argument("--span", type=int, default=12)
    args = ap.parse_args()

    if args.cmd == "extract":
        dump(extract(args.image, pitch=args.pitch, core=args.core), args.out)
    elif args.cmd == "frommap":
        dump(from_map(args.bin, args.width), args.out)
    else:
        compare(load(args.a), load(args.b), args.span)


if __name__ == "__main__":
    main()
