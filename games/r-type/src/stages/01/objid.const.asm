* ===========================================================================
* Objets du stage 01 — genere par tools/gen_objid.py 01
* ===========================================================================
* Les 44 identifiants que la wave reelle du niveau 01 reference, et
* l'index que RunObjects consulte : une page et une adresse par identifiant.
*
* C'est la voie 3 de la frontiere — les deux tables sont EXPORTees par le
* stage, le moteur les tient en EXTERNAL, et le re-link global du chargement
* de scene les repointe a chaque echange. Toutes les entrees visent le meme
* bouchon tant que les ennemis ne sont pas portes ; le chemin exerce, lui,
* est le vrai : wave -> LoadObject_u -> id -> RunObjects -> index -> code.


 IFNDEF OBJID_CONST_01
OBJID_CONST_01          equ 1

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
ObjID_messages               equ 16
ObjID_pow_optionbox          equ 17
ObjID_bitdevice              equ 18
ObjID_forcepod               equ 19
ObjID_forcepod_simplefire    equ 20
ObjID_forcepod_reboundlaser  equ 21
ObjID_forcepod_counterairlaser equ 22
ObjID_scantfire              equ 23
ObjID_tabrokcanon            equ 24
ObjID_shellEraser            equ 25
ObjID_commonmissileflame     equ 26
ObjID_dobkeratops_saw        equ 27
ObjID_dobkeratops_explosion  equ 28
ObjID_patapata               equ 29
ObjID_bug                    equ 30
ObjID_bink                   equ 31
ObjID_pow                    equ 32
ObjID_fadetotunnel           equ 33
ObjID_scant                  equ 34
ObjID_pstaff                 equ 35
ObjID_cancer                 equ 36
ObjID_blaster                equ 37
ObjID_shell                  equ 38
ObjID_tabrok                 equ 39
ObjID_bossmusic              equ 40
ObjID_tailmgr                equ 41
ObjID_dobkeratops            equ 42
ObjID_dobkeratops_jaw        equ 43
ObjID_dobkeratops_monster    equ 44
objid.count                  equ 44
objid.animation              equ ObjID_animation

 ENDC
