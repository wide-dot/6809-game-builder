#!/usr/bin/env python3
"""Les pieces mobiles du vaisseau (wsmgr) TRANCHE PAR TRANCHE, au milieu du stage 3.

    python3 tools/wsmgr_steps_probe.py     (depuis games/r-type)

Meme methode que obj_steps_probe.py (run_until_pc + total_cycles de
l'anneau), a l'interieur de wsmgr.DrawAll : le CPU s'arrete a l'entree de
chaque slot, au `jsr ,y` de chaque tranche et a son retour, ou a wsmgr.hors
quand la bande la rejette — le rejet est PREDIT par la sonde avec le test du
manager (imageset x1/xsize/y1/ysize contre [-8,168) x [28,227]), pour ne pas
depasser la tranche suivante ; de meme pour la boite de la pose en tete de
liste, qui rejette le slot entier (sl.rej). Cumul par famille de listes
(react.sl.*, core.sl.*, flame.sl.*). Les offsets sont lus dans le listing de
l'unite wsmgr resident (gen/stages/03/build/wsmgr-res.lst).
Les cycles d'un slot sont relus dans l'anneau de trace et l'IRQ en est retiree
(les instructions hors manager, hors DRS_XYToAddress, hors fenetre cartouche).
Resultat du 10/09/2026 : doc/profil-boucle-stage3-2026-09.md.
"""
import os, re, sys, collections
__file__ = os.path.abspath("tools/fire_burst_probe.py")
sys.path.insert(0, "../../ci/toje-bench")
sys.argv = ['x', 'dist/to8.fd']
src = open('tools/fire_burst_probe.py').read().split("def weapons():")[0]
src = src.replace("'bytes': ['02', '01']", "'bytes': ['03', '01']").replace("== 2:", "== 3:")
exec(src)
POOL, NOBJ, OSZ = 0x4000, 60, 63
ROUT = 34; REACT = 42; WSMGR = 44
INV = ENG + equ(ENGMAP, 'cheat.invincible')
_, ST3 = unit_base('stage3'); BUILD_CALL = ST3 + 0x022D
_, WSM = unit_base('stage3.wsmgr.res')
W = lambda n: WSM + equ('gen/stages/03/build/wsmgr-res.lwmap', n)
def wsm_offset(pat):
    # l'offset de la premiere ligne du listing de l'unite dont la source contient pat
    for l in open('gen/stages/03/build/wsmgr-res.lst', errors='replace'):
        m = re.match(r'([0-9A-F]{4}) [0-9A-F]+ +\(.*wsmgr\.asm\):\d+ (.*)$', l)
        if m and pat in m.group(2): return int(m.group(1), 16)
    raise SystemExit('listing : %s introuvable' % pat)
SLOT, LISTRD, TR = WSM + wsm_offset('@slot   ldx   wsmgr.sp'), WSM + wsm_offset('ldy   1,x'), WSM + wsm_offset('@tr     ldy   wsmgr.lp')
JSR = WSM + wsm_offset('jsr   ,y'); RET = WSM + wsm_offset('@pg     lda   #0')
HORS, SLOTOUT = W('wsmgr.hors'), W('wsmgr.slotOut')
WSP, WLP, WN, WCOUNT, WLIST = W('wsmgr.sp'), W('wsmgr.lp'), W('wsmgr.n'), W('wsmgr.count'), W('wsmgr.list')
def lst_offset(src_file, src_line):
    for l in open('gen/common/build/engine.lst', errors='replace'):
        m = re.match(r'([0-9A-F]{4}) [0-9A-F ]+\((?:[^)]*/)?%s\):%05d ' % (re.escape(src_file), src_line), l)
        if m: return int(m.group(1), 16)
BS_JSR = ENG + lst_offset('BuildSprites.asm', 347); BS_RET = BS_JSR + 2; BS_OBJ = BS_RET + 1
# les listes de tranches : adresse (page du cast) -> nom
names = {}
for l in open('gen/stages/03/build/stage03-cast.lwmap'):
    m = re.match(r'Symbol: ((?:react|core|flame)\.sl\.[\w.]+) \(.*\) = ([0-9A-F]+)', l)
    if m: names[int(m.group(2), 16)] = m.group(1)
print('WSM %04X WSP %04X SLOT %04X JSR %04X, %d listes nommees, ex. %s' % (WSM, WSP, SLOT, JSR, len(names), list(names.items())[:3]), flush=True)
t.call('write_memory', {'addr': '%04X' % INV, 'bytes': ['01']})
def pool():
    raw = []
    for off in range(0, NOBJ * OSZ, 256):
        raw += t.read('%04X' % (POOL + off), min(256, NOBJ * OSZ - off))
    return [raw[i * OSZ:(i + 1) * OSZ] for i in range(NOBJ)]
def run(n): t.call('run_frames', {'n': n, 'fast': True, 'timeout_ms': 600000})
def cyc(): return t.call('dump_trace_ring', {'count': 1})['instructions'][-1]['total_cycles']
def regs(): return t.call('read_registers')
def until(target, maxi=600000):
    if int(regs()['pc'], 16) == target:
        t.call('step')                   # deja dessus : run_until_pc rendrait sans bouger
    t.call('run_until_pc', {'pc': '%04X' % target, 'max_instructions': maxi})
    return int(regs()['pc'], 16) == target
def w16(a): b = t.read('%04X' % a, 2); return (b[0] << 8) | b[1]
reactors = lambda: [(i, o) for i, o in enumerate(pool()) if o[0] == REACT and (o[1] & 7) == 3 and o[ROUT] == 1]
for i in range(1200):
    run(10)
    if len(reactors()) >= 4: break
# une passe, exacte : a chaque tranche on PREDIT le test de bande (les memes
# comparaisons que wsmgr.asm, sur l'imageset lu dans la page montee) pour
# savoir si le prochain arret est le jsr ,y ou wsmgr.hors.
SL, ST, SB = 48, 28, 28 + 199
BIG = 20000    # l'IRQ (musique comprise) peut tomber entre deux arrets : des milliers d'instructions
def culled(x, y, ims):
    d = t.read('%04X' % ims, 13)
    x1, xs, y1, ys = d[11], d[4], d[12], d[5]
    a = (x + x1 - (SL - 8)) & 0xFF
    if a > 176: return True
    a = (a + xs) & 0xFF
    if a > 176: return True
    b = (y + y1 - ST) & 0xFF
    if b > SB - ST: return True
    b = (b + ys) & 0xFF
    return b > SB - ST + 1
def slot_culled(x, y, lst):
    # la boite de pose en tete de liste (fcb n, x1, xw0, xdl, y1, yh0, ydt — tools/wsmgr_box.py),
    # la page de la piece montee : les memes comparaisons que wsmgr.asm
    d = t.read('%04X' % lst, 7)
    a = (x + d[1] - (SL - 8)) & 0xFF
    if a <= 176:
        if (a + d[2]) & 0xFF > 176: return True
    elif a + d[3] < 256: return True
    b = (y + d[4] - ST) & 0xFF
    if b <= SB - ST:
        return (b + d[5]) & 0xFF > SB - ST + 1
    return b + d[6] < 256
# LES CYCLES SANS L'IRQ : entre deux arrets, l'anneau de trace est relu et seules
# comptent les instructions du manager, de DRS_XYToAddress et de la fenetre
# cartouche (les routines compilees) ; le reste est l'IRQ (musique comprise),
# qui tombait dans les mesures precedentes au hasard des slots.
DRS = ENG + equ(ENGMAP, 'DRS_XYToAddress')
inside = lambda pc: WSM <= pc < WSM + 0x300 or DRS <= pc < DRS + 0x40 or pc < 0x4000
IRQ = [0]
def span(c_prev, count=256):
    r = t.call('dump_trace_ring', {'count': count})['instructions']
    if r[0]['total_cycles'] > c_prev:
        if count < 4096: return span(c_prev, 4096)
        raise SystemExit('anneau deborde entre deux arrets')
    tot = 0
    for e in r:
        if e['total_cycles'] <= c_prev: continue
        if inside(int(e['pc'], 16)): tot += e['cycles']
        else: IRQ[0] += e['cycles']
    return tot
fam = lambda nm: re.sub(r'\.\d+$', '', nm)
per = collections.defaultdict(lambda: [0, 0, 0, 0, 0, 0])   # famille -> [slots, dessinees, rejetees, cycles routines, cycles total, slots rejetes]
NL = 3; drawall = []
def to_wsmgr():
    while True:
        assert until(BS_JSR)
        if t.read('%04X' % w16(BS_OBJ), 1)[0] == WSMGR: return
        assert until(BS_RET)
for it in range(NL):
    to_wsmgr(); c_all = cyc()
    count = t.read('%04X' % WCOUNT, 1)[0]
    if count: assert until(SLOT, BIG)
    for k in range(count):
        sp = w16(WSP); lst = w16(sp + 1); nm = fam(names.get(lst, '$%04X' % lst))
        c_prev = cyc(); drawn = rej = 0; cr = ct = 0; srej = 0
        assert until(LISTRD, BIG); ct += span(c_prev); c_prev = cyc()
        xy = t.read('%04X' % W('wsmgr.xy'), 2); x, y = xy[0], xy[1]
        if slot_culled(x, y, lst):
            assert until(SLOTOUT, BIG); srej = 1; n = 0
        else:
            assert until(TR, BIG)
            n = t.read('%04X' % WN, 1)[0]
        ct += span(c_prev); c_prev = cyc()
        for i in range(n):
            lp = w16(WLP); ims = w16(lp)
            if culled(x, y, ims):
                assert until(HORS, BIG); rej += 1
            else:
                if not until(JSR, BIG):
                    d = t.read('%04X' % ims, 15)
                    raise SystemExit('slot %s tranche %d/%d : jsr non atteint, pc=%s x=%d y=%d ims=%04X %s n=%d lp=%04X' % (nm, i, n, regs()['pc'], x, y, ims, d, t.read('%04X' % WN, 1)[0], w16(WLP)))
                ct += span(c_prev); c_prev = cyc()
                assert until(RET, BIG); c = span(c_prev, 1024); cr += c; ct += c; c_prev = cyc(); drawn += 1
            assert w16(WLP) == lp + 2, 'prediction fausse (slot %s tranche %d)' % (nm, i)
            if i + 1 < n: assert until(TR, BIG)
            ct += span(c_prev); c_prev = cyc()
        if k + 1 < count: assert until(SLOT, BIG)
        else: assert until(BS_RET, BIG)
        ct += span(c_prev)
        p = per[nm]; p[0] += 1; p[1] += drawn; p[2] += rej; p[3] += cr; p[4] += ct; p[5] += srej
    if not count: assert until(BS_RET)
    drawall.append(cyc() - c_all)
    print('boucle %d : wsmgr.DrawAll %d cycles, %d slots' % (it + 1, drawall[-1], count), flush=True)
print('\n%-30s %5s %6s %6s %6s %9s %9s %9s %8s' % ('piece', 'slots', 'dessin', 'rejet', 'sl.rej', 'routines', 'tour', 'total', 'tour/tr'))
T = [0] * 6
def ligne(nm, v):
    ns, dr, rj, cr, ct, sr = v
    print('%-30s %5.1f %6.1f %6.1f %6.1f %9.0f %9.0f %9.0f %8.0f' % (nm, ns / NL, dr / NL, rj / NL, sr / NL, cr / NL, (ct - cr) / NL, ct / NL, (ct - cr) / max(1, dr + rj)))
for nm, v in sorted(per.items(), key=lambda kv: -kv[1][4]):
    T = [a + b for a, b in zip(T, v)]; ligne(nm, v)
ligne('total', T)
print('wsmgr.DrawAll par boucle (IRQ comprise) : %s ; IRQ retiree des slots : %d cycles' % (drawall, IRQ[0]))
t.close()
