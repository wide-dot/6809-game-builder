#!/usr/bin/env python3
"""Comprimer un masque de cellules en RLE, pour la remise a neuf du champ.

    python3 tools/rle_mask.py <masque.bin> <sortie.rle>

## Pourquoi

Le champ de gommes du stage 4 doit repartir INTACT quand le joueur meurt : la
vague rejoue le meme Cytron depuis le checkpoint, et s'il retracait sa ligne
par-dessus celle d'avant on accumulerait des traces fantomes. `checkpoint.load`
ne touche pas au disque — la remise a neuf doit donc se faire en memoire, et il
faut une copie pristine.

Mais la region `collision` de la page $17 est bornee : le builder place l'init
du stage juste apres la PLUS GROSSE unite de collision ($136F, celle du stage
1), et l'unite du stage 4 en occupe deja 3 971. Une copie brute de 1 440 octets
la ferait deborder.

D'ou ce RLE : le masque des gommes tombe de 1 440 a 262 octets (131 sequences),
parce que le champ est un bloc compact — de longues suites de $00 et de $FF.
`pellet.reset` le deroule et recompose `C = T OR D0` a la volee.

## Format

Des paires [compte(1..255), valeur(1)], terminees par un octet de compte nul.
Volontairement trivial : le decodeur 6809 fait dix instructions et tourne une
fois par mort, pas par trame. Un ZX0 ferait mieux (67 octets) mais couterait le
decompresseur et un tampon ; ici la simplicite gagne.
"""
import sys


def rle(data):
    out = bytearray()
    i = 0
    runs = 0
    while i < len(data):
        j = i
        while j < len(data) and data[j] == data[i] and j - i < 255:
            j += 1
        out.append(j - i)
        out.append(data[i])
        runs += 1
        i = j
    out.append(0)          # sentinelle de fin
    return out, runs


def decode(blob):
    """Le miroir exact du decodeur 6809 — sert a verifier l'aller-retour."""
    out = bytearray()
    i = 0
    while blob[i]:
        out.extend([blob[i + 1]] * blob[i])
        i += 2
    return out


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    src, dst = sys.argv[1], sys.argv[2]
    with open(src, 'rb') as f:
        data = f.read()
    blob, runs = rle(data)
    if decode(blob) != data:
        raise SystemExit('ERREUR : l\'aller-retour RLE ne redonne pas la source')
    with open(dst, 'wb') as f:
        f.write(blob)
    print('%s : %d octets -> %s : %d octets (%d sequences), aller-retour verifie'
          % (src, len(data), dst, len(blob), runs))
    return 0


if __name__ == '__main__':
    sys.exit(main())
