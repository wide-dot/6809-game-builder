; PALETTE-MIGREE — voir games/r-type/tools/palette-code.txt
; ===========================================================================
; Starfield - 22 etoiles sur le ciel ouvert du niveau 1 : 8 sur le plan 0,
; 7 sur les plans 1 et 2.
;
; Les etoiles n'ont AUCUN etat mutable, et depuis stardata.asm elles n'ont plus
; non plus de calcul d'adresse : l'adresse VRAM d'une etoile ne depend que de
; (plan, offset, etoile), trois valeurs connues a la COMPILATION (x_base et y
; sont des constantes, l'offset ne prend que 144 valeurs entieres). Tracer, c'est
; donc `ldx ,u++`. La table (6048 o) vit dans la page cartouche : gratuite en RAM
; residente, et valable pour les DEUX buffers (le pager permute les pages
; physiques, l'adresse logique ne bouge pas).
;
; Toutes les etoiles d'un plan partagent un offset de defilement, et tous les
; x_base sont PAIRS. Comme le wrap ajoute 144 (pair), parite(x) == parite(off) :
; le nibble est connu une fois par PLAN et par passe, pas par etoile. D'ou deux
; boucles specialisees (nibble haut / nibble bas) et 2 o par entree de table.
;
; Couleurs = index materiels (un nibble EST un index : pas de decalage de
; transparence comme dans les PNG) : 1 = gris moyen #616161, 2 = gris clair
; #A8A8A8, 4 = bleu fonce #00618F. Les valeurs qui font foi sont les masques du
; descripteur, plus bas ; celles-ci n'en sont que le rappel.
;
; Invariant central : le ciel est le nibble 0.
;   tracer  : si notre nibble == 0 -> ecrire la couleur
;   effacer : si notre nibble == notre couleur -> remettre 0
;
; Les deux operations sont le MEME XOR, dans l'ordre inverse :
;   tracer  = tester 0 puis XOR   (0 ^ couleur = couleur)
;   effacer = XOR puis tester 0   (couleur ^ couleur = 0)
; et le masque n'est plus qu'un XOR de convenance : il VAUT la couleur.
;
; CE QUE CA COUTE, et c'est assume (auteur, 16/08) : le decor peint AUSSI son
; noir en nibble 0. Le ciel et le noir du decor sont donc le meme index, et une
; etoile peut desormais s'allumer dans une zone noire du decor ou d'un sprite.
; C'est mesure et petit — ~0,8 % de la bande d'etoiles cote decor, 26 px noirs
; sur les 1561 px du vaisseau — mais ce n'est pas nul. Avant, le ciel avait son
; propre noir (l'index 15) ; cet index porte maintenant un vert clair reserve
; aux sprites propres au stage 1, et le fondu de tunnel qui l'exploitait est
; retire.
;
; OVERLAY : UNE passe par trame. L'effacement global noircit le champ en tete
; de verrou et les etoiles se tracent DESSUS immediatement — ecriture directe,
; sans lecture ni test, le champ etant vierge par construction — puis les
; tuiles et les sprites recouvrent tout ce qu'ils traversent. La passe ERASE,
; ses tables d'offsets par buffer et le test "ciel vierge" sont partis avec
; le chantier effacement (l'effaceur global fait leur travail).
; ===========================================================================
; V2-DEVIATION: INCLUDE de macros.asm retire — l'unite hote le porte deja
; (en v1 chaque objet etait une unite d'assemblage a lui seul).

; ---------------------------------------------------------------------------
; Corps deroules. Les etoiles d'un plan sont adressees a OFFSET CONSTANT depuis
; U : `ldx \1,u` (6 cycles, offset 5 bits) au lieu de `ldx ,u++` (8), et surtout
; plus de `dec starCnt` + `bne` (10) -- soit ~12 des ~47 cycles par etoile. Le
; deroulage ne coute que de la page cartouche.
;
;   \1 = offset de CETTE etoile dans la table (0,2,..,12, et 14 pour la 8e)
;   \2 = offset de la SUIVANTE, qui sert de cible au saut (99 = fin de passe)
;
; COULEUR PAR ETOILE, a cout nul : chaque bloc lit SON masque XOR dans le
; descripteur, en offset NEGATIF depuis Y (les 16 masques sont ranges DEVANT le
; point d'entree du descripteur) : masque haut de l'etoile i en i-16,y, masque
; bas en i-8,y. i = \1/2 (ecrit \1/2-16 : sur si lwasm evalue gauche->droite). Offsets -16..-1 = 5 bits -> meme taille (2 o) et
; meme cout (5 cycles) que l'ancien `eora 4,y` a couleur unique par plan.
;
; Les plans n'ont pas tous le meme nombre d'etoiles (8 pour le plan 0, 7 pour
; les autres). Plutot que deux chaines completes, le bloc de la 8e etoile
; (offset 14) est place EN TETE et enchaine sur le bloc de la 1re : un plan a 8
; etoiles entre par le bloc de tete, un plan a 7 entre juste apres, et les deux
; sortent au meme rts. La 8e etoile coute donc du code une seule fois, et rien
; du tout aux plans qui ne l'ont pas.
;
; Le label est en tete de bloc et porte une instruction : lwasm ne definit un
; label depuis un parametre QUE dans ce cas. Une ligne ne portant que `\1` ou
; `sfdh\1` seul ne definit rien (erreur "Undefined symbol"), et les labels
; anonymes `>` / `!` ne se re-resolvent pas par expansion de macro.
; ---------------------------------------------------------------------------
; OVERLAY : ecriture DIRECTE — ni lecture, ni test, ni XOR. Le champ vient
; d'etre efface : l'autre nibble de l'octet est du ciel a zero, ecrire l'octet
; entier est juste. Un masque a zero (etoile eteinte par le fondu) ecrit du
; noir sur du noir. Le second argument des invocations (l'ancien chainage de
; saut) est conserve mais inutilise.
STAR_DH MACRO                           ; tracer, nibble haut
sfdh\1  ldx   \1,u
        lda   \1/2-16,y                 ; la couleur de CETTE etoile
        sta   ,x
 ENDM

STAR_DL MACRO                           ; tracer, nibble bas
sfdl\1  ldx   \1,u
        lda   \1/2-8,y
        sta   ,x
 ENDM

; V2-DEVIATION: le point d'entree unique `Object` et sa table de routage
; `sf_rtn` sont retires. En v1 il fallait un ObjID et une commande dans B parce
; qu'un objet ne s'atteignait que par l'index d'objets. En v2 les trois routines
; sont des symboles de lien que l'appelant vise directement par paged.call : on
; economise la table (6 o), le registre de commande et le jmp indirect, et le
; champ d'etoiles cesse d'occuper un identifiant que seule la vague devrait
; nommer. Les trois routines elles-memes sont inchangees.
; Cas de migration : docs/lang/en/migration/paged-routine.md
; Les trois routines sont exportees par l'unite enveloppe (starfield.asm).

; ---------------------------------------------------------------------------
; Descripteurs de plan - 25 octets : 16 masques DEVANT le point d'entree Y,
; puis 9 octets de parametres.
;   -16..-9,y  masques XOR nibble haut, un par etoile (couleur<<4)
;    -8..-1,y  masques XOR nibble bas,  un par etoile (couleur)
;    0,y  table (2)          adresse de starTab_pN
;    2,y  vitesse 8.8 (2)
;    4,y  pas (1)            nb_etoiles*2 (14 ou 16)
;    5,y  8e etoile (1)      1 = ce plan a une 8e etoile (entree du corps deroule)
;    6,y  nb de tours (1)    1 ou 2 (cf. gen_stardata.py)
;    7,y  lapStride (2)      pas*144, deplacement d'un tour dans la table
; Les etoiles vont vers la GAUCHE : x = x_base - offset, offset croissant.
;
; Les masques sont PAR ETOILE (le corps deroule lit -16+i,y / -8+i,y, cf. les
; macros) : la couleur de chaque etoile est un octet ici, cout zero en cycles.
; Le ciel valant 0, le masque VAUT la couleur : 1 = gris moyen #616161,
; 2 = gris clair #A8A8A8, 4 = bleu fonce #00618F. Les octets sont renumerotes
; par tools/palette_code.py, jamais a la main. L'etoile 8 (offset 14) = slot 7.
; ---------------------------------------------------------------------------
; Les masques de la table sont REECRITS par le fondu de sortie : StarfieldDraw
; les rebatit au palier courant quand celui-ci change (garde starTblPal). Les
; valeurs nominales font foi dans starMasksNominal ; celles ci-dessous n'en
; sont que l'etat de depart.
        fcb   $20,$10,$20,$20,$10,$20,$10,$20   ; p0 : clair,moyen,clair,clair,moyen,clair,moyen,clair
        fcb   $02,$01,$02,$02,$01,$02,$01,$02
planeTable
        fdb   starTab_p0
        fdb   $0100                     ; 1.0 px/trame (plan rapide)
        fcb   16,1                      ; 8 etoiles (2 amas de 4) -> pas 16
        fcb   2                         ; 2 tours : hauteurs differentes a chaque passage
        fdb   16*144                    ; lapStride = 2304
        fcb   $10,$40,$10,$10,$40,$10,$40,$00   ; p1 : moyen,bleu,moyen,moyen,bleu,moyen,bleu (7 etoiles)
        fcb   $01,$04,$01,$01,$04,$01,$04,$00
        fdb   starTab_p1
        fdb   $0080                     ; 0.5 px/trame
        fcb   14,0                      ; 7 etoiles -> pas 14
        fcb   1                         ; 1 tour (plan lent, ne repasse pas dans l'intro)
        fdb   14*144                    ; lapStride (inutilise a 1 tour)
        fcb   $40,$40,$10,$40,$40,$10,$40,$00   ; p2 : bleu fonce dominant, 2 grises moyennes (7 etoiles)
        fcb   $04,$04,$01,$04,$04,$01,$04,$00
        fdb   starTab_p2
        fdb   $0040                     ; 0.25 px/trame (plan lointain, le plus sombre)
        fcb   14,0                      ; 7 etoiles -> pas 14
        fcb   1                         ; 1 tour
        fdb   14*144                    ; lapStride (inutilise)

; ---------------------------------------------------------------------------
; Les masques NOMINAUX — 48 octets (p0 haut+bas, p1, p2), la reference que
; StarMasksApply transforme au palier courant. Les paliers n'existent pas en
; donnees : chaque octet nominal se transforme SEUL (cf. StarMasksApply), et
; un masque a zero eteint l'etoile — XOR nul, le trace n'ecrit plus rien,
; l'effacement ne matche que le ciel deja vide.
; ---------------------------------------------------------------------------
starMasksNominal
        fcb   $20,$10,$20,$20,$10,$20,$10,$20
        fcb   $02,$01,$02,$02,$01,$02,$01,$02
        fcb   $10,$40,$10,$10,$40,$10,$40,$00
        fcb   $01,$04,$01,$01,$04,$01,$04,$00
        fcb   $40,$40,$10,$40,$40,$10,$40,$00
        fcb   $04,$04,$01,$04,$04,$01,$04,$00
; ---------------------------------------------------------------------------
; Les durees par variant — la transposition de starfield_variant_dispatch
; (arcade 0x1000:8314), en trames de jeu TO8. L'horloge de wave v2 vaut 2x
; l'unite arcade (rate 2.0 de l'extraction), d'ou :
;   0  depart du stage 1     arcade 352x2 = 704. Suffisant : l'entree du
;      variant 2 prolonge le champ bien avant le terme (t=396 < 8+704).
;   1  boss du stage 4       arcade $8000, "jamais" — le combat finit avant.
;      $FFFF chez nous ($10000 ne tient pas sur 16 bits), meme intention.
;   2  apres le checkpoint 1 du stage 1. PAS la valeur arcade (2192x2 = 4384) :
;      sa carte est plus longue que la notre. Le ciel de NOTRE carte finit au
;      point que la v1 avait regle a l'oeil — camera 436 px, soit
;      436/24*128 = 2325 trames — et l'entree de wave est a t=396 :
;      2325-396 = 1929. Le variant 0, prolonge par celui-ci, meurt au meme
;      point : le compte est le meme qu'en jeu normal qu'au respawn.
;   3  cinematique finale du stage 8   arcade 2192x2 = 4384, garde tel quel.
; ---------------------------------------------------------------------------
starLifetimes
        fdb   704                       ; 0 : stage 1, depart
        fdb   $FFFF                     ; 1 : stage 4, boss Compiler
        fdb   1929                      ; 2 : stage 1, apres le checkpoint 1
        fdb   4384                      ; 3 : stage 8, cinematique finale

; ---------------------------------------------------------------------------
; StarfieldInit - naissance ou PROLONGATION, sur le modele de l'arcade.
;
; Y = variant 0..3, l'octet 5 de l'entree de wave (l'arcade lit CL & 3 dans
; starfield_spawner, 0x40:E430). Il indexe starLifetimes, la transposition de
; starfield_variant_dispatch (0x1000:8314) — reduite a son seul champ utile :
; nous n'avons ni naissances d'etoiles (spawn_period) ni vitesse par etoile
; (velocity_lut), nos 22 etoiles sont permanentes et leurs vitesses par plan.
;
; CHAMP MORT : naissance complete — offsets a zero, masques nominaux, duree.
; CHAMP VIVANT : prolongation seule — la duree devient max(restante, nouvelle),
; les offsets ne bougent PAS (les 22 etoiles ne sautent pas), et les masques
; redeviennent nominaux par le mecanisme de bascule par buffer (un fondu
; entame par une vie precedente serait fige la, sinon). C'est ce qui absorbe
; le chevauchement arcade des variants 0 et 2 au stage 1 : la 2e entree de
; wave etend le champ unique la ou l'arcade empile un second spawner.
;
; Le respawn au checkpoint est couvert par la WAVE, comme l'arcade : le recale
; d'ObjectWave_Init rejoue l'entree starfield posee apres le checkpoint —
; aucun code dedie ici (cf. wave1_starfield_boot/postintro dans le Ghidra).
; ---------------------------------------------------------------------------
StarfieldInit
        tfr   y,d
        andb  #3                        ; variant 0..3 (meme masque que l'arcade)
        aslb
        ldx   #starLifetimes
        ldd   b,x                       ; D = duree du variant, en trames de jeu
        ; les masques repartent au nominal au prochain trace (starPalier 0
        ; != starTblPal -> StarMasksApply) ; l'ecran, lui, est efface chaque
        ; trame — aucune etoile d'un fondu entame n'y survit.
        clr   starPalier
        clr   starFade                  ; un fondu entame repart de zero
        tst   starDead
        beq   sf_extend
        ; mort -> naissance complete : offsets et tours a zero
        std   starLifetime
        ldx   #starCurOff
        ldb   #9                        ; 6 (starCurOff) + 3 (starCurLap)
sf_ini  clr   ,x+
        decb
        bne   sf_ini
        clr   starDead
        rts
sf_extend
        cmpd  starLifetime              ; vivant -> prolonger : max des deux
        bls   >
        std   starLifetime
!       rts

; ---------------------------------------------------------------------------
; StarfieldKill - remise a mort inconditionnelle, SANS effacement : chaque
; entree de stage l'appelle avant sa trame d'amorce, ou les deux tampons
; viennent d'etre noircis de toute facon. L'etat du champ vit en page overlay
; chargee au boot : il SURVIT aux echanges de stage, et sans ce geste un
; retour au stage 1 heriterait de la vie d'un passage precedent.
; ---------------------------------------------------------------------------
StarfieldKill
        lda   #1
        sta   starDead
        rts

; ---------------------------------------------------------------------------
; StarMasksApply - rebatit les masques de planeTable depuis les NOMINAUX,
; transformes au palier demande dans A (et note starTblPal = A). L'echelle
; validee par l'auteur (18/08) est une fonction PURE de l'octet nominal —
; les paliers n'existent donc pas en donnees :
;   palier >= 1 : une claire ($20/$02) descend au gris moyen — un lsra
;   palier >= 2 : une bleue ($40/$04) s'eteint
;   palier >= 3 : une grise moyenne D'ORIGINE ($10/$01) s'eteint ;
;                 les ex-claires, elles, restent (leur nominal est $20/$02)
;   palier 0    : identite — la remise au nominal
; Les masques d'un plan vivent dans les 16 octets qui PRECEDENT ses
; parametres (cf. les macros). Clobber : A, B, X, U. Preserve Y.
; ---------------------------------------------------------------------------
StarMasksApply
        sta   starApplyLvl
        sta   starTblPal                ; la table portera ce palier
        ldu   #planeTable-16            ; masques du plan 0
        ldx   #starMasksNominal
        lda   #3
        sta   starApplyPl               ; plans restants
sfm_pl  ldb   #16
sfm_by  lda   ,x+
        beq   sfm_st                    ; eteinte reste eteinte
        bita  #$22                      ; une claire ?
        beq   >
        tst   starApplyLvl
        beq   sfm_st                    ; palier 0 : nominal tel quel
        lsra                            ; $20->$10, $02->$01
        bra   sfm_st
!       bita  #$44                      ; une bleue ?
        beq   sfm_moy
        lda   starApplyLvl
        cmpa  #2
        blo   sfm_kp                    ; avant le palier 2, elle vit
        clra
        bra   sfm_st
sfm_moy lda   starApplyLvl              ; une grise moyenne d'origine
        cmpa  #3
        blo   sfm_kp
        clra
        bra   sfm_st
sfm_kp  lda   -1,x                      ; retablir l'octet nominal
sfm_st  sta   ,u+
        decb
        bne   sfm_by
        leau  9,u                       ; sauter les 9 octets de parametres
        dec   starApplyPl
        bne   sfm_pl
        rts

; ---------------------------------------------------------------------------
; StarfieldDraw - LA passe du champ d'etoiles, appelee juste apres
; l'effacement global, avant les tuiles. Elle porte aussi le cycle de vie
; (horloge en trames de jeu, fondu en RENDUS — decision auteur, 19/08),
; transplante tel quel de l'ancienne passe ERASE. L'extinction n'a plus de
; queue d'effacement : quand plus rien ne se trace (fondu <= 12, les
; survivantes eteintes), le champ est simplement MORT — l'effaceur global
; nettoie l'ecran a la trame suivante.
; ---------------------------------------------------------------------------
StarfieldDraw
        lda   starDead
        lbne  sfd_done
        lda   starFade
        bne   sfd_fade                  ; fondu entame : il compte en RENDUS
; l'horloge de VIE, en trames de JEU : les trames sautees comptent, meme
; convention que l'avance des offsets plus bas — c'est elle qui ancre la
; fin du champ a une POSITION de la carte.
        ldb   gfxlock.frameDrop.count
        bne   >
        incb                            ; 0 -> compter 1 trame
!       clra
        pshs  d
        ldd   starLifetime
        subd  ,s++
        bhi   >
        ldd   #0                        ; terme deja depasse (grosse rafale de
!       std   starLifetime              ; drops) : le fondu part quand meme
        cmpd  #48
        bhi   sfd_masks                 ; loin du terme
        lda   #48                       ; le terme approche : armer le fondu
        sta   starFade
sfd_fade
        dec   starFade
        lda   starFade
        cmpa  #12
        bhi   >
        lda   #1                        ; 0..12 : les survivantes s'eteignent —
        sta   starDead                  ; plus rien a tracer, le champ est mort
        rts
!       ldb   #1                        ; 37..48 -> palier 1 : les claires en gris moyen
        cmpa  #36
        bhi   sfd_pal
        incb                            ; 25..36 -> palier 2 : les bleues s'eteignent
        cmpa  #24
        bhi   sfd_pal
        incb                            ; 13..24 -> palier 3 : les grises d'origine
sfd_pal cmpb  starPalier
        bls   sfd_masks                 ; palier deja atteint
        stb   starPalier
sfd_masks
; la table au palier courant (et au nominal apres une renaissance)
        lda   starPalier
        cmpa  starTblPal
        beq   >
        jsr   StarMasksApply
!       clr   starPlaneIdx
        ldy   #planeTable
sfd_plane
        ldb   starPlaneIdx
        aslb                            ; B = plan*2
        stb   starCurIdx

; --- 1) AVANCER l'offset courant (compense frame-drop) -----------------------
        lda   gfxlock.frameDrop.count
        bne   >
        inca                            ; 0 -> compter 1 trame
!       sta   starFrameCnt
        ldx   #starCurOff
        ldb   starCurIdx
        abx                             ; X = &starCurOff[plan]
        ldd   ,x
sfd_mv  addd  2,y                       ; + vitesse 8.8 du plan
        dec   starFrameCnt
        bne   sfd_mv
sfd_wrap
        cmpd  #star_x_span*256          ; garder l'offset dans [0, 144.0)
        blo   sfd_wrapEnd
        subd  #star_x_span*256
; chaque wrap de 144 = un tour complet -> avancer le tour courant (mod nb_tours).
; U sert de scratch ici (X garde &starCurOff, D garde l'offset) ; pshs/puls d
; parce que le cmpa du modulo ecrase A, l'octet haut de D.
        pshs  d
        ldu   #starCurLap
        ldb   starPlaneIdx
        lda   b,u                       ; A = tour courant
        inca
        cmpa  6,y                       ; nb de tours du plan
        blo   >
        clra                            ; retour au tour 0
!       sta   b,u
        puls  d
        bra   sfd_wrap
sfd_wrapEnd
        std   ,x

; --- 2) TRACER au nouvel offset ----------------------------------------------
; Deplacement de tour du trace = le tour courant du plan.
        ldb   starPlaneIdx
        jsr   StarLapDispCur            ; B = plan ; met a jour starLapDisp
        lda   ,x                        ; partie entiere du nouvel offset
        jsr   StarDrawPass

        leay  25,y                      ; descripteur suivant (25 octets)
        inc   starPlaneIdx
        lda   starPlaneIdx
        cmpa  #3
        lblo  sfd_plane                 ; branche longue : le corps d'un plan
sfd_done                                ; depasse la portee +/-127
        rts

; ---------------------------------------------------------------------------
; StarLapDispCur - calcule starLapDisp, le deplacement de tour (en octets)
; que StarSetup ajoutera a U : 0 au tour 0, lapStride au tour 1.
;   tour = starCurLap[B]  (B = plan)
; Y = descripteur (lapStride en 7,y). Preservent X. Clobber : A, B, D, U.
; ---------------------------------------------------------------------------
StarLapDispCur
        ldu   #starCurLap
        lda   b,u                       ; A = tour courant (B = plan en entree)
StarLapDisp
        tsta                            ; tour 0 ? (tester A AVANT de charger D)
        beq   >
        ldd   7,y                       ; tour != 0 : disp = lapStride
        std   starLapDisp
        rts
!       clr   starLapDisp               ; tour 0 : disp = 0
        clr   starLapDisp+1
        rts

; ---------------------------------------------------------------------------
; StarSetup - prepare une passe : U = &starTab[plan][tour][offset].
;   entree  : A = offset entier, Y = descripteur, starLapDisp deja calcule
;   sortie  : Z = 1 si offset PAIR (nibble haut), Z = 0 si impair (nibble bas)
;             -- ni JSR ni RTS ne touchent CC, le flag survit au retour.
;   clobber : A, B, D, U
; ---------------------------------------------------------------------------
StarSetup
        sta   starOffInt
        ldb   4,y                       ; pas du plan : nb_etoiles*2 (14 ou 16)
        mul                             ; D = offset*pas (max 143*16 = 2288)
        addd  starLapDisp               ; + tour*lapStride (0 ou 2304)
        ldu   ,y                        ; U = table du plan
        leau  d,u                       ; U = &table[tour][offset][0]
        lda   starOffInt
        bita  #1                        ; parite(x) == parite(offset)
        rts

; ---------------------------------------------------------------------------
; StarDrawPass - trace les etoiles du plan a l'offset A. Le `lda 5,y` du choix
; d'entree vient APRES le `bne` : StarSetup rend son verdict de parite dans Z,
; et lda l'ecraserait.
; ---------------------------------------------------------------------------
StarDrawPass
        jsr   StarSetup
        bne   sf_dr_low
        lda   5,y                       ; ce plan a-t-il une 8e etoile ?
        bne   sfdh14
        bra   sfdh0
; --- nibble haut, deroule
        STAR_DH 14,0                    ; 8e etoile : en tete, enchaine sur la 1re
        STAR_DH 0,2
        STAR_DH 2,4
        STAR_DH 4,6
        STAR_DH 6,8
        STAR_DH 8,10
        STAR_DH 10,12
        STAR_DH 12,99
sfdh99 rts
sf_dr_low
        lda   5,y
        bne   sfdl14
        bra   sfdl0
; --- nibble bas, deroule
        STAR_DL 14,0
        STAR_DL 0,2
        STAR_DL 2,4
        STAR_DL 4,6
        STAR_DL 6,8
        STAR_DL 8,10
        STAR_DL 10,12
        STAR_DL 12,99
sfdl99 rts


; ---------------------------------------------------------------------------
; Adresses VRAM precalculees (6048 o, page cartouche). GENERE : ne pas editer,
; cf. gen_stardata.py.
; ---------------------------------------------------------------------------
        INCLUDE "src/common/fx/starfield/stardata.asm"
