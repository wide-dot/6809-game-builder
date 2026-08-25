* ===========================================================================
* Les témoins du banc d'échange de stages
* ===========================================================================
* Le banc (`ci/toje-bench`) n'a pas d'affichage à lire : il démarre la vraie
* disquette sous toje, sans écran, et juge le jeu en lisant sa RAM. Ces neuf
* octets sont sa sortie — et sa seule entrée, par `bench.request`.
*
* La zone est hors de toute région de chargement, donc elle traverse les
* échanges de scène : c'est ce qui la rend utilisable pour observer un
* échange, et c'est aussi ce qui oblige le jeu à la mettre à zéro lui-même au
* démarrage (personne ne la charge, un témoin non posé lirait ce que la
* machine avait là — $FF, pas $00).
*
* L'ADRESSE NE S'ÉCRIT PLUS ICI. Elle vient de `gen/layout.asm`, que le
* builder génère depuis le <reserved name="bench"> du config — la même équate
* que lisent les scripts de la lane. Le bloc a déménagé trois fois (une région
* à lui de 644 octets pour seize écrits, puis un slot rendu par le pool en
* $8766, puis $87DB quand le title a grossi jusqu'à poser son dernier octet
* dessus) et chaque déménagement a laissé une adresse périmée derrière lui :
* la lane a tué son joueur à l'ancienne adresse pendant six jours, en écrivant
* dans le binaire du stage. Une seule source, plus de littéral.
*
* CE QUI A ÉTÉ RETIRÉ le 25/08/2026, avec sept des seize octets : `t1`..`t5`,
* les cinq contrôles du scénario forcé d'origine, dont la dé-banc-ification du
* 13/08 a supprimé l'écrivain quand le vrai flux du jeu a remplacé le scénario
* — plus personne ne les posait ni ne les lisait ; `stage1Spawns`, jamais
* écrit ; `bench.SCORE`, jamais lu ; et `bench.SCROLL_VEL`, qui n'était pas un
* témoin mais LA VITESSE DE DÉFILEMENT DU JEU — elle est devenue
* `stage.SCROLL_VEL`, dans le corps de stage qui l'emploie.
*
* PIÈGE, toujours d'actualité : cette zone est coincée entre le plafond des
* unités de stage et la région `cast`. Qui fait grossir une unité de stage la
* heurte — le builder le refuse alors explicitement, c'est le garde-fou de
* fb372903. Qui étend variables.asm ou déplace le pool doit regarder ce
* fichier aussi.

 IFNDEF BENCH_CONST
BENCH_CONST equ 1

        ; bench.address, sous sa propre garde d'inclusion
        INCLUDE "gen/layout.asm"

bench.MAGIC        equ $CA

bench.BLOCK        equ bench.address
bench.magic        equ bench.BLOCK+0   ; $CA : la partie a démarré
bench.stage        equ bench.BLOCK+1   ; le numéro du stage qui tourne
bench.frames       equ bench.BLOCK+2   ; compteur de trames, un blocage se voit
bench.camera       equ bench.BLOCK+3   ; (mot) position caméra du stage courant
bench.spawns       equ bench.BLOCK+5   ; (mot) BOUCHONS exécutés — le stage 1 n'en
                                       ; a plus (cast porté), seul le stage 2 compte
bench.spawnStage   equ bench.BLOCK+7   ; le stage dont le bouchon a tourné en dernier :
                                       ; c'est LUI qui prouve le re-link, le moteur ne
                                       ; peut l'atteindre qu'en lisant l'index du stage
                                       ; effectivement chargé
bench.request      equ bench.BLOCK+8   ; la fenêtre de COMMANDE de la lane — le pendant
                                       ; des témoins : un octet que le harnais écrit, lu
                                       ; une fois par tour de stage.loop. Non nul = mort
                                       ; du joueur (le geste de la fin d'explosion) ;
                                       ; remis à zéro en le consommant. C'est ce qui rend
                                       ; le chemin mort/READY/checkpoint/game-over
                                       ; exerçable : le vaisseau de la lane ne meurt pas
                                       ; tout seul.
bench.SIZE         equ 9                    ; le bloc entier, remis à zéro au démarrage

 ENDC
