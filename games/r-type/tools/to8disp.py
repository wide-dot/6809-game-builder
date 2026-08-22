"""Ce que le TO8 AFFICHE d'une couleur stockee — l'algorithme exact de png2pal.

Une palette PNG stocke des valeurs sRGB quelconques ; le TO8 n'en connait
que 4096 (16 niveaux de DAC par composante, rien entre 0 et 97). Au build,
`png2pal` remplace chaque couleur par la plus proche du gamut — et ce
« plus proche » se mesure en **CIEDE2000**, pas en dE76 :

    Png2PalPlugin.getNearestColor : LAB.ciede2000 sur les 4096 entrees
    LAB.fromRGBr(r, g, b, 1.0)    : Lab D65, composantes arrondies au bin 1.0

Reproduire ce choix est la condition d'un apercu honnete. Approcher png2pal
par un dE76 se paie sur les couleurs sombres, ou les deux metriques
divergent completement — vecu sur le stage 3 : #304020 s'affiche #006100
(un vert vif) la ou dE76 annoncait un gris-vert, et deux campagnes couleur
ont ete jugees sur ce mauvais rendu (20/08/2026).

Regle qui en decoule, appliquee par arcade_to_in : **un emplacement de
palette recoit une valeur que le TO8 sait afficher** (displayed(c) est
idempotent). L'editeur de palette montre alors ce que l'ecran montrera.

    from to8disp import displayed
    displayed((48, 64, 32))   -> (0, 97, 0)
"""
import math

TO = [0, 97, 122, 143, 158, 171, 184, 194, 204, 212, 219, 227, 235, 242, 250, 255]
GAMUT = [(r, g, b) for r in TO for g in TO for b in TO]


def lab(rgb, binSize=1.0):
    r, g, b = [v / 255.0 for v in rgb]
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = f(r), f(g), f(b)
    X, Y, Z = 0.950470, 1.0, 1.088830
    x = (0.4124564 * r + 0.3575761 * g + 0.1804375 * b) / X
    y = (0.2126729 * r + 0.7151522 * g + 0.0721750 * b) / Y
    z = (0.0193339 * r + 0.1191920 * g + 0.9503041 * b) / Z
    q = lambda t: t ** (1 / 3) if t > 0.008856 else 7.787037 * t + 4.0 / 29
    x, y, z = q(x), q(y), q(z)
    L, A, B = 116 * y - 16, 500 * (x - y), 200 * (y - z)
    if binSize > 0:
        L = binSize * round(L / binSize)
        A = binSize * round(A / binSize)
        B = binSize * round(B / binSize)
    return (L, A, B)


def ciede2000(l1, l2):
    L1, a1, b1 = l1
    L2, a2, b2 = l2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb ** 7 / (Cb ** 7 + 25.0 ** 7))) if Cb > 0 else 0.5
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if (a1p or b1) else 0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if (a2p or b2) else 0
    dLp, dCp = L2 - L1, C2p - C1p
    if C1p * C2p == 0:
        dhp = 0
    else:
        d = h2p - h1p
        dhp = d - 360 if d > 180 else (d + 360 if d < -180 else d)
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dhp) / 2)
    Lbp, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    if C1p * C2p == 0:
        hbp = h1p + h2p
    else:
        s = h1p + h2p
        hbp = (s + 360) / 2 if abs(h1p - h2p) > 180 and s < 360 else (
            (s - 360) / 2 if abs(h1p - h2p) > 180 else s / 2)
    T = (1 - 0.17 * math.cos(math.radians(hbp - 30))
         + 0.24 * math.cos(math.radians(2 * hbp))
         + 0.32 * math.cos(math.radians(3 * hbp + 6))
         - 0.20 * math.cos(math.radians(4 * hbp - 63)))
    dTh = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * math.sqrt(Cbp ** 7 / (Cbp ** 7 + 25.0 ** 7)) if Cbp > 0 else 0
    Sl = 1 + (0.015 * (Lbp - 50) ** 2) / math.sqrt(20 + (Lbp - 50) ** 2)
    Sc, Sh = 1 + 0.045 * Cbp, 1 + 0.015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dTh)) * Rc
    return math.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2
                     + Rt * (dCp / Sc) * (dHp / Sh))


_GLAB = None
_CACHE = {}


def displayed(c):
    """La couleur que le TO8 affiche pour la valeur stockee `c`."""
    global _GLAB
    c = tuple(c)
    if c in _CACHE:
        return _CACHE[c]
    if _GLAB is None:
        _GLAB = [lab(g) for g in GAMUT]
    lc = lab(c)
    j = min(range(4096), key=lambda k: ciede2000(lc, _GLAB[k]))
    _CACHE[c] = GAMUT[j]
    return _CACHE[c]
