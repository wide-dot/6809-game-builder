* ===========================================================================
* Les scripts d'animation du joueur — portes de generated-code/Player1
* ===========================================================================
* Ils vivent DANS l'unite du joueur, pas dans l'objet d'animation commun :
* AnimateSpriteSync monte la page lue dans Ani_Page_Index[id] avant de
* dereferencer anim,u, et l'index du stage designe donc la page du joueur.
* Le joueur reste ainsi d'un seul tenant — code, scripts et images.
*
* Seul ecart au fichier v1 : les entrees d'imageset s'appellent set_<nom>,
* le nom que gfxcomp v2 genere, la ou la v1 ecrivait Img_<nom>. La
* correspondance est celle de player1.properties (v1) :
*   Img_Player = rship_2, up_0 = rship_3, up_1 = rship_4,
*   down_0 = rship_1, down_1 = rship_0.
* Cas de migration : docs/lang/en/migration/generated-code-addresses.md

        fcb   0
Ani_Player1
        fdb   set_rship_2
        fcb   _resetAnim
        fcb   0
Ani_Player1_up1
        fdb   set_rship_4
        fcb   _resetAnim
        fcb   0
Ani_Player1_up0
        fdb   set_rship_3
        fcb   _resetAnim
        fcb   0
Ani_Player1_dn0
        fdb   set_rship_1
        fcb   _resetAnim
        fcb   0
Ani_Player1_dn1
        fdb   set_rship_0
        fcb   _resetAnim
        fcb   25
Ani_Player1_init
        fdb   set_rship_1
        fdb   set_rship_0
        fdb   set_rship_2
        fdb   set_rship_3
        fdb   set_rship_4
        fdb   set_rship_3
        fdb   set_rship_2
        fcb   _goBackNFrames
        fcb   1
        fcb   0
Ani_Player1_blink
        fdb   set_rship_2
        fdb   0
        fcb   _resetAnim
        fcb   0
Ani_Player1_blink_up1
        fdb   set_rship_4
        fdb   0
        fcb   _resetAnim
        fcb   0
Ani_Player1_blink_up0
        fdb   set_rship_3
        fdb   0
        fcb   _resetAnim
        fcb   0
Ani_Player1_blink_dn0
        fdb   set_rship_1
        fdb   0
        fcb   _resetAnim
        fcb   0
Ani_Player1_blink_dn1
        fdb   set_rship_0
        fdb   0
        fcb   _resetAnim
        fcb   4
Ani_Player1_explode
        fdb   set_player1explosion_0
        fdb   set_player1explosion_1
        fdb   set_player1explosion_2
        fdb   set_player1explosion_3
        fdb   set_player1explosion_4
        fdb   set_player1explosion_5
        fdb   set_player1explosion_6
        fdb   set_player1explosion_7
        fcb   _nextRoutine
