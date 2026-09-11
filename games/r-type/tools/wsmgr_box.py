"""La boite de pose que wsmgr teste AVANT les tranches (tools/gen_warship_slices.py
et gen_warship_flames.py l'ecrivent en tete de chaque liste, 10/09/2026).

Le test des tranches est un containment dans la fenetre elargie ([-8,168) en x,
strict en y) ; une tranche passe si son contenu (imageset x1/xsize, y1/ysize :
le contenu rogne, depuis l'ancre = centre du canevas, x1 = x_min - (w-1)//2,
gfxcomp Image.java) tient dans la fenetre. Le test de slot est EXACT : il
rejette la pose quand AUCUNE tranche ne peut passer, c'est-a-dire quand
  - le bord droit le plus a gauche (min des bords droits) depasse la fenetre
    (toutes sortent a droite), ou
  - le bord gauche le plus a droite (max des bords gauches) est avant la
    fenetre (toutes sortent a gauche) ;
de meme en y avec les bords bas/haut. Six octets depuis l'ancre :
  x1  = min des bords gauches            xw0 = min des bords droits - x1
  xdl = max des bords gauches - x1
  y1  = min des bords hauts              yh0 = min des bords bas - y1
  ydt = max des bords hauts - y1
wsmgr.asm : x + x1 - (screen_left-8) <= 176 ? (+ xw0 > 176 : rejet)
                                          : (+ xdl sans retenue : rejet).
"""


def boite(im, fenetres):
    """im : la pose (mode P, index 0 transparent) ; fenetres : ses tranches en
    (x0, y0, x1, y1). Rend 'x1,xw0,xdl,y1,yh0,ydt' en octets signes."""
    w, h = im.size
    px = im.tobytes()
    cx, cy = (w - 1) // 2, (h - 1) // 2
    L, R, T, B = [], [], [], []
    for x0, y0, x1, y1 in fenetres:
        xs = [x for y in range(y0, y1) for x in range(x0, x1) if px[y * w + x]]
        ys = [y for y in range(y0, y1) for x in range(x0, x1) if px[y * w + x]]
        if not xs:
            continue
        L.append(min(xs) - cx); R.append(max(xs) + 1 - cx)
        T.append(min(ys) - cy); B.append(max(ys) + 1 - cy)
    assert L, 'pose vide'
    x1, y1 = min(L), min(T)
    vals = (x1, min(R) - x1, max(L) - x1, y1, min(B) - y1, max(T) - y1)
    assert all(-128 <= v <= 127 for v in vals), vals
    return ','.join(str(v) for v in vals)
