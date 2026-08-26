# La difficulté arcade : d'où elle vient, ce qu'elle change

Relevé le 26/08/2026 sur la base Ghidra `maincpu`, en partant des références à
l'octet `0x4000_2F2E`. Écrit après avoir figé le wick sur la colonne 0 « par
convention » — ce n'était pas une convention, c'était un oubli.

## 1. Ce n'est pas un réglage : c'est une valeur DÉRIVÉE, recalculée chaque trame

Le tick du joueur (`run_player_one`, `0x40:2027`) reconstruit `0x2F2E` **à
chaque trame**, avant que le moindre ennemi ne le lise :

```
difficulté = 0
si second_loop (0x2F2D)      -> += 2
sinon si DIP2:4 « Hard »     -> += 1        (bit 0x0800 de 0x2044)
si indice_de_stage >= 2      -> += 1        ([BP+0x1E])
plafonné à 3
```

Trois conséquences qu'on ne devine pas :

- **Elle monte avec la progression.** En première boucle et DIP Normal, les
  stages 1 et 2 tournent en difficulté **0** et les stages 3 à 8 en **1**. Le
  même ennemi n'a donc pas le même comportement selon le stage où il apparaît.
- **Le DIP et la boucle ne s'additionnent pas** : la seconde boucle *remplace*
  le bonus de DIP (`sinon si`), elle ne s'y ajoute pas.
- **C'est le joueur qui la pose.** Sans tick joueur — écran de fin, pause —
  elle garde sa dernière valeur.

### Ce que fait notre portage aujourd'hui

`stage-main.asm` sème `globals.difficulty` **à 0 une fois par partie** et ne la
relève jamais (décision auteur du 20/08, et le commentaire sur place annonce
déjà « la rampe progressive reste à porter le jour venu »). Tant qu'elle n'est
pas portée, tout ce qui suit se joue en colonne 0 — mais **le code des ennemis
doit lire la table**, pas figer la colonne : le jour où la rampe arrive, les
comportements suivent sans retoucher un ennemi.

## 2. Ce qu'elle module, objet par objet

Toutes les tables sont dans le segment de données `0x1000`. « rang » = la
largeur d'une entrée.

| Objet | Où | Ce que ça change | Table | rang |
|---|---|---|---|---|
| **mid** | `create_mid` +16 | vitesse (vx, vy) — et le délai de tir, amorcé sur vx : un mid rapide tire moins souvent | `0x298A` | 4 |
| **tabrok** | `run_tabrok_cannon` +80 | graine de la table de guidage des missiles | `0x2B58` | 2 |
| **tabrok** | `run_tabrok_missile_run_mode_1` +70 | base de la table de vitesses des missiles | `0x2C8C` | 2 |
| **cytron** | `create_cytron` +35 | **PV** (`damage_max`) | `0x2D8C` | 1 |
| **gouger** | `create_gouger` +19 | PV — **code mort** : deux instructions plus loin, `damage_max` est écrasé par `0x0A` sans condition | `0x307A` | 1 |
| **pursuer** | `create_pursuer` +33 | constante de rechargement du pas (cadence de re-visée) | `0x31F6` | 2 |
| **pursuer** | `run_pursuer` +64 | table de vitesses, puis indexée par la direction visée | `0x320E` | 2 |
| **p-staff** | `create_p_staff` +20 | durée d'un pas de marche | `0x3346` | 2 |
| **scant** | `create_scant` +363 | période de tir | `0x3856` | 2 |
| **scant** | `create_scant` +649 | vitesse du rayon | `0x385E` | 2 |
| **cheetah** | `create_cheetah` +16 | vitesse ET période des lasers enfants | `0x39B4` | 4 |
| **brood** | `create_zoid` +67 | **combien de zoids** : les trois créneaux existent, mais le troisième est refusé en difficulté 0 | — | — |
| **wick** | `wick_emitter_script_step` +3 | plancher de période et de salve d'émission | `0x3B12` | 4 |
| **wick** | `run_wick` +6 | vitesse de dérive | `0x3B2A` | 2 |
| **wick** | `_aim_attack_engage` +8 | table de vitesses du piqué — quatre tables de seize directions | `0x3B22` → `0x9010/50/90/D0` | 2 |
| **cancer** | `create_cancer` +24 | masque de réactivité : `0x7F` en 0 (re-visée toutes les ~128 trames), `0x07` en 3 (~8) | — | 2 |
| **mikun** | `run_mikun_emitter` +50 | vitesse de lancement — **partage le pool du wick** (`0x9010` pour 0..3) | `0x4284` | 2 |

### La forme est toujours la même

Quinze des dix-sept sites écrivent exactement :

```asm
MOV BL,[0x2F2E]      ; la difficulté
XOR BH,BH
ADD BX,BX            ; ... parfois deux fois, selon le rang
MOV reg,ES:[BX + table]
```

En v2 : `ldb globals.difficulty / andb #3 / aslb… / ldx #table / abx`. Le
`andb #3` n'est pas décoratif — notre variable vit dans un bloc de RAM que rien
ne charge, un résidu indexerait la table hors de ses données.

## 3. Ce qu'elle ne module PAS

Vérifié en négatif, parce que c'est aussi une information :

- **Les PV, sauf pour le cytron.** Le gouger a bien une table de PV indexée par
  la difficulté, et elle est morte — écrasée par un `0x0A` inconditionnel. Le
  wick, le brood et le zoid ont des PV constants.
- **Les boîtes de collision** : aucune table de difficulté n'y touche.
- **Le score** : les récompenses sont fixes.
- **Les waves** : la table de vagues d'un stage est la même à toute difficulté.
  Ce qui change, c'est le comportement de ce qu'elle pond.

## 4. Portée de ce relevé

La liste part de `bridge_xrefs_to 0x4000_2f2e` : 5 écritures (toutes dans le
recalcul du tick joueur) et 18 lectures. **Cette liste n'est pas exhaustive** —
mesuré ailleurs, `run_wick_aim_attack` lit `0x2ED0` sans y figurer. Le motif à
chercher pour compléter est `8a 1e 2e 2f`, et les variantes d'adressage direct
finissent toutes par les octets `2e 2f`.

Les ennemis des stages 3 à 8 non encore portés sont donc à revérifier un par
un au moment de leur portage — d'autant qu'ils tournent, eux, en difficulté 1
au minimum.
