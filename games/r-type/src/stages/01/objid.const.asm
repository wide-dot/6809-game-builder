* ===========================================================================
* Objets du stage 01 — genere par tools/gen_objid.py 01
* ===========================================================================
* Les 19 identifiants que la wave reelle du niveau 01 reference, et
* l'index que RunObjects consulte : une page et une adresse par identifiant.
*
* C'est la voie 3 de la frontiere — les deux tables sont EXPORTees par le
* stage, le moteur les tient en EXTERNAL, et le re-link global du chargement
* de scene les repointe a chaque echange. Toutes les entrees visent le meme
* bouchon tant que les ennemis ne sont pas portes ; le chemin exerce, lui,
* est le vrai : wave -> LoadObject_u -> id -> RunObjects -> index -> code.


ObjID_animation              equ 1
ObjID_explosion              equ 2
ObjID_fade                   equ 3
ObjID_patapata               equ 4
ObjID_bug                    equ 5
ObjID_bink                   equ 6
ObjID_pow                    equ 7
ObjID_fadetotunnel           equ 8
ObjID_scant                  equ 9
ObjID_pstaff                 equ 10
ObjID_cancer                 equ 11
ObjID_blaster                equ 12
ObjID_shell                  equ 13
ObjID_tabrok                 equ 14
ObjID_bossmusic              equ 15
ObjID_tailmgr                equ 16
ObjID_dobkeratops            equ 17
ObjID_dobkeratops_jaw        equ 18
ObjID_dobkeratops_monster    equ 19
objid.count                  equ 19
objid.animation              equ ObjID_animation
