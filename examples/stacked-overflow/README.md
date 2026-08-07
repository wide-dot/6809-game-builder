# stacked-overflow — une liste qui franchit une page

Dix marqueurs de 2 Ko chargés dans une **arène à deux zones** : ils remplissent
la première et débordent dans la seconde. Chaque marqueur est rempli de son
propre numéro, de 1 à 10 — jamais 0, qu'on ne saurait distinguer d'une RAM
jamais écrite.

Deux cibles, `to8.config.xml` et `mo6.config.xml`. L'exemple est né pour
éprouver l'empilement *à l'exécution* (`stacked="true"`), y a trouvé **deux
défauts**, corrigés et prouvés tous les deux — puis a survécu au retrait de
`stacked` (2026-08-06) : il prouve désormais que l'arène remplit ses zones dans
l'ordre et fait déborder la suite dans la zone suivante, le chargeur ne
recevant plus que des destinations explicites (`%01`). Mêmes adresses
attendues, décidées par le builder au lieu d'être recalculées par le chargeur.

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
où le motif apparaît (`type10` et `type11`). **Éprouvé sur MO6 le 2026-08-06**
(émulateur externe, bordure verte) — le TO8 ne peut pas voir ce défaut-là.

Depuis le retrait de `stacked`, le builder n'émet plus de bloc séquentiel pour
des données écrites en RAM : cette marche du chargeur (et son passage de page)
n'est plus exercée que par une table écrite à la main. Le correctif y reste,
prouvé par la validation ci-dessus.

## Comment lire le résultat

Le programme cherche chaque marqueur là où le chargeur devait le mettre, et
répond par la bordure de l'écran :

- **verte** — tous les marqueurs sont à leur place ;
- **rouge** — un manque ; son numéro est laissé dans l'octet `report` du
  programme (juste après le `bra *` final).

Vérifié sur les deux machines le 2026-08-06 : **TO8 vert** (émulateur TOJE,
dix marqueurs aux adresses exactes, franchissement de page compris) et
**MO6 vert** (émulateur externe) — la liste survit désormais au passage de
page quel que soit l'endroit où s'ouvre la fenêtre cartouche. Revérifié TO8
vert après la migration vers l'arène, le même jour.

Au passage : les indices de bordure sont la palette Thomson par défaut —
vert = 2, rouge = 1. Les valeurs initiales (3 et 6) affichaient jaune et cyan,
ce qui a fait passer le checker pour peu fiable alors qu'il disait vrai.

## Construire

```bash
cd examples/stacked-overflow
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f mo6.config.xml
```
