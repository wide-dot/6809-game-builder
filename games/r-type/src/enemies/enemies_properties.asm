; Garde d'inclusion : un membre de PAGESET porte plusieurs blocs qui
; incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
; fois — c'est vrai independamment du pageset.
 IFNDEF ENEMIES_PROPERTIES
ENEMIES_PROPERTIES equ 1

; ***********************************************************************************************
;
; Defines the properties for each enemies. A properties is declined into 4 equates :
; 
; - spritename_scoreIdx  : Reward index into scoreTable (global/score.asm); see AwardScore
; - spritename_hitbox_x  : X radius of collision sensibility
; - spritename_hitbox_y  : Y radius of collision sensibility
; - spritename_hitdamage : Damage sensibility
;                          -128 to -1 : invincible hitbox, potential is never changed
;                          0          : disabled hitbox
;                          1 to 126   : hitbox with remaining potential, when collide potential decrease (min 0)
;                          127        : weak hitbox, when collide hitbox is directly disabled and do no harm to other hitbox
; ***********************************************************************************************

; reward indices into scoreTable (global/score.asm) - arcade score_rewards_table/100
blaster_scoreIdx              equ 0
patapata_scoreIdx             equ 1
bug_scoreIdx                  equ 1
bink_scoreIdx                 equ 1
cancer_scoreIdx               equ 2
tabrok_scoreIdx               equ 7
dobkeratops_eye_scoreIdx      equ 2
dobkeratops_monster_scoreIdx  equ 11
wick_scoreIdx                 equ 0
mid_scoreIdx                  equ 3
dop_scoreIdx                  equ 8
gouger_scoreIdx               equ 4
boldo_scoreIdx                equ 9
pursuer_scoreIdx              equ 2
newt_scoreIdx                 equ 2
cytron_scoreIdx               equ 3
shell_scoreIdx                equ 1
brood_scoreIdx                equ 6
slither_head_scoreIdx         equ 7
slither_body_scoreIdx         equ 2
geld_scoreIdx                 equ 1
outslay_scoreIdx              equ 1
mikun_scoreIdx                equ 1
cheetah_scoreIdx              equ 7
zoid_scoreIdx                 equ 4
fast_scoreIdx                 equ 1
scant_scoreIdx                equ 4
p_staff_scoreIdx              equ 4
gomander_scoreIdx             equ 12
compiler_scoreIdx             equ 11
bellmite_scoreIdx             equ 10
bellmite_satellite_scoreIdx   equ 2
bronco_segment_scoreIdx       equ 0
bronco_chaser_scoreIdx        equ 3
bronco_subchild_scoreIdx      equ 13
bydo_core_scoreIdx            equ 14
warship_subpart_scoreIdx      equ 5
warship_reactor_scoreIdx      equ 7
warship_turret_front_scoreIdx equ 3
warship_multi_turret_scoreIdx equ 6
warship_big_turret_scoreIdx   equ 2
warship_small_turret_scoreIdx equ 1
warship_core_scoreIdx         equ 13
warship_capsule_scoreIdx      equ 7

; cytron — arcade AABB 0x1000:2E36 = -12..+12 sur les deux axes ; x0,375 et
; x0,75 donnent 4 et 9. PV arcade indexes par la difficulte (3/5/8/14) : on
; prend la premiere, comme le reste du cast.
cytron_hitbox_x		equ 4
cytron_hitbox_y		equ 9
cytron_hitdamage	equ 3

patapata_hitbox_x	equ 4
patapata_hitbox_y	equ 8
patapata_hitdamage	equ 1

bug_hitbox_x	        equ 4
bug_hitbox_y	        equ 8
bug_hitdamage	        equ 1

blaster_hitbox_x	equ 4
blaster_hitbox_y	equ 7
blaster_hitdamage	equ 1

bink_hitbox_x		equ 6
bink_hitbox_y		equ 13
bink_hitdamage		equ 1

cancer_hitbox_x		equ 6
cancer_hitbox_y		equ 13
cancer_hitdamage	equ 1

tabrok_hitbox_x		equ 6   ; FIX E : arcade demi-largeur 16 × 0.375 = 6
tabrok_hitbox_y		equ 18  ; FIX E : arcade demi-hauteur 24 × 0.75 = 18
tabrok_hitdamage	equ $1e

dobkeratops_monster_hitbox_x  equ 4
dobkeratops_monster_hitbox_y  equ 8
dobkeratops_monster_hitdamage equ 30 ; ARCADE VERIFIED OK (1e)

dobkeratops_tail_hitbox_x  equ 2
dobkeratops_tail_hitbox_y  equ 4
dobkeratops_tail_hitdamage equ -128

dobkeratops_saw_hitbox_x  equ 3
dobkeratops_saw_hitbox_y  equ 6
dobkeratops_saw_hitdamage equ -128

dobkeratops_eye_hitbox_x  equ 3
dobkeratops_eye_hitbox_y  equ 6
dobkeratops_eye_hitdamage equ 1

; Outslay (stage 2). Boite arcade 1000:427c : 16x16 centree, soit 8 px de
; demi-cote -> 8 x 0.375 = 3 en X et 8 x 0.75 = 6 en Y... mais l'arcade
; compte en pixels arcade et la boite v2 en pixels larges : la demi-largeur
; utile est celle du sprite (12x24 large-dot), d'ou 6 et 12.
; Seul le CORPS est vulnerable et il meurt au premier coup (933c zerote
; [+0x1f] a l'install et body_tick ne le rearme jamais) ; tete, cou, queue,
; finalizer et cadavre reappliquent l'immunite a chaque trame (929b/929f).
; Gomander (boss du stage 2). L'arcade teste la boite de l'ORBE, son point
; faible : les 8 premiers octets de gomander_orb_sprite_offsets (1000:54ea)
; donnent -16..+16 en X et -8..+8 en Y, arcade -> 16*0.375 = 6 et 8*0.75 = 6.
; 8 PV (a256), mais UN coup par exposition : voir gomander/obj.asm.
gomander_hitbox_x	equ 6
gomander_hitbox_y	equ 6
gomander_hitdamage	equ 8

outslay_hitbox_x	equ 6
outslay_hitbox_y	equ 12
outslay_hitdamage	equ 1
outslay_hitdamage_immune equ -128

; slither (stage 5). Les boites arcade sont centrees : 1000:37c6 pour la tete
; (f0 ff 10 00, soit -16..+16 sur les deux axes = 32x32) et 1000:37ce pour un
; corps ou la queue (f6 ff 0a 00 = 20x20). Ramenees a l'echelle TO8 (3/8 en X,
; 3/4 en Y) et exprimees en TAILLE PLEINE, comme le reste du fichier.
; Le hitdamage porte les PV, que la passe de collision decremente :
; 0x0E (14) pour la tete d'apres head_ctor, 6 pour le corps et la queue.
slither_hitbox_x	equ 8
slither_hitbox_y	equ 15
slither_hitdamage	equ 6
slither_head_hitbox_x	equ 12
slither_head_hitbox_y	equ 24
slither_head_hitdamage	equ 14

; Le bydo shot de la salve en etoile. Sa boite est la SIENNE (1000:4196,
; fc ff 04 00 fc ff 04 00 = rayon 4 sur les deux axes), le double du bullet
; commun (1000:84c6, rayon 2) qu'on lui pretait jusqu'ici.
; 4 x 0.375 = 1.5 -> 2 en X, 4 x 0.75 = 3 en Y.
outslay_shot_hitbox_x	equ 2
outslay_shot_hitbox_y	equ 3
outslay_shot_hitdamage	equ 1

; --- HP set inline in the obj (centralised here for the stage-1 catalogue) ---
; Arcade-verified via doc/arcade-combat-reference.md (section 4 roster).
p_staff_hitdamage         equ 6      ; arcade create_p_staff @0x74b4 : +0x2F = 6 (v2)
scant_hitdamage           equ $1e    ; arcade : +0x2F = 30 (v2) ; arcade St.7, reused St.1
; Shell : corps maintenu invincible ($80 = -128) jusqu'a l'ancrage de progression ;
;   le vrai kill = le coeur bleu expose. Logique speciale dans shell/obj.asm
;   (invincible_full_potential + potential_set), pas un simple PV initial.

 ENDC
