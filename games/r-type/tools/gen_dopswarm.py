#!/usr/bin/env python3
"""Genere les tables de l'essaim de Dops (boss du stage 6) depuis la ROM arcade.

L'essaim est porte en REPERE ARCADE, comme Bellmite et le Compiler : les
tables sont recopiees TELLES QUELLES, sans conversion.

  1000:C5E3  le script de l'essaim : {curseur, jeton} par Dop, jusqu'a une
             entree dont le seuil depasse 0x800 (jamais atteinte)
  1000:931C  les quatre decalages de table de vitesse (load_state_preset_4,
             bits 4-5 du jeton)
  1000:2A80  les vitesses par voie, 8.8 : quatre jeux de quatre voies
             {vx, vy} (droite, bas, gauche, haut)
  1000:2A40  la sonde d'anticipation par voie, variante A puis B (2A60) :
             {premier pas x, y, pas suivant x, y}, en pixels

La carte des tuiles ne passe pas par ce script : le port lit la carte de
collision du stage 6 (src/stages/06/terrain/level6_fc.bin) par INCLUDEBIN,
et tools/fidelity/models/dopswarm_model.py a verifie qu'elle rend les memes
reponses que la RAM de tuiles de la borne sur tout le combat.

Sortie : src/enemies/dop/tables.asm.
Rejeu : python3 tools/gen_dopswarm.py (depuis games/r-type/) ;
        python3 tools/gen_dopswarm.py --check dit si la sortie est a jour.
"""
import os
import struct
import sys

ROM = ('/Users/benoitrousseau/Documents/Claude/Projects/re.arcade.r-type'
       '/out/rom/maincpu.bin')
SEG = 0x10000
OUT = 'src/enemies/dop/tables.asm'


def words(rom, a, n):
    return struct.unpack_from('<%dh' % n, rom, SEG + a)


def render(rom):
    script = []
    a = 0xC5E3
    while True:
        t, k = struct.unpack_from('<HH', rom, SEG + a)
        script.append((t, k, a))
        a += 4
        if t > 0x800:
            break
    pre = words(rom, 0x931C, 4)
    vel = words(rom, 0x2A80, 32)
    look = words(rom, 0x2A40, 32)
    L = [
        '; GENERE par tools/gen_dopswarm.py depuis la ROM arcade — ne pas editer.',
        '; Repere ARCADE (x a droite, y vers le haut), valeurs non converties.',
        '',
        '; 1000:C5E3 le script de l\'essaim : {curseur, jeton}',
        'dsw.Script',
    ]
    for t, k, a in script:
        L.append('        fdb   $%04X,$%04X  ; %04X' % (t, k, a))
    L += ['', '; 1000:931C le decalage de table de vitesse, par bits 4-5 du jeton',
          'dsw.VelSet',
          '        fcb   ' + ','.join('$%02X' % (v & 0xFF) for v in pre),
          '', '; 1000:2A80 les vitesses, 8.8 : quatre jeux de {vx, vy} par voie',
          'dsw.Vel']
    for i in range(0, 32, 8):
        L.append('        fdb   ' + ','.join('$%04X' % (v & 0xFFFF) for v in vel[i:i + 8])
                 + '  ; +$%02X' % (i * 2))
    L += ['', '; 1000:2A40 la sonde : {premier pas x, y, pas x, y} par voie, A puis B',
          'dsw.Look']
    for i in range(0, 32, 4):
        L.append('        fdb   ' + ','.join('%d' % v for v in look[i:i + 4])
                 + '  ; %s voie %d' % ('AB'[i // 16], (i // 4) & 3))
    return '\n'.join(L) + '\n'


def main():
    text = render(open(ROM, 'rb').read())
    if '--check' in sys.argv:
        cur = open(OUT).read() if os.path.exists(OUT) else ''
        print('%s : %s' % (OUT, 'a jour' if cur == text else 'PERIME — relancer tools/gen_dopswarm.py'))
        return 0 if cur == text else 1
    open(OUT, 'w').write(text)
    print('%s ecrit' % OUT)
    return 0


if __name__ == '__main__':
    sys.exit(main())
