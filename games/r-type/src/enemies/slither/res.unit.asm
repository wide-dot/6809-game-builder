;*******************************************************************************
; slither — la zone residente du serpent du stage 5, en unite d'ARENE.
;
; TROIS INSTANCES (decision auteur, 25/08/2026). La zone etait un SINGLETON,
; copie de l'outslay — et l'outslay peut se le permettre : la wave du stage 2
; le cite UNE fois, et le gomander en pond pendant son combat, jamais
; concurremment. Son architecture suppose une instance unique, et cette
; supposition n'est ecrite nulle part.
;
; La wave du stage 5, elle, fait naitre QUINZE serpents et la mesure sous toje
; en montre jusqu'a TROIS vivants ensemble (cameras 192, 350, 361). Avec une
; seule zone ils se pietinaient : le dernier ecrivain gagnait l'anneau, les
; records d'un voisin passaient a « fini », et les boites portaient les
; coordonnees d'un autre serpent — d'ou une chaine qui se lisait comme deux ou
; trois morceaux epars a l'ecran.
;
; Le patron est celui du gestionnaire de bug (src/enemies/bug/mgr.asm), qui a
; deja resolu exactement ca avec DEUX instances : un bloc par instance, le
; maitre en prend une a sa naissance et la rend a sa mort ; plus rien de libre
; et la chaine est SAUTEE — la semantique « alloc KO » de la v1.
;
; DIMENSIONNEMENT, releve dans la rom arcade (scripts d'emission 1000:34B6 /
; 1000:34E2) : 1 tete + 9 corps + 1 queue (court) ou 1 tete + 15 corps + 1
; queue (long). On dimensionne sur le LONG. La tete et la queue etant des
; suiveurs a OST, seuls les CORPS ont un record, une boite et un slot.
;
; Retard du dernier corps : 10 + 9*14 = 136 trames ; la queue suit a 146.
; L'anneau de 256 entrees couvre largement, et 256 est le wrap gratuit :
; l'index est un octet qui deborde seul.
;
; Cout : 3 x (768 d'anneau + 135 de boites) = 2 709 octets, contre 903 pour
; l'instance unique. La bande residente du stage 5 est vide par ailleurs.
;*******************************************************************************

slither.ring0  EXPORT
slither.ring1  EXPORT
slither.ring2  EXPORT
slither.boxes0 EXPORT
slither.boxes1 EXPORT
slither.boxes2 EXPORT

slither.NBOX    equ   15                 ; les corps du script long
slither.RINGSZ  equ   256*3              ; les trois plans x, y, pose



 SECTION code

; Un anneau = trois plans d'octets CONTIGUS de 256 : x a +0, y a +256,
; pose a +512. Le code n'a donc qu'UN pointeur a porter par instance.
slither.ring0   fill  0,slither.RINGSZ
slither.ring1   fill  0,slither.RINGSZ
slither.ring2   fill  0,slither.RINGSZ
slither.boxes0  fill  0,slither.NBOX*9
slither.boxes1  fill  0,slither.NBOX*9
slither.boxes2  fill  0,slither.NBOX*9

 ENDSECTION
