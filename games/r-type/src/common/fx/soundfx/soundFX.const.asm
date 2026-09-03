; Garde d'inclusion : un membre de PAGESET porte plusieurs blocs qui
; incluent chacun cet en-tete. Un en-tete doit pouvoir etre inclus deux
; fois — c'est vrai independamment du pageset.
 IFNDEF SOUNDFX_CONST
SOUNDFX_CONST equ 1

; Les six sons portes a la main (Master System 18, 46, 40, 38, 33, 36).
; ExplosionSound est l'explosion MOYENNE de la borne ($51), pas la petite —
; l'ancre 46-explosion-0 etait decalee d'un cran (doc/inventaire-sons.md).
soundFX.FireSound      equ 0    ; 18 - tir de base            (borne $30)
soundFX.ExplosionSound equ 1    ; 46 - explosion moyenne      (borne $51)
soundFX.BonusSound     equ 2    ; 40 - ramassage d'un bonus   (borne $3A)
soundFX.PodAttachSound equ 3    ; 38 - accrochage du pod      (borne $37)
soundFX.FireBlastSound equ 4    ; 33 - relachement du beam    (borne $31)
soundFX.PlayerHitSound equ 5    ; 36 - explosion du joueur    (borne $35)
; Les sept sons retenus a l'ecoute le 03/09/2026 (testeur examples/soundfx),
; generes depuis le corpus Master System par tools/sms_sfx_to_soundfx.py.
;
; SIX SONS DU CORPUS SONT ABANDONNES, et c'est une decision d'ecoute : les
; cinq qui jouent sur l'instrument personnalise du YM2413 (35 missile,
; 48 grosse explosion, 49 Wick, 50 coup ennemi, 51 coup de boss) le
; reecriraient sous la musique, qui s'en sert aussi ; aucun des quinze
; instruments de la ROM ne les rendait acceptables — sauf le coup de boss,
; qui passe en piano (src/common/fx/soundfx/hit-piano.asm) et sert alors aux
; DEUX coups, ennemi et boss. Le laser reflex (41) et le laser de sol (42)
; sonnaient mal en jeu : ils empruntent le son du counter-air. La grosse
; explosion et celle du Wick empruntent l'explosion moyenne. Le missile
; reste MUET (trop de sons simultanes). Detail : doc/inventaire-sons.md.
soundFX.PodEjectSound        equ 6   ; 37 - ejection du force pod      (borne $36)
soundFX.ExtraLifeSound       equ 7   ; 39 - vie supplementaire         (borne $38)
soundFX.CounterAirSound      equ 8   ; 43 - counter-air laser          (borne $3D)
                                     ;      sert aussi au laser reflex ($3B)
                                     ;      et au laser de sol ($3C)
soundFX.PodSimpleFireSound   equ 9   ; 44 - tir simple du pod, reflets (borne $3F)
soundFX.SmallExplosionSound  equ 10  ; 45 - petite explosion           (borne $50)
soundFX.TurretExplosionSound equ 11  ; 47 - explosion de tourelle      (borne $52)
soundFX.HitSound             equ 12  ; 51 en piano - coup encaisse, ennemi
                                     ;      ($56) comme boss ($57)

 ENDC
