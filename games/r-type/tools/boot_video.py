#!/usr/bin/env python3
"""Capture video+son de l'AMORCAGE : menu TO8, fondu, chargement, title.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/boot_video.py dist/to8.fd [dist/boot.avi]

Le declencheur est l'entree du SECTEUR DE BOOT ($6200) : le moniteur vient de
le lire, le menu est encore a l'ecran, et le loader puis la scene de fondu
suivent. La capture s'armer AVANT boot_disk (qui reset et amorce) : un
declencheur pc survit au reset et tombe pendant l'amorcage lui-meme.

Fin : le title est en place (temoin bench : magic $CA, stage 0) plus 300
trames, pour voir le logo se reveler. Le noir entre le fondu et le title est
le vrai temps de chargement de scenes.boot, il est filme tel quel.
"""
import os, sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                '..', '..', '..', 'ci', 'toje-bench'))
from mcp import Toje, bench_block

os.chdir(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
image = os.path.abspath(sys.argv[1])
out = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'dist/boot.avi')
os.makedirs(os.path.dirname(out), exist_ok=True)
for stale in (out, os.path.splitext(out)[0] + '.mp4'):
    if os.path.exists(stale):
        os.remove(stale)
BLOCK = bench_block(image)

t = Toje()
for i in range(1, 9):
    for what in ('clear_watchpoint', 'clear_breakpoint'):
        try:
            t.call(what, {'id': i})
        except Exception:
            pass
r = t.call('arm_video_capture', {'path': out, 'start': {'pc': '6200'},
                                 'max_bytes': 4000000000})
print('capture armee sur le secteur de boot :', r, flush=True)
print(t.call('boot_disk', {'path': image, 'settle_frames': 30}), flush=True)
vs = t.call('video_capture_status')
print('etat apres amorcage :', vs.get('state'), vs.get('frames'), 'img', flush=True)
if vs.get('state') != 'recording':
    raise SystemExit('le declencheur du boot n\'est pas tombe')

done = 0
title_at = None
while done < 6000:
    t.call('run_frames', {'n': 100, 'timeout_ms': 600000})
    done += 100
    b = t.read('%04X' % BLOCK, 2)
    vs = t.call('video_capture_status')
    print('t~%5d  magic=%02X stage=%d  film: %s img' % (done, b[0], b[1], vs.get('frames')), flush=True)
    if title_at is None and b[0] == 0xCA and b[1] == 0:
        title_at = done
        print('le title est en place a t~%d — 300 trames de queue' % done, flush=True)
    if title_at is not None and done >= title_at + 300:
        break

print(t.call('stop_video_capture'), flush=True)
# H.264 OBLIGATOIRE : le defaut h265 sort du hev1 que l'iPhone refuse de lire.
print(t.call('encode_capture', {'path': out, 'codec': 'h264', 'quality': 18}), flush=True)
t.close()
