;*******************************************************************************
; loading — l'image LOADING du changement de mode, portée de la v1
;
; La v1 en faisait un GAME MODE entier : afficher l'image, l'épingler sur la
; page vidéo visible pendant que son loader saccageait l'autre, puis charger.
; Le loader v2 n'écrit PAS dans les tampons vidéo : l'objet suffit — le main
; qui part en échange nettoie l'écran, le dessine dans les deux tampons
; (deux trames), rallume la palette, et l'image reste visible pendant tout le
; scene.load synchrone, jusqu'à l'effacement d'ouverture du mode suivant.
;
; L'objet v1 est repris tel quel : une trame = image posée + DisplaySprite.
; L'unité est paginée dans l'arène title (son consommateur actuel — le départ
; press start) ; le retour de game over pourra la partager plus tard.
;*******************************************************************************

title.loading.Object EXPORT

        INCLUDE "src/common/engine/api.asm"

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"

; V2-DEVIATION : la v1 nomme ses entrées d'imageset `Img_<nom>`, gfxcomp les
; génère en `set_<nom>`. Une table de liaison laisse le fichier v1 au 1:1.
Img_loading equ set_loading_0

title.loading.Object
        INCLUDE "src/common/flow/loading/obj.asm"

 ENDSECTION
