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

; L'ÉTAT DU DÉCOMPTE DE FIN DE STAGE, en bouchon.
;
; `hud.readout` appartient à la séquence de fin de niveau : c'est l'objet
; `endstage` qui l'arme, la cadence et la termine, et il n'est pas porté. Ses
; deux drapeaux vivent donc ici en attendant, et partiront avec lui.
;
; `soundFX.newSound` est la boîte aux lettres du moteur audio, pas porté non
; plus. Le décompte y dépose son bip ; personne ne le relève. Un octet plutôt
; qu'un site d'appel neutralisé : le code du HUD reste FIDÈLE à la v1.
main.endstage.scoreArmed  fcb 0
main.endstage.scoreDone   fcb 0
soundFX.newSound          fcb 0

        INCLUDE "src/common/hud/hud.asm"

; Les deux entrées, nommées pour la frontière : à l'intérieur le fichier v1
; garde ses noms.
hud.normal  equ hud.drawNormal
hud.readout equ hud.scoreReadout

 ENDSECTION
