#!/usr/bin/env python3
"""Genere les tables de la sequence de fin (stage 8) depuis la ROM arcade.

La fin est portee en REPERE ARCADE, comme les boss : les tables sont
recopiees TELLES QUELLES.

  1000:945C  la flotte : 18 vaisseaux {script, y, palette} (spawn_floating_
             score_pickups 40:FB10 — le nom Ghidra est faux, c'est la flotte
             de R-9 du generique), la palette ecrite en RANG de couleur
             (l'ordre de images/fleet : 0x02, 0x64..0x68)
  les SCRIPTS de la flotte (run_floating_score_pickup 40:FB53) : entrees de
             8 octets {debut, vx, vy, image}, une plage BRUTE de la ROM, celle
             que les vaisseaux lisent vraiment (une emulation la trouve)
  1000:88E8  la table des lignes du directeur (40:EF1E), en RANG de descripteur
  les DESCRIPTEURS de texte (blit_text_string_fg 40:ED93) : {attr, 0, long,
             1, x, ligne} puis les caracteres. Ils sont ecrits deux fois :
             la ligne de tilemap et le rang de chaine (0 = ligne blanche, qui
             efface) pour le directeur, la chaine pour le dessin, residente
             (le dessin monte la page du HUD, dont la police fait le texte)

LES LIGNES DU GENERIQUE (17/10/2026) : les glyphes du HUD (DRAW_text_* de
src/common/hud/hud.asm, 4x8, deux plans) sont relus en simulant leur code
compile, et chaque ligne du generique devient UNE image (images/lines/NN.png,
index 0 = transparent) que <gfxcomp> compile en un sprite transparent : au-
dessus des etoiles, sous les vaisseaux, et d'un seul appel par ligne — mesure
sur les 580 rendus de la sequence, 53 a 56 % de cycles en moins que glyphe
par glyphe (pire rendu 15 706 contre 34 868).
LE CADRE DU VIEWPORT : les colonnes noires du masque du jeu (src/common/hud/
mask/images/00.png) sur les lignes du champ, 11 a 190 — et elles seules : les
bandes du haut et du bas sont noires depuis l'effacement de la route de fin
et rien n'y dessine (la flotte reste entre les lignes 12 et 186, le texte
entre 11 et 190), les colonnes, elles, sont salies par les vaisseaux qui
entrent et sortent. Plus la fin de la ligne 10 (pixels 112 a 159) :
l'effacement du champ (playfield.clearBlast) empile du noir avec S de la
ligne 190 a la ligne 11, et une IRQ qui tombe a la fin pose ses 12 octets
sous S, octets 28 a 39 de la ligne 10 (releve sous toje, le masque du jeu
le cache en jeu). Une image que <gfxcomp> compile (images/viewport/00.png).

LA FLOTTE PRECALCULEE (17/10/2026) : le vol des 18 R-9 (run_floating_score_
pickup 40:FB53 : un compteur par trame, l'entree suivante du script quand il
atteint son debut, la vitesse de l'entree courante ajoutee, sortie a x >=
0x2E0) est simule ICI, trame par trame, depuis la creation de la flotte ; ses
fractions de depart sont celles que la borne laisse (le record precedent),
lues dans la reference MAME. La position ECRAN et la pose ne changent que
3 026 fois sur 23 450 trames-vaisseau : chaque vaisseau devient une liste
d'enregistrements {x, y, pose | trames avant le suivant}, et le runtime ne
fait plus que comparer l'horloge a l'echeance suivante et recopier.

Sorties : src/stages/08/ending/tables.asm (l'unite de la fin),
          src/stages/08/ending/fleet.asm (l'unite de la flotte, fleet.unit),
          src/stages/08/ending/text.asm (l'unite du generique, credits.unit),
          images/lines/NN.png et images/viewport/00.png.
Rejeu : python3 tools/gen_ending.py (depuis games/r-type/) ;
        python3 tools/gen_ending.py --check dit si les sorties sont a jour.
"""
import os
import re
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT_TABLES = 'src/stages/08/ending/tables.asm'
OUT_TEXT = 'src/stages/08/ending/text.asm'
OUT_FLEET = 'src/stages/08/ending/fleet.asm'
REF = 'tools/fidelity/ref/ending.ref.jsonl.gz'
T_FLEET = 17013 - 16698                              # ending.T_FLEET
SCREEN_LEFT, SCREEN_TOP = 48, 28                     # engine/constants.asm
HUD = 'src/common/hud/hud.asm'
LINES_DIR = 'src/stages/08/ending/images/lines'
VIEW_OUT = 'src/stages/08/ending/images/viewport/00.png'
MASK = 'src/common/hud/mask/images/00.png'
FIELD_ROWS = range(11, 191)                          # the playfield's lines
IRQ_FRAME = (10, range(112, 160))   # where an IRQ during clearBlast lands
PALETTE_FROM = 'src/stages/08/ending/images/fleet/00.png'

COLOURS = [0x02, 0x64, 0x65, 0x66, 0x67, 0x68]      # images/fleet, by rank
POSES = [0x96D6, 0x96E2, 0x96EE]                     # cells 0x20, 0x22, 0x24
FIRST = [0x8A02, 0x8A20]                             # 40:EEE5, EEEE
ENJOY = 0x8B88                                       # 40:EF64
TO8_RIGHT_COL = 38                                   # x 152: the playfield's edge


def w(rom, a):
    return struct.unpack_from('<H', rom, SEG + a)[0]


def sw(rom, a):
    return struct.unpack_from('<h', rom, SEG + a)[0]


def ships(rom):
    out, a = [], 0x945C
    while True:
        out.append((w(rom, a), w(rom, a + 2), w(rom, a + 4)))
        a += 6
        if w(rom, a) == 0:
            return out


def script_range(rom, fleet):
    """every byte a ship reads until it leaves at x >= 0x2E0 (40:FB83)"""
    used = set()
    for scr, _y, _p in fleet:
        bx, c12, x = scr, 0, 0x120 << 8
        for _ in range(4000):
            c12 += 1
            used.update(range(bx, bx + 10))
            nxt = w(rom, bx + 8)
            cur = bx
            if c12 >= nxt:
                bx += 8
            x += sw(rom, cur + 2)
            if (x >> 8) >= 0x2E0:
                break
    return min(used), max(used) + 1


def lines(rom):
    out, a = [], 0x88E8
    while True:
        v = w(rom, a)
        out.append(v)
        a += 2
        if v == 0:
            return out


def descriptor(rom, d):
    n = rom[SEG + d + 2]
    return {'attr': rom[SEG + d], 'len': n, 'x': rom[SEG + d + 4],
            'row': rom[SEG + d + 5], 'text': rom[SEG + d + 6:SEG + d + 6 + n].decode('ascii')}


def to8_text(desc):
    """the arcade's font draws '/' as a full stop and ':' as '!' ; the line
    keeps its leading spaces as a column shift, its trailing ones go"""
    t = desc['text'].replace('/', '.').replace(':', '!')
    lead = len(t) - len(t.lstrip(' '))
    t = t.strip(' ')
    px = (desc['x'] // 4 - 8) * 8 + lead * 8         # arcade pixel of the first glyph
    col = (8 + px * 3 // 8) // 4                       # its TO8 byte column
    col = min(col, TO8_RIGHT_COL - len(t))             # whole on the playfield
    return col, t


def render(rom):
    table = lines(rom)
    descs = []
    for d in FIRST + [v for v in table if v] + [ENJOY]:
        if d not in descs:
            descs.append(d)
    named = [d for d in descs if descriptor(rom, d)['text'].strip(' ')]
    T = ['; GENERE par tools/gen_ending.py depuis la ROM arcade — ne pas editer.',
         '; Le directeur du generique (la flotte est dans fleet.asm).', '',
         '; les descripteurs : {ligne de tilemap, rang de chaine + 1 (0 = blanche)}',
         'ending.Desc']
    for d in descs:
        de = descriptor(rom, d)
        k = named.index(d) + 1 if d in named else 0
        T.append('        fcb   $%02X,%d                  ; %04X %s' % (de['row'], k, d, de['text'].rstrip()))
    T += ['', '; les deux premieres lignes (40:EEE5), la table du directeur (1000:88E8,',
          '; en rang de descripteur, $FF = fin) et ENJOY (40:EF64)',
          'ending.D_FIRST0 equ %d' % descs.index(FIRST[0]),
          'ending.D_FIRST1 equ %d' % descs.index(FIRST[1]),
          'ending.D_ENJOY  equ %d' % descs.index(ENJOY),
          'ending.Lines',
          '        fcb   ' + ','.join('%d' % descs.index(v) if v else '$FF' for v in table)]
    texts = [to8_text(descriptor(rom, d)) for d in named]
    X = ['; GENERE par tools/gen_ending.py depuis la ROM arcade — ne pas editer.',
         '; Les lignes du generique, par rang de chaine : le sprite compile de la',
         '; ligne (images/lines, gfxcomp cline_N) et sa colonne d\'octet TO8.', '',
         'ending.Lines']
    X.append('        fdb   ' + ','.join('adr_cline_%d_ND0' % i for i in range(len(texts))))
    X.append('ending.Cols')
    X.append('        fcb   ' + ','.join('%d' % c for c, _t in texts))
    for i, (col, t) in enumerate(texts):
        X.append('; %2d  colonne %2d  %s' % (i, col, t))
    return '\n'.join(T) + '\n', '\n'.join(X) + '\n', [t for _c, t in texts]


def fleet_asm(rom):
    """the fleet, flown frame by frame from its creation (40:FB10/FB53),
    reduced to its screen changes: per ship {x, y, pose << 6 | n} records,
    n = frames before the next one (1..63); the last record, off the screen
    with n = 0, is the ship gone; pose 3 = off the screen (not drawn). x and y are the slot's bytes
    (screen_left / screen_top added), 0-based screen x = (x - 320) * 3/8 + 8,
    y = 297 - 3y/4, as ending.ToScreen did."""
    import gzip, json
    first = None
    for line in gzip.open(REF, 'rt'):
        f = json.loads(line)
        if f['ships']:
            first = f
            break
    frac = {s[2]: (s[0] & 0xFF, s[1] & 0xFF) for s in first['ships']}   # by script
    fleet = ships(rom)
    out = ['; GENERE par tools/gen_ending.py depuis la ROM arcade — ne pas editer.',
           '; La flotte de la fin, precalculee : par vaisseau, {x, y, pose << 6 | n}',
           '; (n trames avant le suivant, 0 = le dernier : le vaisseau part ; pose 3 =',
           '; hors de l\'ecran). Premiere echeance : ending.T_FLEET.', '',
           'fleet.T0 equ %d' % T_FLEET, 'fleet.N  equ %d' % len(fleet), '',
           'fleet.Ships']
    out.append('        fdb   ' + ','.join('fleet.S%d' % i for i in range(len(fleet))))
    out.append('fleet.Cols                               ; colour rank x 3: the base of its pictures')
    out.append('        fcb   ' + ','.join('%d' % (3 * COLOURS.index(pal)) for _s, _y, pal in fleet))
    total = 0
    for i, (scr, y0, pal) in enumerate(fleet):
        fx, fy = frac.get(scr, (0, 0))
        p, c = scr, 0
        x, y = (0x120 << 8) | fx, (y0 << 8) | fy
        pose = 1
        states = []                                  # one per frame, from T0
        while True:
            xi, yi = x >> 8, y >> 8
            sx = ((xi - 320) * 3 >> 3) + 8 + SCREEN_LEFT
            sy = 297 - ((yi * 3) >> 2) + SCREEN_TOP
            vis = 0 <= sx <= 255 and 0 <= sy <= 255
            states.append((sx if vis else 0, sy if vis else 0, pose if vis else 3))
            c += 1
            wp = p
            if w(rom, p + 8) <= c:
                p += 8
            x += sw(rom, wp + 2)
            y += sw(rom, wp + 4)
            img = w(rom, wp + 6)
            pose = POSES.index(img) if img in POSES else 2
            if (x >> 8) >= 0x2E0:                    # fb83: gone this frame
                break
        recs = []
        for st in states:
            if recs and recs[-1][0] == st and recs[-1][1] < 63:
                recs[-1][1] += 1
            else:
                recs.append([st, 1])
        out.append('fleet.S%d                                 ; script $%04X, y $%04X, %d frames' % (i, scr, y0, len(states)))
        for st, n in recs:
            out.append('        fcb   %d,%d,$%02X' % (st[0], st[1], (st[2] << 6) | n))
        out.append('        fcb   0,0,$C0                  ; gone (40:FB83)')
        total += len(recs) + 1
    out.insert(5, '; %d enregistrements, %d octets' % (total, 3 * total))
    return '\n'.join(out) + '\n'


def fleet_check(rom):
    """the fleet flown here, against the MAME reference, frame by frame: the
    arcade positions (24 bits) of every ship — 0 when identical"""
    import gzip, json
    ref = [json.loads(l) for l in gzip.open(REF, 'rt')]
    first = next(f for f in ref if f['ships'])
    frac = {s[2]: (s[0] & 0xFF, s[1] & 0xFF) for s in first['ships']}
    trajs = []
    for scr, y0, _pal in ships(rom):
        fx, fy = frac[scr]
        p, c = scr, 0
        x, y = (0x120 << 8) | fx, (y0 << 8) | fy
        traj = [(x, y)]
        while True:
            c += 1
            wp = p
            if w(rom, p + 8) <= c:
                p += 8
            x += sw(rom, wp + 2)
            y += sw(rom, wp + 4)
            if (x >> 8) >= 0x2E0:
                break
            traj.append((x, y))
        trajs.append(traj)
    bad = 0
    for f in ref:
        k = f['gc'] - first['gc']
        if k < 0:
            continue
        mine = sorted(t[k] for t in trajs if k < len(t))
        if mine != sorted((s[0], s[1]) for s in f['ships']):
            bad += 1
    return bad


def hud_glyphs():
    """the HUD font, read back by simulating its compiled glyphs: char ->
    {offset from U: byte}, U on the glyph's 4th line in the $C000 plane, the
    other plane at -$2000"""
    src = open(HUD).read().splitlines()
    start = [k for k, l in enumerate(src) if l.startswith('letter_addr')][0]
    names = []
    for l in src[start:start + 80]:
        m = re.search(r'fdb\s+(DRAW_\w+)', l)
        if m:
            names.append(m.group(1))

    def sim(name):
        i = [k for k, l in enumerate(src) if l.strip() == name][0] + 1
        u, a, w = 0, 0, {}
        while True:
            l = src[i].split(';')[0].split('*')[0].strip()
            i += 1
            if not l:
                continue
            op = l.split()
            o, arg = op[0].upper(), (op[1] if len(op) > 1 else '')
            if o.startswith('PULS'):
                return w
            if o.startswith('PSHS'):
                continue
            off = arg.split(',')[0]
            if o == 'LEAU':
                u += int(off.replace('$', '0x'), 0) if off else 0
            elif o == 'LDA':
                a = int(arg[1:].replace('$', '0x'), 0)
            elif o == 'STA':
                w[u + (int(off.replace('$', '0x'), 0) if off else 0)] = a
            else:
                raise SystemExit('%s : %s inattendu dans %s' % (HUD, o, name))
    return lambda c: sim(names[ord(c) - 32])


def line_images(texts):
    """one indexed picture per line, 4 px per character: a glyph's pixels
    are [A hi, A lo, B hi, B lo] of its rows -3..+4, the HUD's own colours
    (gfxcomp's index = colour + 1), a space is transparent (index 0), the
    palette that of the fleet's pictures (same convention)"""
    from PIL import Image
    glyph = hud_glyphs()
    pal = Image.open(PALETTE_FROM).getpalette()
    out = []
    for t in texts:
        im = Image.new('P', (4 * len(t), 8), 0)
        im.putpalette(pal)
        for k, c in enumerate(t):
            if c == ' ':
                continue
            w = glyph(c)
            for r in range(-3, 5):
                a, b = w.get(r * 40, 0), w.get(r * 40 - 0x2000, 0)
                for x, v in enumerate((a >> 4, a & 15, b >> 4, b & 15)):
                    # gfxcomp: index 0 transparent, index n = colour n - 1;
                    # the HUD's colour 0 is the cell's black: transparent
                    im.putpixel((4 * k + x, r + 3), v + 1 if v else 0)
        out.append(im)
    return out


def viewport_image():
    """the side columns of the game's playfield mask, on the playfield's
    lines only: the rest transparent"""
    from PIL import Image
    mask = Image.open(MASK)
    im = Image.new('P', mask.size, 0)
    im.putpalette(mask.getpalette())
    for y in FIELD_ROWS:
        for x in range(im.width):
            if mask.getpixel((x, y)):
                im.putpixel((x, y), mask.getpixel((x, y)))
    row, xs = IRQ_FRAME
    for x in xs:
        im.putpixel((x, row), mask.getpixel((x, row)))
    return im


def main():
    rom = open(ROM, 'rb').read()
    tables, text, texts = render(rom)
    fleet = fleet_asm(rom)
    pics = [('%s/%02d.png' % (LINES_DIR, i), im) for i, im in enumerate(line_images(texts))]
    pics.append((VIEW_OUT, viewport_image()))
    if '--check' in sys.argv:
        ok = True
        for path, t in ((OUT_TABLES, tables), (OUT_TEXT, text), (OUT_FLEET, fleet)):
            cur = open(path).read() if os.path.exists(path) else ''
            print('%s : %s' % (path, 'a jour' if cur == t else 'PERIME — relancer tools/gen_ending.py'))
            ok = ok and cur == t
        bad = fleet_check(rom)
        print('la flotte contre la reference MAME : %s' % ('identique' if not bad else '%d trames differentes' % bad))
        ok = ok and not bad
        from PIL import Image
        for path, im in pics:
            same = os.path.exists(path) and Image.open(path).tobytes() == im.tobytes()
            print('%s : %s' % (path, 'a jour' if same else 'PERIME — relancer tools/gen_ending.py'))
            ok = ok and same
        return 0 if ok else 1
    os.makedirs(os.path.dirname(OUT_TABLES), exist_ok=True)
    for path, t in ((OUT_TABLES, tables), (OUT_TEXT, text), (OUT_FLEET, fleet)):
        open(path, 'w').write(t)
        print('%s ecrit' % path)
    for d in (LINES_DIR, os.path.dirname(VIEW_OUT)):
        os.makedirs(d, exist_ok=True)
    for f in os.listdir(LINES_DIR):
        os.remove(os.path.join(LINES_DIR, f))
    for path, im in pics:
        im.save(path)
        print('%s ecrit' % path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
