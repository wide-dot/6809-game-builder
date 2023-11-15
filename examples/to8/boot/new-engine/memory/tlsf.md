# Allocation dynamique de mémoire pour Motorola 6809

## TLSF (Two-Level Segregated Fit)

TLSF est un algorithme dont la complexité en temps des fonctions malloc et free est O(1).
Le temps d'exécution est prévisible et ne dépend pas du niveau de fragmentation de la mémoire.
Concrètement, cela signifie qu'il n'y a pas de boucle dans le code pour effectuer la recherche d'un bloc libre d'une taille optimale lors d'un malloc.
Les mécanismes employés permettent d'obtenir ce bloc libre de manière indexée.
Les résultats obtenus en terme de fragmentation mémoire sont proches d'une solution de type "best-fit".

Publications :
- [A constant-time dynamic storage allocator for real-time systems.](./paper/jrts2008.pdf) Miguel Masmano, Ismael Ripoll, et al. Real-Time Systems. Volume 40, Number2 / Nov 2008. Pp 149-179 ISSN: 0922-6443.
- [Implementation of a constant-time dynamic storage allocator.](./paper/spe_2008.pdf) Miguel Masmano, Ismael Ripoll, et al. Software: Practice and Experience. Volume 38 Issue 10, Pages 995 - 1026. 2008.

### Principe de fonctionnement

Le système d'allocation mémoire est constitué des éléments suivants :

- **memory pool**   
    Il s'agit d'une zone de mémoire continue dans laquelle sont stockées les données allouées par l'utilisateur, les propriétés des emplacements libres et allouées.

- **linked list head matrix**   
    Cette matrice stocke le point d'entrée de chaque liste chainée référençant les emplacements libres du *memory pool*. Les listes chainées rassemblent des emplacements de tailles similaires.

- **first level bitmap**   
    Le premier niveau d'indexation est stocké sous la forme d'un mot de 16 bits. Chaque bit indique l'existance d'au moins une liste chainée dans le second niveau d'indexation. Le classement s'effectue par puissance de 2 sur la taille de l'emplacement.

- **second level bitmaps**   
    Le second niveau d'indexation utilise un mot de 16 bits pour chaque premier niveau d'indexation. Chaque bit indique l'existance dans la *linked list head matrix* d'une liste chainée contenant des emplacements de mémoire libres. Le classement s'effectue de manière linéaire sur la taille de l'emplacement.

#### Initialisation

L'initialisation du gestionnaire d'allocation mémoire consiste en :   

1. la réinitialisation des données *linked list head matrix*, *first level bitmap*, *second level bitmaps*
2. la création d'un emplacement libre dans le *memory pool*
3. le positionnement d'un bit dans le *first level bitmap*
4. le positionnement d'un bit dans une des *second level bitmaps*
5. le référencement d'un départ de liste chainée dans la *linked list head matrix* pointant sur l'emplacement créé dans le *memory pool* à l'étape 1

#### Stockage des données dans le *memory pool*

La création d'un emplacement libre dans le *memory pool* s'effectue par l'écriture des données suivantes à l'adresse de l'emplacement :

- [ 1 bit ] type d'emplacement (1: libre)
- [15 bits] taille-1 (3-x7FFF)   
- [16 bits] emplacement physique précédent (adresse)
- [16 bits] emplacement libre précédent dans la liste chainée (adresse)
- [16 bits] emplacement libre suivant dans la liste chainée (adresse)

La création d'un emplacement alloué dans le *memory pool* s'effectue par l'écriture des données suivantes à l'adresse de l'emplacement :

- [ 1 bit ] type d'emplacement (0: alloué)
- [15 bits] taille-1 (0-x7FFF)   
- [16 bits] emplacement physique précédent (adresse)

Un emplacement libre a une taille minimum de 4 octets, cela permet de transformer un emplacement occupé (entête de taille 4 octets) en emplacement libre (entête de taille 8 octets).

Les implémentations de TLSF pour les processeurs 32bits ou plus peuvent utiliser un positionnement du bit de type d'emplacement en début de mot et non en fin (comme proposé ici). Cette solution est pertinente dans le cas où il est nécessaire de garantir un alignement des données (mots de 4 octets par exemple). Cela permet de libérer deux bits non significatifs en début du mot.   
Dans l'implémentation proposée pour le 6809, l'utilisation du bit de signe est préférable car cela permet un test plus rapide du type d'emplacement. D'autre part cela permet de conserver une allocation à l'octet près (au dela du minimum de 4).









