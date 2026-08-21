* ---------------------------------------------------------------------------
* tilemap.patch — la disposition des donnees, partagee
* ---------------------------------------------------------------------------
* Le descripteur est emis par <tilepatch>, et l'etat d'une animation vit dans
* l'OST de l'objet qui la pilote — objet qui vit dans un AUTRE direntry que le
* moteur. Ces equates doivent donc etre incluses des deux cotes : les equates
* ne franchissent pas une frontiere de direntry, seuls les symboles le font,
* et au prix d'une donnee de lien.
* ---------------------------------------------------------------------------
 IFNDEF TILEMAP_PATCH_CONST
TILEMAP_PATCH_CONST equ 1

* --- le descripteur, emis par <tilepatch> -----------------------------------
* UN descripteur porte LES DEUX plans. Ils decrivent la meme animation au meme
* endroit et ne different que par les tuiles nommees ; les separer forcerait
* chaque consommateur a trimballer une paire, et une demande differee ferait
* cinq octets au lieu de trois.
tilemap.desc.cols      equ   0
tilemap.desc.rows      equ   1
tilemap.desc.frames    equ   2
tilemap.desc.col       equ   3
tilemap.desc.row       equ   4
tilemap.desc.hold      equ   5
tilemap.desc.tableEven equ   6
tilemap.desc.tableOdd  equ   8
tilemap.desc.SIZE      equ   10

* --- l'anneau de demandes ---------------------------------------------------
* Une demande = un descripteur et un numero d'image. Trois octets, et rien qui
* soit deference a l'empilage : c'est ce qui dispense le code objet de savoir
* dans quelle page vit son descripteur.
*
* Seize entrees. Le jeu n'en a jamais plus d'une par trame aujourd'hui — une
* seule animation multi-images existe dans tout R-Type, et les 31 epaves du
* cuirasse sont des estampilles ponctuelles — mais l'anneau est le point de
* rendez-vous de TOUS les futurs consommateurs, et 48 octets ne se discutent
* pas. Un debordement est compte dans tilemap.q.lost et ne s'efface jamais.
tilemap.q.LEN          equ   16
tilemap.q.STEP         equ   3

* --- l'etat d'une animation, DANS L'OST DE SON OBJET ------------------------
* Pas d'allocateur, pas de pool : une animation appartient a un objet, et
* l'OST de cet objet EST son emplacement. Instanciation, duree de vie et
* liberation sont celles de l'objet.
*
* On reprend les octets que le moteur d'animation de sprites reserve deja —
* memes index, autres noms. Un objet ne peut evidemment pas faire les deux a
* la fois, ce qui est le cas de tous les consommateurs vises : un morceau de
* decor anime n'a pas de sprite.
*
* PIEGE CONNU : tanim.timer partage l'octet 13 avec `wave_frame_drop`, que
* ObjectWave depose a la creation. Un objet ne d'une wave doit donc lire son
* retard AVANT d'armer son animation — c'est deja la discipline du gomander.
tanim.frame            equ   anim_frame           ; 12 : image courante
tanim.timer            equ   anim_frame_duration  ; 13 : maintien restant
tanim.flags            equ   anim_flags           ; 14

tanim.BACKWARD         equ   %00000001            ; sens de lecture
tanim.DONE             equ   %00000010

 ENDC
