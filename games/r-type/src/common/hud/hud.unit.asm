;*******************************************************************************
; Le HUD — le bandeau du bas, et le décompte de fin de stage
;
; Ce n'est pas un objet : ni OST, ni état par entité, et rien dans la vague ne
; le nomme. Ses deux routines sont donc des symboles de lien que le stage vise
; par `paged.call`, comme les trois du champ d'étoiles — la v1 devait passer
; par un ObjID et une commande dans B faute d'autre moyen d'atteindre du code
; paginé, et `paged.call` écrase justement B.
;
; Il partage la page des overlays avec le masque et les étoiles : ils tournent
; tous dans la même phase de dessin, donc une seule montée de page les couvre.
;
; Il peint DIRECTEMENT en mémoire vidéo, à des adresses absolues de la fenêtre
; `$A000-$DFFF` — c'est la page derrière la fenêtre qui alterne au double
; tampon, pas l'adresse, donc rien à recalculer.
;
; Ce qu'il lit : les vies, le score et l'index de vie supplémentaire dans le
; bloc `globals` (équates absolues, pas de lien), la charge du beam dans l'OST
; du joueur en page directe, et `RandomNumber` pour l'effet de défilement des
; chiffres du décompte.
;
; Le fichier v1 porte ses propres sprites compilés — les douze `DRAW_Img_hud_*`
; sont du code généré une fois puis collé, ce que le `.properties` v1 dit en
; toutes lettres (« used to generate code, should be commented because replaced
; by the code above »). Ils ne passent donc pas par gfxcomp.
;*******************************************************************************

hud.normal  EXPORT
hud.readout EXPORT

; Ce que l'unité emprunte au moteur résident.
RandomNumber            EXTERNAL
gfxlock.frame.count     EXTERNAL
gfxlock.frameDrop.count EXTERNAL
; La boîte aux lettres du pilote de bruitages, dans le moteur résident.
soundFX.newSound        EXTERNAL
; Les deux drapeaux du décompte, résidents dans le stage.
main.endstage.scoreArmed EXTERNAL
main.endstage.scoreDone  EXTERNAL
; Le numero du stage courant (- 1) : le releve de fin l'ecrit dans la
; chaine STAGE n CLEARED — variable residente de l'engine, via le lien.
game.stage               EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/system/to8/map.const.asm"
        ; Les variables inter-main : vies, score 24 bits, index de vie
        ; supplémentaire. Équates absolues du bloc réservé `globals`.
        INCLUDE "src/common/state/variables.asm"
        ; `beam_value`, la charge du beam dans l'OST du joueur.
        INCLUDE "src/common/player/player1.equ"

; L'état du décompte de fin de stage vit AILLEURS : les deux drapeaux sont
; résidents dans le stage — c'est l'objet `endstage` qui les arme et les
; termine, le HUD ne fait que les lire et les rendre — et la boîte aux lettres
; du son est celle du moteur.
;
; Ils ont vécu ici en bouchon tant qu'`endstage` n'était pas porté. Trois
; conséquences, toutes constatées : le décompte ne s'amorçait jamais (personne
; n'écrivait dans la copie privée de `scoreArmed`, donc les chiffres restaient
; à zéro), la séquence ne pouvait pas apprendre qu'il était fini, et le bip du
; décompte — un `std`, deux octets — débordait d'un `fcb` d'un seul et écrasait
; le premier octet du code du HUD.

; Le pont de noms : le fichier v1 appelle DRAW_Img_hud_<n>, gfxcomp genere
; adr_hud_<n>_ND0. Une table de liaison plutot qu'un renommage dans le code,
; comme pour l'explosion et le tir ennemi.
DRAW_Img_hud_0    equ adr_hud_0_ND0
DRAW_Img_hud_1    equ adr_hud_1_ND0
DRAW_Img_hud_2    equ adr_hud_2_ND0
DRAW_Img_hud_3    equ adr_hud_3_ND0
DRAW_Img_hud_4    equ adr_hud_4_ND0
DRAW_Img_hud_5    equ adr_hud_5_ND0
DRAW_Img_hud_6    equ adr_hud_6_ND0
DRAW_Img_hud_7    equ adr_hud_7_ND0
DRAW_Img_hud_8    equ adr_hud_8_ND0
DRAW_Img_hud_9    equ adr_hud_9_ND0
DRAW_Img_hud_b    equ adr_hud_b_ND0
DRAW_Img_hud_life equ adr_hud_life_ND0

        INCLUDE "src/common/hud/hud.asm"

; Les deux entrées, nommées pour la frontière : à l'intérieur le fichier v1
; garde ses noms.
hud.normal  equ hud.drawNormal
hud.readout equ hud.scoreReadout

 ENDSECTION
