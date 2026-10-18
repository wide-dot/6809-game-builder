#!/usr/bin/env python3
"""Give back to the engine's v1 files the direct addressing v1's `setdp` gave.

v1 assembled each unit absolutely under a `setdp` (dp/256 in the game loop,
$E7 in the IRQ handlers) that every included file inherited : an operand in
that page went direct with no `<` in the source. The v2 obj target refuses
`setdp` (docs/lang/en/migration/setdp-obj-target.md) : those operands
assemble extended, a byte and a cycle more each.

This tool reads v1's listings (each v1 game project's generated-code), finds
every instruction of an engine file v1 assembled direct although its source
line has no `<`, and adds the `<` to the same line of the v2 copy (the
manifest's v2_path, lines aligned by their text). The runtime DP is v1's
own, line by line : nothing is guessed. Left alone : a line v1 assembled
both ways (two contexts), a line whose text changed in v2, the KEPT-V2
files, and every v2-only file.

    python3 ci/force-direct.py            # writes the operands, reports them
    python3 ci/force-direct.py --check    # exit 1 if an operand is left to force

V1_REPO : the v1 repository (default ../thomson-to8-game-engine).
"""
import csv, difflib, glob, os, re, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
V1 = os.environ.get('V1_REPO', os.path.join(ROOT, '..', 'thomson-to8-game-engine'))
LISTINGS = os.path.join(V1, 'game-projects', '*', 'generated-code', '**', '*.lst')

LINE = re.compile(r'^([0-9A-F]{4}) ([0-9A-F]+)\s+\(([^)]*)\):(\d+)\s*(?:\[[^\]]*\]\s+\d+)?(.*)$')
INSTR = re.compile(r'^(\S*\s+)([A-Za-z]+)(\s+)([^\s;*].*)$')
# the 6809 instructions with a direct form (the others have none to give back)
CPU = set('''adca adcb adda addb addd anda andb asl asr bita bitb clr cmpa cmpb cmpd
cmps cmpu cmpx cmpy com dec eora eorb inc jmp jsr lda ldb ldd lds ldu ldx ldy lsl
lsr neg ora orb rol ror sbca sbcb sta stb std sts stu stx sty suba subb subd tst'''.split())


def mode(code):
    """'direct', 'extended' or None (no memory operand of these two modes)"""
    op = code[0]
    if op in (0x10, 0x11):
        if len(code) < 2:
            return None
        op = code[1]
    hi = op >> 4
    if hi in (0x0, 0x9, 0xD):
        return 'direct'
    if hi in (0x7, 0xB, 0xF):
        return 'extended'
    return None


def words(text):
    """the words before a ';' comment (the listing may drop a '*' one)"""
    return text.split(';')[0].split()


def main(argv):
    check = '--check' in argv
    manifest = list(csv.DictReader(open(os.path.join(ROOT, 'engine', 'v1-manifest.csv'), encoding='utf-8')))
    v1_to_v2 = {r['v1_path']: r['v2_path'] for r in manifest if not r['deviations'].startswith('KEPT-V2')}
    # every v1 engine file is a candidate source : a listing's file name is cut
    # to 16 characters, a line is attributed only when one file alone matches
    v1_text = {}
    for f in glob.glob(os.path.join(V1, 'engine', '**', '*.asm'), recursive=True):
        v1_text[os.path.relpath(f, V1)] = open(f, encoding='utf-8', errors='replace').read().split('\n')

    seen = {}                                   # (v1 path, line) -> set of modes
    for lst in glob.glob(LISTINGS, recursive=True):
        for l in open(lst, encoding='utf-8', errors='replace'):
            m = LINE.match(l)
            if not m:
                continue
            hint = m.group(3).strip()
            if not hint.startswith('./engine/'):
                continue
            how = mode(bytes.fromhex(m.group(2)))
            if how is None:
                continue
            n, src = int(m.group(4)), words(m.group(5))
            if not src or not any(w.lower() in CPU for w in src[:2]):
                continue
            hits = [p for p, t in v1_text.items()
                    if p.startswith(hint[2:]) and n <= len(t) and words(t[n - 1])[:len(src)] == src]
            if len(hits) != 1 or hits[0] not in v1_to_v2:
                continue
            seen.setdefault((hits[0], n), set()).add(how)

    pending, both = {}, []
    for (p, n), modes in sorted(seen.items()):
        line = v1_text[p][n - 1]
        if '<' in line.split(';')[0]:
            continue
        if modes == {'direct'}:
            pending.setdefault(p, []).append(n)
        elif 'direct' in modes:
            both.append('%s:%d %s' % (p, n, line.strip()))

    total = 0
    for p, lines in sorted(pending.items()):
        v2 = v1_to_v2[p]
        path = os.path.join(ROOT, v2)
        text = open(path, encoding='utf-8', errors='replace').read().split('\n')
        at = {}
        for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, v1_text[p], text, autojunk=False).get_opcodes():
            if tag == 'equal':
                for k in range(i2 - i1):
                    at[i1 + k + 1] = j1 + k + 1
        done = 0
        for n in lines:
            k = at.get(n)
            m = INSTR.match(text[k - 1]) if k else None
            if m and m.group(2).lower() not in CPU:
                m = None
            if not m or m.group(4).startswith(('#', '<', '>', '[')) or ',' in m.group(4).split(';')[0]:
                if k is None:
                    print('%s:%d changed in v2, left alone : %s' % (v2, n, v1_text[p][n - 1].strip()))
                continue
            text[k - 1] = m.group(1) + m.group(2) + m.group(3) + '<' + m.group(4)
            done += 1
        if done:
            if not check:
                open(path, 'w', encoding='utf-8').write('\n'.join(text))
            print('%s : %d operand(s) %s' % (v2, done, 'to force direct' if check else 'forced direct'))
            total += done
    for b in both:
        print('two contexts in v1, left alone :', b)
    print('total', total)
    if check and total:
        sys.exit(1)


if __name__ == '__main__':
    main(sys.argv[1:])
