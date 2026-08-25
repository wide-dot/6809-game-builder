* Object index of stage 4 — hand-maintained since the <objectindex>
* retirement (2026-08-11). Pages come from the layout equates (gen/layout.asm),
* addresses are EXTERNAL symbols the builder bakes (single provider) or the
* loader links ; a dangling name is refused at build. Keep the rows aligned
* with objid.const.asm — id N is row N of every table.

Obj_Index_Page
        fcb   0 ; id 0 : reserved slot, never run
        fcb   map.RAM_OVER_CART+common.anim.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.endlevel.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+common.pow.page ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_checkpoint
        fcb   map.RAM_OVER_CART+common.bossmusic.page ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+lib.patapata.page ; ObjID_patapata
        fcb   map.RAM_OVER_CART+lib.bink.page ; ObjID_bink
        fcb   map.RAM_OVER_CART+lib.cancer.page ; ObjID_cancer
        fcb   map.RAM_OVER_CART+lib.bug.page ; ObjID_bug
        fcb   map.RAM_OVER_CART+lib.pstaff.page ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_starfield
        fcb   map.RAM_OVER_CART+lib.cytron.page ; ObjID_cytron (39)
        fcb   0,0,0,0,0,0,0 ; 40..46 libres
        fcb   map.RAM_OVER_CART+lib.bug.page ; ObjID_bugrender (47)

Obj_Index_Address
        fdb   0
        fdb   Ani_Asd_common ; ObjID_animation
        fdb   explosion.Object ; ObjID_explosion
        fdb   PaletteFade ; ObjID_fade
        fdb   Player ; ObjID_Player1
        fdb   Weapon ; ObjID_Weapon
        fdb   stage.placeholder ; ObjID_commonmissile
        fdb   Beamcharge ; ObjID_beamcharge
        fdb   Beam ; ObjID_beamp
        fdb   emitterFlash.Object ; ObjID_emitter_flash
        ; l'adresse de la region collision, en dur : la region est une
        ; destination fixe placee par le builder — la citer par symbole
        ; couterait un export par stage et un fichier indexe de plus
        ; (vecu : l'index des slots realloue, le pool se fragmente, et
        ; le tampon du repertoire 0 ne trouve plus 1536 octets contigus
        ; au game over)
        fdb   collision.address ; ObjID_collision
        fdb   createFoeFire ; ObjID_createFoeFire
        fdb   loadFirePreset.Object ; ObjID_loadFirePreset
        fdb   foefire.Object ; ObjID_foefire
        fdb   stage.parked ; ObjID_initlevel1
        fdb   engineflames.Object ; ObjID_engineflames
        fdb   messages.Object ; ObjID_messages
        fdb   endlevel.Object ; ObjID_endstage
        fdb   powOptionbox.Object ; ObjID_pow_optionbox
        fdb   bitdevice.Object ; ObjID_bitdevice
        fdb   forcepod.Object ; ObjID_forcepod
        fdb   simplefire.Object ; ObjID_forcepod_simplefire
        fdb   reboundlaser.Object ; ObjID_forcepod_reboundlaser
        fdb   counterairlaser.Object ; ObjID_forcepod_counterairlaser
        fdb   stage.placeholder ; ObjID_scantfire
        fdb   stage.placeholder ; ObjID_tabrokcanon
        fdb   stage.placeholder.raw ; ObjID_shellEraser
        fdb   stage.placeholder ; ObjID_commonmissileflame
        fdb   stage.placeholder ; ObjID_dobkeratops_saw
        fdb   stage.placeholder ; ObjID_dobkeratops_explosion
        fdb   pow.Object ; ObjID_pow
        fdb   stage.placeholder ; ObjID_checkpoint
        fdb   bossmusic.Object ; ObjID_bossmusic
        fdb   patapata.Object ; ObjID_patapata
        fdb   bink.Object ; ObjID_bink
        fdb   cancer.Object ; ObjID_cancer
        fdb   bug.Object ; ObjID_bug
        fdb   pstaff.Object ; ObjID_pstaff
        fdb   stage.starfieldSpawner ; ObjID_starfield
        fdb   cytron.Object ; ObjID_cytron (39)
        fdb   0,0,0,0,0,0,0 ; 40..46 libres
        fdb   bug.Render ; ObjID_bugrender (47)

Ani_Page_Index
        fcb   map.RAM_OVER_CART+stage4.page
        fcb   map.RAM_OVER_CART+common.anim.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.endlevel.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+common.pow.page ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_checkpoint
        fcb   map.RAM_OVER_CART+common.bossmusic.page ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+lib.patapata.page ; ObjID_patapata
        fcb   map.RAM_OVER_CART+lib.bink.page ; ObjID_bink
        fcb   map.RAM_OVER_CART+lib.cancer.page ; ObjID_cancer
        fcb   map.RAM_OVER_CART+lib.bug.page ; ObjID_bug
        fcb   map.RAM_OVER_CART+lib.pstaff.page ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_starfield
        fcb   map.RAM_OVER_CART+lib.cytron.page ; ObjID_cytron (39)
        fcb   0,0,0,0,0,0,0 ; 40..46 libres
        fcb   map.RAM_OVER_CART+lib.bug.page ; ObjID_bugrender (47)

Ani_Asd_Index
        fdb   Ani_Asd_none
        fdb   Ani_Asd_none ; ObjID_animation
        fdb   Ani_Asd_none ; ObjID_explosion
        fdb   Ani_Asd_none ; ObjID_fade
        fdb   Ani_Asd_none ; ObjID_Player1
        fdb   Ani_Asd_none ; ObjID_Weapon
        fdb   Ani_Asd_none ; ObjID_commonmissile
        fdb   Ani_Asd_none ; ObjID_beamcharge
        fdb   Ani_Asd_none ; ObjID_beamp
        fdb   Ani_Asd_none ; ObjID_emitter_flash
        fdb   Ani_Asd_none ; ObjID_collision
        fdb   Ani_Asd_none ; ObjID_createFoeFire
        fdb   Ani_Asd_none ; ObjID_loadFirePreset
        fdb   Ani_Asd_none ; ObjID_foefire
        fdb   Ani_Asd_none ; ObjID_initlevel1
        fdb   Ani_Asd_none ; ObjID_engineflames
        fdb   Ani_Asd_none ; ObjID_messages
        fdb   Ani_Asd_none ; ObjID_endstage
        fdb   Ani_Asd_none ; ObjID_pow_optionbox
        fdb   Ani_Asd_none ; ObjID_bitdevice
        fdb   Ani_Asd_none ; ObjID_forcepod
        fdb   Ani_Asd_none ; ObjID_forcepod_simplefire
        fdb   Ani_Asd_none ; ObjID_forcepod_reboundlaser
        fdb   Ani_Asd_none ; ObjID_forcepod_counterairlaser
        fdb   Ani_Asd_none ; ObjID_scantfire
        fdb   Ani_Asd_none ; ObjID_tabrokcanon
        fdb   Ani_Asd_none ; ObjID_shellEraser
        fdb   Ani_Asd_none ; ObjID_commonmissileflame
        fdb   Ani_Asd_none ; ObjID_dobkeratops_saw
        fdb   Ani_Asd_none ; ObjID_dobkeratops_explosion
        fdb   Ani_Asd_none ; ObjID_pow
        fdb   Ani_Asd_none ; ObjID_checkpoint
        fdb   Ani_Asd_none ; ObjID_bossmusic
        fdb   Ani_Asd_none ; ObjID_patapata
        fdb   Ani_Asd_none ; ObjID_bink
        fdb   Ani_Asd_none ; ObjID_cancer
        fdb   Ani_Asd_none ; ObjID_bug
        fdb   Ani_Asd_none ; ObjID_pstaff
        fdb   Ani_Asd_none ; ObjID_starfield
        fdb   0 ; ObjID_cytron (39) — pas d'animation par table : son script
        fdb   0,0,0,0,0,0,0 ; 40..46 libres  ; pose lui-meme ses images
        fdb   Ani_Asd_none ; ObjID_bugrender (47)

Ani_Asd_none
        fdb   0

Img_Page_Index
        fcb   map.RAM_OVER_CART+stage4.page
        fcb   map.RAM_OVER_CART+common.anim.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.endlevel.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+common.pow.page ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_checkpoint
        fcb   map.RAM_OVER_CART+common.bossmusic.page ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+lib.patapata.page ; ObjID_patapata
        fcb   map.RAM_OVER_CART+lib.bink.page ; ObjID_bink
        fcb   map.RAM_OVER_CART+lib.cancer.page ; ObjID_cancer
        fcb   map.RAM_OVER_CART+lib.bug.page ; ObjID_bug
        fcb   map.RAM_OVER_CART+lib.pstaff.page ; ObjID_pstaff
        fcb   map.RAM_OVER_CART+stage4.page ; ObjID_starfield
        fcb   map.RAM_OVER_CART+lib.cytron.page ; ObjID_cytron (39)
        fcb   0,0,0,0,0,0,0 ; 40..46 libres
        fcb   map.RAM_OVER_CART+lib.bug.page ; ObjID_bugrender (47)
