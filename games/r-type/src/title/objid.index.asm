* Object index of the title — hand-maintained, same rules as the stages :
* id N is row N of every table, keep the rows aligned with objid.const.asm.
* Only the title's own live objects cite a real routine ; every other row
* points at the placeholder (an invoked object that is never carried does
* nothing). Still placeholders : the common rows that will cite resident
* units (fade).

title.text.Object       EXTERNAL
title.pushbutton.Object EXTERNAL
title.scores.Object     EXTERNAL
title.loading.Object    EXTERNAL

Obj_Index_Page
        fcb   map.RAM_OVER_CART+title.main.page ; id 0 : reserved slot, never run
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_logo
        fcb   map.RAM_OVER_CART+title.text.page ; ObjID_text
        fcb   map.RAM_OVER_CART+title.pushbutton.page ; ObjID_push_button
        fcb   map.RAM_OVER_CART+title.scores.page ; ObjID_scores
        fcb   map.RAM_OVER_CART+title.loading.page ; ObjID_loading

Obj_Index_Address
        fdb   title.placeholder ; id 0 : reserved slot, never run
        fdb   title.placeholder ; ObjID_animation
        fdb   title.placeholder ; ObjID_explosion
        fdb   title.placeholder ; ObjID_fade
        fdb   title.placeholder ; ObjID_Player1
        fdb   title.placeholder ; ObjID_Weapon
        fdb   title.placeholder ; ObjID_commonmissile
        fdb   title.placeholder ; ObjID_beamcharge
        fdb   title.placeholder ; ObjID_beamp
        fdb   title.placeholder ; ObjID_emitter_flash
        fdb   title.placeholder ; ObjID_collision
        fdb   title.placeholder ; ObjID_createFoeFire
        fdb   title.placeholder ; ObjID_loadFirePreset
        fdb   title.placeholder ; ObjID_foefire
        fdb   title.placeholder ; ObjID_initlevel1
        fdb   title.placeholder ; ObjID_engineflames
        fdb   title.placeholder ; ObjID_messages
        fdb   title.placeholder ; ObjID_endstage
        fdb   title.placeholder ; ObjID_pow_optionbox
        fdb   title.placeholder ; ObjID_bitdevice
        fdb   title.placeholder ; ObjID_forcepod
        fdb   title.placeholder ; ObjID_forcepod_simplefire
        fdb   title.placeholder ; ObjID_forcepod_reboundlaser
        fdb   title.placeholder ; ObjID_forcepod_counterairlaser
        fdb   title.placeholder ; ObjID_scantfire
        fdb   title.placeholder ; ObjID_tabrokcanon
        fdb   title.placeholder ; ObjID_shellEraser
        fdb   title.placeholder ; ObjID_commonmissileflame
        fdb   title.placeholder ; ObjID_dobkeratops_saw
        fdb   title.placeholder ; ObjID_dobkeratops_explosion
        fdb   logo.Object       ; ObjID_logo
        fdb   title.text.Object ; ObjID_text
        fdb   title.pushbutton.Object ; ObjID_push_button
        fdb   title.scores.Object ; ObjID_scores
        fdb   title.loading.Object ; ObjID_loading

Ani_Page_Index
        fcb   map.RAM_OVER_CART+title.main.page ; id 0 : reserved slot, never run
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_logo
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_text
        fcb   map.RAM_OVER_CART+title.pushbutton.page ; ObjID_push_button
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_scores
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_loading

Ani_Asd_Index
        fdb   Ani_Asd_none ; id 0 : reserved slot, never run
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
        fdb   Ani_Asd_none ; ObjID_logo
        fdb   Ani_Asd_none ; ObjID_text
        fdb   Ani_Asd_none ; ObjID_push_button
        fdb   Ani_Asd_none ; ObjID_scores
        fdb   Ani_Asd_none ; ObjID_loading

Ani_Asd_none
        fdb   0

Img_Page_Index
        fcb   map.RAM_OVER_CART+title.main.page ; id 0 : reserved slot, never run
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_logo
        fcb   map.RAM_OVER_CART+title.main.page ; ObjID_text
        fcb   map.RAM_OVER_CART+title.pushbutton.page ; ObjID_push_button
        fcb   map.RAM_OVER_CART+title.scores.page ; ObjID_scores
        fcb   map.RAM_OVER_CART+title.loading.page ; ObjID_loading

