;*******************************************************************************
; compiler.turret — les seize poses de rotation des tourelles du boss
;
; Un direntry a elles seules, et pour une raison de place : l'unite du compiler
; passait 16 Ko une fois ses neuf scripts de combat ajoutes, et un direntry ne
; peut pas depasser une page. Ce sont les IMAGES qui demenagent, pas le code —
; TurretInit et TurretRun restent dans compiler.unit.asm avec le reste du boss.
;
; Le decoupage est indolore parce que la table Img_Page_Index donne UNE page
; par identifiant d'objet, et que les tourelles ont le leur
; (ObjID_compilerturret) : leur ligne pointe simplement ici. La table de
; pointeurs cpl.turret.images, elle, reste cote code — ses symboles franchissent
; la frontiere de direntry et le loader les resout au chargement.
;*******************************************************************************

 SECTION code
 ENDSECTION
