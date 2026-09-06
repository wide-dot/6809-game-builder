# Pourquoi le tableau est deux fois plus lent que la saisie (05/09/2026)

Profil toje sur le banc (`tools/profile.py`, symbolisé par
`tools/symbolize.py`), 200 trames par écran, soit 4 000 000 de cycles.
Les fps mesurés (`fps-reference.png`) donnent le nombre de boucles dans
la fenêtre : 67 pour la saisie, 34 pour le tableau. D'où le budget PAR
BOUCLE, ce qui compte vraiment :

| poste | saisie | tableau |
|---|---:|---:|
| blast d'effacement (`playfield.clearBlast`) | 23 k | 23 k |
| glyphes (titre, lignes, bas / labels, scores, noms) | 22 k | 47 k |
| conversions de score (`ranking.digits7`) | 3 k | 11 k |
| surlignage de la nouvelle entrée (`text.hiliteLine`) | 1 k (le curseur) | **30 k** |
| attente de la trame (`gfxlock.bufferSwap.wait`, oisif) | 9 k | 7 k |
| **total par boucle** | **60 k = 3 trames** | **117 k = 6 trames** |

Une trame vaut 20 000 cycles ; les fps sont donc **quantifiés à 50/n** :
16,7 = 3 trames, 8,5 ≈ 6 trames. Rien ne change tant qu'on ne franchit pas
une marche entière.

## Les trois causes, par ordre de poids

1. **Le surlignage coûte autant que le blast.** `text.recolor.byte` passe
   chaque octet par deux quartets, deux consultations de table et huit
   décalages : **83 cycles par octet**, 368 octets (23 cellules × 8 rangées
   × 2 plans) par trame. Une table de 256 octets (un `lda a,x` par octet)
   ramènerait ça vers 8 k. La table des rouges tient dans l'arène
   (1 119 octets libres).
2. **Trois fois plus de glyphes** : ~200 par trame (10 lignes × 5 + 7 + 7,
   plus le titre) contre ~85. Un glyphe compilé vaut ~120 cycles, c'est
   incompressible à l'unité.
3. **Dix conversions de score par trame** au lieu de deux : 1,1 k chacune
   (soustractions répétées des puissances de dix). Le tableau est FIGÉ
   pendant sa tenue : convertir une fois à l'entrée (70 chiffres, un tampon
   de 70 octets) rend 11 k.

## Ce que ça donnerait

Surlignage par table (−22 k) et chiffres convertis une fois (−11 k) :
117 k → 84 k, soit **encore 5 trames (10 fps)** — la marche des 4 trames
(12,5 fps) est à 80 k. Il faudrait aussi rogner les glyphes (par exemple ne
pas repeindre les sept espaces d'un nom vide, ~20 % des glyphes de nom).

L'écran de saisie, lui, est à 60 k pour une marche à 40 k : aucune économie
sous 20 k ne se verra, et le blast seul en prend 23 — **le blast est le
plancher de ces écrans, 25 fps au mieux**, tant qu'on efface tout le champ
à chaque trame.

Note de méthode : toje symbolise mal les unités en page (elles partagent la
fenêtre cartouche) ; `paged.call → tryFoeFireShell` dans l'arbre EST le
blast (`common.overlay`), reconnu à son coût.

## Addendum du même jour : la saisie avec les Pata-Pata

Second profil, Pata-Pata armés (`tools/profile.py`, prefixe p3). Par boucle
(42 boucles dans 200 trames, 10,6 fps) : trois blasts 27 k, texte 30 k,
scripts des Pata-Pata (`moveByScript`) 10 k, sprites 6 k, attente 10 k —
95 k, cinq trames. Le premier passage avait 25 % de plus : trois appels
par trame à `playfield.clearLines`, dont la boucle de conversion coûte
8 000 cycles ; les fenêtres sont maintenant des constantes d'assemblage.
