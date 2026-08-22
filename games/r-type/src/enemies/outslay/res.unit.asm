;*******************************************************************************
; outslay — la zone residente du serpent, en unite d'ARENE (decision auteur,
; 22/08/2026). Ancien <reserved stage.outslay> : le marquage bloquait la bande
; par-stage pour TOUS les stages alors que seul le stage 2 s'en sert. Membre
; de l'arene stage2.res, la zone est placee par le packer, verifiee contre les
; locataires du MEME stage seulement — et chargee comme un fichier de zeros,
; donc elle arrive ZEROEE : la lecon reserved-ram-is-not-zeroed (payee deux
; fois ici meme, prev/next residuels a $FFFF) est reglee a la racine.
;
; Le cast y accede par liaison au chargement (extern16) : quatre exports, une
; quinzaine de references. L'anneau reste trois PLANS d'octets contigus de 256
; — l'index d'anneau est un octet qui deborde seul, voir obj.asm.
;*******************************************************************************

outslay.ringX EXPORT
outslay.ringY EXPORT
outslay.ringP EXPORT
outslay.boxes EXPORT

 SECTION code

outslay.ringX   fill  0,256            ; x ecran
outslay.ringY   fill  0,256            ; y ecran
outslay.ringP   fill  0,256            ; pose du script
outslay.boxes   fill  0,20*9           ; 20 boites AABB statiques

 ENDSECTION
