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
; Les treize sons confirmes a l'oreille le 03/09/2026, generes depuis le
; corpus Master System par tools/sms_sfx_to_soundfx.py (voir soundFX.asm).
soundFX.MissileSound         equ 6   ; 35 - lancement du missile     (borne $34)
soundFX.PodEjectSound        equ 7   ; 37 - ejection du force pod    (borne $36)
soundFX.ExtraLifeSound       equ 8   ; 39 - vie supplementaire       (borne $38)
soundFX.ReboundLaserSound    equ 9   ; 41 - laser reflex, tir/rebond (borne $3B)
soundFX.GroundLaserSound     equ 10  ; 42 - laser de sol             (borne $3C)
soundFX.CounterAirSound      equ 11  ; 43 - counter-air laser        (borne $3D)
soundFX.PodSimpleFireSound   equ 12  ; 44 - tir simple du pod, reflets (borne $3F)
soundFX.SmallExplosionSound  equ 13  ; 45 - petite explosion         (borne $50)
soundFX.TurretExplosionSound equ 14  ; 47 - explosion de tourelle    (borne $52)
soundFX.BigExplosionSound    equ 15  ; 48 - grosse explosion         (borne $53)
soundFX.WickExplosionSound   equ 16  ; 49 - explosion du Wick        (borne $54)
soundFX.HitSound             equ 17  ; 50 - coup encaisse            (borne $56)
soundFX.BossHitSound         equ 18  ; 51 - coup encaisse par un boss (borne $57)

 ENDC
