* ===========================================================================
* Les témoins du banc d'échange de stages
* ===========================================================================
* Le banc n'a pas d'affichage à lire : il écrit en RAM, sous $9C00, comme les
* autres bancs du dépôt. La zone est hors de toute région de chargement, donc
* elle traverse les échanges — ce qui est exactement ce qu'on veut vérifier.

bench.MAGIC        equ $CA
bench.SCORE        equ $1234        ; l'état semé au premier stage
bench.STAGE_FRAMES equ 800          ; horloge de niveau : de quoi atteindre les
                                    ; premiers horodatages reels des deux waves
                                    ; (504 pour le niveau 1, 518 pour le 2) et
                                    ; de traverser le niveau 1 en entier
bench.SCROLL_VEL   equ $0200        ; 8.8 : 2 px par trame. La vitesse de r-type
                                    ; est $0030, soit 3/16 de pixel — traverser
                                    ; les 1440 px du niveau 1 y prendrait 7680
                                    ; trames. Le banc accelere pour tenir dans
                                    ; son budget ; c'est la SEULE valeur du banc
                                    ; qui n'est pas celle du jeu.

bench.magic        equ $9C00        ; $CA : la partie a démarré
bench.stage        equ $9C01        ; le numéro du stage qui tourne
bench.frames       equ $9C02        ; compteur de trames, un blocage se voit
bench.camera       equ $9C03        ; (mot) position caméra du stage courant
bench.spawns       equ $9C05        ; (mot) objets réellement exécutés par la wave
bench.t1           equ $9C07        ; $01 le stage 1 a tourné, sa wave a peuplé
bench.t2           equ $9C08        ; $01 le stage 2 a tourné sur SES données
bench.t3           equ $9C09        ; $01 l'état persistant a survécu à l'échange
bench.t4           equ $9C0A        ; $01 retour au stage 1 : l'échange est réversible
bench.t5           equ $9C0B        ; $01 checkpoint sans disque : wave recalée
bench.stage1Spawns equ $9C0D        ; (mot) spawns du premier passage, pour comparer
bench.spawnStage   equ $9C0F        ; numéro du stage dont le bouchon a tourné en
                                    ; dernier : c'est LUI qui prouve le re-link,
                                    ; le moteur ne peut l'atteindre qu'en lisant
                                    ; l'index du stage effectivement chargé
