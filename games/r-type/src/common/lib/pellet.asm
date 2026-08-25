;*******************************************************************************
; La remise a neuf du champ de gommes du stage 4
;
; Inclus par l'unite de collision d'un stage, apres ses cartes.
;
; CE QU'IL RESTE, ET POURQUOI (24/08/2026)
; ----------------------------------------
; Ce fichier portait quatre primitives — test / clear / set / reset — qui
; tenaient d'accord DEUX representations de l'etat des gommes :
;   C  la carte de collision vivante : terrain dur ET gommes
;   T  le terrain dur seul, pour distinguer une gomme d'un mur
; « une gomme vivante » se lisait `C pose ET T libre`, et chaque mutation
; devait ecrire dans C.
;
; Ce n'est plus le montage. Les gommes ont maintenant LEUR carte, residente
; (src/stages/04/gumres.unit.asm) : pscroll la mute, et le moteur de collision
; la lit comme PLAN ARRIERE du stage — le double test qu'il sait deja faire
; rend « dur OU gomme » sans une ligne de plus. Un bit pose dans cette carte
; EST une gomme, par construction : plus rien a croiser, plus rien a
; synchroniser, et les trois divergences que l'ancien montage laissait passer
; (pousse invisible a la collision, effacement laissant un mur, checkpoint
; remettant une seule des deux cartes) disparaissent avec lui.
;
; pellet.test / pellet.clear / pellet.set sont donc supprimees : elles etaient
; deja mortes — depuis le remplacement de pellet par pscroll, plus personne ne
; les appelait. Ce que faisait `clear` se fait desormais par pscroll.erase, et
; ce que faisait `set` par pscroll.grow, sur la meme et unique carte.
;
; LE CONTRAT D'INCLUSION
; ----------------------
; L'unite hote doit avoir defini, avant d'inclure ce fichier :
;   pscroll.gum.map   le debut de la carte des gommes (EXTERNAL, residente)
;   pellet.ball0      le flux RLE des gommes d'origine
;*******************************************************************************

pellet.reset EXPORT

; ---------------------------------------------------------------------------
; pellet.reset — le champ repart INTACT
;
; Appelee a la reprise au checkpoint. La raison est le comportement de la
; vague : elle rejoue le MEME Cytron depuis le point de reprise, et s'il
; retracait sa ligne par-dessus celle d'avant on accumulerait des traces
; fantomes a chaque mort. checkpoint.load ne touche pas au disque, la remise a
; neuf se fait donc en memoire.
;
; La carte des gommes := D0, les gommes d'origine, deroulees d'un flux RLE.
; Plus d'union avec le terrain dur : le dur vit dans l'autre plan et n'a
; jamais bouge.
;
; Le flux est fait de paires [compte, valeur], terminees par un compte nul.
; ~25 000 cycles pour les 1 440 octets — une fois par mort, pas par trame.
;
; Pas de ligne vide dans la routine : elle romprait la portee des labels
; locaux de lwasm.
; ---------------------------------------------------------------------------
pellet.reset
        ldx   #pellet.ball0             ; le flux RLE des gommes d'origine
        ldy   #pscroll.gum.map          ; la carte a reconstruire
@run    ldb   ,x+                       ; le compte de la sequence
        beq   @fin                      ; 0 = fin du flux
        lda   ,x+                       ; la valeur D0 de la sequence
@byte   sta   ,y+
        decb
        bne   @byte
        bra   @run
@fin    rts
