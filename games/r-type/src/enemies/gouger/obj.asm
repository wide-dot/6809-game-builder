;*******************************************************************************
; gouger — SQUELETTE, mais avec sa FICHE DE PORTAGE complete (releve 25/08/2026)
;
; L'ennemi DOMINANT du stage 2 : 29 des 34 spawns de cast. Il se tient sur le
; decor — plafond ou sol — puis plonge en diagonale vers l'intrus.
;
; FICHE DE PORTAGE (source : base Ghidra `maincpu`, subsystem enemy_gouger)
; -------------------------------------------------------------------------
;   40:6f89 create_gouger .............. le spawner
;   40:6fd0 run_gouger ................. le tick, machine a TROIS etats
;   40:7048 .... phase B, la plongee
;   40:7106 .... phase C, le recul apres un coup (0x17 = 23 trames)
;   40:70e3 .... la mort ; 40:7155 .... le retrait silencieux
;   40:7168 draw_gouger_with_hit_blink . le clignotement de coup
;   40:f9f0 load_gouger_preset ......... les quatre variantes
;   1000:9384 la table des variantes (4 x 7 mots)
;   1000:93bc la case +0x34 (4 mots)
;   1000:307e..30fe les quatre tables de poses (16 mots = 8 poses x2)
;   1000:31ee l'AABB
;
; CE QUE PORTE LE DESCRIPTEUR DE WAVE. Le 5e octet, et lui seul (le subtype
; vaut $00 sur les 29 lignes) :
;   bits 0-1 -> la VARIANTE de mouvement (load_gouger_preset, CL & 3)
;   bits 2-3 -> la case +0x34 (load_motion_param_preset_4, (CL >> 2) & 3)
; Les quatre variantes sont toutes employees par la wave.
;
; LES QUATRE VARIANTES, et elles tombent une a une sur nos dossiers d'images :
;
;   var  y      vx      vy     traine x  traine y  poses     images
;   ---  -----  ------  -----  --------  --------  --------  -------------
;    0   $0178  +1.500  -2.000   +0.375    -0.500  1000:30DE  top-right
;    1   $0178  -1.500  -2.000   -0.375    -0.500  1000:30BE  top-left
;    2   $0098  +1.500  +2.000   +0.375    +0.500  1000:309E  bottom-right
;    3   $0098  -1.500  +2.000   -0.375    +0.500  1000:307E  bottom-left
;
; L'axe Y arcade monte : $0178 (376) est donc le PLAFOND et $0098 (152) le
; SOL — les variantes 0 et 1 descendent (vy negatif), les 2 et 3 montent.
; X est fixe a $02D0, juste a droite de l'ecran.
;
; LES POSES. La table d'une variante fait seize mots, mais ce sont HUIT slots
; repetes deux fois — et le cycle fait un aller-retour :
;   30FE 312E 315E 318E 315E 312E 30FE 31BE   (var 3, les autres sont
;                                              identiques a l'adresse pres)
; L'index arcade vaut (anim & 0x3C) >> 1, soit un slot toutes les QUATRE
; trames ; ramene a nos images : slot = (anim >> 2) & 7. La plongee, elle,
; force l'offset 4 — donc le SLOT 2, fixe.
;
; MAIS CES HUIT SLOTS NE FONT PAS HUIT IMAGES. L'aller-retour repasse par les
; memes poses : n'en sont importees que les DISTINCTES
; (arcade_to_sprites.py --dedup, ecrit le 25/08/2026 pour ca). Chaque dossier
; porte sa table slot -> pose dans cycle.txt :
;
;   top-right     5 poses   0 1 2 3 2 1 0 4
;   top-left      5 poses   0 1 2 3 2 1 0 4
;   bottom-right  4 poses   0 1 2 3 2 1 0 3   <- sa 8e pose est identique a la 4e
;   bottom-left   5 poses   0 1 2 3 2 1 0 4
;
; 19 sprites au lieu de 32, soit 41 % de moins, sans rien perdre. La table de
; bottom-right differe d'une entree : le code objet porte donc DEUX tables, pas
; une. Verification independante : les doublons attendus depuis la table arcade
; se retrouvaient exactement dans les images converties avant deduplication.
;
; Chaque pose est un META-SPRITE de DEUX sprites (write_2_sprites) : nos PNG
; 24x48 sont les deux tranches deja composees.
;
; LE FLASH DE COUP : une image blanche par orientation, quatre en tout
; (images/hit/00..03, dans l'ordre des variantes). C'est la POSE 2 qui est
; blanchie — celle que la plongee fige, donc la plus vue. Voir
; tools/gen_gouger_hit.py.
;
; LA MACHINE A TROIS ETATS
;
;   A — cache. Le bit de signe de +0x34 dit plafond ou sol. Tant que la
;       direction rendue par set_direction_to(player_one) differe de celle
;       gravee en +0x36 ($0018/$0028/$0008/$0038 selon la variante), le corps
;       ne bouge pas. Des qu'elle correspond, le tick passe en phase B.
;
;   B — la plongee. Chaque trame : x_pos += scroll_amount (verrou de defilement),
;       puis SONDE DU DECOR au centre.
;         . case VIDE  -> vitesse PRIMAIRE (+0x30/+0x32) et pose FIXE (2).
;         . case SOLIDE-> vitesse de TRAINEE (+0x38/+0x3A), animation, et le
;                         son 0x5F toutes les 0x20 trames.
;       ATTENTION : la plate Ghidra affirmait l'inverse. Le desassemblage est
;       sans ambiguite — `CMP AX,0xFA0 / JZ 0x7086`, et 0x7086 prend la vitesse
;       primaire. Or 0xFA0 est la case VIDE (seule case franchissable, cf. la
;       fiche de probe_foreground_tile) : le gouger RAMPE sur le decor en
;       s'animant, et PLONGE quand il n'y a plus rien sous lui. La plate est
;       corrigee dans la base.
;
;   C — le recul, 0x17 = 23 trames apres chaque coup encaisse. Il continue de
;       defiler et de s'animer, et clignote une trame sur quatre.
;
; PV = 10 (le spawner ecrase la table de difficulte par un $0A inconditionnel).
; Mort : son 0x53, score $86F8, puis grosse explosion gris-brun (40:e817).
; Retrait silencieux hors cadre, mais SEULEMENT si aucun coup n'a ete encaisse
; cette trame — le test de visibilite est dans cette branche-la.
;
; LA SONDE, cote v2. L'arcade lit l'index de tuile et le compare a 0xFA0 ;
; nous avons terrainCollision.do, qui rend B != 0 sur du solide :
;       ldd   <x>  / std terrainCollision.sensor.x
;       ldd   <y>  / std terrainCollision.sensor.y
;       ldb   #1   / jsr terrainCollision.do / tstb
; B = 0 vaut donc « case vide » et rend exactement le test arcade.
;
; CE QUI DEMANDERA UN ARBITRAGE
; - le clignotement de coup passe par un echange de palette d'objet ; la
;   palette TO8 est globale au stage. Meme choix que pour le serpent :
;   une image blanche, ou rien.
; - les sons (0x5F traine, 0x57 coup, 0x53 mort) : aucun ennemi de ce portage
;   n'a de son a ce jour.
; - 23 sprites de 24x48 a compiler (19 poses + 4 blanches), soit ~11,7 Ko a
;   l'estimation de 0,44 octet par pixel relevee sur le serpent. L'arene
;   stage2.foes n'occupe que trois de ses sept pages ; les sprites y prendront
;   leur propre entree de repertoire, le cast n'ayant pas la place.
; - PAS de variante decalee d'un pixel, vu la taille des sprites — meme choix
;   que pour l'outslay.
;*******************************************************************************

gouger.Object
        jmp   stage2.cast.stub          ; implementation vide : compter, rendre le slot
