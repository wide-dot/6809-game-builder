* Index d'objets — genere par tools/gen_objid.py, ne pas editer

Obj_Index_Page
        fcb   0                        ; id 0 : slot reserve, jamais execute
        fcb   map.RAM_OVER_CART+common.anim.page   ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page   ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page   ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page   ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page   ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+commonmissile.Object.page   ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page   ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page   ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page   ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page   ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page   ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page   ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page   ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stageinit.page   ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page   ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page   ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.optionbox.page   ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page   ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page   ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page   ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page   ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page   ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+scantfire.Object.page   ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+tabrokcanon.Object.page   ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+shellEraser.Object.page   ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+commonmissileflame.Object.page   ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+patapata.Object.page   ; ObjID_patapata
        fcb   map.RAM_OVER_CART+bug.Object.page   ; ObjID_bug
        fcb   map.RAM_OVER_CART+bink.Object.page   ; ObjID_bink
        fcb   map.RAM_OVER_CART+common.pow.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_fadetotunnel
        fcb   map.RAM_OVER_CART+scant.Object.page   ; ObjID_scant
        fcb   map.RAM_OVER_CART+pstaff.Object.page   ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+cancer.Object.page   ; ObjID_cancer
        fcb   map.RAM_OVER_CART+blaster.Object.page   ; ObjID_blaster
        fcb   map.RAM_OVER_CART+shell.Object.page   ; ObjID_shell
        fcb   map.RAM_OVER_CART+tabrok.Object.page   ; ObjID_tabrok
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
        fdb   commonmissile.Object        ; ObjID_commonmissile
        fdb   Beamcharge        ; ObjID_beamcharge
        fdb   Beam        ; ObjID_beamp
        fdb   emitterFlash.Object        ; ObjID_emitter_flash
        fdb   terrainCollision.unit        ; ObjID_collision
        fdb   createFoeFire        ; ObjID_createFoeFire
        fdb   loadFirePreset.Object        ; ObjID_loadFirePreset
        fdb   foefire.Object        ; ObjID_foefire
        fdb   initlevel1.Object        ; ObjID_initlevel1
        fdb   engineflames.Object        ; ObjID_engineflames
        fdb   messages.Object        ; ObjID_messages
        fdb   powOptionbox.Object        ; ObjID_pow_optionbox
        fdb   bitdevice.Object        ; ObjID_bitdevice
        fdb   forcepod.Object        ; ObjID_forcepod
        fdb   simplefire.Object        ; ObjID_forcepod_simplefire
        fdb   reboundlaser.Object        ; ObjID_forcepod_reboundlaser
        fdb   counterairlaser.Object        ; ObjID_forcepod_counterairlaser
        fdb   scantfire.Object        ; ObjID_scantfire
        fdb   tabrokcanon.Object        ; ObjID_tabrokcanon
        fdb   shellEraser.Object        ; ObjID_shellEraser
        fdb   commonmissileflame.Object        ; ObjID_commonmissileflame
        fdb   patapata.Object        ; ObjID_patapata
        fdb   bug.Object        ; ObjID_bug
        fdb   bink.Object        ; ObjID_bink
        fdb   pow.Object        ; ObjID_pow
        fdb   stage.placeholder        ; ObjID_fadetotunnel
        fdb   scant.Object        ; ObjID_scant
        fdb   pstaff.Object        ; ObjID_pstaff
        fdb   cancer.Object        ; ObjID_cancer
        fdb   blaster.Object        ; ObjID_blaster
        fdb   shell.Object        ; ObjID_shell
        fdb   tabrok.Object        ; ObjID_tabrok
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
        fcb   map.RAM_OVER_CART+common.anim.page   ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page   ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page   ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page   ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page   ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+commonmissile.Object.page   ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page   ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page   ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page   ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page   ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page   ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page   ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page   ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stageinit.page   ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page   ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page   ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.optionbox.page   ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page   ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page   ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page   ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page   ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page   ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+scantfire.Object.page   ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+tabrokcanon.Object.page   ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+shellEraser.Object.page   ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+commonmissileflame.Object.page   ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+patapata.Object.page   ; ObjID_patapata
        fcb   map.RAM_OVER_CART+bug.Object.page   ; ObjID_bug
        fcb   map.RAM_OVER_CART+bink.Object.page   ; ObjID_bink
        fcb   map.RAM_OVER_CART+common.pow.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_fadetotunnel
        fcb   map.RAM_OVER_CART+scant.Object.page   ; ObjID_scant
        fcb   map.RAM_OVER_CART+pstaff.Object.page   ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+cancer.Object.page   ; ObjID_cancer
        fcb   map.RAM_OVER_CART+blaster.Object.page   ; ObjID_blaster
        fcb   map.RAM_OVER_CART+shell.Object.page   ; ObjID_shell
        fcb   map.RAM_OVER_CART+tabrok.Object.page   ; ObjID_tabrok
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
        fcb   map.RAM_OVER_CART+common.anim.page   ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page   ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page   ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page   ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page   ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+commonmissile.Object.page   ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page   ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page   ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page   ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page   ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page   ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page   ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page   ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stageinit.page   ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page   ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page   ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.optionbox.page   ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page   ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page   ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page   ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page   ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page   ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+scantfire.Object.page   ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+tabrokcanon.Object.page   ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+shellEraser.Object.page   ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+commonmissileflame.Object.page   ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+patapata.Object.page   ; ObjID_patapata
        fcb   map.RAM_OVER_CART+bug.Object.page   ; ObjID_bug
        fcb   map.RAM_OVER_CART+bink.Object.page   ; ObjID_bink
        fcb   map.RAM_OVER_CART+common.pow.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_fadetotunnel
        fcb   map.RAM_OVER_CART+scant.Object.page   ; ObjID_scant
        fcb   map.RAM_OVER_CART+pstaff.Object.page   ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+cancer.Object.page   ; ObjID_cancer
        fcb   map.RAM_OVER_CART+blaster.Object.page   ; ObjID_blaster
        fcb   map.RAM_OVER_CART+shell.Object.page   ; ObjID_shell
        fcb   map.RAM_OVER_CART+tabrok.Object.page   ; ObjID_tabrok
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_tailmgr
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_dobkeratops
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_dobkeratops_jaw
        fcb   map.RAM_OVER_CART+stage.page   ; ObjID_dobkeratops_monster
