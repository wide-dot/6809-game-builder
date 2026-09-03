# soundfx — le testeur de bruitages

Écouter chaque bruitage du corpus Master System de R-Type sur le YM2413 du
TO8, sur son instrument d'origine ou sur l'un des quinze instruments de la ROM
du chip — pour **choisir**, et pour **valider** son par son ce qu'on garde.

Ce n'est pas un jeu : un seul game mode résident, l'écran texte du moniteur,
le pilote de bruitage du jeu (`engine/sound/soundFX.asm`) sous l'IRQ 50 Hz,
et les 54 blocs du corpus.

## Construire et lancer

```
ln -s ../../engine engine      # une fois
java -Dbasedir=<racine du repo> -cp "../../repo/*" \
     com.widedot.m6809.gamebuilder.MainCommand -f to8.config.xml
```

Sortie dans `dist/` (`to8.fd`, `to8.sd`, `to8.sap`).

## À l'écran

```
SON         041  REBOUND LASER
INSTRUMENT  005  CLARINETTE
MODE        AUTO
```

- **AUTO** (au démarrage) : déroule les dix-neuf sons du jeu dans l'ordre du
  corpus ; chaque son qui joue sur l'instrument personnalisé est rejoué sur
  les quinze presets. Un silence de 25 trames sépare deux sons. C'est la
  séquence que la vidéo enregistre (environ 100 s, puis ça reboucle).
- **MANUEL** : `ESPACE` joue, `N`/`P` son suivant/précédent (tout le corpus,
  54 sons), `I`/`U` instrument suivant/précédent (`D'ORIGINE`, puis 0 à 15,
  0 étant l'instrument personnalisé du bloc), `A` rebascule en auto.

Le remplacement d'instrument réécrit le quartet haut des commandes `$30` du
bloc, copié dans un tampon ; le bloc lui-même n'est jamais modifié.

## Le corpus

`src/corpus.asm` et `src/corpus/` sont **générés** par `tools/gen_corpus.py`
depuis `games/r-type/reference/sms/sfx/soundfx/` (la sortie de
`tools/sms_sfx_to_soundfx.py` côté jeu). L'exemple ne dépend pas du jeu au
build : les blocs sont copiés ici, et le script est la seule façon de les
rafraîchir. Il relève pour chaque son son identifiant Master System, son nom,
sa durée, s'il joue sur l'instrument personnalisé et s'il fait partie des
dix-neuf sons du jeu.

Les instruments de la ROM, dans l'ordre du chip : violon, guitare, piano,
flûte, clarinette, hautbois, trompette, orgue, cor, synthé, clavecin,
vibraphone, basse synthé, basse acoustique, guitare électrique.

## La vidéo

`videos/sfx-tester.mp4` — un cycle complet, six minutes : les dix-neuf sons du
jeu, puis les cinq qui jouent sur l'instrument personnalisé rejoués sur les
quinze presets. L'écran annonce le son et l'instrument à chaque fois.

Elle n'est **pas versionnée** (aucun exemple du dépôt ne l'est) : la recette
ci-dessous la reproduit à l'identique.

## Filmer la séquence sous toje

Armer la capture sur l'entrée du game mode, amorcer, laisser courir :

```
arm_video_capture  start={pc:"6300"}
boot_disk          examples/soundfx/dist/to8.fd, settle_frames=60
run_frames         20000            # un cycle complet fait environ 18 000 trames
stop_video_capture
```

Le film porte le son du YM2413 (toje mixe CNA, buzzer, SN76489 et YM2413).
Encoder en **H.264** (`encode_capture codec=h264`, ou ffmpeg avec `-tag:v
avc1`) : le HEVC par défaut sort taggé `hev1`, qu'un iPhone refuse.

## Le piège qui a coûté le plus de temps

Le game mode se charge en **`$6300`, pas en `$6100`**. Les deux pages sous
`$6300` appartiennent au moniteur — sa page directe *et* les tampons de son
écran texte. Chargé en `$6100`, ce testeur voyait huit octets de code effacés
à la première impression, en plein milieu de la routine d'avance : elle
sautait son `ldb tester.sel` et rejouait indéfiniment le premier son, écran
figé. Rien ne plantait, tout avait l'air de marcher. L'exemple `mplus`, qui
lit lui aussi le clavier par le moniteur, charge en `$6300` pour la même
raison.
