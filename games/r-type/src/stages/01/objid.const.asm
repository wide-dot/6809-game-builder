* ===========================================================================
* Objets du stage 01 — genere par tools/gen_objid.py 01
* ===========================================================================
* Les 18 identifiants que la wave reelle du niveau 01 reference, et
* l'index que RunObjects consulte : une page et une adresse par identifiant.
*
* C'est la voie 3 de la frontiere — les deux tables sont EXPORTees par le
* stage, le moteur les tient en EXTERNAL, et le re-link global du chargement
* de scene les repointe a chaque echange. Toutes les entrees visent le meme
* bouchon tant que les ennemis ne sont pas portes ; le chemin exerce, lui,
* est le vrai : wave -> LoadObject_u -> id -> RunObjects -> index -> code.


ObjID_animation              equ 1
ObjID_explosion              equ 2
ObjID_patapata               equ 3
ObjID_bug                    equ 4
ObjID_bink                   equ 5
ObjID_pow                    equ 6
ObjID_fadetotunnel           equ 7
ObjID_scant                  equ 8
ObjID_pstaff                 equ 9
ObjID_cancer                 equ 10
ObjID_blaster                equ 11
ObjID_shell                  equ 12
ObjID_tabrok                 equ 13
ObjID_bossmusic              equ 14
ObjID_tailmgr                equ 15
ObjID_dobkeratops            equ 16
ObjID_dobkeratops_jaw        equ 17
ObjID_dobkeratops_monster    equ 18
objid.count                  equ 18
objid.animation              equ ObjID_animation
