-------------------------------------------------------------------------------
Builder (Conception générale)
-------------------------------------------------------------------------------

Chaque asm doit contenir deux sections :
 SECTION constant ; pour la définition des equates dont la valeur est absolue
 SECTION code     ; pour la définition des equates dont la valeur est relative + définition du code source
 
Contrôles du builder : ORG interdit dans le code source

Il n'est pas utile de dédoublonner Les symboles EXTERNAL avant passage de la commande LWASM
LWASM va naturellement fusionner les sections des asm, on concatène donc les fichiers d'un filegroup avant compilation
Les ID de symboles externes sont définis en triant les symboles par ordre alphabetique au sein d'un block

??? L'ID de file est défini manuellement dans la déclaration des filegroup

Les binaires exécutables sont stockés séparément des valeurs de symboles utilisés pour le link.
Sur le média (disquette ...) on a d'un coté les binaires a charger, de l'autre les données de load-time link.

Une fois les binaires chargés, on charge les définitions de symbole correspondant aux blocs chargés dans un espace tampon.
(Ex : page video de double buffer, ou espace RAM disponible. Dans le cas d'une ROM adossée à la RAM, les données peuvent être lues directement depuis la ROM).
Dans le cas d'un chargement d'un ou plusieurs nouveaux blocks, en présence d'autres block déjà chargés, il faudra recharger les valeurs de symboles de tous les blocks en oeuvre.
(Pour cela on se basera sur un index des blocs chargés en mémoire).
On effectuera un nouveau link complet, ceci afin de gérer le cas des instances multiples de filegroup ou de file.

Un outil indépendant devra pouvoir générer cette liste optimisée d'asm en blocks (reorder in place dans le fichier qui définit les blocks)
=> objectif, avoir des pages de RAM remplies au maximum

Un autre outil indépendant proposera d'agencer les blocks entre eux dans la map complète de la RAM (reorder in place dans le fichier qui liste les blocks)
=> objectif, organiser les données d'un game mode au mieux en ordonant les blocks en ram 
Outil graphique ?

Si on a besoin de "monter" une page :
- utiliser un symbole external (ex: block.0.page EXTERNAL)
- utiliser un nommage spécifique lié au block (ex : lda   #block.0.page)

Le builder va se charger de générer ce symbole dans un block généré dynamiquement (id 0), et qui contiendra les offsets de page pour chaque block référencé en externe
au niveau du projet. dans un projet, les blocks qui ne partagent pas la même interface ont un id différent.

Au build, l'outil java doit faire un pre link des références externes en récupérant le numéro de block correspondant au symbole.
De ce fait, il attribut également un id au symbole.
Dans le cas de deux blocs avec le même id, la liste des exports doit être identique.
Les exports sont triés par ordre alphabétique de manière a avoir les mêmes index entre deux blocks partageant la même interface.

Nouveautés : 
- A l'écriture du code, on défini des fichiers (file) et des groupes de fichiers (filegroup)
- le filegroup sert à :
        - définir un id pour le chargement d'un ensemble de fichiers au runtime
        - permet le chargement d'une zone mémoire continue en RAM d'un seul coup (compression d'une suite continue de fichiers)
        - optimiser l'usage de la RAM en effectuant un précalcul de répartition dans le cas de paginated filegroup
        - les paginated filegroups sont divisés en filegroups par outillage avant le build en fonction d'un org prédéfini, il en resulte la définition de plusieurs filegroups
        - au runtime, le link se fait entre filegroups, ce qui diminue la quantité d'index nécessaire (par rapport à une gestion fichier par fichier).
                

J'ai terminé le chargement des .o en java hier et je suis resté calqué sur le modèle de données de lwasm. En particulier pour le moteur d'expression (celui qui applique les fameux opérateurs d'addition et autres.
et là surprise, pour résoudre les références internes lwasm utilise déjà le moteur d'expression (addresse de base de la section, opérateur +, offset de l'étiquette)

voila un exemple de code objet :
        ldd    player1+x_pos

au build en .o ça donne ça :
    Incomplete references
        ( I16=18 ES=player1 OP=PLUS ) @ 0001
Code : FC0000 ...

soit : à la position 0001 du code, on applique la référence externe player1 et on réalise l'opération PLUS avec la valeur decimale 18 (x_pos)

Je viens de tester en remplaçant le + par un moins dans l'expression ci dessus et j'ai :
    Incomplete references
        ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
donc en "théorie" on ne devrait avoir besoin que de l'opérateur + (et je pense que je ne vais en gérer qu'un seul sam, ton idée me semble raisonable, si on est bloqué plus tard je ferai évoluer) 
=> je vais partir la dessus

Juste une précision pour l'histoire du player1+x_pos, si l'emplacement "player1" ne bouge pas pendant tout le programme (ce qui est le cas dans la réalité, c'est fixe en $9F00), on a tout intérêt a déterminer sa valeur en equate dans un fichier global et à l'importer dans chaque fichier .asm qui en a besoin. Dans ce cas l'adresse est hardcodée et il n'y aura aucune résolution au runtime.
Dans le builder actuel, on "voit" la valeur player1 partout car les equates du main sont automatiquement importés comme include des objets. Dans la v2 il n'y aura plus ces mécanismes dissimulés en "dur" dans le builder, on fera les includes de manière normale dans l'asm. 

                
-------------------------------------------------------------------------------
load-time linker
-------------------------------------------------------------------------------

The load-time linker keep a state of loaded filegroups at runtime.
When a load is requested, parameters are : filegroup id, destination (page/addr)
User can request if a particular filegroup is actually loaded in RAM.
A filegroup can also be unloaded by user request.
Filegroup alias is a text value that is unique in a project (checked at build time).
The builder set an id number for each filegroup alias and export equates at build time.
User must declare equates as EXTERNAL and use this syntax : ldd   #builder.filegroup.<alias> when requesting filegroup to be loaded, or when checking if a filegroup is loaded.
File exported equates must be unique in the whole project.
When paginated filegroup are used, each filegroup must be loaded manually at runtime, it does not change anything for the code as dynamic link resolve addresses.
For paginated filegroup, the builder generates equates as EXTERNAL : builder.pageOffset.<file alias>
file alias are requested only for paginated filegroup.
This value should be added at runtime to the known page id where filegroup was loaded.
known page id must be set as equates for each "scene" (see loader samples)

loaded filegroups at runtime
----------------------------

*** RAM

linker.filegroup.page
             04                                 ; [page]
linker.filegroup.addr
             0C00                               ; [address]

*** RAM or ROM

linker.filegroup.size equ 3                     ; allocated space for array is based on used defined equate (2+linker.filegroup.size*10)

04 0C00      0003                               ; [nb of elements]
             0000 04 0000 03 0100               ; [filegroup:id] [code:page] [code:address] [linkmeta:page] [linkmeta:address]
             0000 04 123C 03 0200               ; [filegroup:id] [code:page] [code:address] [linkmeta:page] [linkmeta:address]
             0000 05 2F10 03 0300               ; [filegroup:id] [code:page] [code:address] [linkmeta:page] [linkmeta:address]
             ...

filegroup binaries
------------------
          
*** RAM or ROM
          
04 0000 : FC0000010E3A20002100220023002400      ; code (0B6B bytes)
          162017B018FF2605270128A536043730
          38F630813183324433843484200F1045
          2019116B21133A12B02217130014E524
          ...

filegroup link metadata (5 consecutive arrays)
----------------------------------------------

- exported constant

03 0100 :    0002                             ; [nb of elements]
             0003                             ; value of symbol 1
             0004                             ; value of symbol 2

- exported

03 0106 :    0001                             ; [nb of elements]
             0586                             ; value of symbol 0 (should add section base address to this value before applying)
             
- local
            
03 010A :    0001                             ; [nb of elements]
             0162 00C3                        ; [dest offset] [val offset] - example : internal ( I16=195 IS=\02code OP=PLUS ) @ 0162

- incomplete (8bit)
             
03 0122 :    0001                             ; [nb of elements]
             0014 0000 0003 0001              ; [dest offset] [val offset] [id block] [id ref] - example : external 8bit ( FLAGS=01 ES=ymm.NO_LOOP ) @ 0014

- incomplete (16bit)
             
03 0110 :    0002                             ; [nb of elements]
             0001 FFF4 0003 0001              ; [dest offset] [val offset] [id block] [id ref] - example : external ( I16=-12 ES=Obj_Index_Address OP=PLUS ) @ 0001
             003E 0000 0003 0002              ;                                                            external ( ES=ymm.music.processFrame ) @ 003E

-------------------------------------------------------------------------------
filegroup Loader
-------------------------------------------------------------------------------

- décrire ici le principe du loader
- gestion de l'entrelacement disquette
- version disquette, version T2 (un loader par média)
- exemple de l'utilisation d'un loader dans le cadre d'une initialisation
        - code de chargement en zone tampon
        - stockage du loader et des données d'index de manière séparée
- expliquer le principe de fonctionnement (comme charge t on le loader ?) => bootloader

-------------------------------------------------------------------------------
Boot loader
-------------------------------------------------------------------------------

- Principe de chargement en $6200 du secteur 1
- personalisation du code (objet + component ?)
- loader simplifié : chargement des données situées après le secteur 1 en respectant l'entrelacement, vers une destination spécifique.
- le nombre de secteurs à lire est déterminé par le builder (EXPORT builder.bootloader.sectors), le builder se base sur la taille des données du filegroup a positionner sur le média disquette en secteur 2
- la destination et le point de lancement est déterminé par include d'equates dans le filegroup du bootloader : bootloader.page bootloader.address
- version disquette / T.2

- TODO : tous les secteurs de boot sont en 1 ?  clarifier la définition du boot et du filegroup de loader

-------------------------------------------------------------------------------
Graphical Editor
-------------------------------------------------------------------------------

- declare binary Asset
- convert binary Asset
- write assembly code
- produce an assembly binary as an Asset (Bootloader, Loader, ...)
- use engine Assets defined as Packages
- declare a Component (assembly code with a specific interface)
- declare an Object (To be used by "managed object" engine routines)
- use engine Objects defined as Packages
- add Components to Objects
- write Component's assembly code
- use engine Components defined as Packages
- declare Files by adding Objects, Components or Assets
- declare FileGroups by adding Files
- declare Medium
- Build Medium
- Execute/Debug Medium

Note : Packages are engine or custom groups of Assets, Components or Objects that are imported in a project