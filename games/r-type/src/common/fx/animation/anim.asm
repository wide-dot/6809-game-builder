;*******************************************************************************
; L'objet d'animation commun
;
; Tous les objets de jeu partagent ces scripts : la v1 en faisait un objet à
; part, chargé une fois, et les tables Ani_Page_Index / Ani_Asd_Index de chaque
; stage y renvoient. C'est donc du commun, pas du stage — mais paginé, parce
; qu'AnimateSprite monte la page avant de lire.
;
; Deux tables : l'index (des pointeurs vers les LUT d'animation) puis les
; scripts eux-mêmes. Ani_Asd_common désigne la première entrée de l'index,
; qu'AnimateSprite déréférence deux fois — Ani_Asd_Index[id] donne l'adresse
; d'une entrée, et le mot qui s'y trouve est la LUT de l'objet.
;*******************************************************************************

Ani_Asd_common EXPORT

 SECTION code

Ani_Asd_common
        INCLUDE "src/common/fx/animation/index.asm"
        INCLUDE "src/common/fx/animation/script.asm"

 ENDSECTION
