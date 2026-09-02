;*******************************************************************************
; sawmgr-res — la boite aux lettres RESIDENTE du manager de scies du
; Dobkeratops, locataire de l'arene stage1.res (comme eyemgr-res).
;
; Le monstre (page du monstre) demande une chaine ; le manager (page du
; manager) la consomme dans son Run. Ni l'un ni l'autre ne monte la page de
; l'autre : cinq octets residents, un drapeau et l'origine (x-6, y+9 de la
; bouche, comme v1 CreateSawChain). L'Init du manager remet le drapeau a zero
; (une demande d'avant un rejeu de checkpoint ne vaut plus).
;*******************************************************************************
main.sawmgr.spawn EXPORT
main.sawmgr.x     EXPORT
main.sawmgr.y     EXPORT
 SECTION code
main.sawmgr.spawn fcb 0              ; 1 = une chaine demandee
main.sawmgr.x     fdb 0              ; origine (repere terrain)
main.sawmgr.y     fdb 0
 ENDSECTION
