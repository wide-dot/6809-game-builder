# CLOS — la chorégraphie caméra du warship (stage 3)

*20/08/2026. Le défaut est trouvé, corrigé et prouvé au runtime.*

## Le défaut

**Le signe de l'axe Y de la conversion arcade → v2 était inversé.** Toute la
trajectoire verticale du cuirassé était en MIROIR : l'arcade le tient HAUT
dans la bande pendant 27 s (33,8 s → 60,9 s du combat) ; sur TO8 il restait
en BAS exactement aussi longtemps. Tout le reste concordait — excursion,
durées, forme de la danse — ce qui a rendu l'erreur chère à voir.

L'exporteur convertissait la vitesse Y du script avec `Conv.yratio`, qui est
négatif parce que **l'axe Y des OBJETS arcade pointe vers le haut**. Mais ces
deux octets ne sont pas des coordonnées d'objet : ce sont les registres de
SCROLL `[0x2EF4]`/`[0x2EF8]`, et une caméra arcade a la même orientation
qu'une caméra v2. Le facteur juste est la magnitude du ratio, sans bascule :
**`sy = vy*+12`**, pas `-12`.

Preuve au niveau instruction, deux indices indépendants :

1. **Le fetch de tuile de fond** (0x40:1EE0..1F03) calcule sa ligne
   `row ≈ (cam_y + 0x17F − pos_y) / 8` : un `cam_y` plus GRAND va chercher une
   tuile plus BAS dans la carte pour le même point d'écran — le contenu monte
   à l'écran. C'est mot pour mot la convention de `mscroll.camera.y`.
2. **Le `NEG` manquant.** `auto_scroll` (0x40:0467) dérive un delta par trame
   pour chaque caméra et le donne aux objets. Les deltas X sont négués
   (0x0490, 0x04C4), les deltas Y **non** (0x04FA, 0x051B). Cette asymétrie
   EST l'axe Y-vers-le-haut qui annule déjà l'inversion de caméra : appliquer
   `yratio` par-dessus la compte deux fois.

(Au passage : les commentaires Ghidra de `tick_warship_master` et de
`warship_inner_script_step` se contredisent sur X/Y — la chaîne n'a été
refermée que par le code : octet 0 → `[BP+0x22]` → `[0x2EF8]` → `scroll_y_bg2`
dont l'entier `0x2ECD` est lu comme `y_background_camera`.)

## Ce qui a débloqué — et la leçon

Deux campagnes de banc avaient prouvé « la caméra suit la référence » puis
« l'écran suit la caméra ». Vrai les deux fois, et inutile : **la référence
portait l'erreur**. Un banc qui confronte le runtime à un modèle converti ne
peut que prouver le runtime fidèle à la conversion.

C'est le **journal runtime par trame** (demandé par l'auteur) qui a tranché :
`tools/warship_log.py` + l'instrumentation `WARSHIP_LOG_PAGE` du pilote →
**0 divergence sur 7044 trames** entre l'état de script lu en RAM et
l'intégrale du ROM. Plus rien à chercher côté v2 : l'erreur était côté arcade,
à deux instructions de là.

> Quand le modèle et le runtime concordent parfaitement et que le résultat
> reste faux, arrêter de déboguer le runtime et re-dériver la conversion
> depuis la MACHINE, pas depuis les annotations. Le commentaire de
> l'exporteur portait déjà `; speedy sign follows Conv.yratio — validate at
> integration` : un drapeau levé, jamais abaissé.

Consigné dans `.claude/skills/enemy-port/arcade-to-v2.md`, nouvelle section
« Caméras et registres de scroll ».

## Ce qui a changé

| Fichier | Changement |
|---|---|
| `re.arcade.r-type` `extractor/Warship.java` | **la source de vérité** : `sy = vy*+12`, doc de classe réécrite avec la preuve |
| `src/stages/03/warship/camera-script.asm` | export régénéré (295 entrées) — excursion v2 y passe de `[-66..38]` à `[-38..66]` |
| `src/stages/03/warship/pilot.asm` | garde `frameDrop.count == 0` (le do-while valait 256 tours) + le journal runtime sous `WARSHIP_LOG_PAGE` |
| `to8.config.xml` | `<define WARSHIP_LOG_PAGE $16>` et la zone d'arène `$16` commentée |
| `src/stages/03/main.asm` | `mscroll.camera.x/y EXTERNAL` sous le define |
| `tools/warship_{log,screen,traj,path,script_table}.py` | référence corrigée ; deux sondes nouvelles |
| `.claude/skills/enemy-port/arcade-to-v2.md` | la section « Caméras et registres de scroll » |

## L'instrumentation (à retirer quand l'auteur le juge bon)

Un enregistrement de **16 octets par trame vidéo dépilée**, écrit par le
pilote dans un anneau de 1008 entrées (20 s) logé en page `$16` :

```
+0 (2) gfxlock.frame.count   +2 (1) frameDrop.count   +3 (1) trames restantes
+4 (2) pilot.cursor          +6 (2) pilot.counter
+8 (2) pilot.sx              +10 (2) pilot.sy
+12 (2) mscroll.camera.x     +14 (2) mscroll.camera.y
```

La sonde monte la page dans la fenêtre cartouche **CPU gelé** (aucun cycle ne
s'écoule entre deux appels MCP, donc aucune IRQ ne voit la fenêtre déplacée)
et remet la page d'origine, relue par `read_page_map`, avant toute reprise.

Retrait : enlever le `<define symbol="WARSHIP_LOG_PAGE" .../>` du config et
décommenter la `<zone page="$16">` de l'arène ennemis. Le code du pilote est
entièrement sous `IFDEF`.

## Rappels

- Test : cheat **stage 3 + INVINCIBLE** (`tct.pstage=3`, `tct.pinv=1`) — les
  sondes le posent et **vérifient `cheat.invincible` en RAM** avant de mesurer.
- Build : `java -Dbasedir=<racine> -cp "../../repo/*"
  com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml`.
- toje : remonter la disquette après chaque rebuild ; `TOJE_FAST=1` pour le
  turbo, mais les dernières trames avant une capture doivent tourner en rendu.
- Témoins : `$87DB` magic `$CA`, `$87DC` stage.

## Reste ouvert (pas des défauts de la chorégraphie)

- **Le stage 3 rend la main à t≈7100 (~142 s)** alors que le script court
  jusqu'à 9536 trames (190 s) : sa carte (`map/in.png`, 1152 px) est plus
  courte que la vie du vaisseau. Probablement sans objet quand la séquence de
  fin arcade (0xc55d) décidera du passage au stage 4.
- **L'ancrage vertical** (`camera y0 = 0` dans `bship.params`) : l'excursion
  est passée de `[-66..38]` à `[-38..66]`. Le cadrage est à juger à l'œil
  contre la vidéo arcade — c'est une constante, pas un signe.
- Non porté : combat, spawner des 27 parties (0xc61f), fin de script, jalons
  musique.
