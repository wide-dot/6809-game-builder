* ===========================================================================
* Les témoins du banc d'échange de stages
* ===========================================================================
* Le banc n'a pas d'affichage à lire : il écrit en RAM. La zone est hors de
* toute région de chargement, donc elle traverse les échanges — ce qui est
* exactement ce qu'on veut vérifier.
*
* Les témoins ne sont plus une RÉGION à eux (ils l'ont été, $9C00, 644 octets
* déclarés pour seize écrits) mais des équates du bloc réservé `globals`,
* juste après les variables inter-main. Même mécanisme, même zone, un seul
* endroit qui survive aux échanges de scène — et quand le banc partira, ces
* seize équates partiront avec lui sans laisser de trou dans le layout.
*
* Ils se placent AU-DESSUS de globals.missileUnlocked : variables.asm est un
* fichier repris de la v1, on l'étend, on ne le réarrange pas.

bench.MAGIC        equ $CA
bench.SCORE        equ $1234        ; l'état semé au premier stage
* Plus d'horloge de niveau : le stage passe la main quand la CAMERA atteint
* scroll_max, la fin de sa carte. Un compteur de trames demandait un recalage
* a chaque changement de longueur de niveau ou de vitesse de scroll, et a la
* vitesse reelle du jeu ses 800 trames ne couvraient qu'un dixieme du niveau 1
* (qui en demande 7680). Voir stage-main.asm.
bench.SCROLL_VEL   equ $0030        ; 8.8 : 3/16 de pixel par trame, la vitesse
                                    ; de r-type. Le banc tournait a $0200 pour
                                    ; traverser le niveau 1 en 800 trames au
                                    ; lieu de 7680 — mais les horodatages d'une
                                    ; wave sont des trames d'arcade, calees sur
                                    ; CETTE vitesse : accelerer le scroll
                                    ; desynchronise les apparitions du decor et
                                    ; rend toute observation d'un ennemi
                                    ; ininterpretable.

bench.magic        equ GLOBAL_VARIABLES+13   ; $CA : la partie a démarré
bench.stage        equ GLOBAL_VARIABLES+14   ; le numéro du stage qui tourne
bench.frames       equ GLOBAL_VARIABLES+15   ; compteur de trames, un blocage se voit
bench.camera       equ GLOBAL_VARIABLES+16   ; (mot) position caméra du stage courant
bench.spawns       equ GLOBAL_VARIABLES+18   ; (mot) objets réellement exécutés par la wave
bench.t1           equ GLOBAL_VARIABLES+20   ; $01 le stage 1 a tourné, sa wave a peuplé
bench.t2           equ GLOBAL_VARIABLES+21   ; $01 le stage 2 a tourné sur SES données
bench.t3           equ GLOBAL_VARIABLES+22   ; $01 l'état persistant a survécu à l'échange
bench.t4           equ GLOBAL_VARIABLES+23   ; $01 retour au stage 1 : l'échange est réversible
bench.t5           equ GLOBAL_VARIABLES+24   ; $01 checkpoint sans disque : wave recalée
bench.stage1Spawns equ GLOBAL_VARIABLES+26   ; (mot) spawns du premier passage, pour comparer
bench.SIZE         equ 16                    ; le bloc entier, remis à zéro au démarrage :
                                             ; la zone n'est chargée par personne, donc
                                             ; sans ça un témoin non posé lit ce que la
                                             ; machine avait là — $FF, pas $00
bench.spawnStage   equ GLOBAL_VARIABLES+28   ; numéro du stage dont le bouchon a tourné en
                                             ; dernier : c'est LUI qui prouve le re-link,
                                             ; le moteur ne peut l'atteindre qu'en lisant
                                             ; l'index du stage effectivement chargé
