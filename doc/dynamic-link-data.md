Les binaires exécutables sont stockés séparément des valeurs de symboles utilisés pour le link.

Lorsqu'on charge un ensemble de blocks (contenant eux même plusieurs .asm), on effectue l'écriture en RAM de tous les binaires.
Une fois les binaires chargés, on charge les définitions de symbole correspondant aux blocs chargés dans un espace tampon.
(Ex : page video de double buffer, ou espace RAM disponible. Dans le cas d'une ROM adossée à la RAM, les données peuvent être utilisées directement depuis la ROM).

Dans le cas d'un chargement d'un ou plusieurs nouveaux blocks, en présence d'autres block déjà chargés, il faudra recharger les valeurs de symboles de tous les blocks en oeuvre.
(Pour cela on se basera sur un index des blocs chargés en mémoire).
On effectuera un nouveau link complet, ceci afin de gérer le cas ou deux blocks alternent avec les mêmes id block/symboles (exemple de surcharge).

Le code doit contenir deux sections :
 SECTION constant ; pour la définition des equates dont la valeur est absolue
 SECTION code     ; pour la définition des equates dont la valeur est relative + définition du code source
 
Contrôles du builder : ORG interdit dans le code source

---------------------------------------------------------------------------------------------------

!!! On charge des blocks constitués de modules (.o), les données de link sont par module ?
ou par block ?
Si on fait deux blocks distincts (id !=) avec les mêmes .asm on a donc des symboles identiques, mais le block est différent
L'avantage d'un block c'est de permettre un agencement optimisé du code dans les pages.
Le build se fait donc sur le code agrégé ... ah tiens ...
mais sur une page entiere seulement (ou il faut ajouter la notion de page aux adresses dans les data link)

Un outil indépendant devra pouvoir générer cette liste optimisée d'asm en blocks (reorder in place dans le fichier qui définit les blocks)
Un autre outil indépendant proposera d'agencer les blocks entre eux dans la map complète de la RAM (reorder in place dans le fichier qui liste les blocks)
Outil graphique ?



BLOCK RUNTIME INDEX
-------------------
; stocke la page et l'adresse des ressources chargées en RAM au runtime          
                    
!!!! A revoir
                    
06 0000 :    03 0100                       ; link data (export constant) [page] [address]
             03 0106                       ; link data (export) [page] [address]
             03 010A                       ; link data (local) [page] [address]
             03 010E                       ; link data (import) [page] [address]
             
block1
             0000 04 0000                       ; module 0: code [page] [address]
             0001 04 123C                       ; module 1: code [page] [address]
             0007 05 2F10                       ; module 7: code [page] [address]
             FFFF                               ; end marker

MODULE CODE
-----------
          
04 0000 : FC0000010E3A20002100220023002400 ; code (0D6B bytes)
          162017B018FF2605270128A536043730
          38F630813183324433843484200F1045
          2019116B21133A12B02217130014E524
          ...

MODULE LINK DATA (export constant)
----------------------------------

03 0100 :    0002                             ; nb of symbols
             0003                             ; value of symbol 1
             0004                             ; value of symbol 2

MODULE LINK DATA (export)
-------------------------

03 0106 :    0001                             ; nb of symbols
             0586                             ; value of symbol 0 (should add section base address to this value before applying)
             
MODULE LINK DATA (local)
------------------------
            
03 010A :    8162 00C3                        ; end marker (bit7=1) [dest offset] [val offset] - example : internal ( I16=195 IS=\02code OP=PLUS ) @ 0162

MODULE LINK DATA (import)
-------------------------
             
03 010E :    0001 FFF4 0003 0001              ; [dest offset] [val offset] [id block] [id ref] - example : external ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
             003E 0000 0003 0002              ;                                                            external ( ES=ymm.music.processFrame ) @ 003E
             C014 0000 0003 0001              ; end marker (bit7=1) 8bit flag  (bit6=1)                    external 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014

On n'a pas parlé des id de pages ... il va falloir voir ça !