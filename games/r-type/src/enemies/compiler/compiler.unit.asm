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

; La table d'oscillation du dome, GENEREE : quatre etapes de trois mots (les
; cases materielles 12, 13, 14) et la sequence du ping-pong avec ses durees.
; Rejeu : python3 tools/gen_dome_pulse.py
        INCLUDE "gen/enemies/compiler/dome-pulse.asm"

; Les trois pieces, dans l'ordre arcade des parties : droite, bas, gauche.
; Une seule pose chacune — ce sont des blocs, l'animation viendra des
; tourelles et des lasers.
cpl.images
        fdb   set_compiler_right
        fdb   set_compiler_bottom
        fdb   set_compiler_left

; La demi-largeur de chaque piece, en px v2 (geometrie.txt : 66, 42, 66 de
; large). C'est la garde de dessin qui la consomme — voir PartLive.draw.
cpl.halfw
        fcb   33,21,33

 ENDSECTION
