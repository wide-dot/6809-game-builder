* Index d'objets — genere par tools/gen_objid.py, ne pas editer

Obj_Index_Page
        fcb   0                        ; id 0 : slot reserve, jamais execute
        fcb   map.RAM_OVER_CART+common.anim.page   ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page   ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page   ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page   ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page   ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+common.missile.page   ; ObjID_commonmissile
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
        fcb   map.RAM_OVER_CART+stage1.endstage.page   ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page   ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page   ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page   ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page   ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page   ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page   ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage1.scantfire.page   ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage1.tabrokcanon.page   ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage1.shelleraser.page   ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+common.missileflame.page   ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage1.dobkeratopssaw.page   ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsexplosion.page   ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+stage1.patapata.page   ; ObjID_patapata
        fcb   map.RAM_OVER_CART+stage1.bug.page   ; ObjID_bug
        fcb   map.RAM_OVER_CART+stage1.bink.page   ; ObjID_bink
        fcb   map.RAM_OVER_CART+common.pow.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage1.fadetotunnel.page   ; ObjID_fadetotunnel
        fcb   map.RAM_OVER_CART+stage1.scant.page   ; ObjID_scant
        fcb   map.RAM_OVER_CART+stage1.pstaff.page   ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+stage1.cancer.page   ; ObjID_cancer
        fcb   map.RAM_OVER_CART+stage1.blaster.page   ; ObjID_blaster
        fcb   map.RAM_OVER_CART+stage1.shell.page   ; ObjID_shell
        fcb   map.RAM_OVER_CART+stage1.tabrok.page   ; ObjID_tabrok
        fcb   map.RAM_OVER_CART+common.bossmusic.page   ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+stage1.tailmgr.page   ; ObjID_tailmgr
        fcb   map.RAM_OVER_CART+stage1.dobkeratops.page   ; ObjID_dobkeratops
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsjaw.page   ; ObjID_dobkeratops_jaw
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsmonster.page   ; ObjID_dobkeratops_monster

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
        fdb   endstage.Object        ; ObjID_endstage
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
        fdb   dobkeratopsSaw.Object        ; ObjID_dobkeratops_saw
        fdb   dobkeratopsExplosion.Object        ; ObjID_dobkeratops_explosion
        fdb   patapata.Object        ; ObjID_patapata
        fdb   bug.Object        ; ObjID_bug
        fdb   bink.Object        ; ObjID_bink
        fdb   pow.Object        ; ObjID_pow
        fdb   fadetotunnel.Object        ; ObjID_fadetotunnel
        fdb   scant.Object        ; ObjID_scant
        fdb   pstaff.Object        ; ObjID_pstaff
        fdb   cancer.Object        ; ObjID_cancer
        fdb   blaster.Object        ; ObjID_blaster
        fdb   shell.Object        ; ObjID_shell
        fdb   tabrok.Object        ; ObjID_tabrok
        fdb   bossmusic.Object        ; ObjID_bossmusic
        fdb   tailmgr.Object        ; ObjID_tailmgr
        fdb   dobkeratops.Object        ; ObjID_dobkeratops
        fdb   dobkeratopsJaw.Object        ; ObjID_dobkeratops_jaw
        fdb   dobkeratopsMonster.Object        ; ObjID_dobkeratops_monster

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
        fcb   map.RAM_OVER_CART+common.missile.page   ; ObjID_commonmissile
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
        fcb   map.RAM_OVER_CART+stage1.endstage.page   ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page   ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page   ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page   ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page   ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page   ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page   ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage1.scantfire.page   ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage1.tabrokcanon.page   ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage1.shelleraser.page   ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+common.missileflame.page   ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage1.dobkeratopssaw.page   ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsexplosion.page   ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+stage1.patapata.page   ; ObjID_patapata
        fcb   map.RAM_OVER_CART+stage1.bug.page   ; ObjID_bug
        fcb   map.RAM_OVER_CART+stage1.bink.page   ; ObjID_bink
        fcb   map.RAM_OVER_CART+common.pow.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage1.fadetotunnel.page   ; ObjID_fadetotunnel
        fcb   map.RAM_OVER_CART+stage1.scant.page   ; ObjID_scant
        fcb   map.RAM_OVER_CART+stage1.pstaff.page   ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+stage1.cancer.page   ; ObjID_cancer
        fcb   map.RAM_OVER_CART+stage1.blaster.page   ; ObjID_blaster
        fcb   map.RAM_OVER_CART+stage1.shell.page   ; ObjID_shell
        fcb   map.RAM_OVER_CART+stage1.tabrok.page   ; ObjID_tabrok
        fcb   map.RAM_OVER_CART+common.bossmusic.page   ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+stage1.tailmgr.page   ; ObjID_tailmgr
        fcb   map.RAM_OVER_CART+stage1.dobkeratops.page   ; ObjID_dobkeratops
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsjaw.page   ; ObjID_dobkeratops_jaw
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsmonster.page   ; ObjID_dobkeratops_monster

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
        fcb   map.RAM_OVER_CART+common.missile.page   ; ObjID_commonmissile
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
        fcb   map.RAM_OVER_CART+stage1.endstage.page   ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page   ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page   ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page   ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page   ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page   ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page   ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage1.scantfire.page   ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage1.tabrokcanon.page   ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage1.shelleraser.page   ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+common.missileflame.page   ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage1.dobkeratopssaw.page   ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsexplosion.page   ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+stage1.patapata.page   ; ObjID_patapata
        fcb   map.RAM_OVER_CART+stage1.bug.page   ; ObjID_bug
        fcb   map.RAM_OVER_CART+stage1.bink.page   ; ObjID_bink
        fcb   map.RAM_OVER_CART+common.pow.page   ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage1.fadetotunnel.page   ; ObjID_fadetotunnel
        fcb   map.RAM_OVER_CART+stage1.scant.page   ; ObjID_scant
        fcb   map.RAM_OVER_CART+stage1.pstaff.page   ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+stage1.cancer.page   ; ObjID_cancer
        fcb   map.RAM_OVER_CART+stage1.blaster.page   ; ObjID_blaster
        fcb   map.RAM_OVER_CART+stage1.shell.page   ; ObjID_shell
        fcb   map.RAM_OVER_CART+stage1.tabrok.page   ; ObjID_tabrok
        fcb   map.RAM_OVER_CART+common.bossmusic.page   ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+stage1.tailmgr.page   ; ObjID_tailmgr
        fcb   map.RAM_OVER_CART+stage1.dobkeratops.page   ; ObjID_dobkeratops
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsjaw.page   ; ObjID_dobkeratops_jaw
        fcb   map.RAM_OVER_CART+stage1.dobkeratopsmonster.page   ; ObjID_dobkeratops_monster
