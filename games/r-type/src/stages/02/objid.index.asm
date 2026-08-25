* Object index of stage 2 — hand-maintained since the <objectindex>
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
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.endlevel.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+common.pow.page ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_checkpoint
        fcb   map.RAM_OVER_CART+common.bossmusic.page ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_wick
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_brood
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gomander
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_segment
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_head
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_render
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_shot
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_tilemapanim
Obj_Index_Page.gouger_tl
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_tl
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_tr
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_bl
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_br
Obj_Index_Page.end

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
        fdb   gouger.Object ; ObjID_gouger
        fdb   wick.Object ; ObjID_wick
        fdb   brood.Object ; ObjID_brood
        fdb   outslay.Object ; ObjID_outslay
        fdb   gomander.Object ; ObjID_gomander
        fdb   outslay.Segment ; ObjID_outslay_segment
        fdb   outslay.Segment ; ObjID_outslay_head
        fdb   outslay.Render ; ObjID_outslay_render
        fdb   outslay.Shot ; ObjID_outslay_shot
        fdb   tilemapanim.Object ; ObjID_tilemapanim
Obj_Index_Address.gouger_tl
        fdb   gouger.Object ; ObjID_gouger_tl
        fdb   gouger.Object ; ObjID_gouger_tr
        fdb   gouger.Object ; ObjID_gouger_bl
        fdb   gouger.Object ; ObjID_gouger_br
Obj_Index_Address.end

Ani_Page_Index
        fcb   map.RAM_OVER_CART+stage2.page
        fcb   map.RAM_OVER_CART+common.anim.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.endlevel.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+common.pow.page ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_checkpoint
        fcb   map.RAM_OVER_CART+common.bossmusic.page ; ObjID_bossmusic
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_wick
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_brood
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gomander
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_segment
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_head
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_render
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_shot
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_tilemapanim
Ani_Page_Index.gouger_tl
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_tl
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_tr
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_bl
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger_br
Ani_Page_Index.end

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
        fdb   Ani_Asd_none ; ObjID_gouger
        fdb   Ani_Asd_none ; ObjID_wick
        fdb   Ani_Asd_none ; ObjID_brood
        fdb   Ani_Asd_none ; ObjID_outslay
        fdb   Ani_Asd_none ; ObjID_gomander
        fdb   Ani_Asd_none ; ObjID_outslay_segment
        fdb   Ani_Asd_none ; ObjID_outslay_head
        fdb   Ani_Asd_none ; ObjID_outslay_render
        fdb   Ani_Asd_none ; ObjID_outslay_shot
        fdb   Ani_Asd_none ; ObjID_tilemapanim
Ani_Asd_Index.gouger_tl
        fdb   Ani_Asd_none ; ObjID_gouger_tl
        fdb   Ani_Asd_none ; ObjID_gouger_tr
        fdb   Ani_Asd_none ; ObjID_gouger_bl
        fdb   Ani_Asd_none ; ObjID_gouger_br
Ani_Asd_Index.end

Ani_Asd_none
        fdb   0

Img_Page_Index
        fcb   map.RAM_OVER_CART+stage2.page
        fcb   map.RAM_OVER_CART+common.anim.page ; ObjID_animation
        fcb   map.RAM_OVER_CART+common.explosion.page ; ObjID_explosion
        fcb   map.RAM_OVER_CART+common.fade.page ; ObjID_fade
        fcb   map.RAM_OVER_CART+common.player.page ; ObjID_Player1
        fcb   map.RAM_OVER_CART+common.weapon.page ; ObjID_Weapon
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_commonmissile
        fcb   map.RAM_OVER_CART+common.beamcharge.page ; ObjID_beamcharge
        fcb   map.RAM_OVER_CART+common.beamp.page ; ObjID_beamp
        fcb   map.RAM_OVER_CART+common.emflash.page ; ObjID_emitter_flash
        fcb   map.RAM_OVER_CART+collision.page ; ObjID_collision
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_createFoeFire
        fcb   map.RAM_OVER_CART+common.firechain.page ; ObjID_loadFirePreset
        fcb   map.RAM_OVER_CART+common.foefire.page ; ObjID_foefire
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_initlevel1
        fcb   map.RAM_OVER_CART+common.engineflames.page ; ObjID_engineflames
        fcb   map.RAM_OVER_CART+common.messages.page ; ObjID_messages
        fcb   map.RAM_OVER_CART+common.endlevel.page ; ObjID_endstage
        fcb   map.RAM_OVER_CART+common.optionbox.page ; ObjID_pow_optionbox
        fcb   map.RAM_OVER_CART+common.bitdevice.page ; ObjID_bitdevice
        fcb   map.RAM_OVER_CART+common.forcepod.page ; ObjID_forcepod
        fcb   map.RAM_OVER_CART+common.simplefire.page ; ObjID_forcepod_simplefire
        fcb   map.RAM_OVER_CART+common.reboundlaser.page ; ObjID_forcepod_reboundlaser
        fcb   map.RAM_OVER_CART+common.counterairlaser.page ; ObjID_forcepod_counterairlaser
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_scantfire
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_tabrokcanon
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_shellEraser
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_commonmissileflame
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_dobkeratops_saw
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_dobkeratops_explosion
        fcb   map.RAM_OVER_CART+common.pow.page ; ObjID_pow
        fcb   map.RAM_OVER_CART+stage2.page ; ObjID_checkpoint
        fcb   map.RAM_OVER_CART+common.bossmusic.page ; ObjID_bossmusic
* Le cast du stage 2. Ces six lignes MANQUAIENT : la table s'arretait a
* ObjID_bossmusic (32) alors que les autres index allaient jusqu'a 37, parce
* que les squelettes du cast n'affichaient rien. Le premier ennemi implemente
* dessine, BuildSprites lit Img_Page_Index[38] hors table, monte une page
* quelconque et saute dans le vide. Une table indexee par identifiant doit
* etre DENSE jusqu'a objid.count — le garde-fou en fin de fichier le verifie
* maintenant.
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gouger ; bascule des l init
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_wick
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_brood
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_gomander
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_segment
        fcb   map.RAM_OVER_CART+stage2.cast.imgHead.page ; ObjID_outslay_head
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_render
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_outslay_shot
        fcb   map.RAM_OVER_CART+stage2.cast.page ; ObjID_tilemapanim
Img_Page_Index.gouger_tl
        fcb   map.RAM_OVER_CART+stage2.cast.imgGougerTL.page ; ObjID_gouger_tl
        fcb   map.RAM_OVER_CART+stage2.cast.imgGougerTR.page ; ObjID_gouger_tr
        fcb   map.RAM_OVER_CART+stage2.cast.imgGougerBL.page ; ObjID_gouger_bl
        fcb   map.RAM_OVER_CART+stage2.cast.imgGougerBR.page ; ObjID_gouger_br
Img_Page_Index.end

* GARDE-FOU. Les cinq tables sont indexees par l'identifiant d'objet : le
* moteur y entre en `abx` sans borne. Une table plus courte que les autres ne
* casse rien tant qu'aucun objet de la queue n'est atteint, puis fait sauter
* le jeu dans le vide — vecu le 21/08/2026, Img_Page_Index s'arretait a
* l'identifiant 32 et le premier segment d'outslay (38) a fige l'ecran.
* L'en-tete demandait deja de « garder les lignes alignees » ; ceci le
* verifie au lieu de l'esperer.
objid.index.expected equ objid.count+1

 IFNE Obj_Index_Page.end-Obj_Index_Page-objid.index.expected
        ERROR Obj_Index_Page : une ligne par identifiant, de 0 a objid.count
 ENDC
 IFNE Obj_Index_Address.end-Obj_Index_Address-objid.index.expected*2
        ERROR Obj_Index_Address : une ligne par identifiant, de 0 a objid.count
 ENDC
 IFNE Ani_Page_Index.end-Ani_Page_Index-objid.index.expected
        ERROR Ani_Page_Index : une ligne par identifiant, de 0 a objid.count
 ENDC
 IFNE Ani_Asd_Index.end-Ani_Asd_Index-objid.index.expected*2
        ERROR Ani_Asd_Index : une ligne par identifiant, de 0 a objid.count
 ENDC
 IFNE Img_Page_Index.end-Img_Page_Index-objid.index.expected
        ERROR Img_Page_Index : une ligne par identifiant, de 0 a objid.count
 ENDC

* ... et le RANG, pas seulement le compte : le 25/08/2026 les quatre gougers
* de direction (43..46) ont ete inseres a la suite de ObjID_gouger (33) au
* lieu de la fin de table. Le compte restait juste, les commentaires aussi,
* et TOUT le cast au-dela de 33 se decalait de quatre rangs : le gouger BL
* etait tique par le code du tir d'outslay, qui le detruisait aussitot.
* Un rang verifie vaut mieux qu'un commentaire.
 IFNE Obj_Index_Page.gouger_tl-Obj_Index_Page-ObjID_gouger_tl
        ERROR Obj_Index_Page : ObjID_gouger_tl n est pas a son rang
 ENDC
 IFNE Obj_Index_Address.gouger_tl-Obj_Index_Address-ObjID_gouger_tl*2
        ERROR Obj_Index_Address : ObjID_gouger_tl n est pas a son rang
 ENDC
 IFNE Ani_Page_Index.gouger_tl-Ani_Page_Index-ObjID_gouger_tl
        ERROR Ani_Page_Index : ObjID_gouger_tl n est pas a son rang
 ENDC
 IFNE Ani_Asd_Index.gouger_tl-Ani_Asd_Index-ObjID_gouger_tl*2
        ERROR Ani_Asd_Index : ObjID_gouger_tl n est pas a son rang
 ENDC
 IFNE Img_Page_Index.gouger_tl-Img_Page_Index-ObjID_gouger_tl
        ERROR Img_Page_Index : ObjID_gouger_tl n est pas a son rang
 ENDC
