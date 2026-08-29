;*******************************************************************************
; compiler — le boss du stage 4, porte depuis l'arcade
;
; INTEGRE ET A L'ECRAN (28/08/2026). L'integration a deterre DEUX bugs
; latents du stage, aucun des deux dans ce fichier :
;   1. l'arene stage4.gfx declarait la page $1D — qui est pscroll.buf3 ;
;   2. pscroll.clearRect ne rabotait pas le BAS de son bloc : un carve de
;      geld sur la derniere rangee effacait la rangee 30, c'est-a-dire
;      pscroll.buf.page, la table des pages de buffers (elle commence a
;      l'octet qui suit la carte). C'etait la cause des gels « aleatoires »
;      qui suivaient les timings de build depuis trois jours.
; Les deux sont corriges (config + pscroll.asm, commentaires sur place).
;
; Pas de source v1 (elle ne portait que le stage 1) : le portage suit le skill
; enemy-port, la base Ghidra fait foi. BLOC 1 — l'orchestrateur, les trois
; parties et leur intro ; les armes, les scripts de combat et la mort suivent.
;
; L'entree doit etre le PREMIER octet de l'unite : le code d'abord, les tables
; ensuite. Cas de migration : docs/lang/en/migration/unit-entry-point.md
;*******************************************************************************

compiler.Object EXPORT

; LES SEIZE POSES DE TOURELLE VIVENT DANS UN AUTRE DIRENTRY
; (lib.compiler.turret) : l'unite passait 16 Ko une fois ses neuf scripts de
; combat ajoutes, et un direntry tient dans une page. Ce sont les IMAGES qui
; ont demenage, pas le code — la table ci-dessous les nomme et le loader
; resout au chargement. Img_Page_Index envoie deja ObjID_compilerturret vers
; leur page.
set_compiler_turret_0  EXTERNAL
set_compiler_turret_1  EXTERNAL
set_compiler_turret_2  EXTERNAL
set_compiler_turret_3  EXTERNAL
set_compiler_turret_4  EXTERNAL
set_compiler_turret_5  EXTERNAL
set_compiler_turret_6  EXTERNAL
set_compiler_turret_7  EXTERNAL
set_compiler_turret_8  EXTERNAL
set_compiler_turret_9  EXTERNAL
set_compiler_turret_10 EXTERNAL
set_compiler_turret_11 EXTERNAL
set_compiler_turret_12 EXTERNAL
set_compiler_turret_13 EXTERNAL
set_compiler_turret_14 EXTERNAL
set_compiler_turret_15 EXTERNAL

        INCLUDE "src/common/engine/api.asm"

Obj_Index_Page    EXTERNAL
Obj_Index_Address EXTERNAL

 SECTION code

        INCLUDE "engine/system/to8/memory-map.equ"
        INCLUDE "src/common/engine/ram.const.asm"
        INCLUDE "engine/constants.asm"
        INCLUDE "engine/macros.asm"
        INCLUDE "engine/collision/macros.asm"
        INCLUDE "engine/collision/struct_AABB.equ"
        INCLUDE "engine/system/to8/map.const.asm"
        INCLUDE "src/stages/04/objid.const.asm"
        INCLUDE "src/enemies/enemies_properties.asm"
        INCLUDE "src/common/fx/explosion/explosion.const.asm"
        INCLUDE "src/common/state/variables.asm"
        INCLUDE "src/common/lib/scale.asm"
        ; les tourelles tirent par le chemin commun (_loadFirePreset,
        ; tryFoeFire) : la macro vient avec.
        INCLUDE "src/common/lib/projectile.macro.asm"

compiler.Object
        INCLUDE "src/enemies/compiler/obj.asm"

; ---------------------------------------------------------------------------
; LES CONSTANTES DU PORTAGE — les valeurs arcade, converties une fois
; ---------------------------------------------------------------------------
; Le point de naissance des trois parties : (0x100, 0x108) arcade (A768).
; La conversion est celle des presets partages — v2_x = (arcade_x - 320)*0,375
; et v2_y = 3 + (392 - arcade_y)*0,75 — donc (-16, 99) en coordonnees ecran.
; x negatif : les parties entrent PAR LA GAUCHE, ce que confirme le sens de
; l'intro (vx positif). Le scroll est fige a ce moment — la borne l'arrete a
; la naissance du boss (create_compiler : « halts both scroll axes »).
cpl.SPAWN_X   equ -16
cpl.SCREEN_W  equ 160          ; le champ visible, en px v2 (garde de dessin)
cpl.SPAWN_Y   equ 99

; Le script d'intro 0x1000:5B54, son unique segment : {vx, vy, duree} =
; {+1.0 px/trame arcade, 0, 0x160 trames}. Un px arcade vaut 0,375 px v2 en X,
; d'ou $60 ; la duree reste en trames de jeu, l'horloge etant calee sur la
; borne (frame.gameCount).
cpl.INTRO_VX  equ $0060
cpl.INTRO_DUR equ $0160

; ---------------------------------------------------------------------------
; LES ARMES — les valeurs arcade, converties une fois
; ---------------------------------------------------------------------------
; La cadence : la borne recharge son compteur depuis une table par difficulte
; (0x1000:5844) ; on prend la premiere entree, comme tout le cast.
; La cadence : la borne la prend dans une table par difficulte (0x1000:5844 —
; 48, 40, 32, 24). On retient 32, sa troisieme entree, PARCE QU'ELLE EST UNE
; PUISSANCE DE DEUX : la cadence se lit alors dans l'horloge de jeu par un
; simple ET, sans compteur a stocker — et l'espace d'objet du boss n'en avait
; plus un seul a offrir.
cpl.FIRE_PERIOD equ 48         ; trames entre deux salves
;   5844 : compiler_difficulty_cadence_table = 48/40/32/24 selon la difficulte.
;   Nous prenons la premiere, comme tout le cast. J'avais pris 32 — la
;   troisieme — parce qu'il me fallait une puissance de deux pour le modulo
;   d'une cadence sans etat : le boss tirait 50% trop vite (releve auteur).

; Les fenetres de tir, en px arcade converties (x0,75 sur l'axe y) : la piece
; droite accepte 0..0x50 px sous elle, la gauche 0..0x30 — elle vise plus
; serre. FIRE_WINY0 recale l'origine sur la piece.
cpl.FIRE_WINY0  equ 0
cpl.FIRE_WINY_R equ 60         ; 0x50 px arcade -> 60 lignes v2
cpl.FIRE_WINY_L equ 36         ; 0x30 px arcade -> 36 lignes v2

; Ou nait le laser : devant la piece droite (+0x50 px arcade), DANS le corps
; de la gauche (+0x10) — la borne le veut ainsi, les tirs gauches sortent du
; ventre de la piece.
cpl.FIRE_AHEAD_R equ 30        ; 0x50 px arcade x 0,375
cpl.FIRE_AHEAD_L equ 6         ; 0x10 px arcade x 0,375

; La vitesse du laser : 0x300 en 8.8 arcade = 3 px/trame, vers la gauche.
; En v2 : 3 x 0,375 = 1,125 px/trame, soit $0120.
cpl.LASER_VX   equ $0120

; Les deux pools de hauteur (0x1000:5850 pour la droite, 0x5860 pour la
; gauche), huit entrees chacun, converties a l'echelle y.
cpl.laser.poolR
        fdb   6,30,18,6,30,18,6,30
cpl.laser.poolL
        fdb   9,23,23,9,9,23,9,23

cpl.laser.images
        fdb   set_compiler_laser_0,set_compiler_laser_1
        fdb   set_compiler_laser_2,set_compiler_laser_3

; ---------------------------------------------------------------------------
; LES TROIS TOURELLES (A762 : leurs offsets et motifs de tir)
; ---------------------------------------------------------------------------
; La borne en accroche DEUX a la piece du bas (motifs 0x30 et 0x40, offsets
; -32,-40 et -24,-64 px arcade) et UNE a la gauche (motif 0x30, offset
; -72,+24). La piece droite n'en a pas : elle a son laser.
; Conversion : x fois 0,375 ; y fois 0,75 ET CHANGE DE SIGNE — l'axe y de la
; borne monte, le notre descend.
;   (-32,-40) -> (-12, +30)      (-24,-64) -> (-9, +48)
;   (-72,+24) -> (-27, -18)
; Une ligne = { piece porteuse, offset x, offset y, motif de tir }.
cpl.TURRETS   equ 3
; Les decalages sont ecrits en complement a deux : lwasm refuse l'operande
; negatif espace dans un fcb, et la valeur brute se relit sans ambiguite.
cpl.turrets.tbl
        fcb   1,$F4,30,$30             ; BAS   : -12, +30
        fcb   1,$F7,48,$40             ; BAS   :  -9, +48, second motif
        fcb   2,$E5,$EE,$30            ; GAUCHE: -27, -18

; Les seize poses de rotation : l'export les a tirees de la table de direction
; de la borne (0x1000:5872, indirect stride 4), donc l'ordre EST celui que
; setDirectionTo rend — une pose par direction, miroirs deja cuits dans les
; images.
cpl.turret.images
        fdb   set_compiler_turret_0,set_compiler_turret_1
        fdb   set_compiler_turret_2,set_compiler_turret_3
        fdb   set_compiler_turret_4,set_compiler_turret_5
        fdb   set_compiler_turret_6,set_compiler_turret_7
        fdb   set_compiler_turret_8,set_compiler_turret_9
        fdb   set_compiler_turret_10,set_compiler_turret_11
        fdb   set_compiler_turret_12,set_compiler_turret_13
        fdb   set_compiler_turret_14,set_compiler_turret_15

; ---------------------------------------------------------------------------
; LE LASER ROULANT de la piece gauche (AE5C : la paire, AEFB : le vol)
; ---------------------------------------------------------------------------
; La borne ouvre une fenetre de 0x40 trames et lache une paire toutes les 16 —
; soit quatre paires, puis le silence jusqu'a ce que son script de combat
; rouvre la fenetre. Ce script n'etant pas porte (bloc 1 : l'intro seule), on
; garde le rythme et on choisit la duree du silence.
cpl.WAVE_GAP   equ 16          ; trames entre deux paires
cpl.WAVE_PAUSE equ 128         ; ... et entre deux fenetres de quatre

; Les deux segments naissent decales : -8 px arcade pour le premier, -0x28
; pour le second, tous deux a +0x38 en y — et l'axe y de la borne MONTE, donc
; cela les place AU-DESSUS de la piece chez nous.
cpl.WAVE_DX1  equ -3           ; -8 px arcade x 0,375
cpl.WAVE_DX2  equ -15          ; -0x28 (-40) x 0,375
cpl.WAVE_DY   equ -42          ; +0x38 (56) x 0,75, sens inverse

; La vitesse horizontale : magnitude 0x80..0xFF en 8.8 arcade (0,5 a 1 px par
; trame), signe tire au sort. Convertie : 0,19 a 0,37 px v2, soit $30..$6F —
; on tire six bits et on part de $30.
cpl.WAVE_VX0  equ $30

; Le mot a double emploi : vitesse verticale ET compte a rebours. La borne le
; tire dans 0x280..0x47F et le decremente de 0x10 par trame (40 a 71 trames
; de vie). Converti a l'echelle y : 0x1E0 et 0x358, decrement 0x0C.
cpl.WAVE_LIFE0 equ $01E0
cpl.WAVE_LIFE1 equ $0358
cpl.WAVE_DECAY equ $000C

cpl.wave.images
        fdb   set_compiler_wave_0,set_compiler_wave_1
        fdb   set_compiler_wave_2,set_compiler_wave_3

; La table d'oscillation du dome, GENEREE : quatre etapes de trois mots (les
; cases materielles 12, 13, 14) et la sequence du ping-pong avec ses durees.
; Rejeu : python3 tools/gen_dome_pulse.py
        INCLUDE "src/enemies/compiler/dome-pulse.asm"

; Les trois pieces, dans l'ordre arcade des parties : droite, bas, gauche.
; Une seule pose chacune — ce sont des blocs, l'animation viendra des
; tourelles et des lasers.
cpl.images
        fdb   set_compiler_right
        fdb   set_compiler_bottom
        fdb   set_compiler_left

; ---------------------------------------------------------------------------
; LA PROFONDEUR, piece par piece (A762 : 0x4020, 0x4010, 0x4000)
; ---------------------------------------------------------------------------
; Notre echelle : 1 devant, 8 derriere ; le joueur est a 3, le boss tient donc
; entre 4 et 8. L'ordre RELATIF de la borne est conserve — droite devant, bas
; au milieu, gauche derriere — les regroupements en moins : elle dispose de
; 65536 niveaux, nous de huit.
;   piece droite 4 | laser droite 5 | tourelles 5 | piece bas 6
;   piece gauche 7 | laser gauche 8 | onde 8
cpl.prio
        fcb   4,6,7                    ; droite, bas, gauche
cpl.PRIO_TURRET equ 5
cpl.PRIO_WAVE   equ 8

; ---------------------------------------------------------------------------
; LE COMBAT : points de vie, coup encaisse, chapelet de mort
; ---------------------------------------------------------------------------
cpl.PART_HP    equ 40          ; A7A4 : 0x28 par piece, les trois pareilles
; La derive de l'auto-destruction : +0x200 en 8.8 arcade, soit 2 px par trame,
; vers la droite. Converti : 2 x 0,375 = 0,75 px v2, donc $00C0.
cpl.SUICIDE_VX equ $00C0
cpl.HIT_FLASH  equ 31          ; 0x1F trames de clignotement apres un coup
cpl.BOOM_FRAMES equ 64         ; B062 : 0x40 trames de chapelet

; Les boites, une par piece, en demi-largeur et demi-hauteur v2 (les tailles
; de geometrie.txt : 66x96, 42x120, 66x84).
cpl.hitbox
        fcb   33,48                    ; droite
        fcb   21,60                    ; bas
        fcb   33,42                    ; gauche

; Les configs, par piece : chacune donne les trois lignes de trois scripts
; parmi lesquelles le spawn tire.
cpl.cfg.index
        fdb   cpl.cfg.right,cpl.cfg.bottom,cpl.cfg.left

; Les neuf scripts de combat et les configs, GENERES depuis la ROM.
; Rejeu : python3 tools/gen_compiler_motion.py
        INCLUDE "src/enemies/compiler/motion.asm"

; Les trois chapelets, GENERES depuis la ROM.
; Rejeu : python3 tools/gen_compiler_death.py
        INCLUDE "src/enemies/compiler/explosions.asm"

; La demi-largeur de chaque piece, en px v2 (geometrie.txt : 66, 42, 66 de
; large). C'est la garde de dessin qui la consomme — voir PartLive.draw.
cpl.halfw
        fcb   33,21,33

 ENDSECTION
