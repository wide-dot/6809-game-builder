* Index d'objets — genere par tools/gen_objid.py, ne pas editer

Obj_Index_Page
        fcb   0                        ; id 0 : slot reserve, jamais execute
        fcb   map.RAM_OVER_CART+anim.page   ; ObjID_animation
        fcb   map.RAM_OVER_CART+explosion.page   ; ObjID_explosion
        fcb   map.RAM_OVER_CART+fade.page   ; ObjID_fade
        fcb   map.RAM_OVER_CART+player.page   ; ObjID_Player1
        fcb   map.RAM_OVER_CART+weapon.page   ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+beamcharge.page   ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+beamp.page   ; ObjID_beamp
        fcb   map.RAM_OVER_CART+emflash.page   ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page   ; ObjID_collision
        fcb   map.RAM_OVER_CART+firechain.page   ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+firechain.page   ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+foefire.page   ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+engineflames.page   ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+enemies.page   ; ObjID_patapata
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
        fdb   Ani_Asd_common        ; ObjID_animation
        fdb   explosion.Object        ; ObjID_explosion
        fdb   PaletteFade        ; ObjID_fade
        fdb   Player        ; ObjID_Player1
        fdb   Weapon        ; ObjID_Weapon
        fdb   stage.placeholder        ; ObjID_commonmissile
        fdb   Beamcharge        ; ObjID_beamcharge
        fdb   Beam        ; ObjID_beamp
        fdb   emitterFlash.Object        ; ObjID_emitter_flash
        fdb   terrainCollision.unit        ; ObjID_collision
        fdb   createFoeFire        ; ObjID_createFoeFire
        fdb   loadFirePreset.Object        ; ObjID_loadFirePreset
        fdb   foefire.Object        ; ObjID_foefire
        fdb   initlevel1.Object        ; ObjID_initlevel1
        fdb   engineflames.Object        ; ObjID_engineflames
        fdb   patapata.Object        ; ObjID_patapata
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

* Les scripts d'animation. Les vrais vivent dans un objet commun qui
* n'est pas encore chargeable (8 Ko de donnees de lien) : en attendant,
* la table est locale et vide — aucun objet ne s'anime encore.
Ani_Page_Index
        fcb   map.RAM_OVER_CART+stage.page
        fcb   map.RAM_OVER_CART+anim.page   ; ObjID_animation
        fcb   map.RAM_OVER_CART+explosion.page   ; ObjID_explosion
        fcb   map.RAM_OVER_CART+fade.page   ; ObjID_fade
        fcb   map.RAM_OVER_CART+player.page   ; ObjID_Player1
        fcb   map.RAM_OVER_CART+weapon.page   ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+beamcharge.page   ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+beamp.page   ; ObjID_beamp
        fcb   map.RAM_OVER_CART+emflash.page   ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page   ; ObjID_collision
        fcb   map.RAM_OVER_CART+firechain.page   ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+firechain.page   ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+foefire.page   ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+engineflames.page   ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+enemies.page   ; ObjID_patapata
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

Ani_Asd_Index
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none

Ani_Asd_none
        fdb   0

* La page des images de chaque objet. Tant que les ennemis ne sont pas
* portes, le bouchon ne dessine rien et la valeur ne sert pas.
Img_Page_Index
        fcb   map.RAM_OVER_CART+stage.page
        fcb   map.RAM_OVER_CART+anim.page   ; ObjID_animation
        fcb   map.RAM_OVER_CART+explosion.page   ; ObjID_explosion
        fcb   map.RAM_OVER_CART+fade.page   ; ObjID_fade
        fcb   map.RAM_OVER_CART+player.page   ; ObjID_Player1
        fcb   map.RAM_OVER_CART+weapon.page   ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+beamcharge.page   ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+beamp.page   ; ObjID_beamp
        fcb   map.RAM_OVER_CART+emflash.page   ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page   ; ObjID_collision
        fcb   map.RAM_OVER_CART+firechain.page   ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+firechain.page   ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+foefire.page   ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+engineflames.page   ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+enemies.page   ; ObjID_patapata
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
