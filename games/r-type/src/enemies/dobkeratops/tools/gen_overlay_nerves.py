#!/usr/bin/env python3
"""Genere les assets du chantier nerfs-overlay du dobkeratops.

Modele unifie : UN systeme d'oeil = UN repertoire de morceaux unitaires,
fusion du nerf optique et de son element d'avant-plan (champignon, chaine),
numerotes de 00 dans l'ordre de disparition. Le manager dessine chaque trame
tous les morceaux non retires ; l'effacement = derouler la sequence, un tick
par pas (-- = tick sans retrait, deux morceaux peuvent partir le meme tick).

Produit dans src/enemies/dobkeratops/images/ :
  bands/00..03.png      : images/face.png (asset PRIMAIRE — l'ex master
                          new_pal/boss.png compose, cale +16,+12, puis
                          retouche : noir de bouche derriere le monstre)
                          decoupee en 4 bandes verticales de
                          16 px (la bande 0, colonnes 0-15, est vide).
  eye-0..3/NN.png       : les morceaux du systeme N (haut -> bas, numerotation
                          des subtypes nerf de obj.asm).
                          - morceaux de nerf : positions = pixels de nerf v1
                            (bande v1 != face v1), couleurs relues dans les
                            bandes v2, partition par piece d'effaceur (piece
                            la plus precoce qui couvre le pixel ; pixel hors
                            masque -> piece la plus proche).
                          - morceaux d'avant-plan (eye-1 : champignon ex
                            dk-eye-1-0 ; eye-3 : chaine ex dk-eye-3-x) :
                            difference de frames successives (les images v1
                            sont emboitees : frame k+1 = frame k moins un bout).
  (jaw/ monster/ saw/ tail/ dans images/ sont des assets PRIMAIRES, pas
  generes — le script n'y touche pas et ne supprime jamais rien.)
  manifest.txt          : sequences d'effacement et provenance de chaque
                          morceau — la reference pour les tables ASM.
  review/               : artefacts de validation (halo, decoupe, composites,
                          GIFs d'animation d'effacement) — pas des assets jeu.

Tous les PNG jeu sont en mode P, canevas 80x180, indices copies verbatim
(gfxcomp lit les indices : 0 = transparent, 1-16 = palette).
"""
import glob
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
DK = os.path.dirname(HERE)
V1 = os.path.normpath(os.path.join(
    DK, '../../../../../..',
    'thomson-to8-game-engine/game-projects/r-type/objects/enemies/dobkeratops/final'))
OUT = os.path.join(DK, 'images')
W, H = 80, 180

# zones y des 4 nerfs (mesurees : n0 y12-35, n1 y54-96, n2 y108-136, n3 y144-168)
ZONES = [(0, 44), (45, 99), (100, 140), (141, 179)]

# sequences d'effacement des nerfs (EraserImages de obj.asm, None = trame vide)
SEQ = [
    [0, 1, 2, 3, 4, 5, 6, 7, 8, None, None, None, 9, 10, 11, 12, 13, 14, 15],
    # v1 sautait les pieces 7-9 (racine du nerf 1) ; on les rejoue dans le trou
    [None] * 5 + [2, 3, 4, 5, 6, 7, 8, 9, None, None, None, 10, 11],
    [0, 1, 2, None, None, None, None, 3, 4, 5, 6, 7, 8, 9, None, None, None, 10, 11],
    [None] * 6 + [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
]

# elements d'avant-plan : (repertoire v1 des frames emboitees, nerf associe,
# sequence de retrait = indice du morceau retire a chaque tick). Transcription
# des tables ForegroundImages de obj.asm : les maintiens (frame repetee)
# deviennent des ticks sans retrait, la disparition finale retire le dernier
# morceau. L'association nerf -> element vient de RunEyes/DeleteEye (subtype 1
# -> champignon ; subtype 3 -> cascade), confirmee par la geometrie.
FG = {
    'dk-eye-1-0': (1, [0, 1] + [None] * 9 + [2, 3, 4]),
    'dk-eye-3-0': (3, [0, 1]),
    'dk-eye-3-1': (3, [0, 1, 2, 3]),
    'dk-eye-3-2': (3, [0, 1] + [None] * 5 + [2]),
}
# cascade du nerf 3 : chaque maillon part quand le precedent est fini
FG_START = {'dk-eye-1-0': 0, 'dk-eye-3-0': 0,
            'dk-eye-3-1': len(FG['dk-eye-3-0'][1]),
            'dk-eye-3-2': len(FG['dk-eye-3-0'][1]) + len(FG['dk-eye-3-1'][1])}

def load_p(path):
    im = Image.open(path)
    assert im.mode == 'P' and im.size == (W, H), f'{path}: {im.mode} {im.size}'
    return list(im.getdata()), im.getpalette()


def load_rgba(path):
    im = Image.open(path).convert('RGBA')
    assert im.size == (W, H), path
    return [(p[0], p[1], p[2]) if p[3] > 0 else None for p in im.getdata()]


def save_p(path, data, palette):
    im = Image.new('P', (W, H), 0)
    im.putdata(data)
    im.putpalette(list(palette[:51]) + [0] * (768 - min(len(palette), 51)))
    im.save(path, bits=8)


def band_of(k):
    return min((k % W) // 16, 4)


def main():
    # -- sources -------------------------------------------------------------
    face_v1 = load_rgba(os.path.join(V1, 'dk-alien.png'))
    bands_v1 = [load_rgba(os.path.join(V1, f'dk-alien nerves-{i}.png')) for i in range(5)]
    bands_v2 = []
    palette = None
    for i in range(5):
        d, pal = load_p(os.path.join(DK, f'reference/dk-alien-nerves/0{i}.png'))
        bands_v2.append(d)
        palette = palette or pal
        assert pal[:48] == palette[:48], f'palette divergente bande {i}'
    # la face : ASSET PRIMAIRE (images/face.png, ex new_pal/boss.png compose
    # puis retouche — le noir de bouche derriere le monstre y est pose en dur).
    # Le generateur la LIT pour en tailler les bandes, il ne l'emet plus.
    face_v2, pal_face = load_p(os.path.join(DK, 'images/face.png'))
    assert pal_face[:48] == palette[:48], 'palette divergente face.png'
    palette = list(pal_face[:51])

    # geometrie v1 == v2 pour chaque bande (positions des pixels presents)
    for i in range(5):
        s1 = {k for k in range(W * H) if bands_v1[i][k] is not None}
        s2 = {k for k in range(W * H) if bands_v2[i][k] != 0}
        assert s1 == s2, f'bande {i}: geometrie v1 != v2 ({len(s1)} vs {len(s2)})'

    # -- pixels de nerf ------------------------------------------------------
    def v1_band_px(k):
        return bands_v1[band_of(k)][k]

    nerve_px = {}  # k -> indice de nerf
    for k in range(W * H):
        b = v1_band_px(k)
        if b is not None and b != face_v1[k]:
            y = k // W
            zone = next((z for z, (y0, y1) in enumerate(ZONES) if y0 <= y <= y1), None)
            assert zone is not None, f'pixel de nerf hors zone: x={k%W} y={y}'
            nerve_px[k] = zone
    counts = [sum(1 for z in nerve_px.values() if z == n) for n in range(4)]
    print(f'pixels de nerf: {len(nerve_px)} (par nerf: {counts})')

    # -- pieces d'effaceur ---------------------------------------------------
    def piece_files(n):
        if n == 1:
            fs = [(2 + i, os.path.join(DK, f'reference/eraser-1/0{i}.png')) for i in range(5)]
            fs += [(i, os.path.join(DK, f'reference/eraser-1-{i}.png')) for i in (7, 8, 9)]
            fs += [(10, os.path.join(DK, 'reference/eraser-1/05.png')),
                   (11, os.path.join(DK, 'reference/eraser-1/06.png'))]
            return sorted(fs)
        files = sorted(glob.glob(os.path.join(DK, f'reference/eraser-{n}/*.png')))
        return [(int(os.path.basename(f)[:-4]), f) for f in files]

    pieces = {}   # (nerf, id v1) -> set de positions du masque
    order = {}    # (nerf, id v1) -> rang dans l'animation (pour "la plus precoce")
    for n in range(4):
        seq_ids = [i for i in SEQ[n] if i is not None]
        for pid, path in piece_files(n):
            d, _ = load_p(path)
            pieces[(n, pid)] = {k for k in range(W * H) if d[k] != 0}
            order[(n, pid)] = seq_ids.index(pid) if pid in seq_ids else len(seq_ids)

    # -- affectation ---------------------------------------------------------
    assign = {}    # k -> (nerf, id v1)
    halo = set()   # pixels hors de tout masque
    for k, n in nerve_px.items():
        covering = [(order[key], key) for key in pieces if key[0] == n and k in pieces[key]]
        if covering:
            assign[k] = min(covering)[1]
        else:
            halo.add(k)
            x, y = k % W, k // W
            best = None
            for key, mask in pieces.items():
                if key[0] != n:
                    continue
                d = min((x - m % W) ** 2 + (y - m // W) ** 2 for m in mask)
                cand = (d, order[key], key)
                if best is None or cand < best:
                    best = cand
            assign[k] = best[2]
    dmax = max((min((k % W - m % W) ** 2 + (k // W - m // W) ** 2
                    for m in pieces[assign[k]]) for k in halo), default=0)
    print(f'couverts par masque: {len(nerve_px)-len(halo)}, '
          f'halo rattache: {len(halo)}, distance max: {math.sqrt(dmax):.1f} px')

    nerve_data = {}  # (nerf, id v1) -> data (les morceaux vides ne sont pas emis)
    for key in pieces:
        data = [0] * (W * H)
        for k, a in assign.items():
            if a == key:
                data[k] = bands_v2[band_of(k)][k]
        if any(data):
            nerve_data[key] = data
        else:
            print(f'  nerf {key[0]} piece v1 {key[1]:02d} : VIDE, non emise')

    # -- morceaux d'avant-plan -----------------------------------------------
    # frames v1 emboitees -> morceau i = frame i moins frame i+1 (le dernier
    # morceau = la derniere frame entiere). Union des morceaux == frame 0.
    fg_data = {}  # nom v1 -> [data des morceaux]
    for name, (nerf, seq) in FG.items():
        frames = []
        for f in sorted(glob.glob(os.path.join(DK, f'reference/{name}/*.png'))):
            d, pal = load_p(f)
            assert pal[:48] == palette[:48], f'palette divergente {f}'
            frames.append(d)
        frames.append([0] * (W * H))
        pcs = []
        for i in range(len(frames) - 1):
            a, b = frames[i], frames[i + 1]
            bad = sum(1 for k in range(W * H) if b[k] and (a[k] == 0 or a[k] != b[k]))
            assert bad == 0, f'{name}: frame {i+1} non emboitee ({bad} px)'
            pcs.append([a[k] if a[k] and not b[k] else 0 for k in range(W * H)])
        union = [0] * (W * H)
        for d in pcs:
            for k, v in enumerate(d):
                if v:
                    assert union[k] == 0, f'{name}: morceaux non disjoints'
                    union[k] = v
        assert union == frames[0], f'{name}: union des morceaux != frame 0'
        assert sorted(x for x in seq if x is not None) == list(range(len(pcs))), \
            f'{name}: sequence incoherente avec {len(pcs)} morceaux'
        fg_data[name] = pcs

    # -- fusion par systeme : eye-N = nerf N + son avant-plan ------------------
    # evenement = (tick, rang, provenance, data) ; numerotation 00.. dans
    # l'ordre des ticks (nerf avant avant-plan sur un tick double).
    eye = {}      # n -> [(data, provenance)]
    eye_seq = {}  # n -> {tick: [ids fusionnes]}
    for n in range(4):
        events = []
        for tick, x in enumerate(SEQ[n]):
            if x is not None and (n, x) in nerve_data:
                events.append((tick, 0, f'nerf/{x:02d}', nerve_data[(n, x)]))
        for name, (nerf, seq) in FG.items():
            if nerf != n:
                continue
            for rel, x in enumerate(seq):
                if x is not None:
                    events.append((FG_START[name] + rel, 1,
                                   f'{name}/{x:02d}', fg_data[name][x]))
        events.sort(key=lambda e: (e[0], e[1]))
        eye[n] = [(data, src) for _, _, src, data in events]
        eye_seq[n] = {}
        for i, (tick, _, _, _) in enumerate(events):
            eye_seq[n].setdefault(tick, []).append(i)

    # -- sorties jeu ---------------------------------------------------------
    os.makedirs(os.path.join(OUT, 'bands'), exist_ok=True)
    for b in range(1, 5):
        data = [face_v2[k] if b * 16 <= k % W < (b + 1) * 16 else 0 for k in range(W * H)]
        save_p(os.path.join(OUT, f'bands/{b - 1:02d}.png'), data, palette)
    assert not any(face_v2[k] for k in range(W * H) if k % W < 16), 'bande 0 non vide !'
    recomp = [face_v2[k] if k % W >= 16 else 0 for k in range(W * H)]
    assert recomp == face_v2, 'recomposition bandes != face'

    for n in range(4):
        dd = os.path.join(OUT, f'eye-{n}')
        os.makedirs(dd, exist_ok=True)
        for i, (data, src) in enumerate(eye[n]):
            save_p(os.path.join(dd, f'{i:02d}.png'), data, palette)
            print(f'  eye-{n}/{i:02d}.png : {sum(1 for v in data if v):3d} px  <- {src}')

    # bandes 16 px par systeme (etat intact, mesure : +8% de cycles vs image
    # complete, 16 appels au lieu de 60) : union des morceaux du systeme,
    # decoupee sur la grille de colonnes de la face. Nommage sequentiel,
    # la colonne d'origine est au manifest.
    eye_bands = {}  # n -> [(colonne, data)]
    for n in range(4):
        full = [0] * (W * H)
        for data, _ in eye[n]:
            for k, v in enumerate(data):
                if v:
                    full[k] = v
        eye_bands[n] = []
        for b in range(5):
            band = [full[k] if b * 16 <= k % W < (b + 1) * 16 else 0
                    for k in range(W * H)]
            if any(band):
                eye_bands[n].append((b, band))
        dd = os.path.join(OUT, f'eye-{n}/bands')
        os.makedirs(dd, exist_ok=True)
        for i, (b, band) in enumerate(eye_bands[n]):
            save_p(os.path.join(dd, f'{i:02d}.png'), band, palette)
            print(f'  eye-{n}/bands/{i:02d}.png : col x{b*16}-{b*16+15}, '
                  f'{sum(1 for v in band if v)} px')

    # -- tables ASM pour le manager (eyemgr / eyepieces) -----------------------
    # bornes playfield precalculees : ancre du boss +/- offsets canevas.
    # convention gfxcomp du canevas 80x180 : centre -1 -> colonne d'ancre 39
    # (verifie sur la face : x1=-23 <-> contenu col 16).
    ANCHOR_COL = 39

    def content_cols(data):
        xs = [k % W for k, v in enumerate(data) if v]
        return min(xs), max(xs)

    # une table par parite : les variantes ND0 et ND1 vivent dans deux
    # direntries (les deux ensemble depassent 16 Ko), chacun avec son hook
    for nd in (0, 1):
        with open(os.path.join(OUT, f'eyes-bands-nd{nd}.tables.asm'), 'w') as f:
            f.write('; genere par tools/gen_overlay_nerves.py — NE PAS EDITER\n')
            f.write('; par systeme : fcb nb, puis par bande : fdb gauche, fdb\n')
            f.write(f'; droite+1 (bornes playfield, ancre = eyemgr.X), fdb ND{nd}\n')
            for n in range(4):
                f.write(f'EB_sys{n}\n        fcb   {len(eye_bands[n])}\n')
                for i, (b, band) in enumerate(eye_bands[n]):
                    x0, x1 = content_cols(band)
                    f.write(f'        fdb   eyemgr.X{x0-ANCHOR_COL:+d},eyemgr.X{x1-ANCHOR_COL+1:+d}\n')
                    f.write(f'        fdb   adr_dkeyes_b{n}{i}_ND{nd}\n')
            f.write('EB_index\n')
            f.write('        fdb   ' + ','.join(f'EB_sys{n}' for n in range(4)) + '\n')

    with open(os.path.join(OUT, 'eyes-seq.tables.asm'), 'w') as f:
        f.write('; genere par tools/gen_overlay_nerves.py — NE PAS EDITER\n')
        f.write('; sequences d\'effacement : un octet par tick = nb de morceaux\n')
        f.write('; retires ce tick (0-2), $FF = fin de sequence\n')
        for n in range(4):
            ticks = max(eye_seq[n]) + 1
            counts = [len(eye_seq[n].get(t, [])) for t in range(ticks)]
            f.write(f'ES_sys{n}\n')
            for off in range(0, len(counts), 16):
                chunk = counts[off:off + 16]
                f.write('        fcb   ' + ','.join(str(c) for c in chunk) + '\n')
            f.write('        fcb   $FF\n')
        f.write('ES_index\n')
        f.write('        fdb   ' + ','.join(f'ES_sys{n}' for n in range(4)) + '\n')

    with open(os.path.join(OUT, 'eyes-pieces.tables.asm'), 'w') as f:
        f.write('; genere par tools/gen_overlay_nerves.py — NE PAS EDITER\n')
        f.write('; par systeme : fcb nb, puis fdb routine par morceau, dans\n')
        f.write('; l\'ordre de retrait (parite unique, cf. manifest)\n')
        for n in range(4):
            f.write(f'EP_sys{n}\n        fcb   {len(eye[n])}\n')
            for i in range(len(eye[n])):
                f.write(f'        fdb   adr_dkeyes_p{n}_{i:02d}_ND0\n')
        f.write('EP_index\n')
        f.write('        fdb   ' + ','.join(f'EP_sys{n}' for n in range(4)) + '\n')

    # -- manifest ------------------------------------------------------------
    lines = ['# overlay/ — assets du dobkeratops, generes par tools/gen_overlay_nerves.py',
             '# un systeme d\'oeil = un repertoire eye-N (nerf + avant-plan fusionnes),',
             '# morceaux numerotes de 00 dans l\'ordre de disparition. Effacement = un',
             '# tick par pas, -- = tick sans retrait, a+b = deux morceaux le meme tick.',
             '# sequences transcrites des tables EraserImages/ForegroundImages de obj.asm',
             '#',
             '# plan d\'encodage (decision auteur, 31/08/2026 — le frame drop absorbe) :',
             '#   bands/ (face) et eye-N/bands/  : draw shift 0 + 1 (scroll au pixel)',
             '#   eye-N/NN (morceaux)            : draw shift 0 OU 1, UN SEUL — la parite',
             '#     de la camera a l\'arret du scroll, a fixer a l\'integration',
             '#   jaw/, monster/                 : draw shift 0 + 1',
             '#   face complete (00-dk-alien)    : draw shift 0 + 1 (inchange)',
             '#   etat intact = bandes ; effacement = morceaux restants ; fini = rien', '']
    lines.append('face.png (ex new_pal/boss.png, cale +16,+12) ; bands/00..03.png : la face en 4 bandes de 16 px (x16-31/32-47/48-63/64-79)')
    lines.append('')
    for n in range(4):
        nb = len(eye[n])
        fgs = [name for name, (nerf, _) in FG.items() if nerf == n]
        what = f'nerf {n}' + (f' + {" + ".join(f"ex {f}" for f in fgs)}' if fgs else '')
        lines.append(f'eye-{n}/ : {nb} morceaux (00-{nb-1:02d}) — {what}')
        ticks = max(eye_seq[n]) + 1
        seq = ' '.join('+'.join(f'{i:02d}' for i in eye_seq[n][t])
                       if t in eye_seq[n] else '--' for t in range(ticks))
        lines.append(f'  effacement : {seq}')
        prov = ' '.join(f'{i:02d}<-{src}' for i, (_, src) in enumerate(eye[n])
                        if not src.startswith('nerf/'))
        if prov:
            lines.append(f'  avant-plan : {prov}')
        bands_txt = ' '.join(f'{i:02d}=x{b*16}-{b*16+15}'
                             for i, (b, _) in enumerate(eye_bands[n]))
        lines.append(f'  bandes (intact) : {bands_txt}')
    lines.append('')
    lines.append('jaw/00-02, monster/00-05, saw/00-03, tail/00-02+end : assets primaires (non generes)')
    with open(os.path.join(OUT, 'manifest.txt'), 'w') as f:
        f.write('\n'.join(lines) + '\n')

    # -- artefacts de revue --------------------------------------------------
    rev = os.path.join(OUT, 'review')
    os.makedirs(rev, exist_ok=True)
    Z = 6

    def rgb(idx):
        return tuple(palette[3 * idx:3 * idx + 3])

    def upscale(im, z=Z):
        return im.resize((im.size[0] * z, im.size[1] * z), Image.NEAREST)

    # halo.png : face en gris, nerf couvert par masque en vert, halo en rouge
    im = Image.new('RGB', (W, H), (20, 20, 30))
    for k in range(W * H):
        if face_v2[k]:
            im.putpixel((k % W, k // W), (70, 70, 70))
    for k in nerve_px:
        im.putpixel((k % W, k // W), (255, 60, 60) if k in halo else (60, 220, 60))
    upscale(im).save(os.path.join(rev, 'halo.png'))

    # cut.png : la decoupe, une couleur par morceau fusionne
    def piece_color(a, b):
        h = (a * 61 + b * 47) % 360
        return Image.new('HSV', (1, 1),
                         (int(h * 255 / 360), 230, 255)).convert('RGB').getpixel((0, 0))

    im = Image.new('RGB', (W, H), (20, 20, 30))
    for k in range(W * H):
        if face_v2[k]:
            im.putpixel((k % W, k // W), (60, 60, 60))
    for n in range(4):
        for i, (data, _) in enumerate(eye[n]):
            for k, v in enumerate(data):
                if v:
                    im.putpixel((k % W, k // W), piece_color(n, i))
    upscale(im).save(os.path.join(rev, 'cut.png'))

    # composites : nouveau (face + morceaux) vs ancien (bandes v2 + frames 0)
    def render(data_list):
        im = Image.new('RGB', (W, H), (0, 0, 0))
        for data in data_list:
            for k, v in enumerate(data):
                if v:
                    im.putpixel((k % W, k // W), rgb(v))
        return im

    all_pieces = [data for n in range(4) for data, _ in eye[n]]
    old_fg = [load_p(sorted(glob.glob(os.path.join(DK, f'reference/{name}/*.png')))[0])[0]
              for name in FG]
    new_c = render([face_v2] + all_pieces)
    old_c = render([[bands_v2[band_of(k)][k] for k in range(W * H)]] + old_fg)
    upscale(new_c, 3).save(os.path.join(rev, 'composite-new.png'))
    upscale(old_c, 3).save(os.path.join(rev, 'composite-old.png'))

    # diff old/new : rouge = perdu (hors simplification), bleu = delta face
    im = Image.new('RGB', (W, H), (25, 25, 25))
    lost = 0
    for k in range(W * H):
        a = old_c.getpixel((k % W, k // W))
        b = new_c.getpixel((k % W, k // W))
        if a == b:
            if a != (0, 0, 0):
                im.putpixel((k % W, k // W), (70, 70, 70))
        elif k in nerve_px:
            im.putpixel((k % W, k // W), (255, 50, 50))
            lost += 1
        else:
            im.putpixel((k % W, k // W), (60, 90, 255))
    upscale(im).save(os.path.join(rev, 'diff.png'))
    print(f'diff : pixels de nerf perdus = {lost} (doit etre 0)')

    # GIFs : effacement du systeme N, les autres systemes restent entiers
    for n in range(4):
        frames = [upscale(new_c, 3)]
        gone = set()
        for t in range(max(eye_seq[n]) + 1):
            gone.update(eye_seq[n].get(t, []))
            layers = [face_v2]
            for m in range(4):
                layers += [d for i, (d, _) in enumerate(eye[m])
                           if m != n or i not in gone]
            frames.append(upscale(render(layers), 3))
        frames += [frames[-1]] * 8
        frames[0].save(os.path.join(rev, f'erase-{n}.gif'), save_all=True,
                       append_images=frames[1:], duration=120, loop=0)
    print('review/ : halo.png, cut.png, composite-new/old.png, diff.png, erase-0..3.gif')


if __name__ == '__main__':
    sys.exit(main())
