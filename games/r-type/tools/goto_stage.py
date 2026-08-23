#!/usr/bin/env python3
"""Sauter a un stage SANS manette — pour les emulateurs qui n'en ont pas.

    TOJE_MCP=<toje>/scripts/toje-mcp.sh python3 tools/goto_stage.py dist/to8.fd 4 \
        [trames] [capture.png]

Le cheat du title compte des appuis joypad puis appelle title.cheat.launch,
qui lit tct.pstage / tct.pinv et saute dans game.stage.switch. Un emulateur
sans manette ne peut donc pas y arriver — mais rien n'empeche de POSER les
memes variables et d'appeler la meme routine. C'est exactement ce que le cheat
aurait produit, sans passer par la lecture d'entree.

La subtilite : title.cheat.launch vit dans une page, appelee par paged.call. On
monte donc la page en fenetre cartouche avant de poser le PC dessus, comme le
title le fait lui-meme.
"""
import os
import re
import shutil
import sys

sys.path.insert(0, "/Users/benoitrousseau/Documents/Claude/Projects/6809-game-builder-gommes/ci/toje-bench")
from mcp import Toje                                            # noqa: E402

image = os.path.abspath(sys.argv[1])
stage = int(sys.argv[2]) if len(sys.argv) > 2 else 4
trames = int(sys.argv[3]) if len(sys.argv) > 3 else 900
dest = sys.argv[4] if len(sys.argv) > 4 else "/tmp/claude-501/stage%d.png" % stage

t = Toje()
t.boot_floppy(image)
t.call("run_frames", {"n": 900})               # que le title soit pose
t.call("run_frames", {"n": 300})
b = t.read("87DB", 8)
print("title : magic=%02X stage=%02X" % (b[0], b[1]))
if b[0] != 0xCA:
    print("!! le jeu n'a pas demarre — inutile d'aller plus loin")
    t.close()
    sys.exit(1)

# Les symboles du title : ils vivent dans la page du cheat, dont l'adresse est
# resolue au chargement. On les lit dans la carte de liens du build.
LWMAP = os.path.join(os.path.dirname(image), "../gen")
sym = {}
for racine, _, fichiers in os.walk(LWMAP):
    for f in fichiers:
        if not f.endswith(".lwmap"):
            continue
        for line in open(os.path.join(racine, f)):
            m = re.match(r'Symbol: (\S+) \(.*\) = ([0-9A-F]+)$', line.strip())
            if m and m.group(1) in ("tct.pstage", "tct.pinv", "title.cheat.launch"):
                sym.setdefault(m.group(1), []).append((f, int(m.group(2), 16)))
for k, v in sorted(sym.items()):
    print("  %-20s %s" % (k, " ".join("%s:%04X" % x for x in v)))
if len(sym) < 3:
    print("!! symboles du cheat introuvables dans les .lwmap")
    t.close()
    sys.exit(2)
# L'unite du cheat : sa page et son adresse se LISENT dans le rapport
# d'occupation du build courant. Les coder en dur les rend faux au premier
# rebuild qui deplace quoi que ce soit (vecu le 23/08).
# LA FENETRE CARTOUCHE DU TO8 EST EN $0000-$3FFF (map.ram.CART_START), pas en
# $A000 — $A000 est l'ecran. Une unite paginee se lit donc a son adresse telle
# quelle, une fois sa page montee.
import json
_h = open(os.path.join(os.path.dirname(image), "occupancy-fd.html")).read()
_D = json.loads(re.search(r'const DATA\s*=\s*(\{.*?\});', _h, re.S).group(1))
CHEAT_PAGE = CHEAT_ADDR = None
for _sc in _D["ram"]["scenes"]:
    for _l in _sc["loads"]:
        if _l["name"] == "title.cheat":
            CHEAT_PAGE, CHEAT_ADDR = _l["page"], _l["address"]
if CHEAT_PAGE is None:
    print("!! title.cheat introuvable dans le rapport d'occupation")
    t.close(); sys.exit(3)
print("cheat : page %02X adresse %04X" % (CHEAT_PAGE, CHEAT_ADDR))


def cart(off):
    return CHEAT_ADDR + off


# monter la page du cheat, comme paged.call le ferait
t.call("write_memory", {"addr": "E7E6", "bytes": ["%02X" % (0x60 + CHEAT_PAGE)]})
t.call("write_memory", {"addr": "%04X" % cart(0xDF), "bytes": ["%02X" % stage]})
t.call("write_memory", {"addr": "%04X" % cart(0xE0), "bytes": ["01"]})
print("cheat pose : stage %d, invincible" % stage)
t.call("set_register", {"reg": "pc", "value": "%04X" % cart(0x9D)})
t.call("run_frames", {"n": 120})
b = t.read("87DB", 8)
print("apres le saut : magic=%02X stage=%02X" % (b[0], b[1]))
t.call("run_frames", {"n": trames})
b = t.read("87DB", 8)
print("apres %d trames : stage=%02X tour=%02X camera=%d spawns=%d"
      % (trames, b[1], b[2], (b[3] << 8) | b[4], (b[5] << 8) | b[6]))
shutil.copy(t.call("screenshot")["path"], dest)
print("capture ->", dest)
t.close()
