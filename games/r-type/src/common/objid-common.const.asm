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

objid.common.count equ 29

 ENDC
