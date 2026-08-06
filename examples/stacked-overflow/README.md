# stacked-overflow — une liste empilée qui franchit une page

Dix marqueurs de 2 Ko chargés dans une région `stacked` : ils remplissent une
page et débordent sur la suivante. Chaque marqueur est rempli de son propre
numéro, de 1 à 10 — jamais 0, qu'on ne saurait distinguer d'une RAM jamais
écrite.

Deux cibles, `to8.config.xml` et `mo6.config.xml`, parce que le défaut cherché
ne se voit que sur l'une des deux.

## Ce que l'exemple a déjà trouvé

**Un décalage d'un octet par fichier**, observé en mémoire sur TO8 après
chargement — indépendamment du programme de vérification :

```
$0000-$07FF   01 01 …      marqueur 1, à sa place
$0800         00           un octet que personne n'a écrit
$0801-$1000   02 02 …      marqueur 2, décalé de 1
$1001         00
$1002-…       03 03 …      marqueur 3, décalé de 2
```

L'entrée de répertoire est pourtant juste : `sizeu = $07FF`, soit 2047, et le
chargeur ajoute 1 — il devrait avancer de 2048 exactement. Le décalage naît
donc à l'exécution, pas dans la donnée. **Non élucidé.**

Ce défaut est visible sur TO8, donc il n'a rien à voir avec celui décrit
ci-dessous. Une liste empilée de n fichiers perd n octets et décale tout ce qui
suit le premier.

## Le défaut que l'exemple était censé éprouver

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
où le motif apparaît (`type10` et `type11`). **Non éprouvé en machine** : c'est
ce que cet exemple doit permettre.

## Comment lire le résultat

Le programme cherche chaque marqueur là où le chargeur devait le mettre, et
répond par la bordure de l'écran :

- **verte** — tous les marqueurs sont à leur place ;
- **rouge** — un manque ; son numéro est laissé dans l'octet `report` du
  programme.

Attendu : TO8 vert avant comme après le correctif (sa fenêtre s'ouvrant à zéro,
il ne pouvait pas voir le défaut) ; MO6 rouge avant, vert après. C'est cette
différence-là qui prouve le correctif.

**En l'état, le programme de vérification n'est pas fiable** : sur TO8 il se fige
sur une instruction qui ne peut pas figer, ce qui veut dire qu'il ne lit pas ce
qu'il croit lire. À reprendre avant de conclure quoi que ce soit de sa bordure.
Le décalage d'un octet, lui, est établi par lecture directe de la mémoire et ne
dépend pas de ce programme.

## Construire

```bash
cd examples/stacked-overflow
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
java -Dbasedir=../.. -cp "../../repo/*" com.widedot.m6809.gamebuilder.MainCommand -f mo6.config.xml
```
