#!/usr/bin/env python3
"""Simulateur du trace des cytrons, A L'ECHELLE ARCADE 1:1.

    python3 ci/toje-bench/cytron_sim.py --wave 0 1 --frames 900 --out sim.png

Rejoue la logique de run_cytron (arcade 0x40:69B4) sur les DONNEES exportees
de la borne, dans un ecran virtuel de 384 x 256 px arcade, tuiles de 8 px.
Le but est d'avoir une REFERENCE INDEPENDANTE du portage : si le trace simule
est celui de la video d'arcade, la reference est bonne, et tout ecart du jeu
est alors imputable au portage — pas aux donnees.

Ce que la borne fait, par trame (plate 0x69B4) :
  1. move_by_script : consomme `bytes/frame` commandes du script bit-packe ;
  2. pos_x += scroll_amount — le cytron est ANCRE AU DECOR ;
  3. la repousse : lit (dx,dy) dans la table indexee par la POSE (0x1000:2D90,
     un cercle de rayon 12 px sur 16 directions), l'ajoute a la position,
     et ecrit UNE cellule si elle lit TILE_EMPTY.

Format du script (un octet = une commande, bits de poids fort en tete) :
  bit7 = 1            -> changement d'image : pose = octet & 0x7F, et la
                         commande NE COMPTE PAS dans le quota de la trame
  bit6=1 bit5=1       -> x -= 1        bit6=0 bit5=1 -> x += 1
  bit4=0 bit3=1       -> y -= 1 (haut) bit4=1 bit3=1 -> y += 1 (bas)
  bit2 = 1            -> fin de segment : passer au suivant de la liste
Les segments d'un script sont une liste terminee par 0 ; un mot 0xF0xx change
le nombre de commandes par trame.
"""
import argparse
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
GAME = os.path.join(ROOT, "games", "r-type")

ARCADE_W, ARCADE_H, TILE = 384, 256, 8


def load_rom_image(path):
    """script.asm -> image memoire {offset: valeur}, mots et octets separes.

    Le fichier est un export brut de la borne : CHAQUE ligne porte son propre
    label `ref_1XXXX`, ou XXXX est l'offset dans le segment de donnees 0x1000.
    Les listes (segments d'un script) ne sont donc pas des tableaux d'assembleur
    mais des suites d'adresses consecutives — il faut reconstruire la memoire
    pour les parcourir comme la borne le fait.
    """
    words, bytes_ = {}, {}
    for line in open(path):
        m = re.match(r"^ref_1([0-9A-Fa-f]{4})\s+(fdb|fcb)\s+(.+?)\s*(;.*)?$",
                     line.rstrip("\n"))
        if not m:
            continue
        off, kind, ops = int(m.group(1), 16), m.group(2), m.group(3).strip()
        if kind == "fdb":
            mm = re.match(r"^ref_1([0-9A-Fa-f]{4})$", ops)
            words[off] = int(mm.group(1), 16) if mm else int(ops.lstrip("$"), 16)
        else:
            v = ops.strip()
            bytes_[off] = (int(v[1:], 2) if v.startswith("%")
                           else int(v[1:], 16) if v.startswith("$") else int(v))
    return words, bytes_


class Rom:
    """Les donnees exportees de la borne, telles qu'elles sont commitees."""

    def __init__(self):
        self.words, self.bytes = load_rom_image(
            os.path.join(GAME, "src/common/fx/animation/script.asm"))
        # la LUT commune : index -> etiquette de script
        self.lut = []
        for line in open(os.path.join(GAME, "src/common/fx/animation/index.asm")):
            m = re.search(r"fdb\s+ref_1([0-9A-Fa-f]{4})", line)
            if m:
                self.lut.append(int(m.group(1), 16))
        # variante de cytron -> (index LUT, commandes par trame)
        self.variant = []
        src = open(os.path.join(GAME, "src/enemies/cytron/movescript.asm")).read()
        tbl = src[src.index("cytron.script.tbl"):]
        equ = dict(re.findall(r"^(\w+)\s+equ\s+(\d+)", open(
            os.path.join(GAME, "src/common/fx/animation/index.equ")).read(), re.M))
        for name, speed in re.findall(r"fdb\s+(\w+)\s*;[^\n]*\n\s*fcb\s+(\d+)", tbl):
            # les equates de index.equ sont des OFFSETS EN OCTETS dans la LUT
            # (moveByScript.initialize fait `ldx anim.addr,x`), pas des index :
            # une entree fait deux octets.
            self.variant.append((int(equ[name]) // 2, int(speed)))
        # le cercle de semis, EN UNITES ARCADE (la table d'origine)
        self.trail = [(-12,0),(-10,4),(-8,8),(-4,10),(0,12),(4,10),(8,8),(10,4),
                      (12,0),(10,-4),(8,-8),(4,-10),(0,-12),(-4,-10),(-8,-8),(-10,-4)]
        # presets xy : la table commitee est DEJA convertie en v2, on revient
        # a l'arcade par l'inverse exact de l'export (cf. l'en-tete de Init)
        self.preset = []
        for line in open(os.path.join(GAME, "src/common/lib/presets/18dd0_preset-xy.asm")):
            m = re.search(r"fcb\s+\$([0-9A-Fa-f]+),\$([0-9A-Fa-f]+)", line)
            if m:
                vx, vy = int(m.group(1), 16), int(m.group(2), 16)
                ax = (vx - 8) / 0.375 + 320
                ay = 392 - (vy - 3) / 0.75      # axe inverse, ancre sur y=392 -> 3
                self.preset.append((ax, ay))


class Cytron:
    """Un cytron, tel que run_cytron le fait vivre."""

    def __init__(self, rom, subtype):
        self.rom = rom
        lut_idx, self.speed = rom.variant[(subtype >> 4) & 0x0F]
        self.script = rom.lut[lut_idx]        # offset de la liste de segments
        self.seg_ptr = self.script            # ou on en est dans la liste
        self.seg = rom.words.get(self.script, 0)   # offset du segment courant
        self.p = self.seg
        self.pose = 0
        self.alive = self.seg != 0
        self.x, self.y = rom.preset[subtype & 0x0F]
        # 0x6984 : `ADD word ptr [SI+0x8], 4`. On travaille dans le repere
        # ARCADE, ou y croit VERS LE HAUT (la table de presets le prouve :
        # arcade y=392 est en haut de l'ecran, y=136 en bas). C'est donc bien
        # une addition ici — la v2, dont l'axe est inverse, la porte en `subd`.
        self.y += 4

    def _next_segment(self):
        """0xFA0E : avancer dans la liste ; 0 = fin de script."""
        self.seg_ptr += 2
        w = self.rom.words.get(self.seg_ptr, 0)
        if w == 0:
            self.alive = False
            return
        if (w >> 8) == 0xF0:                  # 0xF0xx : change la cadence
            self.speed = w & 0xFF
            self._next_segment()
            return
        self.seg, self.p = w, w

    def step_frame(self, scroll):
        left = self.speed
        guard = 0
        while left > 0 and self.alive and guard < 4096:
            guard += 1
            b = self.rom.bytes.get(self.p)
            if b is None:                     # hors segment connu
                self.alive = False
                break
            self.p += 1
            if b & 0x80:                      # changement d'image, hors quota
                self.pose = b & 0x7F
                continue
            if b & 0x20:
                self.x += -1 if (b & 0x40) else 1
            if b & 0x08:
                self.y += -1 if (b & 0x10) else 1
            left -= 1
            if b & 0x04:
                self._next_segment()
        self.x += scroll

    def sow(self):
        dx, dy = self.rom.trail[self.pose & 0x0F]
        # 0x69F2/0x69F5 : `ADD [BP+4], AX` et `ADD [BP+8], CX` — la table est
        # dans le repere arcade et la position aussi, donc on ADDITIONNE les
        # deux composantes. (La v2 retranche dy parce que SON axe est inverse ;
        # ici ce serait une double inversion.)
        return (int((self.x + dx) // TILE), int((self.y + dy) // TILE))


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--wave", nargs="*", type=int, default=[0, 1],
                    help="indices des cytrons dans la wave du stage 4")
    ap.add_argument("--frames", type=int, default=900)
    ap.add_argument("--scroll", type=float, default=0.5,
                    help="px arcade par trame (R-Type : 0,5)")
    ap.add_argument("--out", default="cytron_sim.png")
    ap.add_argument("--txt", help="ecrire aussi le motif en texte")
    args = ap.parse_args()

    rom = Rom()
    wave = []
    for line in open(os.path.join(GAME, "src/stages/04/wave.asm")):
        m = re.search(r"fcb\s+\$(\w\w),\$(\w\w),ObjID_cytron,\$(\w\w),\$(\w\w)", line)
        if m:
            wave.append((int(m.group(1), 16) * 256 + int(m.group(2), 16),
                         int(m.group(4), 16)))
    print("cytrons dans la wave : %d" % len(wave))
    picked = [wave[i] for i in args.wave if i < len(wave)]
    for i, (t, st) in zip(args.wave, picked):
        v = (st >> 4) & 0xF
        print("  #%d : t=$%04X subtype=$%02X -> variante %d (script %s, %d cmd/trame),"
              " preset %d -> depart arcade (%.0f, %.0f)"
              % (i, t, st, v, rom.lut[rom.variant[v][0]], rom.variant[v][1],
                 st & 0xF, *rom.preset[st & 0xF]))

    cells = set()
    actors = [(t, Cytron(rom, st)) for t, st in picked]
    scroll_acc = 0.0
    for f in range(args.frames):
        for t0, c in actors:
            if f * 4 < t0 or not c.alive:      # la wave compte en 1/4 de trame
                continue
            c.step_frame(args.scroll)
            cells.add(c.sow())
    xs = [c[0] for c in cells]; ys = [c[1] for c in cells]
    print("%d cellules semees, etendue x %d..%d, y %d..%d"
          % (len(cells), min(xs), max(xs), min(ys), max(ys)))

    try:
        from PIL import Image, ImageDraw
    except ImportError:
        sys.exit("Pillow requis pour le rendu")
    W = (max(xs) - min(xs) + 3) * TILE
    H = (max(ys) - min(ys) + 3) * TILE
    im = Image.new("RGB", (W * 2, H * 2), (0, 0, 0))
    d = ImageDraw.Draw(im)
    for cx, cy in cells:
        # RETOURNEMENT POUR L'AFFICHAGE : nos cellules sont en repere arcade
        # (y vers le haut), l'image a son origine en haut a gauche.
        x0 = (cx - min(xs) + 1) * TILE * 2
        y0 = (max(ys) - cy + 1) * TILE * 2
        d.ellipse([x0 + 1, y0 + 1, x0 + TILE*2 - 2, y0 + TILE*2 - 2],
                  fill=(90, 170, 70), outline=(150, 220, 120))
        d.ellipse([x0 + 5, y0 + 5, x0 + TILE*2 - 6, y0 + TILE*2 - 6],
                  fill=(210, 140, 40))
    im.save(args.out)
    print("-> %s (%d x %d, echelle 2x)" % (args.out, W, H))
    if args.txt:
        with open(args.txt, "w") as f:
            for r in range(max(ys), min(ys) - 1, -1):   # haut de l'ecran d'abord
                f.write("".join("#" if (c, r) in cells else "."
                                for c in range(min(xs), max(xs) + 1)) + "\n")
        print("-> %s" % args.txt)


if __name__ == "__main__":
    main()
