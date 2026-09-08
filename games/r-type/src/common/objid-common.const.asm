* Object ids shared by every stage — TIER 1 of the numbering model.
*
* The resident engine and the common units bake these numbers once, so every
* stage index MUST carry them at these exact slots ; a stage that has no
* provider for one of them plugs the slot (stage.placeholder). Stage-local
* ids start AFTER this prefix, in the stage's own objid.const.asm — they are
* free per stage, nothing outside the stage cites them.
*
* Hand-maintained since the <objectindex> retirement (2026-08-11) : the
* include IS the invariant — the old generator only promised it in a comment.

 IFNDEF OBJID_COMMON
OBJID_COMMON equ 1

ObjID_animation equ 1
ObjID_explosion equ 2
ObjID_fade equ 3
ObjID_Player1 equ 4
ObjID_Weapon equ 5
ObjID_commonmissile equ 6
ObjID_beamcharge equ 7
ObjID_beamp equ 8
ObjID_emitter_flash equ 9
ObjID_collision equ 10
ObjID_createFoeFire equ 11
ObjID_loadFirePreset equ 12
ObjID_foefire equ 13
ObjID_initlevel1 equ 14
ObjID_engineflames equ 15
ObjID_messages equ 16
ObjID_endstage equ 17
ObjID_pow_optionbox equ 18
ObjID_bitdevice equ 19
ObjID_forcepod equ 20
ObjID_forcepod_simplefire equ 21
ObjID_forcepod_reboundlaser equ 22
ObjID_forcepod_counterairlaser equ 23
ObjID_scantfire equ 24
ObjID_tabrokcanon equ 25
ObjID_shellEraser equ 26
ObjID_commonmissileflame equ 27
ObjID_dobkeratops_saw equ 28
ObjID_dobkeratops_explosion equ 29
* Le meme slot vu des stages 2-8 : LA CASCADE DE MORT DU BOSS. Le stage 1 y
* met la sequence v1 du Dobkeratops, les autres le marcheur commun
* (src/common/fx/bosscascade/obj.asm) avec la table de leur boss — deux
* unites alternatives, un seul identifiant (08/09/2026).
ObjID_bosscascade equ ObjID_dobkeratops_explosion
* Le laser de sol : la TETE de faisceau. Le renderer groupe de ses
* suiveurs sera une ROUTINE de ce meme objet, comme reboundmgr — il ne
* coute pas d'identifiant.
ObjID_forcepod_groundlaser equ 30
ObjID_forcepod_counterairreflect equ 31
; le Pata-Pata, commun depuis le 06/09/2026 : l'ecran de saisie du classement
; le fait naitre dans tous les stages (unite residente, arene objects)
ObjID_patapata equ 32

objid.common.count equ 33
objid.specific.base equ 33             ; le premier identifiant d'un stage

* LE DECOUPAGE DE L'ESPACE D'IDENTIFIANTS (26/08/2026)
*
*    0..32   le prefixe COMMUN, celui de ce fichier
*   33..127  le specifique de chaque ensemble co-chargeable
*            (stage/title objid.const.asm)
*
* La base etait 32 ; le Pata-Pata commun (06/09/2026) l'a poussee a 33, et
* les identifiants specifiques des huit stages ont glisse d'un cran ce
* jour-la (les waves sont symboliques, les tables d'index ont recu la
* ligne 32 par script).
*
* Des bornes rondes, qui se retiennent. La base valait 30 et le commun etait
* plein a l'octet pres : 30 et 31 s'y sont ouverts. Le 30 est alle a la tete
* du laser de sol le 26/08 ; le 31 reste libre. Les identifiants
* specifiques ont tous glisse de deux le jour du changement (decision auteur).
*
* Le plafond de 127 tient a RunObjects, qui met l'identifiant en B et l'echelle
* par aslb+abx : au-dela le bit de poids fort tombe dans le decalage.
 IFGT objid.common.count-objid.specific.base
        ERROR common object ids overflow the specific base
 ENDC

 ENDC
