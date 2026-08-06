# stacked-overflow — une liste empilée qui franchit une page

Dix marqueurs de 2 Ko chargés dans une région `stacked` : ils remplissent une
page et débordent sur la suivante. Chaque marqueur est rempli de son propre
numéro, de 1 à 10 — jamais 0, qu'on ne saurait distinguer d'une RAM jamais
écrite.

Deux cibles, `to8.config.xml` et `mo6.config.xml`. L'exemple aura finalement
trouvé **deux défauts**, corrigés tous les deux.

## Défaut 1 — le décalage d'un octet par fichier (élucidé, corrigé)

Observé en mémoire sur TO8 : marqueur 2 à `$0801`, marqueur 3 à `$1002` — un
octet fantôme entre chaque fichier, cumulatif. Et pire, constaté ensuite :
**seule la première moitié de la liste se chargeait** (5 marqueurs sur 10).

L'entrée de répertoire était pourtant juste (`sizeu = $07FF`, sectorisation
exacte). La cause était dans la **marche des ids du type %11** (liste à ids
consécutifs) : le chargeur calcule l'id suivant d'après les *drapeaux* de
l'entrée —

```asm
ldb   #1                ; id suivant : +1
lda   dir.entry.bitfld,y
lsla
adcb  #0                ; +1 si compressé
lsla
adcb  #0                ; +1 si linkdata
abx
```

— alors que le builder alloue les ids d'après les *déclarations* : un fichier
qui déclare `linkdata="LINK"` réserve un second bloc de 8 octets même quand la
section moissonnée est vide (élagage du loadtimelink), en laissant le drapeau
baissé. Le chargeur avançait donc de 1 au lieu de 2, retombait sur le **bloc
réservé zéroté** et le traitait comme un fichier : `sizea=0` → rien chargé,
`sizeu=0` → avance de `0+1 = 1` octet, et une itération du compteur brûlée.
D'où l'octet fantôme *et* la moitié manquante.

**Correctif** (`DirEntryPlugin`) : le drapeau bit 6 reflète le **bloc réservé**,
pas son contenu. Section déclarée mais vide → drapeau levé sur un descripteur
zéroté ; le chargeur lit une taille de 0 et l'ignore (« Ignore empty link
file », chemin qui existait déjà). Les types %01 et %10 n'ont jamais été
touchés : leurs ids sont explicites.

## Défaut 2 — la page suivante s'ouvrait à zéro

Quand une liste déborde d'une page, le chargeur passe à la suivante. Il y
repartait de l'adresse **zéro** :

```asm
ldu   #0                      ; avant
ldu   #map.ram.CART_START     ; après
```

Sur TO8 la fenêtre cartouche s'ouvre justement à `$0000` : les deux nombres se
confondent, et rien n'a jamais montré le défaut. Sur MO6 elle s'ouvre à
`$B000`, et le chargeur écrivait 45 Ko sous sa fenêtre, en pleine RAM système.

Corrigé dans `engine/system/thomson/bootloader/loader.asm`, aux deux endroits
où le motif apparaît (`type10` et `type11`). **Reste à éprouver sur MO6** — le
TO8 ne peut pas voir ce défaut-là.

## Comment lire le résultat

Le programme cherche chaque marqueur là où le chargeur devait le mettre, et
répond par la bordure de l'écran :

- **verte** — tous les marqueurs sont à leur place ;
- **rouge** — un manque ; son numéro est laissé dans l'octet `report` du
  programme (juste après le `bra *` final).

Vérifié sur TO8 (émulateur TOJE, 2026-08-06) : bordure verte, les dix
marqueurs aux adresses exactes, le franchissement de page compris. Attendu sur
MO6 : rouge avec le seul défaut 2 présent, vert une fois le loader corrigé —
c'est cette différence-là qui prouve le correctif MO6.

Au passage : les indices de bordure sont la palette Thomson par défaut —
vert = 2, rouge = 1. Les valeurs initiales (3 et 6) affichaient jaune et cyan,
ce qui a fait passer le checker pour peu fiable alors qu'il disait vrai.

## Construire

```bash
cd examples/stacked-overflow
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f mo6.config.xml
```
