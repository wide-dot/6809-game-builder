#!/usr/bin/env python3
"""Réaligner les waves des stages sur l'extraction arcade, sans perdre les noms.

La table de vagues de chaque stage sort de re.arcade.r-type (ObjectWave.java,
table ROM $1B993-$1C5DB). L'extraction a progressé depuis l'import initial :
elle sait désormais nommer checkpoint, stageInit, starfield, bink, cancer, pstaff
et bossmusic là où elle n'avait que des numéros. Les waves du dépôt, elles,
portent des noms que l'extracteur ignore — gouger, baldur, gomander, outslay,
wick au stage 02 — trouvés à la main pendant le RE.

Ce script fusionne les deux : il aligne les entrées une à une (même ROM, même
parcours, donc même ordre), apprend l'identifiant de chaque nom déjà posé dans
le dépôt, et réécrit la wave avec l'union des deux nomenclatures.

Une entrée n'est ACTIVE que si son objet est porté. Le dépôt tient déjà cette
règle : au stage 02 les 29 gouger sont nommés mais commentés, seuls pow et
bossmusic tournent. Nommer documente le RE ; activer engage le runtime.

    usage : tools/sync_waves.py [NN ...] [options]

    --src DIR      racine de l'extraction (défaut ../../../re.arcade.r-type/out/object-wave)
    --ported a,b   objets portés, à activer (défaut : la liste ci-dessous)
    --dry-run      n'écrit rien

Le stage 01 est exclu par défaut : sa wave a été retravaillée à la main
(dobkeratops et sa mâchoire, tailmgr, checkpoints neutralisés) et devance
l'extraction. Le passer explicitement force son traitement.

Après modification d'une wave d'un stage monté, régénérer ses tables :
tools/gen_objid.py <NN>.
"""
import argparse
import os
import re
import sys

# Objets réellement portés en v2, donc activables depuis une wave.
# Ennemis : src/enemies/*. Reste : src/common/pickups/pow,
# src/common/state/checkpoint et src/common/flow/bossmusic.
# `fadetotunnel` en faisait partie ; l'objet est retiré depuis le 16/08/2026
# (la nouvelle palette n'a plus d'index de tunnel à faire fondre).
PORTED = ['bink', 'blaster', 'bug', 'cancer', 'checkpoint', 'bossmusic',
          'dobkeratops', 'dobkeratops_jaw', 'dobkeratops_monster',
          'patapata', 'pow', 'pstaff', 'scant', 'shell',
          'tabrok', 'tailmgr']

STAGES = ['02', '03', '04', '05', '06', '07', '08']
ENTRY = re.compile(r'^(?P<dead>[\s;]*)(?:fcb\s+)?'
                   r'\$(?P<hi>[0-9A-Fa-f]{2}),\$(?P<lo>[0-9A-Fa-f]{2}),'
                   r'ObjID_(?P<name>[A-Za-z0-9_]+),'
                   r'\$(?P<idval>[0-9A-Fa-f]{2}),\$(?P<val>[0-9A-Fa-f]{2})\s*$')


def parse(path):
    """Rend (entrées, queue). Une entrée : (nom, hi, lo, idval, val)."""
    entries, tail = [], []
    for line in open(path):
        m = ENTRY.match(line.rstrip('\n'))
        if m:
            entries.append((m['name'], m['hi'].upper(), m['lo'].upper(),
                            m['idval'].upper(), m['val'].upper()))
        else:
            # Tout ce qui n'est pas une entrée est recopié tel quel, lignes
            # vides comprises : la wave se termine sur une ligne vide puis
            # `fdb $FFFF`, et la reproduire évite un diff pour rien.
            tail.append(line.rstrip('\n'))
    return entries, tail


def main():
    ap = argparse.ArgumentParser(add_help=False)
    ap.add_argument('stages', nargs='*', default=None)
    ap.add_argument('--src', default='../../../re.arcade.r-type/out/object-wave')
    ap.add_argument('--ported', default=None)
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('-h', '--help', action='store_true')
    args = ap.parse_args()
    if args.help:
        print(__doc__)
        return 0

    stages = args.stages or STAGES
    ported = set(args.ported.split(',')) if args.ported else set(PORTED)

    print(f'{"stage":6} {"entrees":>8} {"actives":>8} {"nommees":>8} '
          f'{"heritees":>9}  noms repris du depot')
    for stage in stages:
        src = f'{args.src}/{stage}/object-wave-data.asm'
        dst = f'src/stages/{stage}/wave.asm'
        if not os.path.exists(src):
            print(f'{stage:6}  extraction absente ({src})', file=sys.stderr)
            continue

        fresh, tail = parse(src)
        current, _ = parse(dst) if os.path.exists(dst) else ([], [])

        # Alignement positionnel : même ROM, même parcours. On vérifie sur les
        # champs invariants plutôt que de faire confiance à l'ordre en aveugle.
        inherited = {}
        if current:
            if len(current) != len(fresh):
                print(f'{stage:6}  desalignement : {len(current)} entrees dans le '
                      f'depot contre {len(fresh)} extraites', file=sys.stderr)
                return 1
            for (old, *ok), (new, *nk) in zip(current, fresh):
                if ok != nk:
                    print(f'{stage:6}  desalignement sur {ok} / {nk}', file=sys.stderr)
                    return 1
                if new.isdigit() and not old.isdigit():
                    inherited.setdefault(new, old)

        out, active, named = [], 0, 0
        for name, hi, lo, idval, val in fresh:
            name = inherited.get(name, name)
            payload = f'${hi},${lo},ObjID_{name},${idval},${val}'
            if not name.isdigit():
                named += 1
            # Pas de marque en fin de ligne : « nommé mais commenté » se lit
            # déjà tel quel, et une annotation répétée noierait le diff de la
            # prochaine mise à jour sous 40 lignes inchangées au fond.
            if name in ported:
                out.append(f'\tfcb   {payload}')
                active += 1
            else:
                out.append(f';{payload}')

        text = '\n'.join(out + tail) + '\n'
        if not args.dry_run:
            with open(dst, 'w') as f:
                f.write(text)
        print(f'{stage:6} {len(fresh):8} {active:8} {named:8} {len(inherited):9}'
              f'  {", ".join(sorted(inherited.values())) or "-"}')

    if args.dry_run:
        print('\n(dry-run : rien ecrit)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
