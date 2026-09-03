#!/usr/bin/env python3
"""Les glyphes de ponctuation manquants de la police du title.

Rejeu :  python3 tools/gen_font_glyphs.py > gen/hud/font-extra.asm

POURQUOI CE SCRIPT. La police du title ne portait que A-Z, 0-9, l'espace, '!'
et '.'. La saisie du high score a besoin de six signes de plus — l'alphabet
arcade (0x1000:0B5C) en compte trente-quatre, dont '<' pour RUB et ':' pour
END. Les dessiner a la main en 6809 est une corvee illisible : une grille
d'art se relit, pas une suite de LDA/STA.

LE FORMAT, releve sur les glyphes existants (voir doc/high-score-entry-arcade.md).
Un glyphe fait QUATRE pixels de large et HUIT lignes, dont la derniere est
toujours vide. L'ecran est en BM16 : deux plans distants de $2000, et une
cellule d'un octet par plan porte quatre pixels de quatre bits —
    plan A : pixel 0 dans le quartet haut, pixel 1 dans le bas
    plan B : pixel 2 dans le quartet haut, pixel 3 dans le bas
La routine recoit U sur la cellule et ecrit de U-120 a U+160, par pas de 40
(la largeur d'une ligne d'ecran) : le point d'ancrage est au MILIEU du
glyphe, pas en haut.

LA CHARTE DE COULEUR est un degrade vertical, deduit des vingt-six lettres :
    lignes 0-1 : le premier pixel allume de la ligne prend 3, les suivants 6
    lignes 2-4 : 5
    lignes 5-6 : 4
Le point ('.') fait exception avec un 6 en ligne 5 — un reflet. La virgule le
suit, pour rester sa soeur.
"""

# '#' = pixel allume (la couleur vient de la charte), '.' = transparent.
# Chaque grille : 8 lignes de 4 colonnes.
GLYPHES = {
    "question": [
        ".##.",
        "#..#",
        "...#",
        "..#.",
        ".#..",
        "....",
        ".#..",
        "....",
    ],
    "gt": [                      # '>'
        "#...",
        ".#..",
        "..#.",
        "...#",
        "..#.",
        ".#..",
        "#...",
        "....",
    ],
    "lt": [                      # '<', l'alphabet arcade s'en sert pour RUB
        "...#",
        "..#.",
        ".#..",
        "#...",
        ".#..",
        "..#.",
        "...#",
        "....",
    ],
    "comma": [
        "....",
        "....",
        "....",
        "....",
        "....",
        ".#..",
        ".#..",
        "#...",
    ],
    "dash": [
        "....",
        "....",
        "....",
        "###.",
        "....",
        "....",
        "....",
        "....",
    ],
    "colon": [                   # ':', l'alphabet arcade s'en sert pour END
        "....",
        "#...",
        "#...",
        "....",
        "....",
        "#...",
        "#...",
        "....",
    ],
}

# La virgule herite du reflet du point : ligne 5 en 6 plutot qu'en 4.
REFLET = {"comma": {5: 6}}


def couleur(nom, ligne, premier):
    """La couleur d'un pixel allume, selon la charte."""
    exc = REFLET.get(nom, {}).get(ligne)
    if exc is not None:
        return exc
    if ligne <= 1:
        return 3 if premier else 6
    if ligne <= 4:
        return 5
    return 4


def encode(nom, grille):
    """Rend, par ligne, les deux octets de plan (A, B)."""
    out = []
    for y, row in enumerate(grille):
        px = []
        vu = False
        for x, c in enumerate(row):
            if c == "#":
                px.append(couleur(nom, y, not vu))
                vu = True
            else:
                px.append(0)
        out.append(((px[0] << 4) | px[1], (px[2] << 4) | px[3]))
    return out


# Les offsets d'ecran, dans l'ordre ou les glyphes existants les ecrivent.
# U arrive sur la cellule ; la routine se decale de 40 puis adresse en relatif.
ORDRE = [
    # (offset ecran depuis U, expression asm apres 'LEAU 40,U')
    (-120, "-160,U"),
    (-80, "-120,U"),
    (-40, "-80,U"),
    (0, "-40,U"),
    (40, ",U"),
    (80, "40,U"),
    (120, "80,U"),
    (160, "120,U"),
]


def emit(nom, grille):
    lignes = encode(nom, grille)
    print("DRAW_text_%s" % nom)
    print("        pshs u")
    for plan in (0, 1):
        if plan == 1:
            print("        leau  -$2000,u")
        print("        leau  40,u")
        # Grouper par valeur : un LDA sert plusieurs STA, comme la police
        # existante — c'est ce qui la rend compacte.
        vus = {}
        for (off, expr), pair in zip(ORDRE, lignes):
            vus.setdefault(pair[plan], []).append(expr)
        for val in sorted(vus):
            print("        lda   #$%02X" % val)
            for expr in vus[val]:
                print("        sta   %s" % expr)
        if plan == 1:
            print("        puls  u,pc")


def main():
    print("; " + "-" * 73)
    print("; LES GLYPHES DE PONCTUATION DE LA SAISIE DU HIGH SCORE")
    print("; " + "-" * 73)
    print("; Fichier GENERE — ne pas editer.")
    print("; Rejeu : python3 tools/gen_font_glyphs.py > gen/hud/font-extra.asm")
    print(";")
    print("; La police du title n'avait que A-Z, 0-9, l'espace, '!' et '.'.")
    print("; L'alphabet de la saisie (arcade 0x1000:0B5C) demande six signes de")
    print("; plus, dont '<' pour RUB et ':' pour END. Format et charte de")
    print("; couleur : voir l'en-tete du generateur et")
    print("; doc/high-score-entry-arcade.md.")
    print("; " + "-" * 73)
    print()
    for nom, grille in GLYPHES.items():
        for row in grille:
            print("; %s" % row.replace("#", "█"))
        emit(nom, grille)
        print()


if __name__ == "__main__":
    main()
