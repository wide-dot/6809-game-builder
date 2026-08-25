;*******************************************************************************
; La carte des gommes du stage 4, en unite d'ARENE — RESIDENTE.
;
; POURQUOI RESIDENTE. Cette carte est la SECONDE COUCHE DE SOLIDITE du stage :
; c'est elle que `terrainCollision.maps` designe comme plan ARRIERE, et le
; moteur la lit avec la page collision montee dans la fenetre cartouche. Une
; carte qui vivrait dans la page pscroll y serait invisible a cet instant.
;
; Elle est EN MEME TEMPS le bitfield que pscroll mute (setCell / clearCell).
; Une seule carte, deux lecteurs, rien a tenir d'accord — c'est tout l'interet
; du montage : avant, l'etat des gommes existait en deux exemplaires (le champ
; de pscroll et la carte de collision) et les deux divergeaient des la premiere
; pousse.
;
; GEOMETRIE, identique a celle des cartes de collision, a l'octet pres :
; 48 octets par rangee x 30 rangees = 1 440, un bit = une cellule de 3x6 px,
; poids fort d'abord. C'est ce qui permet a pscroll et a terrainCollision
; d'adresser le meme bit sans conversion.
;
; Chargee en ZEROS ; stage4.init la remplit en depliant le flux RLE des gommes
; d'origine (pellet.reset).
;*******************************************************************************

pscroll.gum.map EXPORT

 SECTION code

pscroll.gum.map fill  0,48*30

 ENDSECTION
