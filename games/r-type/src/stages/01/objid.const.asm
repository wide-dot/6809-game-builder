* ===========================================================================
* Objets du stage 01 — genere par tools/gen_objid.py 01
* ===========================================================================
* Les 16 identifiants que la wave reelle du niveau 01 reference, et
* l'index que RunObjects consulte : une page et une adresse par identifiant.
*
* C'est la voie 3 de la frontiere — les deux tables sont EXPORTees par le
* stage, le moteur les tient en EXTERNAL, et le re-link global du chargement
* de scene les repointe a chaque echange. Toutes les entrees visent le meme
* bouchon tant que les ennemis ne sont pas portes ; le chemin exerce, lui,
* est le vrai : wave -> LoadObject_u -> id -> RunObjects -> index -> code.


ObjID_patapata               equ 1
ObjID_bug                    equ 2
ObjID_bink                   equ 3
ObjID_pow                    equ 4
ObjID_fadetotunnel           equ 5
ObjID_scant                  equ 6
ObjID_pstaff                 equ 7
ObjID_cancer                 equ 8
ObjID_blaster                equ 9
ObjID_shell                  equ 10
ObjID_tabrok                 equ 11
ObjID_bossmusic              equ 12
ObjID_tailmgr                equ 13
ObjID_dobkeratops            equ 14
ObjID_dobkeratops_jaw        equ 15
ObjID_dobkeratops_monster    equ 16
objid.count                  equ 16

Obj_Index_Page
        fcb   0                        ; id 0 : slot reserve, jamais execute
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_patapata
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_bug
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_bink
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_fadetotunnel
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_scant
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_cancer
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_blaster
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_shell
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_tabrok
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_tailmgr
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_dobkeratops
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_dobkeratops_jaw
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_dobkeratops_monster

Obj_Index_Address
        fdb   0
        fdb   stage.placeholder        ; ObjID_patapata
        fdb   stage.placeholder        ; ObjID_bug
        fdb   stage.placeholder        ; ObjID_bink
        fdb   stage.placeholder        ; ObjID_pow
        fdb   stage.placeholder        ; ObjID_fadetotunnel
        fdb   stage.placeholder        ; ObjID_scant
        fdb   stage.placeholder        ; ObjID_pstaff
        fdb   stage.placeholder        ; ObjID_cancer
        fdb   stage.placeholder        ; ObjID_blaster
        fdb   stage.placeholder        ; ObjID_shell
        fdb   stage.placeholder        ; ObjID_tabrok
        fdb   stage.placeholder        ; ObjID_bossmusic
        fdb   stage.placeholder        ; ObjID_tailmgr
        fdb   stage.placeholder        ; ObjID_dobkeratops
        fdb   stage.placeholder        ; ObjID_dobkeratops_jaw
        fdb   stage.placeholder        ; ObjID_dobkeratops_monster
