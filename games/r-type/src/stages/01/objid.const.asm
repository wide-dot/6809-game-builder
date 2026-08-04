* ===========================================================================
* Objets du stage 01 — genere par tools/gen_objid.py 01
* ===========================================================================
* Les 31 identifiants que la wave reelle du niveau 01 reference, et
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
ObjID_Player1                equ 4
ObjID_Weapon                 equ 5
ObjID_commonmissile          equ 6
ObjID_beamcharge             equ 7
ObjID_beamp                  equ 8
ObjID_emitter_flash          equ 9
ObjID_collision              equ 10
ObjID_createFoeFire          equ 11
ObjID_loadFirePreset         equ 12
ObjID_foefire                equ 13
ObjID_initlevel1             equ 14
ObjID_engineflames           equ 15
ObjID_patapata               equ 16
ObjID_bug                    equ 17
ObjID_bink                   equ 18
ObjID_pow                    equ 19
ObjID_fadetotunnel           equ 20
ObjID_scant                  equ 21
ObjID_pstaff                 equ 22
ObjID_cancer                 equ 23
ObjID_blaster                equ 24
ObjID_shell                  equ 25
ObjID_tabrok                 equ 26
ObjID_bossmusic              equ 27
ObjID_tailmgr                equ 28
ObjID_dobkeratops            equ 29
ObjID_dobkeratops_jaw        equ 30
ObjID_dobkeratops_monster    equ 31
objid.count                  equ 31
objid.animation              equ ObjID_animation
